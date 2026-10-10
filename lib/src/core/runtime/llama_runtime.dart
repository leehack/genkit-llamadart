import 'package:llamadart/llamadart.dart' as llama;

import '../../api/model_definition.dart';

/// Creates a fresh runtime owned by one registered model.
///
/// The plugin serializes its requests and disposes it after queued work settles.
/// Do not return the same mutable runtime for different model names.
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
/// The plugin initializes a runtime once, then runs one operation at a time
/// for that model. Cancellation can arrive while an operation is active.
///
/// Implementations may import `package:llamadart/llamadart.dart` for the chat,
/// completion and tool types in this contract.
abstract class LlamaDartRuntime {
  /// Creates a runtime implementation for one model's serialized requests.
  LlamaDartRuntime();

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

  /// Formats chat input and returns decoding constraints for [generate].
  ///
  /// When [responseFormat] requests JSON, return the grammar, triggers, stops
  /// and preserved tokens required to enforce it. Reject unsupported constraints
  /// instead of returning a best-effort unconstrained prompt.
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

  /// Embeds texts in input order, returning one vector for each input.
  ///
  /// Honor [normalize] or reject it explicitly when unsupported.
  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    bool normalize = true,
  });

  /// Requests cooperative cancellation of the active generation, if any.
  ///
  /// Returns immediately; the active [create] or [generate] stream must settle
  /// without requiring another request to enter the operation queue.
  void cancelGeneration();

  /// Releases runtime resources after queued requests finish.
  Future<void> dispose();
}
