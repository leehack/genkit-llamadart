import 'package:genkit/plugin.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;

import '../../api/model_definition.dart';
import 'converters/genkit_to_llama.dart';

bool _usesTools(genkit.ModelRequest request) =>
    (request.tools?.isNotEmpty ?? false) ||
    request.messages.any(
      (message) => message.content.any(
        (part) => part.isToolRequest || part.isToolResponse,
      ),
    );

void checkDeclaredModelRequest(
  LlamaModelDefinition definition,
  genkit.ModelRequest request,
) {
  if (request.docs?.isNotEmpty ?? false) {
    throw genkit.GenkitException(
      'llamadart model actions do not support `docs` yet.',
      status: genkit.StatusCode.invalidArgument,
    );
  }
  if (_usesTools(request) && !definition.supportsTools) {
    throw genkit.GenkitException(
      'Tool use is disabled for `${definition.name}`.',
      status: genkit.StatusCode.failedPrecondition,
    );
  }
  if (shouldUseStructuredGeneration(request.output) &&
      !definition.supportsConstrainedOutput) {
    throw genkit.GenkitException(
      'Constrained output is disabled for `${definition.name}`.',
      status: genkit.StatusCode.failedPrecondition,
    );
  }
}

void checkRuntimeReady(
  LlamaModelDefinition definition,
  llama.LlamaEngineCapabilities? capabilities,
) {
  if (capabilities != null && !capabilities.isSupported) {
    throw genkit.GenkitException(
      'The active runtime for `${definition.name}` reports no ready model. '
      'Load a supported model before retrying.',
      status: genkit.StatusCode.failedPrecondition,
    );
  }
}

void requireRuntimeCapability(
  LlamaModelDefinition definition, {
  required bool? supported,
  required String feature,
}) {
  if (supported == true) return;
  throw genkit.GenkitException(
    supported == null
        ? 'The custom runtime for `${definition.name}` cannot confirm $feature. '
              'Implement LlamaRuntimeCapabilityProvider to report support '
              'after initialization.'
        : 'The active runtime for `${definition.name}` does not report support '
              'for $feature. Use a model and backend that support it.',
    status: supported == null
        ? genkit.StatusCode.failedPrecondition
        : genkit.StatusCode.unimplemented,
  );
}

void checkRuntimeModelRequest(
  LlamaModelDefinition definition,
  genkit.ModelRequest request,
  List<llama.LlamaChatMessage> messages,
  llama.LlamaEngineCapabilities? capabilities,
) {
  checkRuntimeReady(definition, capabilities);
  void require(bool? supported, String feature) => requireRuntimeCapability(
    definition,
    supported: supported,
    feature: feature,
  );

  if (_usesTools(request)) {
    require(capabilities?.supportsToolCalling, 'tool calling');
  }
  if (shouldUseStructuredGeneration(request.output)) {
    require(
      capabilities == null
          ? null
          : capabilities.supportsStructuredOutput &&
                capabilities.supportsGrammar,
      'grammar-constrained structured output',
    );
  }
  if (messages.any((message) => message.role == llama.LlamaChatRole.system)) {
    require(capabilities?.supportsMultiTurnChat, 'system-message delivery');
  }
  if (messages.where((m) => m.role != llama.LlamaChatRole.system).length > 1) {
    require(capabilities?.supportsMultiTurnChat, 'multi-turn history');
  }

  // Native LiteRT bundle declarations can under-report encoders. Preserve the
  // core runtime's best-effort media validation without advertising support.
  final bestEffortMedia =
      const bool.fromEnvironment('dart.library.io') &&
      capabilities?.runtime == llama.LlamaRuntime.liteRtLm;
  for (final part in messages.expand((message) => message.parts)) {
    if (part is llama.LlamaImageContent && !bestEffortMedia) {
      require(capabilities?.supportsVision, 'image input');
    } else if (part is llama.LlamaAudioContent && !bestEffortMedia) {
      require(capabilities?.supportsAudio, 'audio input');
    }
  }
}
