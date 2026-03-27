@Tags(<String>['real-model'])
library;

import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:test/test.dart';

import '../test_support/real_model_test_support.dart';

void main() {
  test('real model generate returns text', () async {
    final modelPath = await requireIntegrationModelPath();
    final integration = createIntegrationGenkit(
      modelName: 'real-chat',
      modelPath: modelPath,
      supportsEmbeddings: false,
    );

    try {
      final response = await integration.ai.generate(
        model: llamaDart.model('real-chat'),
        prompt: 'Reply with one short sentence about local testing.',
        config: const LlamaDartGenerationConfig(
          temperature: 0.0,
          maxTokens: 48,
          enableThinking: false,
        ),
      );

      expect(response.text.trim(), isNotEmpty);
    } finally {
      await integration.plugin.dispose();
      await integration.ai.shutdown();
    }
  });
}
