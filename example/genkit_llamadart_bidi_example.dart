// This CLI intentionally opts into Genkit's experimental session protocol.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';

import 'package:genkit/experimental.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/experimental.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run example/genkit_llamadart_bidi_example.dart /models/chat.gguf',
    );
    exitCode = 64;
    return;
  }
  final plugin = LlamaDartBidiPlugin(
    models: [
      LlamaModelDefinition(
        name: 'local',
        modelPath: args.single,
        modelParams: const ModelParams(
          device: ComputeDevice.cpu,
          contextSize: 1024,
          numberOfThreads: 1,
          numberOfThreadsBatch: 1,
        ),
      ),
    ],
    maxSessions: 1,
    maxTurns: 2,
  );
  final ai = Genkit(plugins: [plugin], isDevEnv: false);
  try {
    final session = await ai.generateBidi(
      model: 'llamadart-bidi/local',
      config: const LlamaDartGenerationConfig(
        maxTokens: 32,
        temperature: 0,
        seed: 42,
      ),
    );
    final output = StreamIterator(session.stream);
    try {
      for (final prompt in ['Say hello.', 'What did I ask you to say?']) {
        session.send(prompt);
        if (!await output.moveNext()) {
          throw StateError('The text session closed before its response.');
        }
        print(output.current.text);
      }
      await session.close();
      while (await output.moveNext()) {}
    } finally {
      await session.close();
      await output.cancel();
    }
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
