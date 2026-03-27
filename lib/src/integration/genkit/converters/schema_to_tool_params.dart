import 'package:llamadart/llamadart.dart' as llama;

List<llama.ToolParam> schemaToToolParams(Map<String, dynamic>? schema) {
  if (schema == null) {
    return const <llama.ToolParam>[];
  }

  final normalized = Map<String, dynamic>.from(schema);
  final propertiesRaw = normalized['properties'];
  if (propertiesRaw is! Map) {
    return const <llama.ToolParam>[];
  }

  final requiredNames = _parseRequiredSet(normalized['required']);
  final properties = propertiesRaw.cast<String, dynamic>();

  return properties.entries
      .map((entry) {
        return _mapSchemaToToolParam(
          entry.key,
          entry.value is Map<String, dynamic>
              ? entry.value as Map<String, dynamic>
              : Map<String, dynamic>.from(entry.value as Map),
          required: requiredNames.contains(entry.key),
        );
      })
      .toList(growable: false);
}

llama.ToolParam _mapSchemaToToolParam(
  String name,
  Map<String, dynamic> schema, {
  required bool required,
}) {
  final description = schema['description'] as String?;
  final enumValues = schema['enum'];

  if (enumValues is List && enumValues.every((value) => value is String)) {
    return llama.ToolParam.enumType(
      name,
      values: enumValues.cast<String>(),
      description: description,
      required: required,
    );
  }

  final type = _normalizeType(schema['type']);
  switch (type) {
    case 'string':
      return llama.ToolParam.string(
        name,
        description: description,
        required: required,
      );
    case 'integer':
      return llama.ToolParam.integer(
        name,
        description: description,
        required: required,
      );
    case 'number':
      return llama.ToolParam.number(
        name,
        description: description,
        required: required,
      );
    case 'boolean':
      return llama.ToolParam.boolean(
        name,
        description: description,
        required: required,
      );
    case 'array':
      return llama.ToolParam.array(
        name,
        itemType: _mapArrayItem(name, schema['items']),
        description: description,
        required: required,
      );
    case 'object':
      return llama.ToolParam.object(
        name,
        properties: _mapObjectProperties(schema),
        description: description,
        required: required,
      );
    default:
      return llama.ToolParam.string(
        name,
        description: description,
        required: required,
      );
  }
}

llama.ToolParam _mapArrayItem(String name, Object? rawSchema) {
  if (rawSchema is Map<String, dynamic>) {
    return _mapSchemaToToolParam('${name}_item', rawSchema, required: false);
  }

  if (rawSchema is Map) {
    return _mapSchemaToToolParam(
      '${name}_item',
      rawSchema.cast<String, dynamic>(),
      required: false,
    );
  }

  return llama.ToolParam.string('${name}_item');
}

List<llama.ToolParam> _mapObjectProperties(Map<String, dynamic> schema) {
  final propertiesRaw = schema['properties'];
  if (propertiesRaw is! Map) {
    return const <llama.ToolParam>[];
  }

  final requiredNames = _parseRequiredSet(schema['required']);
  final properties = propertiesRaw.cast<String, dynamic>();

  return properties.entries
      .map((entry) {
        return _mapSchemaToToolParam(
          entry.key,
          entry.value is Map<String, dynamic>
              ? entry.value as Map<String, dynamic>
              : Map<String, dynamic>.from(entry.value as Map),
          required: requiredNames.contains(entry.key),
        );
      })
      .toList(growable: false);
}

Set<String> _parseRequiredSet(Object? raw) {
  if (raw is List && raw.every((value) => value is String)) {
    return raw.cast<String>().toSet();
  }
  return const <String>{};
}

String? _normalizeType(Object? rawType) {
  if (rawType is String) {
    return rawType;
  }

  if (rawType is List) {
    for (final value in rawType) {
      if (value is String && value != 'null') {
        return value;
      }
    }
  }

  return null;
}
