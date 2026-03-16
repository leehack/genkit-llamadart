import 'package:genkit/genkit.dart' show ModelInfo;
import 'package:llamadart/llamadart.dart' show ModelParams;

class LlamaModelDefinition {
  const LlamaModelDefinition({
    required this.name,
    required this.modelPath,
    this.modelParams = const ModelParams(),
    this.mmprojPath,
    this.modelInfo,
  }) : assert(name != ''),
       assert(modelPath != '');

  final String name;
  final String modelPath;
  final ModelParams modelParams;
  final String? mmprojPath;
  final ModelInfo? modelInfo;
}
