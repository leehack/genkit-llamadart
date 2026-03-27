import 'dart:collection';

import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_llamadart/src/core/runtime/llama_runtime.dart';
import 'package:llamadart/llamadart.dart' as llama;

class FakeRuntime implements LlamaRuntime {
  int initializeCount = 0;
  int createCallCount = 0;
  int chatTemplateCallCount = 0;
  int generateCallCount = 0;
  int embedBatchCallCount = 0;
  int disposeCount = 0;

  Object? initializeError;

  bool? lastNormalize;
  List<llama.LlamaChatMessage>? lastMessages;
  final List<List<llama.LlamaChatMessage>> recordedMessages =
      <List<llama.LlamaChatMessage>>[];
  List<llama.ToolDefinition>? lastTools;
  llama.GenerationParams? lastGenerationParams;

  List<llama.LlamaCompletionChunk> createChunks =
      <llama.LlamaCompletionChunk>[];
  final Queue<List<llama.LlamaCompletionChunk>> createScripts =
      Queue<List<llama.LlamaCompletionChunk>>();
  List<String> generatedTokens = <String>[];
  List<List<double>> embeddings = <List<double>>[];
  llama.LlamaChatTemplateResult templateResult =
      const llama.LlamaChatTemplateResult(prompt: 'prompt');

  @override
  Future<void> initialize(LlamaModelDefinition definition) async {
    initializeCount += 1;
    if (initializeError != null) {
      throw initializeError!;
    }
  }

  @override
  Stream<llama.LlamaCompletionChunk> create(
    List<llama.LlamaChatMessage> messages, {
    llama.GenerationParams? params,
    List<llama.ToolDefinition>? tools,
    llama.ToolChoice? toolChoice,
    bool parallelToolCalls = false,
    bool enableThinking = false,
    String? sourceLangCode,
    String? targetLangCode,
    Map<String, dynamic>? chatTemplateKwargs,
  }) async* {
    createCallCount += 1;
    lastMessages = messages;
    recordedMessages.add(List<llama.LlamaChatMessage>.from(messages));
    lastTools = tools;
    lastGenerationParams = params;

    final chunks = createScripts.isNotEmpty
        ? createScripts.removeFirst()
        : createChunks;
    yield* Stream<llama.LlamaCompletionChunk>.fromIterable(chunks);
  }

  @override
  Future<llama.LlamaChatTemplateResult> chatTemplate(
    List<llama.LlamaChatMessage> messages, {
    bool addAssistant = true,
    List<llama.ToolDefinition>? tools,
    llama.ToolChoice toolChoice = llama.ToolChoice.auto,
    bool parallelToolCalls = false,
    bool enableThinking = false,
    Map<String, dynamic>? responseFormat,
    String? sourceLangCode,
    String? targetLangCode,
    bool includeTokenCount = false,
    Map<String, dynamic>? chatTemplateKwargs,
  }) async {
    chatTemplateCallCount += 1;
    lastMessages = messages;
    lastTools = tools;
    return templateResult;
  }

  @override
  Stream<String> generate(
    String prompt, {
    llama.GenerationParams params = const llama.GenerationParams(),
    List<llama.LlamaContentPart>? parts,
  }) async* {
    generateCallCount += 1;
    lastGenerationParams = params;
    yield* Stream<String>.fromIterable(generatedTokens);
  }

  @override
  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    bool normalize = true,
  }) async {
    embedBatchCallCount += 1;
    lastNormalize = normalize;
    return embeddings;
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}

llama.LlamaCompletionChunk textChunk(String text, {String? finishReason}) {
  return llama.LlamaCompletionChunk(
    id: 'chunk',
    object: 'chat.completion.chunk',
    created: 0,
    model: 'model',
    choices: <llama.LlamaCompletionChunkChoice>[
      llama.LlamaCompletionChunkChoice(
        index: 0,
        delta: llama.LlamaCompletionChunkDelta(content: text),
        finishReason: finishReason,
      ),
    ],
  );
}

llama.LlamaCompletionChunk thinkingChunk(String reasoning) {
  return llama.LlamaCompletionChunk(
    id: 'chunk',
    object: 'chat.completion.chunk',
    created: 0,
    model: 'model',
    choices: <llama.LlamaCompletionChunkChoice>[
      llama.LlamaCompletionChunkChoice(
        index: 0,
        delta: llama.LlamaCompletionChunkDelta(thinking: reasoning),
      ),
    ],
  );
}

llama.LlamaCompletionChunk toolCallChunk({
  required String id,
  required String name,
  required String arguments,
  int index = 0,
  String? finishReason = 'tool_calls',
}) {
  return llama.LlamaCompletionChunk(
    id: 'chunk',
    object: 'chat.completion.chunk',
    created: 0,
    model: 'model',
    choices: <llama.LlamaCompletionChunkChoice>[
      llama.LlamaCompletionChunkChoice(
        index: index,
        delta: llama.LlamaCompletionChunkDelta(
          toolCalls: <llama.LlamaCompletionChunkToolCall>[
            llama.LlamaCompletionChunkToolCall(
              index: index,
              id: id,
              type: 'function',
              function: llama.LlamaCompletionChunkFunction(
                name: name,
                arguments: arguments,
              ),
            ),
          ],
        ),
        finishReason: finishReason,
      ),
    ],
  );
}

llama.LlamaCompletionChunk toolCallDeltaChunk({
  int index = 0,
  String? id,
  String? name,
  String? arguments,
  String? finishReason,
}) {
  return llama.LlamaCompletionChunk(
    id: 'chunk',
    object: 'chat.completion.chunk',
    created: 0,
    model: 'model',
    choices: <llama.LlamaCompletionChunkChoice>[
      llama.LlamaCompletionChunkChoice(
        index: index,
        delta: llama.LlamaCompletionChunkDelta(
          toolCalls: <llama.LlamaCompletionChunkToolCall>[
            llama.LlamaCompletionChunkToolCall(
              index: index,
              id: id,
              type: 'function',
              function: llama.LlamaCompletionChunkFunction(
                name: name,
                arguments: arguments,
              ),
            ),
          ],
        ),
        finishReason: finishReason,
      ),
    ],
  );
}

llama.LlamaCompletionChunk stopChunk() {
  return llama.LlamaCompletionChunk(
    id: 'chunk',
    object: 'chat.completion.chunk',
    created: 0,
    model: 'model',
    choices: <llama.LlamaCompletionChunkChoice>[
      llama.LlamaCompletionChunkChoice(
        index: 0,
        delta: llama.LlamaCompletionChunkDelta(),
        finishReason: 'stop',
      ),
    ],
  );
}
