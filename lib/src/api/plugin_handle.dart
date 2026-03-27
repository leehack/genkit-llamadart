import 'package:genkit/plugin.dart';

import '../integration/genkit/action_support.dart';
import '../integration/genkit/plugin.dart';
import 'embed_config.dart';
import 'generation_config.dart';
import 'model_definition.dart';

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
