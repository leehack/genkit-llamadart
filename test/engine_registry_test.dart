import 'dart:async';

import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_llamadart/src/engine_registry.dart';
import 'package:test/test.dart';

import 'src/fake_runtime.dart';

void main() {
  test(
    'EngineRegistry reuses a single runtime and queues operations',
    () async {
      var factoryCalls = 0;
      final runtime = FakeRuntime();
      final registry = EngineRegistry(
        models: const <LlamaModelDefinition>[
          LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
        ],
        runtimeFactory: () {
          factoryCalls += 1;
          return runtime;
        },
      );

      var activeOperations = 0;
      var maxActiveOperations = 0;
      final executionOrder = <int>[];

      Future<int> runOperation(int index) {
        return registry.withRuntime('local', (_) async {
          activeOperations += 1;
          maxActiveOperations = activeOperations > maxActiveOperations
              ? activeOperations
              : maxActiveOperations;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          executionOrder.add(index);
          activeOperations -= 1;
          return index;
        });
      }

      final results = await Future.wait(<Future<int>>[
        runOperation(1),
        runOperation(2),
        runOperation(3),
      ]);

      expect(results, <int>[1, 2, 3]);
      expect(executionOrder, <int>[1, 2, 3]);
      expect(maxActiveOperations, 1);
      expect(factoryCalls, 1);
      expect(runtime.initializeCount, 1);
    },
  );

  test('EngineRegistry isolates runtimes across model names', () async {
    var factoryCalls = 0;
    final runtimes = <FakeRuntime>[FakeRuntime(), FakeRuntime()];
    final registry = EngineRegistry(
      models: const <LlamaModelDefinition>[
        LlamaModelDefinition(name: 'alpha', modelPath: '/tmp/alpha.gguf'),
        LlamaModelDefinition(name: 'beta', modelPath: '/tmp/beta.gguf'),
      ],
      runtimeFactory: () => runtimes[factoryCalls++],
    );

    var activeOperations = 0;
    var maxActiveOperations = 0;

    Future<String> runOperation(String modelName) {
      return registry.withRuntime(modelName, (_) async {
        activeOperations += 1;
        maxActiveOperations = activeOperations > maxActiveOperations
            ? activeOperations
            : maxActiveOperations;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        activeOperations -= 1;
        return modelName;
      });
    }

    final results = await Future.wait<String>(<Future<String>>[
      runOperation('alpha'),
      runOperation('beta'),
    ]);

    expect(results, <String>['alpha', 'beta']);
    expect(maxActiveOperations, 2);
    expect(factoryCalls, 2);
    expect(runtimes[0].initializeCount, 1);
    expect(runtimes[1].initializeCount, 1);
  });

  test('EngineRegistry rejects unknown model names', () async {
    final registry = EngineRegistry(
      models: const <LlamaModelDefinition>[
        LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
      ],
      runtimeFactory: () => FakeRuntime(),
    );

    expect(
      () => registry.withRuntime('missing', (_) async => 1),
      throwsA(isA<StateError>()),
    );
  });

  test('EngineRegistry disposes failed initialization and retries', () async {
    var factoryCalls = 0;
    final failedRuntime = FakeRuntime()
      ..initializeError = StateError('failed to initialize');
    final healthyRuntime = FakeRuntime();
    final registry = EngineRegistry(
      models: const <LlamaModelDefinition>[
        LlamaModelDefinition(name: 'local', modelPath: '/tmp/model.gguf'),
      ],
      runtimeFactory: () =>
          factoryCalls++ == 0 ? failedRuntime : healthyRuntime,
    );

    await expectLater(
      () => registry.withRuntime('local', (_) async => 1),
      throwsA(isA<StateError>()),
    );

    final result = await registry.withRuntime('local', (_) async => 42);

    expect(result, 42);
    expect(failedRuntime.disposeCount, 1);
    expect(healthyRuntime.initializeCount, 1);
    expect(factoryCalls, 2);
  });
}
