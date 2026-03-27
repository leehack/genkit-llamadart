import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:test/test.dart';

void main() {
  test('LlamaDartEmbedConfig.fromJson parses normalize flag', () {
    final config = LlamaDartEmbedConfig.fromJson(<String, dynamic>{
      'normalize': false,
    });

    expect(config.normalize, isFalse);
  });
}
