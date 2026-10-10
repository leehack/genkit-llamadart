import 'package:llamadart/llamadart.dart' as llama;

import '../../api/model_definition.dart';

Map<String, dynamic> supportMetadataFor(
  LlamaModelDefinition definition, {
  llama.LlamaEngineCapabilities? capabilities,
}) {
  final ready = capabilities?.isSupported == true;
  final tools =
      definition.supportsTools && ready && capabilities!.supportsToolCalling;
  return <String, dynamic>{
    'multiturn': ready && capabilities!.supportsMultiTurnChat,
    'media':
        ready && (capabilities!.supportsVision || capabilities.supportsAudio),
    'tools': tools,
    'toolChoice': tools,
    'systemRole': ready && capabilities!.supportsMultiTurnChat,
    'constrained':
        definition.supportsConstrainedOutput &&
        ready &&
        capabilities!.supportsStructuredOutput &&
        capabilities.supportsGrammar,
    'constrainedWithTools': false,
    'embeddings':
        definition.supportsEmbeddings &&
        ready &&
        capabilities!.supportsEmbeddings,
  };
}
