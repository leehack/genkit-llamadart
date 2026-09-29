import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:genkit/genkit.dart';
import 'package:genkit/telemetry.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_otel/genkit_otel.dart';

Future<void> main() async {
  final modelPath = Platform.environment['LLAMADART_MODEL_PATH'];
  if (modelPath == null) {
    stderr.writeln('Set LLAMADART_MODEL_PATH to a local chat GGUF.');
    exitCode = 64;
    return;
  }
  await otel.OTel.initialize(
    serviceName: 'genkit-llamadart-example',
    enableLogs: false,
    detectPlatformResources: false,
  );
  configureInstrumentation(
    GenAiInstrumentation(
      contentCapturingMode: ContentCapturingMode.noContent,
      captureActionIO: false,
    ),
  );
  final plugin = llamaDart(
    models: [
      LlamaModelDefinition(
        name: 'local',
        modelPath: modelPath,
        supportsEmbeddings: false,
      ),
    ],
    observers: [OtelEngineObserver()],
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
    try {
      await plugin.dispose();
    } finally {
      try {
        await ai.shutdown();
      } finally {
        try {
          // A short CLI run may finish before the periodic metric export.
          await otel.OTel.meterProvider().forceFlush();
        } finally {
          await otel.OTel.shutdown();
        }
      }
    }
  }
}

// Engine spans provide runtime diagnostics. GenAiInstrumentation alone records
// model token metrics, so observing the engine does not count tokens twice.
final class OtelEngineObserver extends LlamaEngineObserver {
  @override
  LlamaOperationObserver onStart(LlamaOperation operation) {
    final span = otel.OTel.tracerProvider()
        .getTracer('llamadart-engine')
        .startSpan(
          'llamadart.${operation.runtimeType}',
          kind: otel.SpanKind.internal,
        );
    return _OtelOperation(span);
  }
}

final class _OtelOperation extends LlamaOperationObserver {
  _OtelOperation(this.span);
  final otel.APISpan span;

  @override
  void onEnd(LlamaOperationResult result) {
    // Avoid exporting exception messages, model paths or request content.
    span.setStringAttribute(
      'llamadart.outcome',
      result.cancelled
          ? 'cancelled'
          : result.error != null
          ? 'failed'
          : 'completed',
    );
    span.end();
  }
}
