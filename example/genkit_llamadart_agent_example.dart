import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:schemantic/schemantic.dart';

final SchemanticType<Map<String, dynamic>> _jsonMapSchema = SchemanticType.map(
  SchemanticType.string(),
  SchemanticType.dynamicSchema(),
);

final SchemanticType<Map<String, dynamic>> _weatherToolInputSchema =
    JsonObjectSchema(
      name: 'WeatherToolInput',
      description: 'Arguments for the get_weather tool.',
      properties: <String, $Schema>{
        'location': $Schema.string(
          description: 'City name such as Seoul or Tokyo.',
        ),
        'unit': $Schema.string(
          description: 'Temperature unit.',
          enumValues: const <String>['celsius', 'fahrenheit'],
        ),
      },
      requiredProperties: const <String>['location'],
    );

final SchemanticType<Map<String, dynamic>> _timeToolInputSchema =
    JsonObjectSchema(
      name: 'LocalTimeToolInput',
      description: 'Arguments for the get_local_time tool.',
      properties: <String, $Schema>{
        'city': $Schema.string(
          description: 'City name such as Seoul or Tokyo.',
        ),
      },
      requiredProperties: const <String>['city'],
    );

final SchemanticType<Map<String, dynamic>> _factToolInputSchema =
    JsonObjectSchema(
      name: 'LookupFactToolInput',
      description: 'Arguments for the lookup_fact tool.',
      properties: <String, $Schema>{
        'topic': $Schema.string(description: 'The topic to look up.'),
      },
      requiredProperties: const <String>['topic'],
    );

const String _modelPathEnv = 'LLAMADART_MODEL_PATH';
const String _mmprojPathEnv = 'LLAMADART_MMPROJ_PATH';
const String _promptEnv = 'LLAMADART_PROMPT';

const String _agentSystemPrompt =
    'You are a command-line agent. Use tools whenever they are relevant before answering. '
    'For get_weather you must provide location and may provide unit. '
    'For get_local_time you must provide city. '
    'For lookup_fact you must provide topic. '
    'After a tool returns, incorporate the result into a concise final answer.';

const Map<String, Map<String, dynamic>> _weatherByLocation =
    <String, Map<String, dynamic>>{
      'seoul': <String, dynamic>{
        'location': 'Seoul',
        'condition': 'clear',
        'temperatureC': 19,
        'temperatureF': 66,
      },
      'tokyo': <String, dynamic>{
        'location': 'Tokyo',
        'condition': 'cloudy',
        'temperatureC': 22,
        'temperatureF': 72,
      },
      'san francisco': <String, dynamic>{
        'location': 'San Francisco',
        'condition': 'foggy',
        'temperatureC': 14,
        'temperatureF': 57,
      },
    };

const Map<String, Map<String, dynamic>> _timeByCity =
    <String, Map<String, dynamic>>{
      'seoul': <String, dynamic>{
        'city': 'Seoul',
        'localTime': '2026-03-13 21:15',
        'timezone': 'Asia/Seoul',
      },
      'tokyo': <String, dynamic>{
        'city': 'Tokyo',
        'localTime': '2026-03-13 21:15',
        'timezone': 'Asia/Tokyo',
      },
      'san francisco': <String, dynamic>{
        'city': 'San Francisco',
        'localTime': '2026-03-13 05:15',
        'timezone': 'America/Los_Angeles',
      },
    };

const Map<String, Map<String, dynamic>>
_factsByTopic = <String, Map<String, dynamic>>{
  'genkit': <String, dynamic>{
    'topic': 'genkit',
    'fact':
        'Genkit can automatically execute tool loops when a model returns tool requests.',
  },
  'llamadart': <String, dynamic>{
    'topic': 'llamadart',
    'fact':
        'llamadart runs GGUF models locally from Dart and Flutter applications.',
  },
};

Future<void> main() async {
  final modelPath = Platform.environment[_modelPathEnv];
  final mmprojPath = Platform.environment[_mmprojPathEnv];
  final initialPrompt = Platform.environment[_promptEnv];

  if (modelPath == null || modelPath.isEmpty) {
    stderr.writeln('Set $_modelPathEnv to a local GGUF model path.');
    exitCode = 64;
    return;
  }

  final plugin = llamaDart(
    models: <LlamaModelDefinition>[
      LlamaModelDefinition(
        name: 'local-agent',
        modelPath: modelPath,
        mmprojPath: mmprojPath,
        modelParams: const ModelParams(contextSize: 8192),
      ),
    ],
  );

  final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);
  final tools = <Tool<dynamic, dynamic>>[
    _defineWeatherTool(ai),
    _defineLocalTimeTool(ai),
    _defineKnowledgeTool(ai),
  ];

  var history = <Message>[
    Message(
      role: Role.system,
      content: <Part>[TextPart(text: _agentSystemPrompt)],
    ),
  ];

  try {
    if (initialPrompt != null && initialPrompt.trim().isNotEmpty) {
      history = await _runTurn(ai, history, tools, initialPrompt.trim());
      return;
    }

    stdout.writeln('Interactive llamadart agent');
    stdout.writeln('Type `quit` to exit or `clear` to reset history.');
    stdout.writeln(
      'Try: What is the weather in Seoul, and what time is it there?',
    );

    while (true) {
      stdout.write('\nuser> ');
      final input = stdin.readLineSync();
      if (input == null) {
        stdout.writeln();
        break;
      }

      final trimmed = input.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed == 'quit' || trimmed == 'exit') {
        break;
      }
      if (trimmed == 'clear') {
        history = history.take(1).toList(growable: false);
        stdout.writeln('History cleared.');
        continue;
      }

      history = await _runTurn(ai, history, tools, trimmed);
    }
  } finally {
    await plugin.dispose();
  }
}

Future<List<Message>> _runTurn(
  Genkit ai,
  List<Message> history,
  List<Tool<dynamic, dynamic>> tools,
  String input,
) async {
  final requestMessages = <Message>[
    ...history,
    Message(
      role: Role.user,
      content: <Part>[TextPart(text: input)],
    ),
  ];

  stdout.write('assistant> ');
  final response = await ai.generate(
    model: llamaDart.model('local-agent'),
    messages: requestMessages,
    tools: tools,
    maxTurns: 8,
    context: <String, dynamic>{'latestUserInput': input},
    config: const LlamaDartGenerationConfig(
      temperature: 0.2,
      maxTokens: 256,
      enableThinking: false,
      parallelToolCalls: true,
    ),
  );

  stdout.writeln(response.text.isEmpty ? '<empty>' : response.text);

  return response.messages;
}

Tool<Map<String, dynamic>, Map<String, dynamic>> _defineWeatherTool(Genkit ai) {
  return ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'get_weather',
    description:
        'Get current weather for a location. Required input key: location. Optional input key: unit.',
    inputSchema: _weatherToolInputSchema,
    outputSchema: _jsonMapSchema,
    fn: (input, context) async {
      final inferredLocation = _inferLocation(
        context.context?['latestUserInput'],
      );
      final location = _stringArg(
        input,
        'location',
        fallback: inferredLocation ?? 'unknown',
      );
      final unit = _stringArg(
        input,
        'unit',
        fallback: _inferUnit(context.context?['latestUserInput']) ?? 'celsius',
      );
      final weather =
          _weatherByLocation[location.toLowerCase()] ??
          <String, dynamic>{
            'location': location,
            'condition': 'unknown',
            'temperatureC': 20,
            'temperatureF': 68,
          };

      final output = <String, dynamic>{
        ...weather,
        'unit': unit,
        'reportedTemperature': unit == 'fahrenheit'
            ? weather['temperatureF']
            : weather['temperatureC'],
      };
      _logTool('get_weather', input, output);
      return output;
    },
  );
}

Tool<Map<String, dynamic>, Map<String, dynamic>> _defineLocalTimeTool(
  Genkit ai,
) {
  return ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'get_local_time',
    description: 'Get the local time for a city. Required input key: city.',
    inputSchema: _timeToolInputSchema,
    outputSchema: _jsonMapSchema,
    fn: (input, context) async {
      final city = _stringArg(
        input,
        'city',
        fallback:
            _inferLocation(context.context?['latestUserInput']) ?? 'unknown',
      );
      final output =
          _timeByCity[city.toLowerCase()] ??
          <String, dynamic>{
            'city': city,
            'localTime': '2026-03-13 12:00',
            'timezone': 'UTC',
          };
      _logTool('get_local_time', input, output);
      return output;
    },
  );
}

Tool<Map<String, dynamic>, Map<String, dynamic>> _defineKnowledgeTool(
  Genkit ai,
) {
  return ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'lookup_fact',
    description:
        'Look up a short stored fact by topic. Required input key: topic.',
    inputSchema: _factToolInputSchema,
    outputSchema: _jsonMapSchema,
    fn: (input, context) async {
      final topic = _stringArg(
        input,
        'topic',
        fallback: _inferTopic(context.context?['latestUserInput']) ?? 'unknown',
      );
      final output =
          _factsByTopic[topic.toLowerCase()] ??
          <String, dynamic>{'topic': topic, 'fact': 'No stored fact found.'};
      _logTool('lookup_fact', input, output);
      return output;
    },
  );
}

String _stringArg(
  Map<String, dynamic> input,
  String key, {
  required String fallback,
}) {
  final value = input[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

String? _inferLocation(Object? rawInput) {
  final input = rawInput is String ? rawInput.toLowerCase() : '';
  if (input.contains('san francisco')) {
    return 'San Francisco';
  }
  if (input.contains('seoul')) {
    return 'Seoul';
  }
  if (input.contains('tokyo')) {
    return 'Tokyo';
  }
  return null;
}

String? _inferUnit(Object? rawInput) {
  final input = rawInput is String ? rawInput.toLowerCase() : '';
  if (input.contains('fahrenheit')) {
    return 'fahrenheit';
  }
  if (input.contains('celsius')) {
    return 'celsius';
  }
  return null;
}

String? _inferTopic(Object? rawInput) {
  final input = rawInput is String ? rawInput.toLowerCase() : '';
  if (input.contains('genkit')) {
    return 'genkit';
  }
  if (input.contains('llamadart')) {
    return 'llamadart';
  }
  return null;
}

void _logTool(String name, Map<String, dynamic> input, Object output) {
  stderr.writeln(
    '[tool:$name] input=${jsonEncode(input)} output=${jsonEncode(output)}',
  );
}

final class JsonObjectSchema extends SchemanticType<Map<String, dynamic>> {
  JsonObjectSchema({
    required this.name,
    required this.properties,
    this.requiredProperties = const <String>[],
    this.description,
  });

  final String name;
  final String? description;
  final Map<String, $Schema> properties;
  final List<String> requiredProperties;

  @override
  Map<String, dynamic> parse(Object? json) {
    if (json is Map<String, dynamic>) {
      return json;
    }
    if (json is Map) {
      return json.cast<String, dynamic>();
    }
    throw FormatException('Expected a JSON object for $name.');
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: name,
    definition: $Schema
        .object(
          properties: properties,
          required: requiredProperties,
          description: description,
        )
        .value,
  );
}
