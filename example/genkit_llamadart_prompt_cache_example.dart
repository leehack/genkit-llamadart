import 'dart:io';

import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run example/genkit_llamadart_prompt_cache_example.dart /models/chat.gguf',
    );
    exitCode = 64;
    return;
  }
  final pool = LlamaDartRuntimePool(
    model: LlamaModelDefinition(
      name: 'raw',
      modelPath: args.single,
      modelParams: const ModelParams(
        device: ComputeDevice.cpu,
        contextSize: 512,
        numberOfThreads: 1,
        numberOfThreadsBatch: 1,
      ),
    ),
    enablePromptCache: true,
    maxOwners: 1,
    maxPromptCaches: 1,
  );
  try {
    final first = await pool.open();
    final cache = await first.cachePrompt(
      'Once upon a time, in a quiet village near the mountains',
    );
    await first.close();
    final replacement = await pool.open();
    print(
      await replacement.generateFromCache(
        cache,
        params: const GenerationParams(maxTokens: 16, temp: 0, seed: 42),
      ),
    );
    cache.dispose();
  } finally {
    await pool.close();
  }
}
