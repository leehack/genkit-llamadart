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

genkit.ModelInfo modelInfoFor(LlamaModelDefinition definition) {
  final provided = definition.modelInfo;
  final supports = <String, dynamic>{
    'multiturn': true,
    'media': definition.mmprojPath != null,
    'tools': definition.supportsTools,
    'toolChoice': definition.supportsTools,
    'systemRole': true,
    'constrained': definition.supportsConstrainedOutput,
    'constrainedWithTools': false,
    'embeddings': definition.supportsEmbeddings,
    ...?provided?.supports,
  };

  return genkit.ModelInfo(
    versions: provided?.versions,
    label: provided?.label ?? definition.name,
    configSchema: provided?.configSchema,
    supports: supports,
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
