import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_llamadart/src/engine_registry.dart';
import 'package:genkit_llamadart/src/model_action.dart';
import 'package:llamadart/llamadart.dart' as llama;
import 'package:test/test.dart';

import 'src/fake_runtime.dart';

void main() {
  test('model action streams text and reasoning chunks', () async {
    final runtime = FakeRuntime()
      ..createChunks = <dynamic>[
        thinkingChunk('thinking'),
        textChunk('hello'),
        stopChunk(),
      ].cast();
    final action = buildModelAction(
      definition: const LlamaModelDefinition(
        name: 'local',
        modelPath: '/tmp/model.gguf',
      ),
      registry: EngineRegistry(
        models: const <LlamaModelDefinition>[
          LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
        ],
        runtimeFactory: () => runtime,
      ),
    );

    final streamed = <genkit.ModelResponseChunk>[];
    final response = await action(
      genkit.ModelRequest(
        messages: <genkit.Message>[
          genkit.Message(
            role: genkit.Role.user,
            content: <genkit.Part>[genkit.TextPart(text: 'Hi')],
          ),
        ],
      ),
      onChunk: streamed.add,
    );

    expect(streamed, hasLength(2));
    expect(streamed.first.content.first.reasoning, 'thinking');
    expect(streamed.last.text, 'hello');
    expect(response.text, 'hello');
    expect(response.message!.content.first.reasoning, 'thinking');
  });

  test(
    'model action returns tool requests from final tool call chunk',
    () async {
      final runtime = FakeRuntime()
        ..createChunks = <dynamic>[
          toolCallChunk(
            id: 'call-1',
            name: 'get_weather',
            arguments: '{"city":"Seoul"}',
          ),
        ].cast();
      final action = buildModelAction(
        definition: const LlamaModelDefinition(
          name: 'local',
          modelPath: '/tmp/model.gguf',
        ),
        registry: EngineRegistry(
          models: const <LlamaModelDefinition>[
            LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
          ],
          runtimeFactory: () => runtime,
        ),
      );

      final response = await action(
        genkit.ModelRequest(
          messages: <genkit.Message>[
            genkit.Message(
              role: genkit.Role.user,
              content: <genkit.Part>[genkit.TextPart(text: 'Weather?')],
            ),
          ],
          tools: <genkit.ToolDefinition>[
            genkit.ToolDefinition(
              name: 'get_weather',
              description: 'Get weather',
              inputSchema: <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'city': <String, dynamic>{'type': 'string'},
                },
              },
            ),
          ],
        ),
      );

      expect(response.toolRequests, hasLength(1));
      expect(response.toolRequests.single.name, 'get_weather');
      expect(response.toolRequests.single.input, <String, dynamic>{
        'city': 'Seoul',
      });
      expect(response.raw, isNot(contains('path')));
    },
  );

  test('model action accumulates streamed tool call argument deltas', () async {
    final runtime = FakeRuntime()
      ..createChunks = <dynamic>[
        toolCallDeltaChunk(id: 'call-1', name: 'get_weather', arguments: '{'),
        toolCallDeltaChunk(arguments: '"city":"Seo'),
        toolCallDeltaChunk(arguments: 'ul"}', finishReason: 'tool_calls'),
      ].cast();
    final action = buildModelAction(
      definition: const LlamaModelDefinition(
        name: 'local',
        modelPath: '/tmp/model.gguf',
      ),
      registry: EngineRegistry(
        models: const <LlamaModelDefinition>[
          LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
        ],
        runtimeFactory: () => runtime,
      ),
    );

    final response = await action(
      genkit.ModelRequest(
        messages: <genkit.Message>[
          genkit.Message(
            role: genkit.Role.user,
            content: <genkit.Part>[genkit.TextPart(text: 'Weather?')],
          ),
        ],
        tools: <genkit.ToolDefinition>[
          genkit.ToolDefinition(
            name: 'get_weather',
            description: 'Get weather',
            inputSchema: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{
                'city': <String, dynamic>{'type': 'string'},
              },
            },
          ),
        ],
      ),
    );

    expect(response.toolRequests, hasLength(1));
    expect(response.toolRequests.single.ref, 'call-1');
    expect(response.toolRequests.single.input, <String, dynamic>{
      'city': 'Seoul',
    });
  });

  test(
    'model action uses structured generation for constrained JSON output',
    () async {
      final runtime = FakeRuntime()
        ..templateResult = const llama.LlamaChatTemplateResult(
          prompt: 'prompt',
          format: 0,
        )
        ..generatedTokens = <String>['{"answer":"hi"}'];
      final action = buildModelAction(
        definition: const LlamaModelDefinition(
          name: 'local',
          modelPath: '/tmp/model.gguf',
        ),
        registry: EngineRegistry(
          models: const <LlamaModelDefinition>[
            LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
          ],
          runtimeFactory: () => runtime,
        ),
      );

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

  test('model action rejects docs input', () async {
    final runtime = FakeRuntime();
    final action = buildModelAction(
      definition: const LlamaModelDefinition(
        name: 'local',
        modelPath: '/tmp/model.gguf',
      ),
      registry: EngineRegistry(
        models: const <LlamaModelDefinition>[
          LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
        ],
        runtimeFactory: () => runtime,
      ),
    );

    expect(
      () => action(
        genkit.ModelRequest(
          messages: <genkit.Message>[
            genkit.Message(
              role: genkit.Role.user,
              content: <genkit.Part>[genkit.TextPart(text: 'Hi')],
            ),
          ],
          docs: <genkit.DocumentData>[
            genkit.DocumentData(
              content: <genkit.Part>[genkit.TextPart(text: 'doc')],
            ),
          ],
        ),
      ),
      throwsA(
        isA<genkit.GenkitException>().having(
          (error) => error.status,
          'status',
          genkit.StatusCodes.INVALID_ARGUMENT,
        ),
      ),
    );
  });

  test('model action rejects tool use when disabled for the model', () async {
    final runtime = FakeRuntime();
    final action = buildModelAction(
      definition: const LlamaModelDefinition(
        name: 'local',
        modelPath: '/tmp/model.gguf',
        supportsTools: false,
      ),
      registry: EngineRegistry(
        models: const <LlamaModelDefinition>[
          LlamaModelDefinition(
            name: 'local',
            modelPath: '/tmp/model.gguf',
            supportsTools: false,
          ),
        ],
        runtimeFactory: () => runtime,
      ),
    );

    expect(
      () => action(
        genkit.ModelRequest(
          messages: <genkit.Message>[
            genkit.Message(
              role: genkit.Role.user,
              content: <genkit.Part>[genkit.TextPart(text: 'Use a tool')],
            ),
          ],
          tools: <genkit.ToolDefinition>[
            genkit.ToolDefinition(
              name: 'lookup',
              description: 'Lookup a value',
              inputSchema: <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{},
              },
            ),
          ],
        ),
      ),
      throwsA(
        isA<genkit.GenkitException>().having(
          (error) => error.status,
          'status',
          genkit.StatusCodes.FAILED_PRECONDITION,
        ),
      ),
    );
  });

  test(
    'model action rejects constrained output when disabled for the model',
    () async {
      final runtime = FakeRuntime();
      final action = buildModelAction(
        definition: const LlamaModelDefinition(
          name: 'local',
          modelPath: '/tmp/model.gguf',
          supportsConstrainedOutput: false,
        ),
        registry: EngineRegistry(
          models: const <LlamaModelDefinition>[
            LlamaModelDefinition(
              name: 'local',
              modelPath: '/tmp/model.gguf',
              supportsConstrainedOutput: false,
            ),
          ],
          runtimeFactory: () => runtime,
        ),
      );

      expect(
        () => action(
          genkit.ModelRequest(
            messages: <genkit.Message>[
              genkit.Message(
                role: genkit.Role.user,
                content: <genkit.Part>[genkit.TextPart(text: 'JSON please')],
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
              constrained: true,
            ),
          ),
        ),
        throwsA(
          isA<genkit.GenkitException>().having(
            (error) => error.status,
            'status',
            genkit.StatusCodes.FAILED_PRECONDITION,
          ),
        ),
      );
    },
  );

  test(
    'model action rejects constrained structured output with tools',
    () async {
      final runtime = FakeRuntime();
      final action = buildModelAction(
        definition: const LlamaModelDefinition(
          name: 'local',
          modelPath: '/tmp/model.gguf',
        ),
        registry: EngineRegistry(
          models: const <LlamaModelDefinition>[
            LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
          ],
          runtimeFactory: () => runtime,
        ),
      );

      expect(
        () => action(
          genkit.ModelRequest(
            messages: <genkit.Message>[
              genkit.Message(
                role: genkit.Role.user,
                content: <genkit.Part>[genkit.TextPart(text: 'JSON please')],
              ),
            ],
            tools: <genkit.ToolDefinition>[
              genkit.ToolDefinition(
                name: 'lookup',
                description: 'Lookup a value',
                inputSchema: <String, dynamic>{
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
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
              constrained: true,
            ),
          ),
        ),
        throwsA(
          isA<genkit.GenkitException>().having(
            (error) => error.status,
            'status',
            genkit.StatusCodes.UNIMPLEMENTED,
          ),
        ),
      );
    },
  );
}
