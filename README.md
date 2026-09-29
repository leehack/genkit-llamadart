# genkit_llamadart

[![pub package](https://img.shields.io/pub/v/genkit_llamadart.svg)](https://pub.dev/packages/genkit_llamadart)
[![pub points](https://img.shields.io/pub/points/genkit_llamadart)](https://pub.dev/packages/genkit_llamadart/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Run local LLMs in [Genkit Dart](https://pub.dev/packages/genkit) apps. This
plugin runs llama.cpp GGUF models and LiteRT-LM bundles in-process through
[`llamadart`](https://pub.dev/packages/llamadart), so Dart and Flutter apps get
offline, on-device chat, streaming, tool calling, structured JSON output, and
embeddings without an OpenAI-compatible HTTP server.

## Features

- Chat generation with token streaming
- Genkit tool calling for multi-turn agent loops
- Constrained JSON output on grammar-capable backends
- Text embeddings
- Image and audio input with an optional multimodal projector
- Local model paths, or source-backed preparation from local, HTTP(S), and
  Hugging Face `ModelSource` values with caching, downloads, checksums, and
  progress snapshots
- Lazy model loading with queued per-model execution
- Genkit request cancellation, token usage, timings, and engine observers for
  OpenTelemetry instrumentation
- Android, iOS, macOS, Linux, Windows, and web

## Installation

Add Genkit and the plugin to your app:

```bash
dart pub add genkit genkit_llamadart
```

For structured output, also add `schemantic`:

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
`package:genkit_llamadart/genkit_llamadart.dart` for Genkit APIs.

### AI agent skills

genkit_llamadart ships [agent skills](https://dart.dev/tools/pub/package-skills)
for setup and generation, tool calling, and structured JSON output. Install
them into your coding agent's skills directory from your app's root:

```bash
dart run skills@ get
```

### Requirements

- Dart SDK `^3.12.0`, Genkit `0.17.x`, and llamadart `0.9.x`
- a local model file supported by `llamadart`, or a `ModelSource` that
  resolves to one
- the native `llamadart` runtime prerequisites for your platform
- optionally, a multimodal projector file or source for image or audio input

Follow the [`llamadart` documentation](https://llamadart.leehack.com/) for
native backends, Apple SwiftPM companion packages, and platform support.

Flutter Apple builds that use the companion SwiftPM packages require deployment
targets of iOS `16.4` or newer and macOS `14.0` or newer. If an iOS app still
uses CocoaPods, set the Podfile platform to `16.4` or newer too.

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

Don't have a model file yet? Use
[source-backed preparation](#source-backed-model-preparation) to download one,
or see [Choosing a model](#choosing-a-model).

## Choosing a Model

Pass an existing local path with `LlamaModelDefinition(modelPath: ...)`, or let
`llamaDart.prepareModel(...)` resolve a local, HTTP(S), or Hugging Face
`ModelSource` into the package-managed cache. Good places to find models:

- [`llamadart` documentation](https://llamadart.leehack.com/)
- [Hugging Face GGUF search](https://huggingface.co/models?search=gguf)
- [LiteRT community models](https://huggingface.co/litert-community) for
  `.litertlm` bundles, on `llamadart` targets that support LiteRT-LM

What to look for:

- chat and agents: an instruct or chat GGUF model
- Android LiteRT-LM chat: a `.litertlm` bundle such as Gemma 4 E2B
- embeddings: an embedding GGUF model
- multimodal input: a vision-capable GGUF model and, when required, a matching
  `mmproj` file

Before downloading a model, check its model card for:

- quantization level and expected RAM or CPU requirements
- chat template or instruct formatting
- context length
- whether tool calling or JSON-style output works well
- whether a separate projector file is required for image input

For tiny CPU-friendly smoke-test models, use
`hf://unsloth/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q2_K.gguf` for
chat and
`hf://second-state/jina-embeddings-v2-small-en-GGUF/jina-embeddings-v2-small-en-Q2_K.gguf`
for embeddings.

## Examples

| Example | Model | Shows |
| --- | --- | --- |
| [`genkit_llamadart_example.dart`](example/genkit_llamadart_example.dart) | chat | streaming chat generation |
| [`genkit_llamadart_source_prepare_example.dart`](example/genkit_llamadart_source_prepare_example.dart) | any source | resolving a `ModelSource` through the package-managed cache |
| [`genkit_llamadart_preparation_task_example.dart`](example/genkit_llamadart_preparation_task_example.dart) | any source | preparation snapshots, warm-up, then generation |
| [`genkit_llamadart_agent_example.dart`](example/genkit_llamadart_agent_example.dart) | chat | multi-turn tool loop; interactive when `LLAMADART_PROMPT` is unset |
| [`genkit_llamadart_json_example.dart`](example/genkit_llamadart_json_example.dart) | grammar-capable chat | constrained JSON output with streaming |
| [`genkit_llamadart_embedding_example.dart`](example/genkit_llamadart_embedding_example.dart) | embedding | vector dimensions and sample values |
| [`genkit_llamadart_observability_example.dart`](example/genkit_llamadart_observability_example.dart) | chat | OpenTelemetry spans and metrics through `genkit_otel` |

The table lists examples in the recommended order to try them. Examples that
take a model path read it from `LLAMADART_MODEL_PATH`; add
`LLAMADART_MMPROJ_PATH` to the chat and agent examples when the model requires
a projector file.

```bash
LLAMADART_MODEL_PATH=/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf \
dart run example/genkit_llamadart_example.dart
```

The same form runs the agent, JSON, and embedding examples. Use an embedding
model for the embedding example. The observability example also needs an
OpenTelemetry collector; see [Observability](#observability).

The preparation examples take a local path, HTTP(S) URL, or Hugging Face source
and default to the tiny SmolLM2 model:

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

## Source-Backed Model Preparation

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

### Observable Preparation and Warm-Up

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

### GenUI and Server Integration

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

## Tool Calling

- Genkit can drive multi-turn tool loops through this plugin; see the
  [agent example](example/genkit_llamadart_agent_example.dart).
- Tool callbacks return `ToolResult.response(value)`. Multipart tool-result
  content is rejected with `UNIMPLEMENTED`; return text or structured `output`
  instead.
- Tool input schemas and tool-request inputs must be JSON objects. Primitive or
  list root inputs cannot be represented by `llamadart`'s map argument API and
  fail with `INVALID_ARGUMENT`.
- Named Schemantic object schemas are supported; local `$ref` and `$defs`
  wrappers emitted by Genkit are resolved before tool parameters are mapped.
- Local models may vary in how reliably they emit structured tool arguments.
  If a model emits empty or weak tool arguments, use strong tool descriptions,
  prompt guidance, and app context to stabilize behavior.

## Observability

Configure a production instrumentation provider with
`configureInstrumentation(...)` from `package:genkit/telemetry.dart` before
creating `Genkit`. Genkit's development provider activates when a telemetry
server is configured; installing this plugin alone does not export telemetry.

The model response supplies backend-reported `usage.inputTokens`, `outputTokens`,
`totalTokens`, and `cachedContentTokens`. Missing measurements remain absent;
zero counts remain zero. Native llama.cpp and capable WebGPU bridges report
usage; do not assume every backend provides it.

`response.raw` additionally includes:

- `usage`: llamadart's usage map, with `time_to_first_token_ms` and `duration_ms`
  when reported. These backend timings exclude the plugin queue and model load.
- `queueMs`: time waiting for the model's serialized execution slot.
- `initializationMs`: time obtaining the runtime, including lazy model/projector
  loading on its first request.
- `totalLatencyMs`: elapsed time in the model action, including queue and setup.

`response.latencyMs` retains its existing generation-path timing after runtime
initialization. Usage is captured for ordinary chat and constrained JSON output.
These are per-model-call measurements; Genkit handles multi-turn aggregation.

Pass `observers: [yourObserver]` to `llamaDart(...)`, `prepareModel(...)`, or
`prepareModelTask(...)` to observe engine model loads, chat/text generation,
and embeddings, including failures and cancellation. Extend
`LlamaEngineObserver` and `LlamaOperationObserver`. Callbacks execute in the
request's Dart zone, allowing your instrumentation provider to correlate them
with the surrounding Genkit span, including after queue waits. Observer errors
are logged by llamadart without breaking inference. With a custom runtime
factory, that factory is responsible for installing its observers.

Observers receive request content. Export prompts, responses and tool data only
with an explicit application opt-in. Count token usage once at the model level;
engine diagnostics can carry the same measurements and should not increment a
second model-usage counter.

See [the observability example](example/genkit_llamadart_observability_example.dart)
for `genkit_otel`'s `GenAiInstrumentation` and correlated engine spans. The
example initializes and shuts down the OpenTelemetry SDK, exporting model token
and duration metrics once. Message capture and raw action I/O are explicitly
disabled. Engine spans include only operation names and outcomes; upstream
instrumentation may still export exception details on failures.

The telemetry packages are development dependencies here; applications adopting
this example should add `genkit_otel` and `dartastic_opentelemetry` to their own
dependencies. They are not required by the plugin itself.

Start an OpenTelemetry collector accepting OTLP HTTP on port 4318, then run:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 \
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
LLAMADART_MODEL_PATH=/models/chat.gguf \
dart run example/genkit_llamadart_observability_example.dart
```

## Configuration

### Model Capability Flags

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

### Default Request Settings

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

## Lifecycle and Cancellation

- models load lazily on first use
- requests for the same model are queued through a single runtime instance
- different model names get separate runtime instances
- pass `cancel: controller.token` to Genkit generation for cooperative
  cancellation; queued cancelled requests are checked before loading or
  generation, without interrupting another active request, and settle when
  their queue slot is reached
- call `prepared.cancelActiveGeneration()` to implement a stop button for a prepared model
- call `plugin.cancelActiveGeneration(name)` for one registered model, or
  `plugin.cancelActiveGenerations()` to stop all currently loaded models
- these helpers cancel only the active generation; a separately queued request
  can still start afterward
- Genkit `ai.generate()` can return `finishReason: failed` or `aborted`;
  inspect the outcome and `error`/`cause` before using the result
- `LlamaPreparedModel.warmUp()` still throws on failure or cancellation
- call `await plugin.dispose()` before process shutdown to release native state
- plugin disposal is terminal; create a new plugin or prepared-model handle instead of reusing it
- if multiple runtimes fail during disposal, the returned `ParallelWaitError`
  retains every underlying failure
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

## Upgrading to 2.0

Version 2.0 requires Dart 3.12, Genkit 0.17, llamadart 0.9, and Schemantic
0.2.3. When upgrading from 1.x (Genkit 0.13–0.15):

- Return `ToolResult.response(value)` from tool callbacks; see
  [Tool Calling](#tool-calling).
- Check generation results for `failed` or `aborted` finish reasons, and
  optionally pass Genkit cancellation tokens; see
  [Lifecycle and Cancellation](#lifecycle-and-cancellation).

See the [changelog](CHANGELOG.md) for the full list of changes.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local checks, real-model smoke
tests, and the release process, and [ARCHITECTURE.md](ARCHITECTURE.md) for the
package layering rules. Report bugs and request features in the
[issue tracker](https://github.com/leehack/genkit-llamadart/issues).
