import 'package:genkit/plugin.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;

import '../../api/model_definition.dart';
import '../../core/metadata/model_capabilities.dart';
import '../../core/runtime/engine_registry.dart';

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

genkit.ModelInfo modelInfoFor(
  LlamaModelDefinition definition, {
  llama.LlamaEngineCapabilities? capabilities,
}) {
  final provided = definition.modelInfo;
  return genkit.ModelInfo(
    versions: provided?.versions,
    label: provided?.label ?? definition.name,
    configSchema: provided?.configSchema,
    supports: <String, dynamic>{
      ...?provided?.supports,
      ...supportMetadataFor(definition, capabilities: capabilities),
    },
    stage: provided?.stage,
  );
}

void trackCapabilityMetadata(
  Map<String, dynamic> metadata,
  LlamaModelDefinition definition,
  EngineRegistry registry,
) {
  void refresh() {
    // Keep labels, schemas and framework/app annotations stable; only support
    // changes when the runtime is probed.
    final model = metadata['model'] as Map<String, dynamic>;
    model['supports'] = <String, dynamic>{
      ...?model['supports'] as Map<String, dynamic>?,
      ...?definition.modelInfo?.supports,
      ...supportMetadataFor(
        definition,
        capabilities: registry.capabilitiesFor(definition.name),
      ),
    };
    metadata['llamadartCapabilities'] = capabilityMetadataFor(
      definition,
      registry,
    );
  }

  refresh();
  registry.onCapabilitiesChanged(definition.name, refresh);
}

Map<String, dynamic> capabilityMetadataFor(
  LlamaModelDefinition definition,
  EngineRegistry registry,
) => {
  'state': registry.capabilityStateFor(definition.name),
  'ready': registry.capabilitiesFor(definition.name)?.isSupported == true,
  'declared': {
    'tools': definition.supportsTools,
    'constrained': definition.supportsConstrainedOutput,
    'embeddings': definition.supportsEmbeddings,
  },
};

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
