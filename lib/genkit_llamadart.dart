/// Native Genkit Dart integration for local `llamadart` models.
library;

export 'package:llamadart/llamadart.dart' show ModelParams;

export 'src/llamadart_plugin.dart'
    show LlamaDartPlugin, LlamaDartPluginHandle, llamaDart;
export 'src/model_definition.dart' show LlamaModelDefinition;
export 'src/options.dart' show LlamaDartEmbedConfig, LlamaDartGenerationConfig;
