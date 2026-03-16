import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_llamadart/src/engine_registry.dart';
import 'package:genkit_llamadart/src/model_action.dart';
import 'package:llamadart/llamadart.dart' as llama;
import 'package:test/test.dart';

import 'src/fake_runtime.dart';

void main() {
  test('model action streams text and reasoning chunks', () async {
    final runtime = FakeRuntime()
      ..createChunks = <dynamic>[
        thinkingChunk('thinking'),
        textChunk('hello'),
        stopChunk(),
      ].cast();
    final action = buildModelAction(
      definition: const LlamaModelDefinition(
        name: 'local',
        modelPath: '/tmp/model.gguf',
      ),
      registry: EngineRegistry(
        models: const <LlamaModelDefinition>[
          LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
        ],
        runtimeFactory: () => runtime,
      ),
    );

    final streamed = <genkit.ModelResponseChunk>[];
    final response = await action(
      genkit.ModelRequest(
        messages: <genkit.Message>[
          genkit.Message(
            role: genkit.Role.user,
            content: <genkit.Part>[genkit.TextPart(text: 'Hi')],
          ),
        ],
      ),
      onChunk: streamed.add,
    );

    expect(streamed, hasLength(2));
    expect(streamed.first.content.first.reasoning, 'thinking');
    expect(streamed.last.text, 'hello');
    expect(response.text, 'hello');
    expect(response.message!.content.first.reasoning, 'thinking');
  });

  test(
    'model action returns tool requests from final tool call chunk',
    () async {
      final runtime = FakeRuntime()
        ..createChunks = <dynamic>[
          toolCallChunk(
            id: 'call-1',
            name: 'get_weather',
            arguments: '{"city":"Seoul"}',
          ),
        ].cast();
      final action = buildModelAction(
        definition: const LlamaModelDefinition(
          name: 'local',
          modelPath: '/tmp/model.gguf',
        ),
        registry: EngineRegistry(
          models: const <LlamaModelDefinition>[
            LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
          ],
          runtimeFactory: () => runtime,
        ),
      );

      final response = await action(
        genkit.ModelRequest(
          messages: <genkit.Message>[
            genkit.Message(
              role: genkit.Role.user,
              content: <genkit.Part>[genkit.TextPart(text: 'Weather?')],
            ),
          ],
          tools: <genkit.ToolDefinition>[
            genkit.ToolDefinition(
              name: 'get_weather',
              description: 'Get weather',
              inputSchema: <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'city': <String, dynamic>{'type': 'string'},
                },
              },
            ),
          ],
        ),
      );

      expect(response.toolRequests, hasLength(1));
      expect(response.toolRequests.single.name, 'get_weather');
      expect(response.toolRequests.single.input, <String, dynamic>{
        'city': 'Seoul',
      });
    },
  );

  test(
    'model action uses structured generation for constrained JSON output',
    () async {
      final runtime = FakeRuntime()
        ..templateResult = const llama.LlamaChatTemplateResult(
          prompt: 'prompt',
          format: 0,
        )
        ..generatedTokens = <String>['{"answer":"hi"}'];
      final action = buildModelAction(
        definition: const LlamaModelDefinition(
          name: 'local',
          modelPath: '/tmp/model.gguf',
        ),
        registry: EngineRegistry(
          models: const <LlamaModelDefinition>[
            LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
          ],
          runtimeFactory: () => runtime,
        ),
      );

      final response = await action(
        genkit.ModelRequest(
          messages: <genkit.Message>[
            genkit.Message(
              role: genkit.Role.user,
              content: <genkit.Part>[
                genkit.TextPart(text: 'Respond with JSON'),
              ],
            ),
          ],
          output: genkit.OutputConfig(
            format: 'json',
            schema: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{
                'answer': <String, dynamic>{'type': 'string'},
              },
            },
          ),
        ),
      );

      expect(runtime.chatTemplateCallCount, 1);
      expect(runtime.generateCallCount, 1);
      expect(response.text, '{"answer":"hi"}');
    },
  );
}
