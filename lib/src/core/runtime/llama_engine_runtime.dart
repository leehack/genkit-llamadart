import 'package:llamadart/llamadart.dart' as llama;

import '../../api/model_definition.dart';
import 'llama_runtime.dart';

class LlamaEngineRuntime implements LlamaRuntime {
  LlamaEngineRuntime({llama.LlamaEngine? engine})
    : _engine = engine ?? llama.LlamaEngine(llama.LlamaBackend());

  final llama.LlamaEngine _engine;
  bool _initialized = false;

  @override
  Future<void> initialize(LlamaModelDefinition definition) async {
    if (_initialized) {
      return;
    }

    await _engine.loadModel(
      definition.modelPath,
      modelParams: definition.modelParams,
    );
    if (definition.mmprojPath != null) {
      await _engine.loadMultimodalProjector(definition.mmprojPath!);
    }
    _initialized = true;
  }

  @override
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
  }) {
    return _engine.create(
      messages,
      params: params,
      tools: tools,
      toolChoice: toolChoice,
      parallelToolCalls: parallelToolCalls,
      enableThinking: enableThinking,
      sourceLangCode: sourceLangCode,
      targetLangCode: targetLangCode,
      chatTemplateKwargs: chatTemplateKwargs,
    );
  }

  @override
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
  }) {
    return _engine.chatTemplate(
      messages,
      addAssistant: addAssistant,
      tools: tools,
      toolChoice: toolChoice,
      parallelToolCalls: parallelToolCalls,
      enableThinking: enableThinking,
      responseFormat: responseFormat,
      sourceLangCode: sourceLangCode,
      targetLangCode: targetLangCode,
      includeTokenCount: includeTokenCount,
      chatTemplateKwargs: chatTemplateKwargs,
    );
  }

  @override
  Stream<String> generate(
    String prompt, {
    llama.GenerationParams params = const llama.GenerationParams(),
    List<llama.LlamaContentPart>? parts,
  }) {
    return _engine.generate(prompt, params: params, parts: parts);
  }

  @override
  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    bool normalize = true,
  }) {
    return _engine.embedBatch(texts, normalize: normalize);
  }

  @override
  void cancelGeneration() => _engine.cancelGeneration();

  @override
  Future<void> dispose() async {
    await _engine.dispose();
  }
}
