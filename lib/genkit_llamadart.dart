/// Genkit integration for local `llamadart` GGUF models.
///
/// This package lets Genkit applications run local models in-process through
/// `llamadart`, without needing an OpenAI-compatible HTTP server.
///
/// Use [llamaDart] to:
///
/// - create a plugin from one or more [LlamaModelDefinition] values
/// - reference a registered Genkit model with `llamaDart.model(...)`
/// - reference a registered Genkit embedder with `llamaDart.embedder(...)`
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
///   prompt: 'Say hello in one short sentence.',
/// );
/// ```
///
/// Main docs and runnable examples live in `README.md`.
/// For native `llamadart` installation and platform guidance, see
/// https://llamadart.leehack.com/.
library;

export 'package:llamadart/llamadart.dart' show ModelParams;

export 'src/api/embed_config.dart' show LlamaDartEmbedConfig;
export 'src/api/generation_config.dart' show LlamaDartGenerationConfig;
export 'src/api/model_definition.dart' show LlamaModelDefinition;
export 'src/api/plugin_handle.dart' show LlamaDartPluginHandle, llamaDart;
export 'src/integration/genkit/plugin.dart' show LlamaDartPlugin;
