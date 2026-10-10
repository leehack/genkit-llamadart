# Runtime support

## Feature permissions

Use `LlamaModelDefinition` to permit features for each registered model:

- `supportsEmbeddings`: register an embedder when the model should expose one
- `supportsTools`: permit tool requests and tool history
- `supportsConstrainedOutput`: permit grammar-constrained JSON output

These flags default to `true` for backward compatibility. Setting a flag to
`false` rejects that feature with `FAILED_PRECONDITION` before loading the model.
An enabled flag is permission to use a feature when the runtime supports it.

Discovery stays lazy: `plugin.init()` and `plugin.list()` never load models.
Standard `model.supports` booleans start at `false` because support is not yet
confirmed. Metadata includes `llamadartCapabilities` with:

- `state`: `unloaded`, `unverified` (a pending/failed probe or no provider), or `verified`
- `ready`: whether the last checked runtime reports a loaded, usable model
- `declared`: the definition's `tools`, `constrained`, and `embeddings` permissions

After initialization, the plugin reads `LlamaEngine.capabilities` before every
queued request and updates registered and cached discovery metadata, preserving
labels, schemas and other model annotations. These snapshots describe the last
check; every request checks again. A failed probe clears previous support and
blocks inference. Disposing the plugin clears its
support metadata. Registering an action does not guarantee that its runtime
supports the requested feature.

Tools, strict JSON, embeddings, system messages, conversation history, images,
and audio are checked before generation or embedding. Confirmed unsupported
features fail with `UNIMPLEMENTED`; an unready runtime fails with
`FAILED_PRECONDITION`. Through `ai.generate()`, failures can become a response
with `finishReason: failed`, so inspect the result's error.

| Runtime capability snapshot | Adapter behavior |
| --- | --- |
| llama.cpp GGUF | Uses loaded capabilities for tools, history, grammar, embeddings, and projector media. A projector path alone does not confirm media support. |
| Native LiteRT-LM | Preserves chat and tools when supported; rejects strict JSON and embeddings when unsupported. Built-in encoders need no projector. Media declarations can under-report encoders, so native media requests retain llamadart's best-effort runtime validation; unconfirmed media is not advertised. |
| LiteRT-LM Web | A snapshot that reports latest-text-only chat rejects history, system messages, tools, and media instead of silently dropping them. This does not establish Genkit Dart browser compatibility. |

Backend support does not prove model quality or template behavior. For example,
`systemRole` means the runtime delivers system messages to the chat template;
a model may still interpret them differently. Tool-choice constraints and
model-specific embedding eligibility remain validated by llamadart.
`constrainedWithTools` remains `false`.

Use `modelInfo` to customize labels, versions, configuration schema, stage, or
additional support metadata. Custom support keys are preserved; standard keys
are derived from permissions and verified capabilities and cannot be overridden.

Custom runtimes implement the exported `LlamaDartRuntime` interface and are
supplied through `LlamaDartPlugin(runtimeFactory: ...)`. They can also implement
`LlamaRuntimeCapabilityProvider` and return a fresh `LlamaEngineCapabilities` snapshot after initialization. Default runtimes
already do this. Existing implementations without the optional interface still
compile and can serve single-turn text; advanced requests fail with
`FAILED_PRECONDITION` and a provider diagnostic. This tightens advanced custom
runtime behavior to prevent unverified support claims.

## Limitations

- model paths are local filesystem paths after `ModelSource` resolution
- embeddings are text-only
- LiteRT-LM `.litertlm` bundles can be used for chat and tool-call flows, but
  constrained JSON output currently requires a backend with grammar constraints;
  set `supportsConstrainedOutput: false` for `.litertlm` model definitions.
- constrained structured output with active tool calling is not supported yet
- some models may need prompt tuning for reliable tool arguments
- multimodal requests require a compatible model and runtime; llama.cpp also
  requires a compatible projector, while native LiteRT-LM can use built-in encoders
- direct HTTP(S) image inputs are backend-dependent and currently supported by
  WebGPU; download the image to a local path or provide `data:` bytes for other
  compatible multimodal backends
