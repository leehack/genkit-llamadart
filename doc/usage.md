# Generation, tools and embeddings

## Embeddings

Use `llamaDart.embedder(...)` with `ai.embed(...)` for single or multiple documents.
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

## Structured JSON output

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
      Map<String, dynamic>,
      LlamaDartGenerationConfig
    >(
      model: llamaDart.model('local-json'),
      prompt: 'Summarize this review as JSON: The battery life is great.',
      outputSchema: answerSchema,
      outputFormat: 'json',
      outputConstrained: true,
      config: const LlamaDartGenerationConfig(enableThinking: false),
    );

    if (response.finishReason == FinishReason.failed ||
        response.finishReason == FinishReason.aborted) {
      throw response.cause ?? StateError('Generation did not complete.');
    }
    print(jsonEncode(response.output));
  } finally {
    await plugin.dispose();
    await ai.shutdown();
  }
}
```

## Image and audio input

If your model needs a multimodal projector, set `mmprojPath` on the model
definition and register the plugin in your Genkit instance. For example, use
`modelPath: '/models/vision.gguf'` with
`mmprojPath: '/models/mmproj.gguf'`. Native LiteRT-LM bundles can have built-in
encoders and need no projector. Requests can include Genkit `Media` parts
alongside text:

```dart
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
if (response.finishReason == FinishReason.failed ||
    response.finishReason == FinishReason.aborted) {
  throw response.cause ?? StateError('Generation did not complete.');
}
print(response.text);
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

## Tool calling

- Genkit can drive multi-turn tool loops through this plugin; see the
  [agent example](../example/genkit_llamadart_agent_example.dart).
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

## Generation settings

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

## Lifecycle and cancellation

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
