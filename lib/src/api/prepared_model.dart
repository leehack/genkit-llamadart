import 'package:genkit/plugin.dart';
import 'package:llamadart/llamadart.dart' as llama;

import '../integration/genkit/plugin.dart';
import 'embed_config.dart';
import 'generation_config.dart';
import 'model_definition.dart';

/// Result of preparing a `llamadart` model source for Genkit registration.
///
/// The handle contains the resolved local model/cache entries, the normal
/// `LlamaModelDefinition` produced from those entries, a ready-to-register
/// [plugin], and typed Genkit references for generation and embeddings.
class LlamaPreparedModel {
  /// Creates a prepared model handle.
  const LlamaPreparedModel({
    required this.definition,
    required this.plugin,
    required this.modelRef,
    required this.modelEntry,
    this.embedderRef,
    this.mmprojEntry,
  });

  /// Local-path model definition that was registered on [plugin].
  final LlamaModelDefinition definition;

  /// Genkit plugin exposing [definition] as a model action and, when enabled,
  /// an embedder action.
  final LlamaDartPlugin plugin;

  /// Typed Genkit model reference for [definition].
  final ModelRef<LlamaDartGenerationConfig> modelRef;

  /// Typed Genkit embedder reference, or null when embeddings were disabled.
  final EmbedderRef<LlamaDartEmbedConfig>? embedderRef;

  /// Cache entry returned by the `llamadart` download/cache manager for the
  /// primary GGUF model source.
  final llama.ModelCacheEntry modelEntry;

  /// Cache entry returned for the optional multimodal projector source.
  final llama.ModelCacheEntry? mmprojEntry;

  /// Disposes runtimes owned by [plugin].
  Future<void> dispose() {
    return plugin.dispose();
  }
}
