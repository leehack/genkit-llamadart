import 'package:llamadart/llamadart.dart' as llama;

import '../../api/model_definition.dart';

/// Creates a runtime owned and serialized by the plugin.
typedef LlamaDartRuntimeFactory = LlamaDartRuntime Function();

// Preserve the internal spellings used by existing runtime implementations.
typedef LlamaRuntimeFactory = LlamaDartRuntimeFactory;
typedef LlamaRuntime = LlamaDartRuntime;

/// Optional capability probe for custom runtimes.
///
/// Read after initialization and before every request. Return a fresh snapshot
/// for the active model; returning unsupported or throwing prevents inference.
/// Runtimes without this interface can serve single-turn text, but cannot
/// confirm tools, structured output, media, embeddings or message history.
abstract interface class LlamaRuntimeCapabilityProvider {
  /// Capabilities of the currently loaded model and backend.
  Future<llama.LlamaEngineCapabilities> get capabilities;
}

/// Runtime operations used by the Genkit adapter.
///
/// Implement [LlamaRuntimeCapabilityProvider] to confirm advanced capabilities.
abstract class LlamaDartRuntime {
  /// Loads the model and optional projector from [definition].
  Future<void> initialize(LlamaModelDefinition definition);

  /// Generates chat completions from the supplied conversation.
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

  /// Applies the model's chat template and optional output constraints.
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

  /// Generates raw text using the supplied prompt and grammar settings.
  Stream<String> generate(
    String prompt, {
    llama.GenerationParams params = const llama.GenerationParams(),
    List<llama.LlamaContentPart>? parts,
  });

  /// Embeds a batch of texts, optionally normalizing their vectors.
  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    bool normalize = true,
  });

  /// Cancels the generation currently running on this runtime, if any. Returns
  /// immediately; the in-flight [create] / [generate] stream ends shortly after.
  void cancelGeneration();

  /// Releases runtime resources after queued requests finish.
  Future<void> dispose();
}
