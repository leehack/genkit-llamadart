import 'dart:async';

import 'package:genkit/plugin.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;

import '../../../api/generation_config.dart';
import '../../../api/model_definition.dart';
import '../../../api/media_resolver.dart';
import '../../../core/runtime/engine_registry.dart';
import '../../../core/runtime/llama_runtime.dart';
import '../../../core/runtime/operation_usage.dart';
import '../../../core/streaming/completion_accumulator.dart';
import '../action_support.dart';
import '../converters/genkit_to_llama.dart';
import '../converters/llama_to_genkit.dart';
import '../converters/remote_media.dart';
import '../request_support.dart';

typedef _ModelActionContext =
    genkit.ActionFnArg<genkit.ModelResponseChunk, genkit.ModelRequest, void>;

genkit.Model<LlamaDartGenerationConfig> buildModelAction({
  required LlamaModelDefinition definition,
  required EngineRegistry registry,
  LlamaDartMediaResolver? mediaResolver,
}) {
  final modelInfo = modelInfoFor(definition);
  final actionName = actionNameFor(definition.name);

  final action = genkit.Model<LlamaDartGenerationConfig>(
    name: actionName,
    metadata: actionMetadataFor(definition, modelInfo: modelInfo),
    fn: (request, context) async {
      final total = Stopwatch()..start();
      checkDeclaredModelRequest(definition, request);
      final LlamaDartGenerationConfig config;
      try {
        config = LlamaDartGenerationConfig.fromJson(request.config);
      } on FormatException catch (error) {
        throw genkit.GenkitException(
          error.message,
          status: genkit.StatusCode.invalidArgument,
        );
      }
      final tools = toLlamaTools(request.tools);
      final messages = await resolveLlamaMessages(
        request.messages,
        resolver: mediaResolver,
        cancel: context.cancel,
      );
      final capture = OperationUsage();
      return runZoned(() async {
        final response = await registry.withRuntime(definition.name, (
          runtime,
        ) async {
          context.cancel?.throwIfCancelled();
          final unregister = context.cancel?.onCancel(runtime.cancelGeneration);
          try {
            final response = await _runModel(
              definition: definition,
              runtime: runtime,
              capabilities: registry.capabilitiesFor(definition.name),
              request: request,
              messages: messages,
              tools: tools,
              config: config,
              context: context,
            );
            context.cancel?.throwIfCancelled();
            return response;
          } finally {
            unregister?.call();
          }
        }, beforeInitialize: context.cancel?.throwIfCancelled);
        response.usage ??= toGenkitUsage(capture.usage);
        if (capture.finishReason != null) {
          response.finishReason = mapFinishReason(capture.finishReason);
        }
        response.raw = {
          ...?response.raw,
          'queueMs': capture.queueMs,
          'initializationMs': capture.initializationMs,
          'totalLatencyMs': total.elapsedMicroseconds / 1000,
          if (capture.usage != null) 'usage': capture.usage!.toJson(),
        };
        return response;
      }, zoneValues: {operationUsageKey: capture});
    },
  );
  trackCapabilityMetadata(action.metadata, definition, registry);
  return action;
}

Future<genkit.ModelResponse> _runModel({
  required LlamaModelDefinition definition,
  required LlamaRuntime runtime,
  required llama.LlamaEngineCapabilities? capabilities,
  required genkit.ModelRequest request,
  required List<llama.LlamaChatMessage> messages,
  required List<llama.ToolDefinition> tools,
  required LlamaDartGenerationConfig config,
  required _ModelActionContext context,
}) async {
  checkRuntimeModelRequest(definition, request, messages, capabilities);
  final params = toGenerationParams(config);
  checkRuntimeGenerationConfig(
    definition,
    request,
    messages,
    params,
    capabilities,
  );
  final toolChoice = toLlamaToolChoice(
    request.toolChoice,
    hasTools: tools.isNotEmpty,
  );
  final started = Stopwatch()..start();

  if (shouldUseStructuredGeneration(request.output)) {
    if (tools.isNotEmpty && toolChoice != llama.ToolChoice.none) {
      throw genkit.GenkitException(
        'llamadart does not support constrained structured output with tools yet.',
        status: genkit.StatusCode.unimplemented,
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
    allowToolCalls: tools.isNotEmpty && toolChoice != llama.ToolChoice.none,
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

  context.cancel?.throwIfCancelled();
  final stops = <String>{
    ...template.additionalStops,
    ...params.stopSequences,
  }.toList(growable: false);
  final inputParts = <llama.LlamaContentPart>[];
  for (final message in messages) {
    inputParts.addAll(message.parts);
  }

  final budget = params.thinkingBudget;
  final tags = budget == null
      ? null
      : llama.ChatTemplateEngine.thinkingTagsFor(template.format);
  final resolvedBudget = budget == null
      ? null
      : llama.ThinkingBudget(
          maxTokens: budget.maxTokens,
          startTag: budget.startTag ?? tags!.startTag,
          endTag: budget.endTag ?? tags!.endTag,
          forcedMessage: budget.forcedMessage,
        );
  final rawOutput = StringBuffer();
  await for (final token in runtime.generate(
    template.prompt,
    params: params.copyWith(
      stopSequences: stops,
      grammar: template.grammar,
      thinkingBudget: resolvedBudget,
      grammarLazy: template.grammarLazy,
      grammarTriggers: template.grammarTriggers
          .map((trigger) {
            return llama.GenerationGrammarTrigger.typed(
              type: llama.GrammarTriggerType.fromWireValue(trigger.type),
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

  context.cancel?.throwIfCancelled();
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
