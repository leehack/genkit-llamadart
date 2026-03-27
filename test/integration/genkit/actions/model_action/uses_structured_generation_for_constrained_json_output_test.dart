import 'package:genkit/genkit.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;
import 'package:test/test.dart';

import '../../../../core/runtime/test_support/fake_runtime.dart';
import '../test_support/action_harness.dart';

void main() {
  test(
    'model action uses structured generation for constrained JSON output',
    () async {
      final runtime = FakeRuntime()
        ..templateResult = const llama.LlamaChatTemplateResult(
          prompt: 'prompt',
          format: 0,
        )
        ..generatedTokens = <String>['{"answer":"hi"}'];
      final action = testModelAction(runtime: runtime);

      final response = await action(
        genkit.ModelRequest(
          messages: <genkit.Message>[
            genkit.Message(
              role: genkit.Role.user,
              content: <genkit.Part>[
                genkit.TextPart(text: 'Respond with JSON'),
              ],
            ),
          ],
          output: genkit.OutputConfig(
            format: 'json',
            schema: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{
                'answer': <String, dynamic>{'type': 'string'},
              },
            },
          ),
        ),
      );

      expect(runtime.chatTemplateCallCount, 1);
      expect(runtime.generateCallCount, 1);
      expect(response.text, '{"answer":"hi"}');
    },
  );
}
