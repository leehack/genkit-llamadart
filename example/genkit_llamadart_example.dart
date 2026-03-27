import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main() async {
  final modelPath = Platform.environment['LLAMADART_MODEL_PATH'];
  final mmprojPath = Platform.environment['LLAMADART_MMPROJ_PATH'];
  final prompt =
      Platform.environment['LLAMADART_PROMPT'] ??
      'Say hello in one short sentence.';

  if (modelPath == null || modelPath.isEmpty) {
    stderr.writeln('Set LLAMADART_MODEL_PATH to a local GGUF model path.');
    exitCode = 64;
    return;
  }

  final plugin = llamaDart(
    models: <LlamaModelDefinition>[
      LlamaModelDefinition(
        name: 'local-chat',
        modelPath: modelPath,
        mmprojPath: mmprojPath,
      ),
    ],
  );

  final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);

  stdout.writeln('Prompt: $prompt');
  stdout.write('Response: ');

  try {
    final response = await ai.generate(
      model: llamaDart.model('local-chat'),
      prompt: prompt,
      config: const LlamaDartGenerationConfig(
        temperature: 0.2,
        maxTokens: 96,
        enableThinking: false,
      ),
      onChunk: (chunk) {
        if (chunk.text.isNotEmpty) {
          stdout.write(chunk.text);
        }
      },
    );

    if (response.text.isEmpty) {
      stdout.writeln('<empty>');
    } else {
      stdout.writeln();
    }
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
