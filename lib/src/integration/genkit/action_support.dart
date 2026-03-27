import 'package:genkit/plugin.dart' as genkit;

import '../../api/model_definition.dart';
import '../../core/metadata/model_capabilities.dart';

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

genkit.ModelInfo modelInfoFor(LlamaModelDefinition definition) {
  final provided = definition.modelInfo;
  return genkit.ModelInfo(
    versions: provided?.versions,
    label: provided?.label ?? definition.name,
    configSchema: provided?.configSchema,
    supports: <String, dynamic>{
      ...supportMetadataFor(definition),
      ...?provided?.supports,
    },
    stage: provided?.stage,
  );
}

Map<String, dynamic> rawResponseMetadata(
  LlamaModelDefinition definition, {
  bool structured = false,
}) {
  return <String, dynamic>{
    'provider': llamaDartPluginName,
    'model': definition.name,
    if (structured) 'structured': true,
  };
}
