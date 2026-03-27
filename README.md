# genkit_llamadart

`genkit_llamadart` is a Genkit Dart plugin for running local GGUF models through
`llamadart` in-process, without an OpenAI-compatible HTTP server.

It is designed for local-first Genkit applications that want a simple Dart API
for chat generation, streaming, tool loops, constrained JSON output, and text
embeddings.

## Features

- local filesystem `modelPath` configuration
- lazy model loading
- queued per-model execution
- chat generation with streaming
- Genkit tool request emission
- constrained JSON output
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

## Requirements

- Dart SDK `^3.10.7`
- a local GGUF model file
- the native `llamadart` runtime prerequisites for your platform
- an optional multimodal projector file if you want image input support

This package uses the hosted `llamadart` package from pub.dev. Follow the
`llamadart` installation guidance for native backend and platform support.

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

## Model Capability Flags

Use `LlamaModelDefinition` to control what each registered model advertises and
accepts:

- `supportsEmbeddings`: only register an embedder when the model should expose one
- `supportsTools`: disable Genkit tool use for models or templates that should not use tools
- `supportsConstrainedOutput`: disable constrained JSON output for models that should not advertise it

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

## Examples

- basic chat generation: `example/genkit_llamadart_example.dart`
- multi-turn tool loop: `example/genkit_llamadart_agent_example.dart`
- embeddings: `example/genkit_llamadart_embedding_example.dart`
- constrained JSON output: `example/genkit_llamadart_json_example.dart`

Run them with a local model path:

```bash
LLAMADART_MODEL_PATH=/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf \
dart run example/genkit_llamadart_example.dart
```

Agent example:

```bash
LLAMADART_MODEL_PATH=/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf \
dart run example/genkit_llamadart_agent_example.dart
```

Embedding example:

```bash
LLAMADART_MODEL_PATH=/models/nomic-embed-text.gguf \
dart run example/genkit_llamadart_embedding_example.dart
```

Structured JSON example:

```bash
LLAMADART_MODEL_PATH=/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf \
dart run example/genkit_llamadart_json_example.dart
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
      LlamaModelDefinition(name: 'local-embed', modelPath: '/models/embed.gguf'),
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
      LlamaModelDefinition(name: 'local-json', modelPath: '/models/chat.gguf'),
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
        Media(url: 'file:///tmp/example.png', contentType: 'image/png'),
      ],
    ),
  ],
);
```

Supported media inputs:

- images from local paths, `file://`, `data:`, and `http(s)` URLs
- audio from local paths, `file://`, and `data:` URLs

## Tool Calling Notes

- Genkit can drive multi-turn tool loops through this plugin.
- `example/genkit_llamadart_agent_example.dart` shows a local agent flow.
- Local models may vary in how reliably they emit structured tool arguments.
- If a model emits empty or weak tool arguments, use strong tool descriptions,
  prompt guidance, and app context to stabilize behavior.

## Lifecycle And Runtime Behavior

- models load lazily on first use
- requests for the same model are queued through a single runtime instance
- different model names get separate runtime instances
- call `await plugin.dispose()` before process shutdown to release native state
- call `await ai.shutdown()` when your Genkit app is done

## Limitations

- model paths are local filesystem paths
- embeddings are text-only
- constrained structured output with active tool calling is not supported yet
- some models may need prompt tuning for reliable tool arguments
- multimodal requests require a compatible model and projector file

## Development

Contributor docs:

- architecture: `ARCHITECTURE.md`
- contribution workflow: `CONTRIBUTING.md`

Useful local checks before publishing:

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
dart pub publish --dry-run
```

Optional real-model smoke tests are included. You can point them at local GGUF
files, or let them download tiny public test models from Hugging Face:

```bash
LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1 \
dart test test/integration/genkit/plugin/real_model_generate_returns_text_test.dart

LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1 \
dart test test/integration/genkit/actions/embedder_action/real_model_embed_returns_vector_test.dart

LLAMADART_INTEGRATION_MODEL_PATH=/models/tiny-chat.gguf \
dart test -t real-model test/integration/genkit/plugin/real_model_generate_returns_text_test.dart

LLAMADART_INTEGRATION_EMBED_MODEL_PATH=/models/tiny-embed.gguf \
dart test -t real-model test/integration/genkit/actions/embedder_action/real_model_embed_returns_vector_test.dart
```

Optional environment variables for smoke tests:

- `LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1` enables auto-download of the bundled tiny test models
- `LLAMADART_TEST_MODEL_DIR` overrides the local GGUF cache directory
- `HUGGING_FACE_HUB_TOKEN` is an optional token for authenticated or rate-limited Hugging Face downloads

Default auto-downloaded smoke-test models:

- chat: `unsloth/SmolLM2-135M-Instruct-GGUF` / `SmolLM2-135M-Instruct-Q2_K.gguf` (~88 MB)
- embeddings: `second-state/jina-embeddings-v2-small-en-GGUF` / `jina-embeddings-v2-small-en-Q2_K.gguf` (~20 MB)

These defaults are meant for CPU-friendly smoke testing on low-end developer
machines and CI, not as quality benchmarks for application behavior.

The unit test tree mirrors `lib/src/` so API, core, and Genkit integration code
can evolve independently without mixing concerns.
