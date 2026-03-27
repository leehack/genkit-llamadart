import 'package:genkit/plugin.dart';

import '../integration/genkit/action_support.dart';
import '../integration/genkit/plugin.dart';
import 'embed_config.dart';
import 'generation_config.dart';
import 'model_definition.dart';

/// Global handle used to configure and reference the `llamadart` plugin.
const LlamaDartPluginHandle llamaDart = LlamaDartPluginHandle();

/// Factory and typed reference helper for the `llamadart` Genkit plugin.
class LlamaDartPluginHandle {
  /// Creates a plugin handle.
  const LlamaDartPluginHandle();

  /// Creates a plugin instance for the provided model definitions.
  LlamaDartPlugin call({required List<LlamaModelDefinition> models}) {
    return LlamaDartPlugin(models: models);
  }

  /// Returns a typed Genkit model reference.
  ModelRef<LlamaDartGenerationConfig> model(String name) {
    return modelRef<LlamaDartGenerationConfig>(actionNameFor(name));
  }

  /// Returns a typed Genkit embedder reference.
  EmbedderRef<LlamaDartEmbedConfig> embedder(String name) {
    return embedderRef<LlamaDartEmbedConfig>(actionNameFor(name));
  }
}
