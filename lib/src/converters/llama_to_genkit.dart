import 'dart:convert';

import 'package:genkit/plugin.dart' as genkit;
import 'package:llamadart/llamadart.dart' as llama;

final RegExp _inlineToolCallPattern = RegExp(
  r'<tool_call>\s*(\{.*?\})\s*</tool_call>',
  dotAll: true,
);

genkit.ModelResponseChunk? toGenkitChunk(llama.LlamaCompletionChunk chunk) {
  if (chunk.choices.isEmpty) {
    return null;
  }

  final choice = chunk.choices.first;
  final parts = <genkit.Part>[];
  final delta = choice.delta;

  if (delta.thinking != null && delta.thinking!.isNotEmpty) {
    parts.add(genkit.ReasoningPart(reasoning: delta.thinking!));
  }
  if (delta.content != null && delta.content!.isNotEmpty) {
    parts.add(genkit.TextPart(text: delta.content!));
  }
  if (delta.toolCalls != null) {
    parts.addAll(delta.toolCalls!.map(toGenkitToolRequestPart));
  }

  if (parts.isEmpty) {
    return null;
  }

  return genkit.ModelResponseChunk(
    role: genkit.Role.model,
    index: choice.index,
    content: parts,
    aggregated: false,
  );
}

genkit.ToolRequestPart toGenkitToolRequestPart(
  llama.LlamaCompletionChunkToolCall toolCall,
) {
  final function = toolCall.function;
  final rawArguments = function?.arguments;

  return genkit.ToolRequestPart(
    toolRequest: genkit.ToolRequest(
      ref: toolCall.id ?? 'call_${toolCall.index}',
      name: function?.name ?? 'unknown',
      input: _decodeToolArguments(rawArguments),
    ),
    metadata: rawArguments == null
        ? null
        : <String, dynamic>{'rawArguments': rawArguments},
  );
}

genkit.FinishReason mapFinishReason(String? finishReason) {
  return switch (finishReason) {
    'length' => genkit.FinishReason.length,
    'content_filter' => genkit.FinishReason.blocked,
    'tool_calls' => genkit.FinishReason.stop,
    'stop' => genkit.FinishReason.stop,
    null => genkit.FinishReason.stop,
    _ => genkit.FinishReason.unknown,
  };
}

class CompletionAccumulator {
  final StringBuffer _text = StringBuffer();
  final StringBuffer _reasoning = StringBuffer();
  final List<llama.LlamaCompletionChunkToolCall> _toolCalls =
      <llama.LlamaCompletionChunkToolCall>[];

  genkit.FinishReason finishReason = genkit.FinishReason.stop;
  String? finishMessage;

  void addChunk(llama.LlamaCompletionChunk chunk) {
    if (chunk.choices.isEmpty) {
      return;
    }

    final choice = chunk.choices.first;
    final delta = choice.delta;
    if (delta.content != null) {
      _text.write(delta.content);
    }
    if (delta.thinking != null) {
      _reasoning.write(delta.thinking);
    }
    if (delta.toolCalls != null && delta.toolCalls!.isNotEmpty) {
      _toolCalls
        ..clear()
        ..addAll(delta.toolCalls!);
    }
    if (choice.finishReason != null) {
      finishReason = mapFinishReason(choice.finishReason);
    }
  }

  genkit.ModelResponse toModelResponse({
    required double latencyMs,
    required Map<String, dynamic> raw,
  }) {
    final fallback = _toolCalls.isEmpty
        ? _extractInlineToolCalls(_text.toString())
        : null;
    final fallbackToolRequests =
        fallback?.toolRequests ?? const <genkit.ToolRequestPart>[];
    final visibleText = fallback?.remainingText ?? _text.toString();

    final parts = <genkit.Part>[];
    if (_reasoning.isNotEmpty) {
      parts.add(genkit.ReasoningPart(reasoning: _reasoning.toString()));
    }
    if (visibleText.isNotEmpty ||
        (_toolCalls.isEmpty && fallbackToolRequests.isEmpty && parts.isEmpty)) {
      parts.add(genkit.TextPart(text: visibleText));
    }
    parts.addAll(_toolCalls.map(toGenkitToolRequestPart));
    parts.addAll(fallbackToolRequests);

    return genkit.ModelResponse(
      message: genkit.Message(role: genkit.Role.model, content: parts),
      finishReason: finishReason,
      finishMessage: finishMessage,
      latencyMs: latencyMs,
      raw: raw,
    );
  }
}

_InlineToolExtractionResult? _extractInlineToolCalls(String text) {
  final matches = _inlineToolCallPattern
      .allMatches(text)
      .toList(growable: false);
  if (matches.isEmpty) {
    return null;
  }

  final toolRequests = <genkit.ToolRequestPart>[];
  for (var i = 0; i < matches.length; i++) {
    final payload = matches[i].group(1);
    if (payload == null) {
      return null;
    }

    final decoded = _tryDecodeMap(payload);
    if (decoded == null) {
      return null;
    }

    final name = decoded['name'];
    if (name is! String || name.isEmpty) {
      return null;
    }

    final id = decoded['id'];
    toolRequests.add(
      genkit.ToolRequestPart(
        toolRequest: genkit.ToolRequest(
          ref: id is String && id.isNotEmpty ? id : 'call_$i',
          name: name,
          input: _coerceToolInput(decoded['arguments']),
        ),
        metadata: <String, dynamic>{'rawToolCall': payload},
      ),
    );
  }

  final remainingText = text.replaceAll(_inlineToolCallPattern, '').trim();
  return _InlineToolExtractionResult(
    toolRequests: toolRequests,
    remainingText: remainingText,
  );
}

Map<String, dynamic> _coerceToolInput(Object? value) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  if (value is String) {
    return _decodeToolArguments(value);
  }
  return <String, dynamic>{'value': value};
}

Map<String, dynamic>? _tryDecodeMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {
    return null;
  }
  return null;
}

class _InlineToolExtractionResult {
  const _InlineToolExtractionResult({
    required this.toolRequests,
    required this.remainingText,
  });

  final List<genkit.ToolRequestPart> toolRequests;
  final String remainingText;
}

Map<String, dynamic> _decodeToolArguments(String? rawArguments) {
  if (rawArguments == null || rawArguments.isEmpty) {
    return const <String, dynamic>{};
  }

  try {
    final decoded = jsonDecode(rawArguments);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return <String, dynamic>{'value': decoded};
  } catch (_) {
    return <String, dynamic>{'_raw': rawArguments};
  }
}
