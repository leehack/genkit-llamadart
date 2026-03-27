import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:test/test.dart';

void main() {
  test('LlamaModelDefinition stores capability flags', () {
    const definition = LlamaModelDefinition(
      name: 'local',
      modelPath: '/tmp/model.gguf',
      supportsEmbeddings: false,
      supportsTools: false,
      supportsConstrainedOutput: false,
    );

    expect(definition.supportsEmbeddings, isFalse);
    expect(definition.supportsTools, isFalse);
    expect(definition.supportsConstrainedOutput, isFalse);
  });
}
