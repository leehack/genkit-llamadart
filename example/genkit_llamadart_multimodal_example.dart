import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError(
      'Supply a vision GGUF, its matching projector and a PNG/JPEG image.',
    );
  }
  final prepared = await llamaDart.prepareModel(
    name: 'vision',
    source: ModelSource.path(args[0]),
    mmprojSource: ModelSource.path(args[1]),
    modelParams: const ModelParams(
      contextSize: 4096,
      device: ComputeDevice.cpu,
    ),
    supportsEmbeddings: false,
  );
  final ai = prepared.createGenkit();
  try {
    final response = await ai.generate(
      messages: [
        Message(
          role: Role.user,
          content: [
            TextPart(text: 'Describe this image in one sentence.'),
            MediaPart(media: Media(url: File(args[2]).absolute.uri.toString())),
          ],
        ),
      ],
      config: const LlamaDartGenerationConfig(maxTokens: 128, temperature: 0),
    );
    if (response.finishReason == FinishReason.failed ||
        response.finishReason == FinishReason.aborted) {
      throw response.cause ?? StateError('Image description did not complete.');
    }
    print(response.text);
  } finally {
    try {
      await prepared.dispose();
    } finally {
      await ai.shutdown();
    }
  }
}
