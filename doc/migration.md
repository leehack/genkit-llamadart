# Migration guide

## Upgrading to 3.0 (Genkit 1.0)

Version 3.0.0 requires Dart 3.12, Genkit 1.0, llamadart 0.11.1, and
Schemantic 1.0. For applications using the previous dependency versions:

- Put the output type first in explicit generation type arguments:
  `ai.generate<T, LlamaDartGenerationConfig>(...)` and
  `ai.generateStream<T, LlamaDartGenerationConfig>(...)`.
- Replace `GenerateResponseHelper<T>` with `GenerateResult<T>`, including
  explicit types for results returned by `prepared.warmUp<T>(ai)`.
- Use `ToolChoice.auto`, `ToolChoice.required`, or `ToolChoice.none` for
  Genkit's `toolChoice`; use `StatusCode.invalidArgument` and other
  lowerCamelCase status values when checking errors.
- Replace `ai.embedMany(...)` with `ai.embed(...)` for multiple documents.
- Define custom Schemantic JSON schemas with plain maps instead of `$Schema`.
- Use `ModelParams(device: ComputeDevice.cpu)` (or `auto`, `gpu`, or `npu`)
  for device selection. The deprecated `LiteRtLmBackendPreference` export
  has been removed; replace it with `ComputeDevice`.
- Use `genkit_otel` 0.2.0 or newer with Genkit 1.0.
- Flutter Apple apps using runtime companions must upgrade them alongside
  llamadart: core 0.11.1 pairs with `llamadart_llama_cpp_flutter` 0.0.21
  and `llamadart_litert_lm_flutter` 0.0.13. See the
  [llamadart 0.11.1 installation notes](https://pub.dev/packages/llamadart/versions/0.11.1#install)
  for the matching runtime packaging.

## Upgrading to 2.0

Version 2.0 requires Dart 3.12, Genkit 0.17, llamadart 0.9, and Schemantic
0.2.3. When upgrading from 1.x (Genkit 0.13–0.15):

- Return `ToolResult.response(value)` from tool callbacks; see
  [Tool calling](usage.md#tool-calling).
- Check generation results for `failed` or `aborted` finish reasons, and
  optionally pass Genkit cancellation tokens; see
  [Lifecycle and cancellation](usage.md#lifecycle-and-cancellation).

See the [changelog](../CHANGELOG.md) for the full list of changes.
