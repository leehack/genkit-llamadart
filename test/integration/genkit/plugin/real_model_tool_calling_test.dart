@Tags(['real-model', 'tool-model'])
library;

import 'package:genkit/genkit.dart';
import 'package:genkit/plugin.dart' as api;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

import '../test_support/real_model_test_support.dart';

void main() {
  test(
    'pinned Qwen3 completes real tool loops and honours tool choice',
    () async {
      final path = await requireIntegrationToolModelPath();
      final plugin = llamaDart(
        models: [
          LlamaModelDefinition(
            name: 'tool-qualified',
            modelPath: path,
            supportsEmbeddings: false,
            modelParams: const ModelParams(
              contextSize: 4096,
              device: ComputeDevice.cpu,
            ),
          ),
        ],
      );
      final ai = Genkit(plugins: [plugin], isDevEnv: false);
      addTearDown(() async {
        await plugin.dispose();
        await ai.shutdown();
      });
      var calls = 0;
      var code = '';
      final tool = ai.defineTool<Map<String, dynamic>, String>(
        name: 'get_verification_code',
        description: 'Retrieve the current verification code. Call once.',
        inputSchema: SchemanticType.from(
          jsonSchema: {
            'type': 'object',
            'properties': <String, dynamic>{},
            'additionalProperties': false,
          },
          parse: (value) => (value as Map).cast<String, dynamic>(),
        ),
        outputSchema: SchemanticType.string(),
        fn: (input, _) async {
          expect(input, isEmpty);
          calls++;
          return ToolResult.response(code);
        },
      );
      final finishAfterRequired = ai.defineGenerateMiddleware<void>(
        name: 'finishAfterRequired',
        create: (_, _) => _FinishAfterRequired(),
      );
      for (final choice in [ToolChoice.auto, ToolChoice.required]) {
        calls = 0;
        code = 'NORTHSTAR-${choice == ToolChoice.auto ? 48271 : 93652}';
        final result = await ai.generate(
          model: llamaDart.model('tool-qualified'),
          system:
              'Use the tool to retrieve the code. After receiving its result, '
              'reply with that exact code and nothing else. Call the tool once.',
          prompt: 'What is the current verification code? Do not guess.',
          tools: [tool],
          toolChoice: choice,
          maxTurns: 3,
          use: choice == ToolChoice.required ? [finishAfterRequired()] : null,
          config: const LlamaDartGenerationConfig(
            temperature: 0,
            seed: 42,
            maxTokens: 128,
          ),
        );
        expect(
          result.finishReason,
          FinishReason.stop,
          reason: '$choice: ${result.error}',
        );
        expect(calls, 1, reason: '$choice must execute a real tool request');
        expect(result.text, contains(code));
        final history = result.messages;
        expect(
          history.any((m) => m.content.any((p) => p.isToolRequest)),
          isTrue,
        );
        expect(
          history.any(
            (m) =>
                m.role == Role.tool &&
                m.content.any(
                  (p) => p.toolResponsePart?.toolResponse.output == code,
                ),
          ),
          isTrue,
        );
      }
      calls = 0;
      final none = await ai.generate(
        model: llamaDart.model('tool-qualified'),
        prompt: 'Call get_verification_code to retrieve the verification code.',
        tools: [tool],
        toolChoice: ToolChoice.none,
        config: const LlamaDartGenerationConfig(temperature: 0, maxTokens: 32),
      );
      expect(none.finishReason, isNot(FinishReason.failed));
      expect(calls, 0);
      expect(
        none.messages.expand((m) => m.content).any((p) => p.isToolRequest),
        isFalse,
      );

      final truncated = await ai.generate(
        model: llamaDart.model('tool-qualified'),
        prompt: 'Retrieve the verification code with the tool.',
        tools: [tool],
        toolChoice: ToolChoice.required,
        config: const LlamaDartGenerationConfig(temperature: 0, maxTokens: 1),
      );
      expect(
        truncated.finishReason,
        anyOf(FinishReason.length, FinishReason.failed),
      );
      expect(calls, 0, reason: 'Truncation must not dispatch a partial call');

      final action = (await plugin.init())
          .whereType<api.Model<LlamaDartGenerationConfig>>()
          .single;
      final cancellation = CancellationController();
      await expectLater(
        action(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'Retrieve the verification code.')],
              ),
            ],
            config: const LlamaDartGenerationConfig(maxTokens: 128).toJson(),
            tools: [
              ToolDefinition(
                name: 'get_verification_code',
                description: 'Retrieve the current verification code.',
                inputSchema: {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              ),
            ],
            toolChoice: ToolChoice.required,
          ),
          cancel: cancellation.token,
          onChunk: (_) => cancellation.cancel(),
        ),
        throwsA(isA<CancelledException>()),
      );
      final recovered = await ai.generate(
        model: llamaDart.model('tool-qualified'),
        prompt: 'Reply OK.',
        config: const LlamaDartGenerationConfig(temperature: 0, maxTokens: 64),
      );
      expect(recovered.finishReason, FinishReason.stop);
      expect(recovered.text.trim(), isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

// Genkit retains required across turns; the app explicitly allows a final answer.
class _FinishAfterRequired extends GenerateMiddleware {
  @override
  Future<ModelResponse> model(
    ModelRequest request,
    api.ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest,
      api.ActionFnArg<ModelResponseChunk, ModelRequest, void>,
    )
    next,
  ) {
    if (request.messages.any((m) => m.role == Role.tool)) {
      request = ModelRequest(
        messages: request.messages,
        config: request.config,
        tools: request.tools,
        toolChoice: ToolChoice.none,
        output: request.output,
        docs: request.docs,
      );
    }
    return next(request, ctx);
  }
}
