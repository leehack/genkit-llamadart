@Tags(<String>['real-model'])
library;

import 'dart:io';

import 'package:genkit/plugin.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'real native LiteRT media works without a projector and strict JSON stays guarded',
    () async {
      final path =
          Platform.environment['LLAMADART_INTEGRATION_LITERT_MODEL_PATH'];
      final imagePath =
          Platform.environment['LLAMADART_INTEGRATION_LITERT_IMAGE_PATH'];
      final audioPath =
          Platform.environment['LLAMADART_INTEGRATION_LITERT_AUDIO_PATH'];
      if (path == null || imagePath == null || audioPath == null) {
        markTestSkipped(
          'Set the LiteRT model, image and audio fixture paths documented in CONTRIBUTING.md.',
        );
        return;
      }
      final plugin = LlamaDartPlugin(
        models: [
          LlamaModelDefinition(
            name: 'real-litert',
            modelPath: path,
            modelParams: const ModelParams(
              device: ComputeDevice.cpu,
              contextSize: 2048,
            ),
          ),
        ],
      );
      addTearDown(plugin.dispose);
      final actions = await plugin.init();
      final model = actions
          .whereType<genkit.Model<LlamaDartGenerationConfig>>()
          .single;
      final embedder = actions
          .whereType<genkit.Embedder<LlamaDartEmbedConfig>>()
          .single;
      Map<String, dynamic> supports() =>
          (model.metadata['model'] as Map<String, dynamic>)['supports']
              as Map<String, dynamic>;
      final config = const LlamaDartGenerationConfig(
        maxTokens: 8,
        temperature: 0,
      ).toJson();
      genkit.ModelRequest request(List<genkit.Part> parts) =>
          genkit.ModelRequest(
            messages: [genkit.Message(role: genkit.Role.user, content: parts)],
            config: config,
          );
      final text = await model(request([genkit.TextPart(text: 'Say hello.')]));
      expect(text.text.trim(), isNotEmpty);
      expect(supports()['constrained'], false);
      expect(supports()['embeddings'], false);
      expect(
        supports()['media'],
        true,
        reason:
            'Use a native LiteRT bundle with confirmed built-in vision or audio encoders.',
      );
      final image = await model(
        request([
          genkit.TextPart(text: 'Describe this image briefly.'),
          genkit.MediaPart(
            media: genkit.Media(
              url: Uri.file(imagePath).toString(),
              contentType: 'image/png',
            ),
          ),
        ]),
      );
      expect(image.text.trim(), isNotEmpty);
      final audio = await model(
        request([
          genkit.TextPart(text: 'Describe this audio briefly.'),
          genkit.MediaPart(
            media: genkit.Media(
              url: Uri.file(audioPath).toString(),
              contentType: 'audio/wav',
            ),
          ),
        ]),
      );
      expect(audio.text.trim(), isNotEmpty);
      await expectLater(
        model(
          genkit.ModelRequest(
            messages: [
              genkit.Message(
                role: genkit.Role.user,
                content: [genkit.TextPart(text: 'Return JSON.')],
              ),
            ],
            output: genkit.OutputConfig(format: 'json'),
          ),
        ),
        throwsA(
          isA<genkit.GenkitException>().having(
            (e) => e.status,
            'status',
            genkit.StatusCode.unimplemented,
          ),
        ),
      );
      await expectLater(
        embedder(
          genkit.EmbedRequest(
            input: [
              genkit.DocumentData(content: [genkit.TextPart(text: 'Hello')]),
            ],
          ),
        ),
        throwsA(
          isA<genkit.GenkitException>().having(
            (e) => e.status,
            'status',
            genkit.StatusCode.unimplemented,
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
