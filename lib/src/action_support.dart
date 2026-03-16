import 'package:genkit/plugin.dart' as genkit;

import 'model_definition.dart';

const String llamaDartPluginName = 'llamadart';

String actionNameFor(String modelName) => '$llamaDartPluginName/$modelName';

Map<String, dynamic> actionMetadataFor(
  LlamaModelDefinition definition, {
  genkit.ModelInfo? modelInfo,
}) {
  return <String, dynamic>{
    'label': definition.name,
    'description': definition.name,
    if (modelInfo != null) 'model': modelInfo.toJson(),
    if (modelInfo == null) 'model': <String, dynamic>{'label': definition.name},
  };
}

Map<String, dynamic> rawResponseMetadata(
  LlamaModelDefinition definition, {
  bool structured = false,
}) {
  return <String, dynamic>{
    'provider': llamaDartPluginName,
    'model': definition.name,
    'path': definition.modelPath,
    if (structured) 'structured': true,
  };
}
