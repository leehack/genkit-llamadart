import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main() async {
  final source = const String.fromEnvironment(
    'LLAMADART_MODEL_SOURCE',
    defaultValue:
        'hf://unsloth/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q2_K.gguf',
  );
  final cacheDirectory = const String.fromEnvironment(
    'LLAMADART_MODEL_CACHE',
    defaultValue: '',
  );

  final task = llamaDart.prepareModelTask(
    name: 'observable-chat',
    source: ModelSource.parse(source),
    modelParams: const ModelParams(contextSize: 4096),
    options: ModelLoadOptions(
      cachePolicy: ModelCachePolicy.preferCached,
      cacheDirectory: cacheDirectory.isEmpty ? null : cacheDirectory,
    ),
    supportsEmbeddings: false,
  );

  final subscription = task.snapshots.listen((snapshot) {
    final fraction = snapshot.fraction == null
        ? ''
        : ' ${(snapshot.fraction! * 100).toStringAsFixed(1)}%';
    final sourceRole = snapshot.sourceRole == null
        ? ''
        : ' ${snapshot.sourceRole!.name}';
    print('${snapshot.stage.name}$sourceRole$fraction');
  });

  LlamaPreparedModel? prepared;
  Genkit? ai;
  try {
    prepared = await task.result;
    ai = prepared.createGenkit();

    await prepared.warmUp(
      ai,
      systemPrompt: 'Use terse answers.',
      prompt: 'Reply with one token: ready',
    );

    final response = await ai.generate(
      model: prepared.modelRef,
      prompt: 'Say hello in one sentence.',
      config: const LlamaDartGenerationConfig(
        maxTokens: 32,
        temperature: 0.0,
        enableThinking: false,
      ),
    );
    print(response.text);
  } finally {
    await subscription.cancel();
    await task.dispose();
    if (prepared != null) {
      await prepared.dispose();
    }
    if (ai != null) {
      await ai.shutdown();
    }
  }
}
