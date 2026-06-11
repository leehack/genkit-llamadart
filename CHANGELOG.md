## 1.3.3 - 2026-06-10

- Widen the Genkit and Schemantic dependency constraints to allow `genkit` `0.14.x` while keeping compatibility with `0.13.x`.
- Widen the `llamadart` dependency constraint to allow `llamadart` `0.8.x` while keeping compatibility with `0.7.x`.
- Remove the unnecessary Flutter SDK environment constraint from the package metadata.

## 1.3.2 - 2026-06-07

- Add explicit pub.dev platform metadata for Android, iOS, Linux, macOS, web, and Windows so the package listing reflects the cross-platform support inherited from `llamadart`.

## 1.3.1 - 2026-06-06

- Update the `llamadart` dependency constraint to `^0.7.1` so Genkit models can use `.litertlm` LiteRT-LM bundles on supported `llamadart` targets.
- Re-export LiteRT-LM and advanced `ModelParams` option enums from the top-level package API.
- Clarify README and API docs that model paths are not GGUF-only, and that this release resolves through the Flutter SDK required by hosted `llamadart`.

## 1.3.0 - 2026-06-04

- Add plugin and prepared-model APIs for cancelling active `llamadart` generations without holding the underlying `LlamaEngine`.

## 1.2.0 - 2026-05-25

- Add source-backed model preparation with `ModelSource`, package-managed cache/download options, optional mmproj resolution, and typed prepared-model refs.
- Add observable model preparation tasks with progress snapshots, cache-hit states, failure reporting, and cancellation.
- Add prepared-model `createGenkit`, warm-up, and ownership-aware disposal helpers.
- Document direct GenUI and `genkit_shelf` integration paths for prepared local models.

## 1.1.1

- Update the Genkit dependency constraint to `^0.13.2` and verify compatibility with `llamadart` `0.6.14`.

## 1.1.0

- Expand README with installation, lifecycle, embeddings, JSON output, and multimodal guidance
- Add standalone embedding and constrained JSON example programs
- Add explicit `ai.shutdown()` cleanup to example apps
- Add per-model capability flags for embeddings, tools, and constrained output
- Harden streamed tool-call accumulation and raw response metadata
- Add CI and failure-path coverage for plugin, runtime, model, and embedder behavior
- Reorganize source into api, core, and Genkit integration layers
- Mirror the test tree to the source layout with one test per file
- Add optional Hugging Face-backed real-model smoke tests for generation and embeddings
- Add architecture and contributing guides for maintainers and contributors
- Cache downloaded real-model GGUF artifacts in CI

## 1.0.0

- Add an in-process Genkit plugin backed by `llamadart`
- Support local path-based chat generation, streaming, embeddings, and tool loops
- Add example apps for basic generation and a multi-turn agent workflow
- Add tests for converters, runtime queueing, embeddings, and Genkit tool loops
- Add pub.dev-ready package metadata and MIT license
