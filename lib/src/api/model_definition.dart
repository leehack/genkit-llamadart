import 'package:genkit/genkit.dart' show ModelInfo;
import 'package:llamadart/llamadart.dart' show ModelParams;

/// Static configuration for one `llamadart` model exposed through Genkit.
///
/// Use one definition per local model you want to register. The same
/// definition controls the model name, native loading parameters, optional
/// multimodal projector path, and which Genkit capabilities are advertised.
///
/// ```dart
/// const chatModel = LlamaModelDefinition(
///   name: 'local-chat',
///   modelPath: '/models/chat.gguf',
///   modelParams: ModelParams(contextSize: 8192),
///   supportsTools: true,
///   supportsConstrainedOutput: true,
/// );
/// ```
class LlamaModelDefinition {
  /// Creates a model definition for a local model file.
  const LlamaModelDefinition({
    required this.name,
    required this.modelPath,
    this.modelParams = const ModelParams(),
    this.mmprojPath,
    this.supportsEmbeddings = true,
    this.supportsTools = true,
    this.supportsConstrainedOutput = true,
    this.modelInfo,
  }) : assert(name != ''),
       assert(modelPath != '');

  /// Unique model name used in Genkit refs like `llamadart/<name>`.
  final String name;

  /// Filesystem path to a model file supported by `llamadart`.
  ///
  /// This can be a GGUF file or a `.litertlm` LiteRT-LM bundle on supported
  /// `llamadart` platforms.
  final String modelPath;

  /// Native engine parameters used while loading the model.
  final ModelParams modelParams;

  /// Optional path to a multimodal projector file.
  final String? mmprojPath;

  /// Whether this definition should register a Genkit embedder action.
  final bool supportsEmbeddings;

  /// Whether this definition should accept Genkit tool requests.
  final bool supportsTools;

  /// Whether this definition should accept constrained JSON output requests.
  ///
  /// Disable this for `.litertlm` LiteRT-LM bundles until `llamadart` exposes
  /// grammar constraints for that backend.
  final bool supportsConstrainedOutput;

  /// Optional Genkit model metadata override.
  final ModelInfo? modelInfo;
}
