# Architecture

`genkit_llamadart` is organized as a layered adapter around `llamadart`.

## Layers

### `lib/src/api/`

Public package surface and stable user-facing types.

- `plugin_handle.dart`: `llamaDart`, typed model refs, typed embedder refs
- `model_definition.dart`: static model registration config
- `generation_config.dart`: request-time model options
- `embed_config.dart`: request-time embed options

Rules:

- safe to export from `lib/genkit_llamadart.dart`
- should not depend on Genkit action internals or runtime orchestration
- should stay small, stable, and easy to document

### `lib/src/core/`

Runtime and transport-neutral `llamadart` logic.

- `runtime/`: engine lifecycle and queued runtime access
- `streaming/`: chunk accumulation and stream assembly helpers
- `metadata/`: model capability shaping shared by integrations

Rules:

- should not depend on package public exports
- should avoid Genkit-specific request/response types where possible
- should contain reusable logic if another integration layer is added later

### `lib/src/integration/genkit/`

The Genkit adapter layer.

- plugin registration
- model and embedder actions
- Genkit <-> `llamadart` conversion
- action metadata and raw response shaping

Rules:

- this is the only layer that should know about Genkit action wiring
- request validation that is specific to Genkit belongs here
- it can depend on both `api` and `core`

## Dependency Direction

Dependencies should flow inward in this direction:

`api` <- `core` <- `integration`

More concretely:

- `api` must not import `integration`
- `core` must not import `integration`
- `integration` may import `api` and `core`

`lib/genkit_llamadart.dart` re-exports the supported public API without exposing
the internal layout to package consumers.

## Test Layout

The `test/` tree mirrors `lib/src/`.

- `test/api/`
- `test/core/`
- `test/integration/genkit/`

Conventions:

- one `test()` per file
- shared helpers live in nearby `test_support/` directories
- fake runtimes and harnesses should stay out of production code
- real-model smoke tests live under `test/integration/genkit/`

## Real-Model Smoke Tests

The real-model tests intentionally use tiny GGUF files so they can run in CPU
mode in CI and on low-end developer machines.

Current defaults:

- chat: `unsloth/SmolLM2-135M-Instruct-GGUF` / `SmolLM2-135M-Instruct-Q2_K.gguf`
- embeddings: `second-state/jina-embeddings-v2-small-en-GGUF` / `jina-embeddings-v2-small-en-Q2_K.gguf`

These are smoke-test models, not quality baselines. They are chosen to validate
loading, generation, and embedding paths cheaply.
