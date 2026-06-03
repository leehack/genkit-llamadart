import 'dart:async';

import '../../api/model_definition.dart';
import 'llama_engine_runtime.dart';
import 'llama_runtime.dart';

class EngineRegistry {
  EngineRegistry({
    required Iterable<LlamaModelDefinition> models,
    LlamaRuntimeFactory? runtimeFactory,
  }) : _definitions = {for (final model in models) model.name: model},
       _runtimeFactory = runtimeFactory ?? (() => LlamaEngineRuntime());

  final Map<String, LlamaModelDefinition> _definitions;
  final LlamaRuntimeFactory _runtimeFactory;
  final Map<String, _EngineEntry> _entries = {};

  Future<T> withRuntime<T>(
    String modelName,
    Future<T> Function(LlamaRuntime runtime) operation,
  ) {
    final definition = _definitions[modelName];
    if (definition == null) {
      throw StateError('Unknown llamadart model: $modelName');
    }

    final entry = _entries.putIfAbsent(
      modelName,
      () => _EngineEntry(definition, _runtimeFactory),
    );
    return entry.run(operation);
  }

  /// Cancels the generation in flight for [modelName] without queueing behind
  /// it. Throws [StateError] for a model name that was never registered
  /// (consistent with [withRuntime]); a no-op for a registered model whose
  /// runtime hasn't loaded yet or isn't generating.
  void cancelActiveGeneration(String modelName) {
    if (!_definitions.containsKey(modelName)) {
      throw StateError('Unknown llamadart model: $modelName');
    }
    _entries[modelName]?.cancelGeneration();
  }

  /// Cancels every in-flight generation across loaded runtimes, bypassing the
  /// per-model operation queue so a cancel never waits behind the run it stops.
  void cancelActiveGenerations() {
    for (final entry in _entries.values) {
      entry.cancelGeneration();
    }
  }

  Future<void> dispose() async {
    final entries = _entries.values.toList(growable: false);
    _entries.clear();

    for (final entry in entries) {
      await entry.dispose();
    }
  }
}

class _EngineEntry {
  _EngineEntry(this._definition, this._runtimeFactory);

  final LlamaModelDefinition _definition;
  final LlamaRuntimeFactory _runtimeFactory;

  Future<void> _tail = Future<void>.value();
  Future<LlamaRuntime>? _loading;
  LlamaRuntime? _runtime;

  /// Cancels the runtime's in-flight generation directly, without going through
  /// the operation queue. Reads the loaded runtime field, so it is a no-op while
  /// the model is still loading or idle.
  void cancelGeneration() {
    _runtime?.cancelGeneration();
  }

  Future<T> run<T>(Future<T> Function(LlamaRuntime runtime) operation) {
    final completer = Completer<T>();

    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        final runtime = await _ensureRuntime();
        final result = await operation(runtime);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  Future<void> dispose() async {
    await _tail.catchError((Object _) {});

    final runtime = _runtime;
    _runtime = null;
    _loading = null;

    if (runtime != null) {
      await runtime.dispose();
    }
  }

  Future<LlamaRuntime> _ensureRuntime() async {
    if (_runtime != null) {
      return _runtime!;
    }

    final existingLoad = _loading;
    if (existingLoad != null) {
      return existingLoad;
    }

    final loadFuture = () async {
      final runtime = _runtimeFactory();
      try {
        await runtime.initialize(_definition);
        _runtime = runtime;
        return runtime;
      } catch (_) {
        _runtime = null;
        await runtime.dispose();
        rethrow;
      } finally {
        _loading = null;
      }
    }();

    _loading = loadFuture;
    return loadFuture;
  }
}
