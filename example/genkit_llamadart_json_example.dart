import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:schemantic/schemantic.dart';

final SchemanticType<Map<String, dynamic>> _reviewSchema =
    SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'summary': <String, Object?>{'type': 'string'},
          'sentiment': <String, Object?>{'type': 'string'},
        },
        'required': <String>['summary', 'sentiment'],
        'additionalProperties': false,
      },
      parse: (json) {
        if (json is Map<String, dynamic>) {
          return json;
        }
        if (json is Map) {
          return json.cast<String, dynamic>();
        }
        throw FormatException('Expected a JSON object.');
      },
    );

Future<void> main() async {
  final modelPath = Platform.environment['LLAMADART_MODEL_PATH'];
  final prompt =
      Platform.environment['LLAMADART_PROMPT'] ??
      'Summarize this review as JSON: The battery lasts all day, but the speakers are weak.';

  if (modelPath == null || modelPath.isEmpty) {
    stderr.writeln('Set LLAMADART_MODEL_PATH to a local GGUF model path.');
    exitCode = 64;
    return;
  }

  final plugin = llamaDart(
    models: <LlamaModelDefinition>[
      LlamaModelDefinition(name: 'local-json', modelPath: modelPath),
    ],
  );

  final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);

  try {
    final response = await ai
        .generate<LlamaDartGenerationConfig, Map<String, dynamic>>(
          model: llamaDart.model('local-json'),
          prompt: prompt,
          outputSchema: _reviewSchema,
          outputFormat: 'json',
          outputConstrained: true,
          config: const LlamaDartGenerationConfig(
            temperature: 0.1,
            maxTokens: 128,
            enableThinking: false,
          ),
        );

    stdout.writeln(jsonEncode(response.output));
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
