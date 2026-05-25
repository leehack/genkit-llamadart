import 'package:genkit/plugin.dart';
import 'package:llamadart/llamadart.dart' as llama;

import '../integration/genkit/action_support.dart';
import '../integration/genkit/plugin.dart';
import 'embed_config.dart';
import 'generation_config.dart';
import 'model_definition.dart';
import 'prepared_model.dart';

/// Global handle used to configure and reference the `llamadart` plugin.
///
/// ```dart
/// final plugin = llamaDart(
///   models: const <LlamaModelDefinition>[
///     LlamaModelDefinition(
///       name: 'local-chat',
///       modelPath: '/models/chat.gguf',
///     ),
///   ],
/// );
/// ```
const LlamaDartPluginHandle llamaDart = LlamaDartPluginHandle();

/// Factory and typed reference helper for the `llamadart` Genkit plugin.
///
/// ```dart
/// import 'package:genkit/genkit.dart';
/// import 'package:genkit_llamadart/genkit_llamadart.dart';
///
/// final plugin = llamaDart(
///   models: const <LlamaModelDefinition>[
///     LlamaModelDefinition(
///       name: 'local-chat',
///       modelPath: '/models/chat.gguf',
///     ),
///   ],
/// );
///
/// final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);
/// final response = await ai.generate(
///   model: llamaDart.model('local-chat'),
///   prompt: 'Say hello.',
/// );
/// ```
class LlamaDartPluginHandle {
  /// Creates a plugin handle.
  const LlamaDartPluginHandle();

  /// Creates a plugin instance for the provided model definitions.
  ///
  /// Each definition registers a Genkit model action, plus an embedder action
  /// when `supportsEmbeddings` is enabled.
  LlamaDartPlugin call({required List<LlamaModelDefinition> models}) {
    return LlamaDartPlugin(models: models);
  }

  /// Resolves a `llamadart` [llama.ModelSource] into a Genkit-ready model.
  ///
  /// This helper uses `llamadart`'s package-managed [llama.ModelDownloadManager]
  /// instead of creating a separate cache layer. Remote HTTP(S) and Hugging Face
  /// sources are downloaded or read from cache according to [options]; local
  /// sources are validated by the manager and remain subject to `llamadart`'s
  /// local-source option checks. When [mmprojSource] is provided, it is resolved
  /// with [mmprojOptions] and wired into the produced [LlamaModelDefinition].
  ///
  /// The returned [LlamaPreparedModel] exposes the normal plugin and typed refs,
  /// so generation still uses `Genkit.generate` with `llamaDart.model(name)`.
  Future<LlamaPreparedModel> prepareModel({
    required String name,
    required llama.ModelSource source,
    llama.ModelParams modelParams = const llama.ModelParams(),
    llama.ModelSource? mmprojSource,
    llama.ModelLoadOptions options = llama.ModelLoadOptions.defaults,
    llama.ModelLoadOptions mmprojOptions = llama.ModelLoadOptions.defaults,
    llama.ModelDownloadManager? downloadManager,
    llama.ModelDownloadProgressCallback? onModelProgress,
    llama.ModelDownloadProgressCallback? onMmprojProgress,
    bool supportsEmbeddings = true,
    bool supportsTools = true,
    bool supportsConstrainedOutput = true,
    ModelInfo? modelInfo,
  }) async {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Model name must not be empty.');
    }

    final manager = downloadManager ?? llama.DefaultModelDownloadManager();
    final modelEntry = await manager.ensureModel(
      source,
      options: options,
      onProgress: onModelProgress,
    );
    final mmprojEntry = mmprojSource == null
        ? null
        : await manager.ensureModel(
            mmprojSource,
            options: mmprojOptions,
            onProgress: onMmprojProgress,
          );

    final definition = LlamaModelDefinition(
      name: name,
      modelPath: modelEntry.filePath,
      modelParams: modelParams,
      mmprojPath: mmprojEntry?.filePath,
      supportsEmbeddings: supportsEmbeddings,
      supportsTools: supportsTools,
      supportsConstrainedOutput: supportsConstrainedOutput,
      modelInfo: modelInfo,
    );
    final plugin = LlamaDartPlugin(models: <LlamaModelDefinition>[definition]);

    return LlamaPreparedModel(
      definition: definition,
      plugin: plugin,
      modelRef: model(name),
      embedderRef: supportsEmbeddings ? embedder(name) : null,
      modelEntry: modelEntry,
      mmprojEntry: mmprojEntry,
    );
  }

  /// Returns a typed Genkit model reference.
  ///
  /// The [name] must match a [LlamaModelDefinition.name] registered on the
  /// plugin instance.
  ModelRef<LlamaDartGenerationConfig> model(String name) {
    return modelRef<LlamaDartGenerationConfig>(actionNameFor(name));
  }

  /// Returns a typed Genkit embedder reference.
  ///
  /// The [name] must match a [LlamaModelDefinition.name] registered on the
  /// plugin instance and that model must support embeddings.
  EmbedderRef<LlamaDartEmbedConfig> embedder(String name) {
    return embedderRef<LlamaDartEmbedConfig>(actionNameFor(name));
  }
}
