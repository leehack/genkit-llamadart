## Unreleased

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
