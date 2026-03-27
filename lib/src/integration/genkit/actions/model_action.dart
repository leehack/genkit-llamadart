import 'dart:async';

import 'package:genkit/plugin.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;

import '../../../api/generation_config.dart';
import '../../../api/model_definition.dart';
import '../../../core/runtime/engine_registry.dart';
import '../../../core/runtime/llama_runtime.dart';
import '../../../core/streaming/completion_accumulator.dart';
import '../action_support.dart';
import '../converters/genkit_to_llama.dart';
import '../converters/llama_to_genkit.dart';

typedef _ModelActionContext =
    genkit.ActionFnArg<genkit.ModelResponseChunk, genkit.ModelRequest, void>;

genkit.Model<LlamaDartGenerationConfig> buildModelAction({
  required LlamaModelDefinition definition,
  required EngineRegistry registry,
}) {
  final modelInfo = modelInfoFor(definition);
  final actionName = actionNameFor(definition.name);

  return genkit.Model<LlamaDartGenerationConfig>(
    name: actionName,
    metadata: actionMetadataFor(definition, modelInfo: modelInfo),
    fn: (request, context) {
      if (request == null) {
        throw genkit.GenkitException(
          'Model request cannot be null.',
          status: genkit.StatusCodes.INVALID_ARGUMENT,
        );
      }

      return registry.withRuntime(
        definition.name,
        (runtime) => _runModel(
          definition: definition,
          runtime: runtime,
          request: request,
          context: context,
        ),
      );
    },
  );
}

Future<genkit.ModelResponse> _runModel({
  required LlamaModelDefinition definition,
  required LlamaRuntime runtime,
  required genkit.ModelRequest request,
  required _ModelActionContext context,
}) async {
  if (request.docs != null && request.docs!.isNotEmpty) {
    throw genkit.GenkitException(
      'llamadart model actions do not support `docs` yet.',
      status: genkit.StatusCodes.INVALID_ARGUMENT,
    );
  }

  final hasTools = request.tools?.isNotEmpty ?? false;
  if (hasTools && !definition.supportsTools) {
    throw genkit.GenkitException(
      'Tool use is disabled for `${definition.name}`.',
      status: genkit.StatusCodes.FAILED_PRECONDITION,
    );
  }

  if (shouldUseStructuredGeneration(request.output) &&
      !definition.supportsConstrainedOutput) {
    throw genkit.GenkitException(
      'Constrained output is disabled for `${definition.name}`.',
      status: genkit.StatusCodes.FAILED_PRECONDITION,
    );
  }

  final config = LlamaDartGenerationConfig.fromJson(request.config);
  final messages = toLlamaMessages(request.messages);
  final tools = toLlamaTools(request.tools);
  final params = toGenerationParams(config);
  final toolChoice = toLlamaToolChoice(
    request.toolChoice,
    hasTools: tools.isNotEmpty,
  );
  final started = Stopwatch()..start();

  if (shouldUseStructuredGeneration(request.output)) {
    if (tools.isNotEmpty && toolChoice != llama.ToolChoice.none) {
      throw genkit.GenkitException(
        'llamadart does not support constrained structured output with tools yet.',
        status: genkit.StatusCodes.UNIMPLEMENTED,
      );
    }

    return _runStructuredModel(
      definition: definition,
      runtime: runtime,
      messages: messages,
      config: config,
      params: params,
      output: request.output,
      context: context,
      started: started,
    );
  }

  return _runStreamingModel(
    definition: definition,
    runtime: runtime,
    messages: messages,
    tools: tools,
    toolChoice: toolChoice,
    config: config,
    params: params,
    context: context,
    started: started,
  );
}

Future<genkit.ModelResponse> _runStreamingModel({
  required LlamaModelDefinition definition,
  required LlamaRuntime runtime,
  required List<llama.LlamaChatMessage> messages,
  required List<llama.ToolDefinition> tools,
  required llama.ToolChoice? toolChoice,
  required LlamaDartGenerationConfig config,
  required llama.GenerationParams params,
  required _ModelActionContext context,
  required Stopwatch started,
}) async {
  final accumulator = CompletionAccumulator();

  await for (final chunk in runtime.create(
    messages,
    params: params,
    tools: tools.isEmpty ? null : tools,
    toolChoice: toolChoice,
    parallelToolCalls:
        config.parallelToolCalls ??
        LlamaDartGenerationConfig.defaultParallelToolCalls,
    enableThinking:
        config.enableThinking ??
        LlamaDartGenerationConfig.defaultEnableThinking,
    sourceLangCode: config.sourceLangCode,
    targetLangCode: config.targetLangCode,
    chatTemplateKwargs: config.chatTemplateKwargs,
  )) {
    accumulator.addChunk(chunk);
    if (context.streamingRequested) {
      final responseChunk = toGenkitChunk(chunk);
      if (responseChunk != null) {
        context.sendChunk(responseChunk);
      }
    }
  }

  return toGenkitModelResponse(
    accumulator.toResult(),
    latencyMs: started.elapsedMilliseconds.toDouble(),
    raw: rawResponseMetadata(definition),
  );
}

Future<genkit.ModelResponse> _runStructuredModel({
  required LlamaModelDefinition definition,
  required LlamaRuntime runtime,
  required List<llama.LlamaChatMessage> messages,
  required LlamaDartGenerationConfig config,
  required llama.GenerationParams params,
  required genkit.OutputConfig? output,
  required _ModelActionContext context,
  required Stopwatch started,
}) async {
  final responseFormat = toResponseFormat(output);
  final template = await runtime.chatTemplate(
    messages,
    addAssistant: true,
    tools: null,
    toolChoice: llama.ToolChoice.none,
    parallelToolCalls: false,
    enableThinking:
        config.enableThinking ??
        LlamaDartGenerationConfig.defaultEnableThinking,
    responseFormat: responseFormat,
    sourceLangCode: config.sourceLangCode,
    targetLangCode: config.targetLangCode,
    includeTokenCount: false,
    chatTemplateKwargs: config.chatTemplateKwargs,
  );

  final stops = <String>{
    ...template.additionalStops,
    ...params.stopSequences,
  }.toList(growable: false);
  final inputParts = <llama.LlamaContentPart>[];
  for (final message in messages) {
    inputParts.addAll(message.parts);
  }

  final rawOutput = StringBuffer();
  await for (final token in runtime.generate(
    template.prompt,
    params: params.copyWith(
      stopSequences: stops,
      grammar: template.grammar,
      grammarLazy: template.grammarLazy,
      grammarTriggers: template.grammarTriggers
          .map((trigger) {
            return llama.GenerationGrammarTrigger(
              type: trigger.type,
              value: trigger.value,
              token: trigger.token,
            );
          })
          .toList(growable: false),
      preservedTokens: <String>{
        ...template.preservedTokens,
        ...params.preservedTokens,
      }.toList(growable: false),
    ),
    parts: inputParts,
  )) {
    rawOutput.write(token);
    if (context.streamingRequested) {
      context.sendChunk(
        genkit.ModelResponseChunk(
          role: genkit.Role.model,
          content: <genkit.Part>[genkit.TextPart(text: token)],
          aggregated: false,
        ),
      );
    }
  }

  final parsed = llama.ChatTemplateEngine.parse(
    template.format,
    rawOutput.toString(),
    parseToolCalls: false,
    thinkingForcedOpen: template.thinkingForcedOpen,
    parser: template.parser,
  );

  final parts = <genkit.Part>[];
  if (parsed.reasoningContent != null && parsed.reasoningContent!.isNotEmpty) {
    parts.add(genkit.ReasoningPart(reasoning: parsed.reasoningContent!));
  }

  if (parsed.content.isNotEmpty || parts.isEmpty) {
    parts.add(genkit.TextPart(text: parsed.content));
  }

  return genkit.ModelResponse(
    message: genkit.Message(role: genkit.Role.model, content: parts),
    finishReason: genkit.FinishReason.stop,
    latencyMs: started.elapsedMilliseconds.toDouble(),
    raw: rawResponseMetadata(definition, structured: true),
  );
}
