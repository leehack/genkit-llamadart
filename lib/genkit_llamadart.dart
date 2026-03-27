/// Native Genkit Dart integration for local `llamadart` models.
library;

export 'package:llamadart/llamadart.dart' show ModelParams;

export 'src/api/embed_config.dart' show LlamaDartEmbedConfig;
export 'src/api/generation_config.dart' show LlamaDartGenerationConfig;
export 'src/api/model_definition.dart' show LlamaModelDefinition;
export 'src/api/plugin_handle.dart' show LlamaDartPluginHandle, llamaDart;
export 'src/integration/genkit/plugin.dart' show LlamaDartPlugin;
