import '../../api/model_definition.dart';

Map<String, dynamic> supportMetadataFor(LlamaModelDefinition definition) {
  return <String, dynamic>{
    'multiturn': true,
    'media': definition.mmprojPath != null,
    'tools': definition.supportsTools,
    'toolChoice': definition.supportsTools,
    'systemRole': true,
    'constrained': definition.supportsConstrainedOutput,
    'constrainedWithTools': false,
    'embeddings': definition.supportsEmbeddings,
  };
}
