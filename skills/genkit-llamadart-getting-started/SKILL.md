---
name: genkit-llamadart-getting-started
description: >-
  Use when running a local GGUF or LiteRT-LM model in a Genkit Dart app with
  genkit_llamadart: registering models with llamaDart(...) or
  llamaDart.prepareModel(...), calling ai.generate or ai.generateStream,
  embeddings, generation config, cancellation, failed or aborted responses,
  and disposing the plugin.
---

# Getting started with genkit_llamadart

## Guidelines

- Add `genkit` and `genkit_llamadart` (`dart pub add genkit genkit_llamadart`).
  Import `package:genkit_llamadart/genkit_llamadart.dart`; it re-exports the
  llamadart types this plugin needs (`ModelParams`, `ModelSource`,
  `ModelLoadOptions`, `ModelCachePolicy`, observers, exceptions). Native
  runtime setup and platform notes live at https://llamadart.leehack.com/.
- Register models in one of two ways:
  - The app already has a local file: `llamaDart(models: [LlamaModelDefinition(name: ..., modelPath: ...)])`,
    then `Genkit(plugins: [plugin])` and reference it with
    `llamaDart.model(name)`.
  - Resolve a local path, HTTP(S) URL or `hf://owner/repo/file.gguf` source
    through llamadart's cache: `await llamaDart.prepareModel(name: ..., source: ModelSource.parse(...))`.
    It returns a `LlamaPreparedModel` with `plugin`, `modelRef`, optional
    `embedderRef` and `createGenkit()`. Use `llamaDart.prepareModelTask(...)`
    instead when a UI needs progress snapshots and cancellation.
- Set the capability flags on every definition. `supportsEmbeddings`,
  `supportsTools` and `supportsConstrainedOutput` all default to `true`; set
  them to `false` for what the model should not serve (for example
  `supportsEmbeddings: false` for a chat model). Requests that use a disabled
  capability fail with `FAILED_PRECONDITION`.
- Set the context window with `modelParams: ModelParams(contextSize: ...)`.
  Tune a request with `LlamaDartGenerationConfig` (`temperature`, `topP`,
  `topK`, `minP`, `penalty`, `maxTokens`, `stop`, `seed`, `enableThinking`,
  `parallelToolCalls`, `chatTemplateKwargs`). Defaults: temperature 0.8,
  maxTokens 4096, thinking off.
- Stream with `ai.generateStream<LlamaDartGenerationConfig, Object?>(...)`:
  iterate the chunks for `chunk.text`, then `await stream.onResult` for the
  final response.
- Model and tool errors do not throw from `generate`: the response has
  `finishReason == FinishReason.failed`, and a cancel or exhausted `maxTurns`
  yields `FinishReason.aborted`. Check `finishReason`, then read
  `response.error` / `response.cause`, before using `text` or `output`.
- Cancel cooperatively by passing `cancel: controller.token` from a Genkit
  `CancellationController`. For a stop button, `plugin.cancelActiveGeneration(name)`
  or `prepared.cancelActiveGeneration()` cancels only the active generation;
  queued requests still run.
- Models load lazily on first use, and requests to the same model run one at a
  time. Call `prepared.warmUp(ai)` to load ahead of the first user request.
- Always `await plugin.dispose()` (or `prepared.dispose()`) and
  `await ai.shutdown()` in a `finally`. Disposal is terminal: create a new
  plugin instead of reusing one.
- Embeddings use `llamaDart.embedder(name)` with `ai.embed(...)` or
  `ai.embedMany(...)`, need an embedding model with `supportsEmbeddings: true`,
  and accept text-only documents.

## Examples

Register a local model file and stream a reply:

```dart
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main() async {
  final plugin = llamaDart(
    models: const <LlamaModelDefinition>[
      LlamaModelDefinition(
        name: 'local-chat',
        modelPath: '/models/chat.gguf',
        modelParams: ModelParams(contextSize: 8192),
        supportsEmbeddings: false,
      ),
    ],
  );
  final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);

  try {
    final stream = ai.generateStream<LlamaDartGenerationConfig, Object?>(
      model: llamaDart.model('local-chat'),
      prompt: 'Say hello in one short sentence.',
      config: const LlamaDartGenerationConfig(
        temperature: 0.2,
        maxTokens: 128,
        enableThinking: false,
      ),
    );
    await for (final chunk in stream) {
      stdout.write(chunk.text);
    }
    stdout.writeln();

    final response = await stream.onResult;
    if (response.finishReason == FinishReason.failed ||
        response.finishReason == FinishReason.aborted) {
      stderr.writeln('Generation stopped: ${response.error?.message}');
    }
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
```

Download a model through llamadart's cache, warm it up, generate with a
timeout-driven cancel:

```dart
import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main() async {
  final prepared = await llamaDart.prepareModel(
    name: 'local-chat',
    source: ModelSource.parse(
      'hf://unsloth/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q2_K.gguf',
    ),
    modelParams: const ModelParams(contextSize: 4096),
    options: ModelLoadOptions(
      cachePolicy: ModelCachePolicy.preferCached,
      cacheDirectory: '/path/to/app/model-cache',
    ),
    onModelProgress: (progress) => print(progress),
    supportsEmbeddings: false,
  );
  final ai = prepared.createGenkit();
  final cancellation = CancellationController();
  final timer = Timer(const Duration(seconds: 30), cancellation.cancel);

  try {
    await prepared.warmUp(ai);
    final response = await ai.generate(
      model: prepared.modelRef,
      prompt: 'Name three uses for an on-device model.',
      cancel: cancellation.token,
    );
    if (response.finishReason == FinishReason.aborted) {
      print('Cancelled.');
    } else if (response.finishReason == FinishReason.failed) {
      print('Failed: ${response.cause ?? response.error?.message}');
    } else {
      print(response.text);
    }
  } finally {
    timer.cancel();
    await prepared.dispose();
    await ai.shutdown();
  }
}
```

Embed text with an embedding model:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<List<double>> embedText(String text) async {
  final plugin = llamaDart(
    models: const <LlamaModelDefinition>[
      LlamaModelDefinition(
        name: 'local-embed',
        modelPath: '/models/embed.gguf',
        supportsTools: false,
        supportsConstrainedOutput: false,
      ),
    ],
  );
  final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);

  try {
    final embeddings = await ai.embed(
      embedder: llamaDart.embedder('local-embed'),
      document: DocumentData(content: <Part>[TextPart(text: text)]),
      options: const LlamaDartEmbedConfig(normalize: true),
    );
    return embeddings.single.embedding;
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
```

## More

- README (preparation tasks, multimodal input, observability, limitations):
  https://pub.dev/packages/genkit_llamadart
- llamadart runtime and platform setup: https://llamadart.leehack.com/
