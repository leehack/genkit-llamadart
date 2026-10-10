import 'dart:convert';

import 'package:genkit/plugin.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;
import 'package:schemantic/schemantic.dart';

Map<String, dynamic> constrainedToolSchema(
  List<llama.ToolDefinition> tools,
  llama.ToolChoice choice,
  Map<String, dynamic>? outputSchema,
) {
  final response = outputSchema ?? <String, dynamic>{'type': 'object'};
  final calls = [
    for (final tool in tools)
      {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'const': tool.name},
          'arguments': tool.toJsonSchema(),
        },
        'required': ['name', 'arguments'],
        'additionalProperties': false,
      },
  ];
  final toolEnvelope = <String, dynamic>{
    'type': 'object',
    'properties': {
      'tool_call': calls.length == 1 ? calls.single : {'anyOf': calls},
    },
    'required': ['tool_call'],
    'additionalProperties': false,
  };
  final responseEnvelope = <String, dynamic>{
    'type': 'object',
    'properties': {
      'response': {r'$ref': r'#/$defs/genkitResponse'},
    },
    'required': ['response'],
    'additionalProperties': false,
  };
  return {
    r'$defs': {'genkitResponse': _nestReferences(response)},
    if (choice == llama.ToolChoice.required)
      ...toolEnvelope
    else
      'anyOf': [toolEnvelope, responseEnvelope],
  };
}

Future<void> validateConstrainedValue(
  Object? value,
  Map<String, dynamic> schema,
) async {
  final type = SchemanticType.from(jsonSchema: schema, parse: (value) => value);
  if ((await type.validate(value)).isNotEmpty) throw invalidConstrainedOutput();
}

Object? decodeConstrainedValue(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    throw invalidConstrainedOutput();
  }
}

genkit.GenkitException invalidConstrainedOutput() => genkit.GenkitException(
  'The model returned incomplete or invalid constrained output. No partial result or tool call was published.',
  status: genkit.StatusCode.failedPrecondition,
);

Map<String, dynamic> _nestReferences(Map<String, dynamic> schema) {
  const children = {
    'additionalProperties',
    'unevaluatedProperties',
    'propertyNames',
    'items',
    'additionalItems',
    'unevaluatedItems',
    'contains',
    'not',
    'if',
    'then',
    'else',
  };
  const dictionaries = {
    'properties',
    'patternProperties',
    r'$defs',
    'definitions',
    'dependentSchemas',
  };
  const lists = {'allOf', 'anyOf', 'oneOf', 'prefixItems'};
  if (schema.keys.any(
    {
      r'$id',
      r'$anchor',
      r'$dynamicAnchor',
      r'$dynamicRef',
      'dependencies',
    }.contains,
  )) {
    throw genkit.GenkitException(
      'Constrained tools do not support scoped, anchored, dynamic references or legacy dependencies. Use local JSON pointer references.',
      status: genkit.StatusCode.invalidArgument,
    );
  }
  final result = Map<String, dynamic>.from(schema);
  final reference = schema[r'$ref'];
  if (reference != null) {
    if (reference is! String ||
        !(reference == '#' || reference.startsWith('#/'))) {
      throw genkit.GenkitException(
        'Constrained tools support local JSON pointer schema references only.',
        status: genkit.StatusCode.invalidArgument,
      );
    }
    result[r'$ref'] = r'#/$defs/genkitResponse' + reference.substring(1);
  }
  for (final entry in schema.entries) {
    final value = entry.value;
    if (dictionaries.contains(entry.key) && value is Map) {
      result[entry.key] = <String, dynamic>{
        for (final child in value.entries)
          child.key as String: child.value is Map
              ? _nestReferences((child.value as Map).cast<String, dynamic>())
              : child.value,
      };
    } else if ((lists.contains(entry.key) || entry.key == 'items') &&
        value is List) {
      result[entry.key] = [
        for (final child in value)
          child is Map ? _nestReferences(child.cast<String, dynamic>()) : child,
      ];
    } else if (children.contains(entry.key) && value is Map) {
      result[entry.key] = _nestReferences(value.cast<String, dynamic>());
    }
  }
  return result;
}
