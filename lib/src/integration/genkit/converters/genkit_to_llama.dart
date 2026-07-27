import 'dart:convert';
import 'dart:typed_data';

import 'package:genkit/plugin.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;

import '../../../api/generation_config.dart';
import 'schema_to_tool_params.dart';

List<llama.LlamaChatMessage> toLlamaMessages(List<genkit.Message> messages) {
  final converted = <llama.LlamaChatMessage>[];

  for (final message in messages) {
    if (message.role == genkit.Role.tool) {
      final toolResponses = message.content
          .where((part) => part.isToolResponse)
          .map((part) => part.toolResponsePart!)
          .toList(growable: false);

      if (toolResponses.isEmpty) {
        throw genkit.GenkitException(
          'Tool messages must contain at least one tool response part.',
          status: genkit.StatusCodes.INVALID_ARGUMENT,
        );
      }

      for (final part in toolResponses) {
        converted.add(
          llama.LlamaChatMessage.withContent(
            role: llama.LlamaChatRole.tool,
            content: [
              llama.LlamaToolResultContent(
                id: part.toolResponse.ref,
                name: part.toolResponse.name,
                result: _normalizeToolResultOutput(part.toolResponse.output),
              ),
            ],
          ),
        );
      }
      continue;
    }

    final parts = <llama.LlamaContentPart>[];
    for (final part in message.content) {
      final convertedPart = _toLlamaPart(part);
      if (convertedPart != null) {
        parts.add(convertedPart);
      }
    }

    converted.add(
      llama.LlamaChatMessage.withContent(
        role: _toLlamaRole(message.role),
        content: parts.isEmpty
            ? <llama.LlamaContentPart>[const llama.LlamaTextContent('')]
            : parts,
      ),
    );
  }

  return converted;
}

List<llama.ToolDefinition> toLlamaTools(List<genkit.ToolDefinition>? tools) {
  if (tools == null || tools.isEmpty) {
    return const <llama.ToolDefinition>[];
  }

  return tools
      .map<llama.ToolDefinition>((genkit.ToolDefinition tool) {
        return llama.ToolDefinition(
          name: tool.name,
          description: tool.description,
          parameters: schemaToToolParams(tool.inputSchema),
          handler: (_) async {
            throw UnsupportedError('Tool execution is handled by Genkit.');
          },
        );
      })
      .toList(growable: false);
}

llama.GenerationParams toGenerationParams(LlamaDartGenerationConfig config) {
  return llama.GenerationParams(
    maxTokens: config.maxTokens ?? LlamaDartGenerationConfig.defaultMaxTokens,
    temp: config.temperature ?? LlamaDartGenerationConfig.defaultTemperature,
    topK: config.topK ?? LlamaDartGenerationConfig.defaultTopK,
    topP: config.topP ?? LlamaDartGenerationConfig.defaultTopP,
    minP: config.minP ?? LlamaDartGenerationConfig.defaultMinP,
    penalty: config.penalty ?? LlamaDartGenerationConfig.defaultPenalty,
    seed: config.seed,
    stopSequences: config.stop ?? const <String>[],
  );
}

llama.ToolChoice? toLlamaToolChoice(
  String? toolChoice, {
  required bool hasTools,
}) {
  if (!hasTools) {
    return null;
  }

  return switch (toolChoice) {
    'none' => llama.ToolChoice.none,
    'required' => llama.ToolChoice.required,
    _ => llama.ToolChoice.auto,
  };
}

Map<String, dynamic>? toResponseFormat(genkit.OutputConfig? output) {
  if (output == null) {
    return null;
  }

  if (output.schema != null) {
    return {
      'type': 'json_schema',
      'json_schema': {'schema': output.schema},
    };
  }

  if (output.format == 'json' || output.contentType == 'application/json') {
    return {'type': 'json_object'};
  }

  return null;
}

bool shouldUseStructuredGeneration(genkit.OutputConfig? output) {
  if (output == null || output.constrained == false) {
    return false;
  }

  return output.schema != null ||
      output.format == 'json' ||
      output.contentType == 'application/json';
}

String documentToPlainText(genkit.DocumentData document) {
  final buffer = StringBuffer();

  for (final part in document.content) {
    if (part.isText) {
      buffer.write(part.text);
      continue;
    }

    if (part.isReasoning) {
      continue;
    }

    throw genkit.GenkitException(
      'llamadart embeddings currently support text-only documents.',
      status: genkit.StatusCodes.INVALID_ARGUMENT,
    );
  }

  return buffer.toString();
}

llama.LlamaChatRole _toLlamaRole(genkit.Role role) {
  return switch (role) {
    final value when value == genkit.Role.system => llama.LlamaChatRole.system,
    final value when value == genkit.Role.user => llama.LlamaChatRole.user,
    final value when value == genkit.Role.tool => llama.LlamaChatRole.tool,
    _ => llama.LlamaChatRole.assistant,
  };
}

llama.LlamaContentPart? _toLlamaPart(genkit.Part part) {
  if (part.isText) {
    return llama.LlamaTextContent(part.text!);
  }

  if (part.isMedia) {
    return _toLlamaMediaPart(part.media!);
  }

  if (part.isToolRequest) {
    final toolRequest = part.toolRequest!;
    final arguments = toLlamaToolArguments(toolRequest.input);
    return llama.LlamaToolCallContent(
      id: toolRequest.ref,
      name: toolRequest.name,
      arguments: arguments,
      rawJson: jsonEncode(arguments),
    );
  }

  if (part.isToolResponse) {
    final toolResponse = part.toolResponse!;
    return llama.LlamaToolResultContent(
      id: toolResponse.ref,
      name: toolResponse.name,
      result: _normalizeToolResultOutput(toolResponse.output),
    );
  }

  if (part.isReasoning) {
    return null;
  }

  if (part.isData || part.isCustom || part.isResource) {
    throw genkit.GenkitException(
      'Unsupported Genkit part type for llamadart requests: ${part.toJson().keys.join(', ')}',
      status: genkit.StatusCodes.INVALID_ARGUMENT,
    );
  }

  return null;
}

Map<String, dynamic> toLlamaToolArguments(Object? input) {
  if (input == null) {
    return const <String, dynamic>{};
  }
  if (input is Map<String, dynamic>) {
    return input;
  }
  if (input is Map && input.keys.every((key) => key is String)) {
    return <String, dynamic>{
      for (final entry in input.entries) entry.key as String: entry.value,
    };
  }
  throw genkit.GenkitException(
    'llamadart tool requests require object-shaped input.',
    status: genkit.StatusCodes.INVALID_ARGUMENT,
  );
}

llama.LlamaContentPart _toLlamaMediaPart(genkit.Media media) {
  final contentType = media.contentType ?? _inferContentType(media.url);
  final isImage = contentType?.startsWith('image/') ?? false;
  final isAudio = contentType?.startsWith('audio/') ?? false;

  if (!isImage && !isAudio) {
    throw genkit.GenkitException(
      'Unsupported media type for llamadart: ${contentType ?? media.url}',
      status: genkit.StatusCodes.INVALID_ARGUMENT,
    );
  }

  final uri = Uri.tryParse(media.url);
  if (uri != null && uri.scheme == 'data') {
    final data = UriData.parse(media.url).contentAsBytes();
    final bytes = Uint8List.fromList(data);
    return isImage
        ? llama.LlamaImageContent(bytes: bytes)
        : llama.LlamaAudioContent(bytes: bytes);
  }

  final filePath = _toFilePath(uri, media.url);
  if (filePath != null) {
    return isImage
        ? llama.LlamaImageContent(path: filePath)
        : llama.LlamaAudioContent(path: filePath);
  }

  if (isImage && (uri?.scheme == 'http' || uri?.scheme == 'https')) {
    return llama.LlamaImageContent(url: media.url);
  }

  throw genkit.GenkitException(
    'Unsupported media URL for llamadart: ${media.url}',
    status: genkit.StatusCodes.INVALID_ARGUMENT,
  );
}

String? _inferContentType(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && uri.scheme == 'data') {
    return UriData.parse(url).mimeType;
  }

  final lowerPath = (uri?.path.isNotEmpty ?? false)
      ? uri!.path.toLowerCase()
      : url.toLowerCase();
  if (lowerPath.endsWith('.png') ||
      lowerPath.endsWith('.jpg') ||
      lowerPath.endsWith('.jpeg') ||
      lowerPath.endsWith('.gif') ||
      lowerPath.endsWith('.webp')) {
    return 'image/*';
  }
  if (lowerPath.endsWith('.wav') ||
      lowerPath.endsWith('.mp3') ||
      lowerPath.endsWith('.m4a') ||
      lowerPath.endsWith('.ogg')) {
    return 'audio/*';
  }

  return null;
}

String? _toFilePath(Uri? uri, String originalUrl) {
  if (_windowsDrivePath.hasMatch(originalUrl)) {
    return originalUrl;
  }
  if (uri == null || uri.scheme.isEmpty) {
    return originalUrl;
  }

  if (uri.scheme == 'file') {
    return uri.toFilePath();
  }

  return null;
}

final RegExp _windowsDrivePath = RegExp(r'^[A-Za-z]:[\\/]');

String _normalizeToolResultOutput(Object? output) {
  if (output == null) {
    return 'null';
  }
  if (output is String) {
    return output;
  }

  try {
    return jsonEncode(output);
  } catch (_) {
    return output.toString();
  }
}
