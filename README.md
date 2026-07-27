# genkit_llamadart

`genkit_llamadart` is a Genkit Dart plugin for running local models through
`llamadart` in-process, without an OpenAI-compatible HTTP server.

It is designed for local-first Genkit applications that want a simple Dart API
for chat generation, streaming, tool loops, constrained JSON output, and text
embeddings.

## Features

- local filesystem `modelPath` configuration
- source-backed model preparation with `ModelSource`, cache, download, and progress snapshots
- lazy model loading
- queued per-model execution
- chat generation with streaming
- Genkit tool request emission
- constrained JSON output on grammar-capable backends
- text embeddings
- optional multimodal projector support

## Install

Add both Genkit and the plugin to your app:

```bash
dart pub add genkit genkit_llamadart
```

If you want structured outputs, also add `schemantic`:

```bash
dart pub add schemantic
```

Flutter iOS/macOS apps that want Swift Package Manager-linked Apple
XCFrameworks should also add the `llamadart` runtime companion packages for
the model families they ship:

```bash
flutter pub add llamadart_llama_cpp_flutter # GGUF / llama.cpp
flutter pub add llamadart_litert_lm_flutter # .litertlm / LiteRT-LM
```

These companion packages provide Apple runtime packaging only. Keep importing
and using `package:genkit_llamadart/genkit_llamadart.dart` for Genkit APIs.

## Requirements

- Dart SDK `^3.10.7`
- a local model file supported by `llamadart`, or a `ModelSource` that resolves to one
- the native `llamadart` runtime prerequisites for your platform
- an optional multimodal projector file or source if you want image input support

This package uses the hosted `llamadart` package from pub.dev. Follow the
`llamadart` installation guidance for native backend, Apple SwiftPM companion
packages, and platform support:

- `llamadart` docs: https://llamadart.leehack.com/

Flutter Apple builds that use the companion SwiftPM packages require deployment
targets of iOS `16.4` or newer and macOS `14.0` or newer. If an iOS app still
uses CocoaPods, set the Podfile platform to `16.4` or newer too.

## Finding Models

This package runs `llamadart` model files locally. You can pass an existing local path with
`LlamaModelDefinition(modelPath: ...)`, or let `llamaDart.prepareModel(...)`
resolve a local, HTTP(S), or Hugging Face `ModelSource` into the package-managed
cache. Good places to find models:

- `llamadart` docs: https://llamadart.leehack.com/
- Hugging Face GGUF search: https://huggingface.co/models?search=gguf
- LiteRT-LM bundles: use `.litertlm` files on `llamadart` targets that support LiteRT-LM

What to look for:

- chat and agent examples: an instruct or chat GGUF model
- Android LiteRT-LM chat: a `.litertlm` bundle such as Gemma 4 E2B
- embedding example: an embedding GGUF model
- multimodal usage: a vision-capable GGUF model and, when required, a matching `mmproj` file

Before downloading a model, check its model card for:

- quantization level and expected RAM or CPU requirements
- chat template or instruct formatting
- context length
- whether tool calling or JSON-style output works well
- whether a separate projector file is required for image input

If you just want a tiny CPU-friendly smoke-test model, the real-model test
section later in this README lists the small GGUF files used in CI.

## Try It Fast

If you only want to confirm the plugin works end-to-end, start with the
streaming chat example and a small instruct/chat model.

Example and model guide:

- `example/genkit_llamadart_example.dart`: chat or instruct model; streams tokens to stdout
- `example/genkit_llamadart_agent_example.dart`: chat or instruct model; streams replies and becomes interactive when `LLAMADART_PROMPT` is not set
- `example/genkit_llamadart_json_example.dart`: grammar-capable chat or instruct model with decent JSON adherence; streams raw JSON tokens before printing parsed output
- `example/genkit_llamadart_embedding_example.dart`: embedding GGUF; prints vector dimensions and sample values
- `example/genkit_llamadart_source_prepare_example.dart`: resolves a `ModelSource` through the package-managed cache before generation
- `example/genkit_llamadart_preparation_task_example.dart`: prints observable preparation snapshots, warms up the model, then generates
- multimodal requests: add `LLAMADART_MMPROJ_PATH` when the selected model requires a projector file

If you still need `llamadart` runtime or platform setup help before trying the
examples, check https://llamadart.leehack.com/ first.

## Quickstart

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main() async {
  final plugin = llamaDart(
    models: const <LlamaModelDefinition>[
      LlamaModelDefinition(
        name: 'local-chat',
        modelPath: '/models/qwen3.gguf',
        modelParams: ModelParams(contextSize: 8192),
        supportsEmbeddings: false,
      ),
    ],
  );

  final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);

  try {
    final response = await ai.generate(
      model: llamaDart.model('local-chat'),
      prompt: 'Say hello in one sentence.',
      config: const LlamaDartGenerationConfig(
        temperature: 0.2,
        maxTokens: 96,
        enableThinking: false,
      ),
    );

    print(response.text);
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
```

## Source-backed model preparation

If your app does not already manage model files itself, use
`llamaDart.prepareModel(...)` with `llamadart`'s `ModelSource` and
package-managed cache/download options. The helper resolves the source to a
local file, builds the normal `LlamaModelDefinition`, and returns a plugin plus
typed model/embedder refs for standard Genkit calls.

```dart
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
      sha256: null, // set to a 64-character SHA-256 digest when available
      bearerToken: null, // set for private remote sources
    ),
    supportsEmbeddings: false,
  );

  final ai = Genkit(plugins: <LlamaDartPlugin>[prepared.plugin]);
  try {
    final response = await ai.generate(
      model: prepared.modelRef,
      prompt: 'Say hello in one sentence.',
    );
    print(response.text);
  } finally {
    await prepared.dispose();
    await ai.shutdown();
  }
}
```

Use this path for HTTP(S), Hugging Face, or local `ModelSource` values when you
want `llamadart` to own cache lookup, download, checksum verification, and
private-token/header plumbing. Keep constructing `LlamaModelDefinition` manually
when your application already has a local filesystem path and owns all download
or cache policy itself.

For multimodal models, pass `mmprojSource` and optional `mmprojOptions`; the
resolved projector file path is wired into `LlamaModelDefinition.mmprojPath`.
Local `ModelSource.path(...)` values use `llamadart`'s local-path semantics:
remote-only options such as cache policy overrides, cache directories, bearer
tokens, headers, resume, and retry settings are rejected instead of silently
ignored.

### Observable preparation and warm-up

Flutter and other client apps can use `prepareModelTask(...)` when they need
deterministic loading UI for source resolution, cache checks, downloads,
verification, Genkit setup, failures, and cancellation.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main() async {
  final task = llamaDart.prepareModelTask(
    name: 'local-chat',
    source: ModelSource.parse(
      'hf://unsloth/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q2_K.gguf',
    ),
    modelParams: const ModelParams(contextSize: 4096),
    options: ModelLoadOptions(
      cachePolicy: ModelCachePolicy.preferCached,
      cacheDirectory: '/path/to/app/model-cache',
    ),
    supportsEmbeddings: false,
  );

  final subscription = task.snapshots.listen((snapshot) {
    // Bind these fields into your UI state, ChangeNotifier, Bloc, Riverpod, etc.
    final stage = snapshot.stage;
    final fraction = snapshot.fraction;
    final modelPath = snapshot.modelEntry?.filePath;
    final errorText = snapshot.errorMessage;
    print('$stage ${fraction ?? '-'} ${modelPath ?? errorText ?? ''}');
  });

  LlamaPreparedModel? prepared;
  Genkit? ai;
  try {
    prepared = await task.result;
    ai = prepared.createGenkit();

    await prepared.warmUp(
      ai,
      systemPrompt: 'Use terse, app-friendly answers.',
      prompt: 'Reply with one token: ready',
      config: const LlamaDartGenerationConfig(
        maxTokens: 1,
        temperature: 0.0,
        enableThinking: false,
      ),
    );

    final response = await ai.generate(
      model: prepared.modelRef,
      prompt: 'Say hello in one sentence.',
    );
    print(response.text);
  } finally {
    await subscription.cancel();
    await task.dispose();
    if (prepared != null) {
      await prepared.dispose();
    }
    if (ai != null) {
      await ai.shutdown();
    }
  }
}
```

Call `task.cancel()` to request cooperative cancellation while preparation is in
flight. Disposing the task closes snapshot resources; disposing the returned
`LlamaPreparedModel` releases plugin/runtime resources owned by this package.
`prepared.createGenkit()` is a convenience for registering the plugin, but the
returned `Genkit` instance remains caller-owned and should still be shut down by
the app.

### GenUI and server integration

UI frameworks such as GenUI should adapt through normal Genkit model refs and
backends. Once your app has a prepared model, pass `prepared.modelRef` and
`prepared.plugin` into the Genkit-facing adapter instead of depending on a
provider-specific GenUI llamadart bridge:

```dart
final prepared = await llamaDart.prepareModel(...);
final ai = prepared.createGenkit();

final session = GenkitGenUiSession(
  backend: GenkitBackend<LlamaDartGenerationConfig>(
    ai: ai,
    model: prepared.modelRef,
    config: const LlamaDartGenerationConfig(maxTokens: 512),
  ),
  catalog: appCatalog,
);
```

Use `genkit_llamadart` directly when the app wants source-backed local model
preparation, progress snapshots, typed Genkit refs, warm-up, and lifecycle
helpers. Manually construct `LlamaModelDefinition(modelPath: ...)` when another
part of the app already owns file resolution and caching. Provider-specific
packages such as `genui_genkit_llamadart` should be treated as transitional UI
wiring once the GenUI docs can point at the direct Genkit model-ref path above.

The same prepared-model API works in backend/server apps. A server package can
add `genkit_shelf` and expose a Genkit flow while keeping model preparation in
one place:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_shelf/genkit_shelf.dart';

Future<void> main() async {
  final prepared = await llamaDart.prepareModel(
    name: 'server-chat',
    source: ModelSource.parse('/models/server-chat.gguf'),
    modelParams: const ModelParams(contextSize: 8192),
    supportsEmbeddings: false,
  );
  final ai = prepared.createGenkit();

  final flow = ai.defineFlow<String, String, String, void>(
    name: 'localChat',
    fn: (prompt, context) async {
      final stream = ai.generateStream<LlamaDartGenerationConfig, Object?>(
        model: prepared.modelRef,
        prompt: prompt,
        config: const LlamaDartGenerationConfig(maxTokens: 512),
      );

      await for (final chunk in stream) {
        if (chunk.text.isNotEmpty) {
          context.sendChunk(chunk.text);
        }
      }

      return (await stream.onResult).text;
    },
  );

  await startFlowServer(flows: [flow], port: 8080);
}
```

## Model Capability Flags

Use `LlamaModelDefinition` to control what each registered model advertises and
accepts:

- `supportsEmbeddings`: only register an embedder when the model should expose one
- `supportsTools`: disable Genkit tool use for models or templates that should not use tools
- `supportsConstrainedOutput`: disable constrained JSON output for models that should not advertise it, including `.litertlm` LiteRT-LM bundles until that backend supports grammar constraints

These flags default to `true` for backward compatibility. Set them explicitly
for single-purpose chat, embedding, and structured-output models so Genkit does
not advertise actions the selected model should not serve.

Use `modelInfo` to customize Genkit metadata such as the label, versions,
configuration schema, stage, or additional support metadata.
`modelInfo.supports` is merged after the derived capability flags and therefore
overrides advertised metadata only; it does not bypass runtime enforcement by
`supportsTools`, `supportsConstrainedOutput`, or `supportsEmbeddings`. Keep
overridden metadata aligned with those flags.

## Default Request Settings

Unless you override them in `LlamaDartGenerationConfig`, the plugin uses these
defaults:

- `temperature: 0.8`
- `topP: 0.9`
- `topK: 40`
- `minP: 0.0`
- `penalty: 1.1`
- `maxTokens: 4096`
- `enableThinking: false`
- `parallelToolCalls: false`

Additional request controls include:

- `stop`: custom stop sequences
- `seed`: an optional deterministic sampling seed
- `sourceLangCode` and `targetLangCode`: language hints for translation-style templates
- `chatTemplateKwargs`: extra globals passed through to the model chat template

## Examples

- basic streaming chat generation: `example/genkit_llamadart_example.dart`
- source-backed model preparation: `example/genkit_llamadart_source_prepare_example.dart`
- observable preparation and warm-up: `example/genkit_llamadart_preparation_task_example.dart`
- multi-turn tool loop: `example/genkit_llamadart_agent_example.dart`
- embeddings: `example/genkit_llamadart_embedding_example.dart`
- constrained JSON output with streaming: `example/genkit_llamadart_json_example.dart`

Run the streaming chat example with a local instruct/chat model:

```bash
LLAMADART_MODEL_PATH=/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf \
dart run example/genkit_llamadart_example.dart
```

Run the agent example with a local instruct/chat model:

```bash
LLAMADART_MODEL_PATH=/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf \
dart run example/genkit_llamadart_agent_example.dart
```

Run the embedding example with a local embedding model:

```bash
LLAMADART_MODEL_PATH=/models/nomic-embed-text.gguf \
dart run example/genkit_llamadart_embedding_example.dart
```

Run the structured JSON streaming example with a local instruct/chat model:

```bash
LLAMADART_MODEL_PATH=/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf \
dart run example/genkit_llamadart_json_example.dart
```

Run the source-backed preparation example from a local path, HTTP(S) URL, or
Hugging Face source:

```bash
dart run -DLLAMADART_MODEL_SOURCE=hf://owner/repo/model.gguf \
  example/genkit_llamadart_source_prepare_example.dart
```

Use a `.litertlm` source the same way on supported `llamadart` targets:

```bash
dart run \
  -DLLAMADART_MODEL_SOURCE='https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true' \
  example/genkit_llamadart_source_prepare_example.dart
```

Examples are easiest to test in this order:

1. `example/genkit_llamadart_example.dart`
2. `example/genkit_llamadart_source_prepare_example.dart`
3. `example/genkit_llamadart_preparation_task_example.dart`
4. `example/genkit_llamadart_agent_example.dart`
5. `example/genkit_llamadart_json_example.dart`
6. `example/genkit_llamadart_embedding_example.dart`

## Embeddings

Use `llamaDart.embedder(...)` with `ai.embed(...)` or `ai.embedMany(...)`.
Embeddings currently accept text-only documents.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

Future<void> main() async {
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
      document: DocumentData(
        content: <Part>[TextPart(text: 'hello world from llamadart')],
      ),
      options: const LlamaDartEmbedConfig(normalize: true),
    );

    print(embeddings.single.embedding.length);
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
```

## Structured JSON Output

Constrained JSON mode works with Genkit output schemas. This is useful when you
need machine-readable output from a local model.

```dart
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:schemantic/schemantic.dart';

final answerSchema = SchemanticType.from<Map<String, dynamic>>(
  jsonSchema: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'summary': <String, Object?>{'type': 'string'},
      'sentiment': <String, Object?>{'type': 'string'},
    },
    'required': <String>['summary', 'sentiment'],
    'additionalProperties': false,
  },
  parse: (json) {
    if (json is Map<String, dynamic>) {
      return json;
    }
    if (json is Map) {
      return json.cast<String, dynamic>();
    }
    throw FormatException('Expected a JSON object.');
  },
);

Future<void> main() async {
  final plugin = llamaDart(
    models: const <LlamaModelDefinition>[
      LlamaModelDefinition(
        name: 'local-json',
        modelPath: '/models/chat.gguf',
        supportsEmbeddings: false,
        supportsTools: false,
      ),
    ],
  );
  final ai = Genkit(plugins: <LlamaDartPlugin>[plugin]);

  try {
    final response = await ai.generate<
      LlamaDartGenerationConfig,
      Map<String, dynamic>
    >(
      model: llamaDart.model('local-json'),
      prompt: 'Summarize this review as JSON: The battery life is great.',
      outputSchema: answerSchema,
      outputFormat: 'json',
      outputConstrained: true,
      config: const LlamaDartGenerationConfig(enableThinking: false),
    );

    print(jsonEncode(response.output));
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
```

## Multimodal Requests

If your model needs a multimodal projector, set `mmprojPath` on the model
definition. Requests can include Genkit `Media` parts alongside text.

```dart
final plugin = llamaDart(
  models: const <LlamaModelDefinition>[
    LlamaModelDefinition(
      name: 'local-vision',
      modelPath: '/models/vision.gguf',
      mmprojPath: '/models/mmproj.gguf',
      supportsEmbeddings: false,
    ),
  ],
);

final response = await ai.generate(
  model: llamaDart.model('local-vision'),
  messages: <Message>[
    Message(
      role: Role.user,
      content: <Part>[
        TextPart(text: 'Describe this image in one sentence.'),
        MediaPart(
          media: Media(
            url: 'file:///tmp/example.png',
            contentType: 'image/png',
          ),
        ),
      ],
    ),
  ],
);
```

Supported media inputs:

- images from local paths, `file://`, and `data:` URLs on compatible
  multimodal backends
- `http(s)` image URLs on backends that consume remote URLs directly
  (currently WebGPU)
- audio from local paths, `file://`, and `data:` URLs

For local files and HTTP(S) URLs with a recognized extension, the media type is
inferred from the URI path. This includes signed HTTP(S) URLs with query
parameters or fragments, although remote fetching remains backend-dependent.
Local `file://` URLs cannot include query parameters or fragments. Provide
`contentType` when the path has no recognizable media extension.

## Tool Calling Notes

- Genkit can drive multi-turn tool loops through this plugin.
- `example/genkit_llamadart_agent_example.dart` shows a local agent flow.
- Tool input schemas and tool-request inputs must be JSON objects. Primitive or
  list root inputs cannot be represented by `llamadart`'s map argument API and
  fail with `INVALID_ARGUMENT`.
- Local models may vary in how reliably they emit structured tool arguments.
- If a model emits empty or weak tool arguments, use strong tool descriptions,
  prompt guidance, and app context to stabilize behavior.

## Lifecycle And Runtime Behavior

- models load lazily on first use
- requests for the same model are queued through a single runtime instance
- different model names get separate runtime instances
- call `prepared.cancelActiveGeneration()` to implement a stop button for a prepared model
- call `plugin.cancelActiveGeneration(name)` for one registered model, or
  `plugin.cancelActiveGenerations()` to stop all currently loaded models
- cancellation targets only the active generation; a separately queued request can still start afterward
- call `await plugin.dispose()` before process shutdown to release native state
- plugin disposal is terminal; create a new plugin or prepared-model handle instead of reusing it
- call `await ai.shutdown()` when your Genkit app is done

## Limitations

- model paths are local filesystem paths after `ModelSource` resolution
- embeddings are text-only
- LiteRT-LM `.litertlm` bundles can be used for chat and tool-call flows, but
  constrained JSON output currently requires a backend with grammar constraints;
  set `supportsConstrainedOutput: false` for `.litertlm` model definitions.
- constrained structured output with active tool calling is not supported yet
- some models may need prompt tuning for reliable tool arguments
- multimodal requests require a compatible model and projector file
- direct HTTP(S) image inputs are backend-dependent and currently supported by
  WebGPU; download the image to a local path or provide `data:` bytes for other
  compatible multimodal backends

## Development

Contributor docs:

- architecture: `ARCHITECTURE.md`
- contribution workflow: `CONTRIBUTING.md`

Useful local checks before publishing:

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
flutter pub publish --dry-run
```

Optional real-model smoke tests are included. You can point them at local model
files, or let them download tiny public GGUF test models from Hugging Face:

```bash
LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1 \
dart test -t real-model

LLAMADART_INTEGRATION_MODEL_PATH=/models/tiny-chat.gguf \
LLAMADART_INTEGRATION_EMBED_MODEL_PATH=/models/tiny-embed.gguf \
dart test -t real-model
```

Optional environment variables for smoke tests:

- `LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1` enables auto-download of the bundled tiny test models
- `LLAMADART_TEST_MODEL_DIR` overrides the local test-model cache directory
- `HUGGING_FACE_HUB_TOKEN` is an optional token for authenticated or rate-limited Hugging Face downloads

Auto-downloaded smoke-test models are cached under
`.dart_tool/llamadart_test_models` by default. Their Hugging Face revisions are
pinned, and cached or downloaded files are verified against their expected size
and SHA-256 digest before use.

Default auto-downloaded smoke-test models:

- chat: `unsloth/SmolLM2-135M-Instruct-GGUF` / `SmolLM2-135M-Instruct-Q2_K.gguf` (~88 MB)
- embeddings: `second-state/jina-embeddings-v2-small-en-GGUF` / `jina-embeddings-v2-small-en-Q2_K.gguf` (~20 MB)

These defaults are meant for CPU-friendly smoke testing on low-end developer
machines and CI, not as quality benchmarks for application behavior.

The unit test tree mirrors `lib/src/` so API, core, and Genkit integration code
can evolve independently without mixing concerns.
