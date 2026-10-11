import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:schemantic/schemantic.dart';

/// Runs an application-owned raw completion through a typed Genkit flow.
Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Supply a local GGUF model path.');
  final pool = LlamaDartRuntimePool(
    model: LlamaModelDefinition(name: 'raw', modelPath: args.single),
    maxOwners: 1,
  );
  final ai = Genkit();
  try {
    final owner = await pool.open();
    final complete = ai.defineFlow<String, String, void, void>(
      name: 'ownedCompletion',
      inputSchema: SchemanticType.string(minLength: 1),
      outputSchema: SchemanticType.string(),
      fn: (prompt, context) => owner.generate(
        prompt,
        params: const GenerationParams(maxTokens: 32, temp: 0),
        cancellation: context.cancel,
      ),
    );
    print(await complete('Once upon a time'));
  } finally {
    try {
      await pool.close();
    } finally {
      await ai.shutdown();
    }
  }
}
