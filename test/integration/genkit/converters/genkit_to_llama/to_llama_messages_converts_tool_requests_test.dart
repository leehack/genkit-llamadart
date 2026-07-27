import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/src/integration/genkit/converters/genkit_to_llama.dart';
import 'package:llamadart/llamadart.dart' as llama;
import 'package:test/test.dart';

void main() {
  test('toLlamaMessages converts object-shaped tool request input', () {
    final messages = <genkit.Message>[
      genkit.Message(
        role: genkit.Role.model,
        content: <genkit.Part>[
          genkit.ToolRequestPart(
            toolRequest: genkit.ToolRequest(
              ref: 'call-1',
              name: 'lookup',
              input: <String, dynamic>{'city': 'Seoul'},
            ),
          ),
        ],
      ),
    ];

    final converted = toLlamaMessages(messages);
    final toolCall =
        converted.single.parts.single as llama.LlamaToolCallContent;

    expect(toolCall.arguments, <String, dynamic>{'city': 'Seoul'});
    expect(toolCall.rawJson, '{"city":"Seoul"}');
  });

  test('tool request conversion rejects non-object input', () {
    expect(
      () => toLlamaToolArguments('Seoul'),
      throwsA(
        isA<genkit.GenkitException>().having(
          (error) => error.status,
          'status',
          genkit.StatusCodes.INVALID_ARGUMENT,
        ),
      ),
    );
  });
}
