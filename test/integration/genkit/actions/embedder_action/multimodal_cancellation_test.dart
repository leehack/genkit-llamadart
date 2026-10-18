import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/src/integration/genkit/actions/embedder_action.dart';
import 'package:test/test.dart';

import '../../../../core/runtime/test_support/fake_embedding_runtime.dart';
import '../test_support/action_harness.dart';

void main() {
  final request = genkit.EmbedRequest(
    input: [
      genkit.DocumentData(
        content: [
          genkit.MediaPart(
            media: genkit.Media(
              url: 'data:image/png;base64,AQID',
              contentType: 'image/png',
            ),
          ),
        ],
      ),
    ],
  );

  test(
    'pre-cancelled and queued requests never cancel another embedding',
    () async {
      final runtime = FakeEmbeddingRuntime()
        ..blockEmbedding = true
        ..embeddings = [
          [1.0],
        ];
      final registry = testRegistry(runtime: runtime);
      addTearDown(() async {
        runtime.releaseAll();
        await registry.dispose();
      });
      final action = buildEmbedderAction(
        definition: testModelDefinition(),
        registry: registry,
      );
      final controller = genkit.CancellationController()..cancel();
      await expectLater(
        action(request, cancel: controller.token),
        throwsA(isA<genkit.CancelledException>()),
      );
      expect(runtime.initializeCount, 0);
      final first = action(request);
      await runtime.started.future;
      final queued = genkit.CancellationController();
      final rejected = expectLater(
        action(request, cancel: queued.token),
        throwsA(isA<genkit.CancelledException>()),
      );
      queued.cancel();
      expect(runtime.cancelGenerationCount, 0);
      runtime.releaseAll();
      await first;
      await rejected;
      expect(runtime.contentCalls, 1);
      expect(runtime.embeddingProbeCount, 1);
    },
  );

  test(
    'active cancellation signals once and drains before releasing the queue',
    () async {
      final runtime = FakeEmbeddingRuntime()
        ..blockEmbedding = true
        ..embeddings = [
          [1.0],
        ];
      final registry = testRegistry(runtime: runtime);
      addTearDown(() async {
        runtime.releaseAll();
        await registry.dispose();
      });
      final action = buildEmbedderAction(
        definition: testModelDefinition(),
        registry: registry,
      );
      final controller = genkit.CancellationController();
      var settled = false;
      final cancelled = expectLater(
        action(
          request,
          cancel: controller.token,
        ).whenComplete(() => settled = true),
        throwsA(isA<genkit.CancelledException>()),
      );
      await runtime.started.future;
      final next = action(request);
      controller.cancel();
      await Future<void>(() {});
      expect(runtime.cancelGenerationCount, 1);
      expect(runtime.contentCalls, 1);
      expect(settled, false);
      runtime.releaseAll();
      await cancelled;
      await next;
      expect(runtime.contentCalls, 2);
      controller.cancel();
      expect(runtime.cancelGenerationCount, 1);
    },
  );

  test(
    'cancellation during probing avoids inference and backend cancellation',
    () async {
      final runtime = FakeEmbeddingRuntime()..blockProbe = true;
      final registry = testRegistry(runtime: runtime);
      addTearDown(() async {
        runtime.releaseAll();
        await registry.dispose();
      });
      final action = buildEmbedderAction(
        definition: testModelDefinition(),
        registry: registry,
      );
      final controller = genkit.CancellationController();
      final cancelled = expectLater(
        action(request, cancel: controller.token),
        throwsA(isA<genkit.CancelledException>()),
      );
      await runtime.probing.future;
      controller.cancel();
      runtime.releaseAll();
      await cancelled;
      expect(runtime.contentCalls, 0);
      expect(runtime.cancelGenerationCount, 0);
    },
  );
}
