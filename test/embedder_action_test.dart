import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_llamadart/src/embedder_action.dart';
import 'package:genkit_llamadart/src/engine_registry.dart';
import 'package:test/test.dart';

import 'src/fake_runtime.dart';

void main() {
  test('embedder action returns embeddings and preserves metadata', () async {
    final runtime = FakeRuntime()
      ..embeddings = <List<double>>[
        <double>[1, 2, 3],
      ];
    final action = buildEmbedderAction(
      definition: const LlamaModelDefinition(
        name: 'local',
        modelPath: '/tmp/model.gguf',
      ),
      registry: EngineRegistry(
        models: const <LlamaModelDefinition>[
          LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
        ],
        runtimeFactory: () => runtime,
      ),
    );

    final response = await action(
      genkit.EmbedRequest(
        input: <genkit.DocumentData>[
          genkit.DocumentData(
            content: <genkit.Part>[genkit.TextPart(text: 'hello world')],
            metadata: <String, dynamic>{'id': 'doc-1'},
          ),
        ],
        options: <String, dynamic>{'normalize': false},
      ),
    );

    expect(runtime.embedBatchCallCount, 1);
    expect(runtime.lastNormalize, false);
    expect(response.embeddings.single.embedding, <double>[1, 2, 3]);
    expect(response.embeddings.single.metadata, <String, dynamic>{
      'id': 'doc-1',
    });
  });
}
