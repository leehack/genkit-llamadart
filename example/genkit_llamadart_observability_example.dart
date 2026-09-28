import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit/telemetry.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

// A minimal console provider. Production applications can implement the same
// public Genkit interfaces using their telemetry backend's tracing SDK.
final _activeSpan = Object();
int _nextId = 0;

Future<void> main() async {
  final modelPath = Platform.environment['LLAMADART_MODEL_PATH'];
  if (modelPath == null) {
    stderr.writeln('Set LLAMADART_MODEL_PATH to a local chat GGUF.');
    exitCode = 64;
    return;
  }
  configureInstrumentation(ConsoleInstrumentation());
  final plugin = llamaDart(
    models: [
      LlamaModelDefinition(
        name: 'local',
        modelPath: modelPath,
        supportsEmbeddings: false,
      ),
    ],
    observers: [ConsoleEngineObserver()],
  );
  final ai = Genkit(plugins: [plugin], isDevEnv: false);
  try {
    final response = await ai.generate(
      model: llamaDart.model('local'),
      prompt: 'Say hello briefly.',
      config: const LlamaDartGenerationConfig(maxTokens: 32),
    );
    // Print measurements only: no prompts, generated text, paths or tool data.
    stdout.writeln(
      jsonEncode({
        'usage': response.usage?.toJson(),
        'finishReason': response.finishReason.toString(),
      }),
    );
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}

class ConsoleInstrumentation implements Instrumentation {
  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function([SpanContext? span]) next,
  ) async {
    final parent = Zone.current[_activeSpan] as _ConsoleSpan?;
    final id = (++_nextId).toString();
    final span = _ConsoleSpan(parent?.traceId ?? id, id);
    final timer = Stopwatch()..start();
    var outcome = 'completed';
    try {
      final result = await runZoned(
        () => next(span),
        zoneValues: {_activeSpan: span},
      );
      final finishReason = switch (result) {
        ModelResponse response => response.finishReason,
        GenerateResponse response => response.finishReason,
        _ => null,
      };
      if (finishReason == FinishReason.failed) outcome = 'failed';
      if (finishReason == FinishReason.aborted) outcome = 'cancelled';
      return result;
    } on CancelledException {
      outcome = 'cancelled';
      rethrow;
    } catch (_) {
      outcome = 'failed';
      rethrow;
    } finally {
      stdout.writeln(
        jsonEncode({
          'event': 'genkit_span',
          'traceId': span.traceId,
          'spanId': span.spanId,
          'actionType': metadata.actionType,
          'durationMs': timer.elapsedMicroseconds / 1000,
          'outcome': outcome,
        }),
      );
    }
  }
}

class _ConsoleSpan implements SpanContext {
  _ConsoleSpan(this.traceId, this.spanId);
  @override
  final String traceId;
  @override
  final String spanId;
  @override
  void setMetadata(Map<String, Object?> metadata) {}
}

final class ConsoleEngineObserver extends LlamaEngineObserver {
  @override
  LlamaOperationObserver onStart(LlamaOperation operation) {
    return _ConsoleOperation(
      Zone.current[_activeSpan] as _ConsoleSpan?,
      operation.runtimeType.toString(),
    );
  }
}

final class _ConsoleOperation extends LlamaOperationObserver {
  _ConsoleOperation(this.span, this.operation);
  final _ConsoleSpan? span;
  final String operation;
  final Stopwatch timer = Stopwatch()..start();
  @override
  void onEnd(LlamaOperationResult result) {
    stdout.writeln(
      jsonEncode({
        'event': 'llamadart_operation',
        'traceId': span?.traceId,
        'parentSpanId': span?.spanId,
        'operation': operation,
        'durationMs': timer.elapsedMicroseconds / 1000,
        'outcome': result.cancelled
            ? 'cancelled'
            : result.error != null
            ? 'failed'
            : 'completed',
        'usage': result.usage?.toJson(),
      }),
    );
  }
}
