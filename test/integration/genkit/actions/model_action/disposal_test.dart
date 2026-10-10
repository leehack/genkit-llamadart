import 'package:genkit/plugin.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:test/test.dart';

import '../../../../core/runtime/test_support/fake_runtime.dart';

void main() {
  test(
    'disposing after invoking a text action drains the accepted request',
    () async {
      final runtime = FakeRuntime()..createChunks = [textChunk('completed')];
      final plugin = LlamaDartPlugin(
        models: const [
          LlamaModelDefinition(name: 'local', modelPath: '/model.gguf'),
        ],
        runtimeFactory: () => runtime,
      );
      addTearDown(plugin.dispose);
      final model = (await plugin.init())
          .whereType<genkit.Model<LlamaDartGenerationConfig>>()
          .single;
      final pending = model(
        genkit.ModelRequest(
          messages: [
            genkit.Message(
              role: genkit.Role.user,
              content: [genkit.TextPart(text: 'Hello')],
            ),
          ],
        ),
      );
      final disposal = plugin.dispose();
      expect((await pending).text, 'completed');
      await disposal;
      expect(runtime.createCallCount, 1);
      expect(runtime.disposeCount, 1);
    },
  );
}
