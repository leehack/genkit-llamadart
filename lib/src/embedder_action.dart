import 'package:genkit/plugin.dart' as genkit;

import 'action_support.dart';
import 'converters/genkit_to_llama.dart';
import 'engine_registry.dart';
import 'model_definition.dart';
import 'options.dart';

genkit.Embedder<LlamaDartEmbedConfig> buildEmbedderAction({
  required LlamaModelDefinition definition,
  required EngineRegistry registry,
}) {
  final actionName = actionNameFor(definition.name);

  return genkit.Embedder<LlamaDartEmbedConfig>(
    name: actionName,
    metadata: actionMetadataFor(definition),
    fn: (request, _) async {
      if (request == null) {
        throw genkit.GenkitException(
          'Embedder request cannot be null.',
          status: genkit.StatusCodes.INVALID_ARGUMENT,
        );
      }

      final config = LlamaDartEmbedConfig.fromJson(request.options);
      final texts = request.input
          .map(documentToPlainText)
          .toList(growable: false);

      final embeddings = await registry.withRuntime(definition.name, (runtime) {
        return runtime.embedBatch(texts, normalize: config.normalize ?? true);
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
}
