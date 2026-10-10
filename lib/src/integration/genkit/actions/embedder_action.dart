import 'package:genkit/plugin.dart' as genkit;

import '../../../api/embed_config.dart';
import '../../../api/model_definition.dart';
import '../../../core/runtime/engine_registry.dart';
import '../action_support.dart';
import '../converters/genkit_to_llama.dart';
import '../request_support.dart';

genkit.Embedder<LlamaDartEmbedConfig> buildEmbedderAction({
  required LlamaModelDefinition definition,
  required EngineRegistry registry,
}) {
  final actionName = actionNameFor(definition.name);

  final action = genkit.Embedder<LlamaDartEmbedConfig>(
    name: actionName,
    metadata: actionMetadataFor(
      definition,
      modelInfo: modelInfoFor(definition, generation: false),
      generation: false,
    ),
    fn: (request, _) async {
      if (!definition.supportsEmbeddings) {
        throw genkit.GenkitException(
          'Embeddings are disabled for `${definition.name}`.',
          status: genkit.StatusCode.failedPrecondition,
        );
      }

      final config = LlamaDartEmbedConfig.fromJson(request.options);
      final texts = request.input
          .map(documentToPlainText)
          .toList(growable: false);

      final embeddings = await registry.withRuntime(definition.name, (runtime) {
        final capabilities = registry.capabilitiesFor(definition.name);
        checkRuntimeReady(definition, capabilities);
        requireRuntimeCapability(
          definition,
          supported: capabilities?.supportsEmbeddings,
          feature: 'embeddings',
        );
        return runtime.embedBatch(
          texts,
          normalize: config.normalize ?? LlamaDartEmbedConfig.defaultNormalize,
        );
      });

      return genkit.EmbedResponse(
        embeddings: embeddings
            .asMap()
            .entries
            .map((entry) {
              return genkit.Embedding(
                embedding: entry.value,
                metadata: request.input[entry.key].metadata,
              );
            })
            .toList(growable: false),
      );
    },
  );
  trackCapabilityMetadata(action.metadata, definition, registry);
  return action;
}
