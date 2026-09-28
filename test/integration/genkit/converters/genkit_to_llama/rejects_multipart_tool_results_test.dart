import 'package:genkit/plugin.dart';
import 'package:genkit_llamadart/src/integration/genkit/converters/genkit_to_llama.dart';
import 'package:test/test.dart';

void main() {
  test('multipart tool results fail explicitly for every message role', () {
    for (final role in [Role.tool, Role.user]) {
      expect(
        () => toLlamaMessages([
          Message(
            role: role,
            content: [
              ToolResponsePart(
                toolResponse: ToolResponse(
                  name: 'lookup',
                  output: 'ok',
                  content: [
                    {'text': 'extra'},
                  ],
                ),
              ),
            ],
          ),
        ]),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.UNIMPLEMENTED,
          ),
        ),
      );
    }
  });
}
