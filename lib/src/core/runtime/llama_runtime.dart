import 'package:llamadart/llamadart.dart' as llama;

import '../../api/model_definition.dart';

typedef LlamaRuntimeFactory = LlamaRuntime Function();

abstract class LlamaRuntime {
  Future<void> initialize(LlamaModelDefinition definition);

  Stream<llama.LlamaCompletionChunk> create(
    List<llama.LlamaChatMessage> messages, {
    llama.GenerationParams? params,
    List<llama.ToolDefinition>? tools,
    llama.ToolChoice? toolChoice,
    bool parallelToolCalls = false,
    bool enableThinking = false,
    String? sourceLangCode,
    String? targetLangCode,
    Map<String, dynamic>? chatTemplateKwargs,
  });

  Future<llama.LlamaChatTemplateResult> chatTemplate(
    List<llama.LlamaChatMessage> messages, {
    bool addAssistant = true,
    List<llama.ToolDefinition>? tools,
    llama.ToolChoice toolChoice = llama.ToolChoice.auto,
    bool parallelToolCalls = false,
    bool enableThinking = false,
    Map<String, dynamic>? responseFormat,
    String? sourceLangCode,
    String? targetLangCode,
    bool includeTokenCount = false,
    Map<String, dynamic>? chatTemplateKwargs,
  });

  Stream<String> generate(
    String prompt, {
    llama.GenerationParams params = const llama.GenerationParams(),
    List<llama.LlamaContentPart>? parts,
  });

  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    bool normalize = true,
  });

  Future<void> dispose();
}
