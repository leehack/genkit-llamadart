import 'dart:convert';

import 'package:llamadart/llamadart.dart' as llama;
import 'package:test/test.dart';

import '../../../../example/decision/triage_flow.dart';

Map<String, dynamic> _result() => llama.DecisionResult(
  model: 'laya',
  answers: {
    'department': llama.ChoiceAnswer(
      choice: 'billing',
      probabilities: {
        'billing': 0.7,
        'technical': 0.1,
        'sales': 0.1,
        'other': 0.1,
      },
      confidence: 0.5,
      actProbability: 1,
    ),
    'urgency': llama.ScoreAnswer(
      score: 1.4,
      legend: {'0': 'not urgent', '1': 'soon', '2': 'critical'},
      probabilities: {'0': 0.1, '1': 0.4, '2': 0.5},
      confidence: 0.2,
      actProbability: 1,
    ),
    'refund': llama.NoulAnswer(noul: 0.8, confidence: 0.8, actProbability: 1),
  },
  usage: const llama.DecisionUsage(inputTokens: 200, outputTokens: 0),
).toJson();

void main() {
  test(
    'complete upstream response preserves fractional scores and JSON data',
    () async {
      final result = _result();
      expect(await triageOutputSchema.validate(result), isEmpty);
      final roundTrip = triageOutputSchema.parse(
        jsonDecode(jsonEncode(result)),
      );
      expect(roundTrip, result);
      expect(roundTrip['answers']['urgency']['score'], 1.4);
    },
  );

  test(
    'response schema rejects missing or mismatched decision answers',
    () async {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (result) => result['answers'].remove('refund'),
        (result) => result['answers']['refund']['type'] = 'choice',
        (result) => result['answers']['department']['choice'] = 'invented',
        (result) =>
            result['answers']['department']['probabilities'].remove('sales'),
        (result) => result['answers']['urgency']['legend'].remove('2'),
        (result) => result['answers']['refund']['noul'] = 1.1,
        (result) => result['answers']['urgency']['score'] = 3,
        (result) => result['answers']['department'].remove('confidence'),
        (result) => result['usage']['output_tokens'] = 1,
      ]) {
        final result =
            jsonDecode(jsonEncode(_result())) as Map<String, dynamic>;
        mutate(result);
        expect(
          await triageOutputSchema.validate(result),
          isNotEmpty,
          reason: '$result',
        );
      }
    },
  );
}
