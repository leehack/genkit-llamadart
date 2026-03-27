import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main() async {
  final modelPath = Platform.environment['LLAMADART_MODEL_PATH'];
  final inputText =
      Platform.environment['LLAMADART_EMBED_TEXT'] ??
      'hello world from genkit_llamadart';

  if (modelPath == null || modelPath.isEmpty) {
    stderr.writeln('Set LLAMADART_MODEL_PATH to a local GGUF model path.');
    exitCode = 64;
    return;
  }

  final plugin = llamaDart(
    models: <LlamaModelDefinition>[
      LlamaModelDefinition(name: 'local-embed', modelPath: modelPath),
    ],
  );

  final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);

  try {
    final embeddings = await ai.embed(
      embedder: llamaDart.embedder('local-embed'),
      document: DocumentData(
        content: <Part>[TextPart(text: inputText)],
        metadata: <String, dynamic>{'source': 'example'},
      ),
      options: const LlamaDartEmbedConfig(normalize: true),
    );

    final vector = embeddings.single.embedding;
    stdout.writeln('Input: $inputText');
    stdout.writeln('Dimensions: ${vector.length}');
    stdout.writeln(
      'First values: ${vector.take(8).map((v) => v.toStringAsFixed(4)).join(', ')}',
    );
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
