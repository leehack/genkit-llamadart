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

  final prepared = await llamaDart.prepareModel(
    name: 'source-chat',
    source: ModelSource.parse(source),
    modelParams: const ModelParams(contextSize: 4096),
    options: ModelLoadOptions(
      cachePolicy: ModelCachePolicy.preferCached,
      cacheDirectory: cacheDirectory.isEmpty ? null : cacheDirectory,
    ),
    supportsEmbeddings: false,
  );
  final ai = prepared.createGenkit();

  try {
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
    await prepared.dispose();
    await ai.shutdown();
  }
}
