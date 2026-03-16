import 'package:genkit/genkit.dart' show ModelInfo;
import 'package:llamadart/llamadart.dart' show ModelParams;

/// Static configuration for one `llamadart` model exposed through Genkit.
class LlamaModelDefinition {
  /// Creates a model definition for a local GGUF-backed model.
  const LlamaModelDefinition({
    required this.name,
    required this.modelPath,
    this.modelParams = const ModelParams(),
    this.mmprojPath,
    this.modelInfo,
  }) : assert(name != ''),
       assert(modelPath != '');

  /// Unique model name used in Genkit refs like `llamadart/<name>`.
  final String name;

  /// Filesystem path to the GGUF model file.
  final String modelPath;

  /// Native engine parameters used while loading the model.
  final ModelParams modelParams;

  /// Optional path to a multimodal projector file.
  final String? mmprojPath;

  /// Optional Genkit model metadata override.
  final ModelInfo? modelInfo;
}
