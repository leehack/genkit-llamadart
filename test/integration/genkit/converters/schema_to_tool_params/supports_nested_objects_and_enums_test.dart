import 'package:genkit_llamadart/src/integration/genkit/converters/schema_to_tool_params.dart';
import 'package:test/test.dart';

void main() {
  test('schemaToToolParams supports nested objects and enums', () {
    final params = schemaToToolParams(<String, dynamic>{
      'type': 'object',
      'required': <String>['city', 'unit'],
      'properties': <String, dynamic>{
        'city': <String, dynamic>{'type': 'string'},
        'unit': <String, dynamic>{
          'type': 'string',
          'enum': <String>['celsius', 'fahrenheit'],
        },
        'filters': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'days': <String, dynamic>{'type': 'integer'},
          },
        },
      },
    });

    expect(params, hasLength(3));
    expect(params[0].name, 'city');
    expect(params[1].name, 'unit');
    expect(params[2].name, 'filters');
  });
}
