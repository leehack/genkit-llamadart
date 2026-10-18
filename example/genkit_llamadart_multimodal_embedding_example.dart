import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

/// Embeds one ordered text/image/audio document with local model files.
///
/// GGUF: `dart run example/genkit_llamadart_multimodal_embedding_example.dart MODEL PROJECTOR IMAGE AUDIO`
/// LiteRT CPU: use `--litert MODEL IMAGE AUDIO` instead (no projector).
Future<void> main(List<String> args) async {
  final liteRt = args.isNotEmpty && args.first == '--litert';
  final paths = liteRt ? args.skip(1).toList() : args;
  if (paths.length != (liteRt ? 3 : 4)) {
    throw ArgumentError(
      'Supply MODEL PROJECTOR IMAGE AUDIO, or --litert MODEL IMAGE AUDIO.',
    );
  }
  final plugin = llamaDart(
    models: [
      LlamaModelDefinition(
        name: 'media-embed',
        modelPath: paths[0],
        mmprojPath: liteRt ? null : paths[1],
        modelParams: ModelParams(
          device: ComputeDevice.cpu,
          liteRtLmEmbeddingEngine: liteRt,
          contextSize: 2048,
          batchSize: liteRt ? 0 : 2048,
          microBatchSize: liteRt ? 0 : 2048,
        ),
        supportsTools: false,
        supportsConstrainedOutput: false,
      ),
    ],
  );
  final ai = Genkit(plugins: [plugin], isDevEnv: false);
  try {
    final inspection = await plugin.inspectModel('media-embed');
    final modalities = inspection.embeddingCapabilities;
    if (modalities?.text != true ||
        modalities?.image != true ||
        modalities?.audio != true) {
      throw LlamaUnsupportedException(
        'This example needs text, image and audio embedding support.',
      );
    }
    // LiteRT embeddings require encoded bytes rather than unresolved file paths.
    Future<MediaPart> mediaFile(String path, String type) async => MediaPart(
      media: Media(
        url: UriData.fromBytes(
          await File(path).readAsBytes(),
          mimeType: type,
        ).toString(),
        contentType: type,
      ),
    );
    final result = await ai.embed(
      embedder: llamaDart.embedder('media-embed'),
      document: DocumentData(
        content: [
          TextPart(text: 'Compare this scene '),
          await mediaFile(paths[liteRt ? 1 : 2], 'image/png'),
          TextPart(text: ' with this sound '),
          await mediaFile(paths[liteRt ? 2 : 3], 'audio/wav'),
        ],
        metadata: {'id': 'scene-and-sound'},
      ),
      options: const LlamaDartEmbedConfig(normalize: true),
    );
    stdout.writeln('Dimensions: ${result.single.embedding.length}');
    stdout.writeln('Source: ${result.single.metadata?['id']}');
  } finally {
    try {
      await plugin.dispose();
    } finally {
      await ai.shutdown();
    }
  }
}
