@Tags(<String>['real-model'])
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:test/test.dart';

import '../../test_support/real_model_test_support.dart';

void main() {
  test('real model embed returns vector', () async {
    final modelPath = await requireIntegrationEmbedModelPath();
    final integration = createIntegrationGenkit(
      modelName: 'real-embed',
      modelPath: modelPath,
    );

    try {
      final embeddings = await integration.ai.embed(
        embedder: llamaDart.embedder('real-embed'),
        document: DocumentData(
          content: <Part>[TextPart(text: 'integration test text')],
        ),
        options: const LlamaDartEmbedConfig(normalize: true),
      );

      expect(embeddings, hasLength(1));
      expectFiniteEmbedding(embeddings.single);
    } finally {
      await integration.plugin.dispose();
      await integration.ai.shutdown();
    }
  });
}
