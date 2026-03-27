import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:test/test.dart';

void main() {
  test('plugin init and list skip embedder actions when disabled', () async {
    final plugin = LlamaDartPlugin(
      models: const <LlamaModelDefinition>[
        LlamaModelDefinition(
          name: 'local',
          modelPath: '/tmp/model.gguf',
          supportsEmbeddings: false,
          supportsTools: false,
          supportsConstrainedOutput: false,
        ),
      ],
    );

    final actions = await plugin.init();
    final metadata = await plugin.list();

    expect(actions, hasLength(1));
    expect(actions.single.actionType, 'model');
    expect(metadata, hasLength(1));
    expect(metadata.single.actionType, 'model');

    final model = metadata.single.metadata['model']! as Map<String, dynamic>;
    final supports = model['supports']! as Map<String, dynamic>;
    expect(supports['tools'], isFalse);
    expect(supports['toolChoice'], isFalse);
    expect(supports['constrained'], isFalse);
    expect(supports['constrainedWithTools'], isFalse);
    expect(supports['embeddings'], isFalse);
  });
}
