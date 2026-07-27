import 'package:genkit/plugin.dart' as genkit;
import 'package:genkit_llamadart/src/integration/genkit/converters/genkit_to_llama.dart';
import 'package:test/test.dart';

void main() {
  test('toLlamaTools rejects non-object input schemas', () {
    for (final schema in <Map<String, dynamic>>[
      <String, dynamic>{'type': 'string'},
      <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      <String, dynamic>{'type': 'number'},
      <String, dynamic>{},
    ]) {
      expect(
        () => toLlamaTools(<genkit.ToolDefinition>[
          genkit.ToolDefinition(
            name: 'lookup',
            description: 'Look up a value.',
            inputSchema: schema,
          ),
        ]),
        throwsA(
          isA<genkit.GenkitException>().having(
            (error) => error.status,
            'status',
            genkit.StatusCodes.INVALID_ARGUMENT,
          ),
        ),
        reason: 'Expected schema $schema to be rejected.',
      );
    }
  });
}
