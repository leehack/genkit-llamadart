# Runnable examples

Run these commands from the repository root after `dart pub get`. The examples
are native Dart CLIs. CPU defaults avoid GPU setup; they do not qualify a
Flutter Web deployment. The first run downloads weights when a default source
is listed; later runs reuse llamadart's cache.

## Start here

```bash
dart run example/genkit_llamadart_example.dart
```

The [pub.dev example](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_example.dart) is a standalone Qwen3.5
quickstart with a pinned Hugging Face revision, 4,096-token context and model
sampling settings. It downloads about 533 MB. To use an existing model instead:

```bash
dart run example/genkit_llamadart_example.dart /models/chat.gguf
```

The streaming, agent, JSON, retrieval, resource and inspection examples use that same
Qwen3.5 default. Set `LLAMADART_MODEL_PATH` to reuse a local instruct GGUF.
Model quality and supported options can differ with that override.

| Example | Run with `dart run example/…` | What it demonstrates |
| --- | --- | --- |
| [Streaming](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_streaming_example.dart) | `genkit_llamadart_streaming_example.dart` | Incremental text plus the final `onResult` outcome |
| [Agent](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_agent_example.dart) | `genkit_llamadart_agent_example.dart` | Typed city arguments, deterministic sampling, a Genkit tool loop and multi-turn history; fixtures are **demo data**, not live weather |
| [Rich tool schemas](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_tool_schema_example.dart) | `genkit_llamadart_tool_schema_example.dart /models/Qwen3-1.7B-Q4_K_M.gguf` | Nullable input, numeric enums, closed objects and a native Genkit handler loop; local Qwen3 fixture required |
| [Structured JSON](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_json_example.dart) | `genkit_llamadart_json_example.dart` | Grammar-constrained streaming and parsed output; native grammar support required |
| [Local retrieval](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_retrieval_example.dart) | `genkit_llamadart_retrieval_example.dart` | Search three local text files, bound context and return an answer with source IDs |
| [Resource/data input](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_resources_example.dart) | `genkit_llamadart_resources_example.dart` | Explicitly resolve an approved resource and render bounded JSON data before generation |
| [Inspection and scoring](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_inspection_example.dart) | `genkit_llamadart_inspection_example.dart` | Loaded backend/context, raw token counts and next-token probabilities; native decoder required |
| [Embeddings](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_embedding_example.dart) | `genkit_llamadart_embedding_example.dart` | Normalized text vectors; downloads a pinned Jina embedding GGUF, about 20 MB |
| [Multimodal embeddings](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_multimodal_embedding_example.dart) | `genkit_llamadart_multimodal_embedding_example.dart MODEL PROJECTOR IMAGE AUDIO` (or `--litert MODEL IMAGE AUDIO`) | Ordered text/image/audio to one normalized vector; local embedding model and fixtures required, LiteRT CPU is explicitly selected |
| [Download/cache](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_source_prepare_example.dart) | `genkit_llamadart_source_prepare_example.dart` | Source preparation and cache reuse; pinned SmolLM2, about 88 MB |
| [Preparation UI](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_preparation_task_example.dart) | `genkit_llamadart_preparation_task_example.dart` | Download/load snapshots and warm-up; pinned SmolLM2, about 88 MB |
| [Decisions](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_decision_example.dart) | `genkit_llamadart_decision_example.dart` | Non-generative Laya choice, score and yes/no in a typed flow; downloads encoder/head, about 380 MB |
| [Dedicated owner](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_owner_example.dart) | `genkit_llamadart_owner_example.dart /models/base.gguf` | Application-owned raw completion and cancellation in a Genkit flow |
| [Raw-prompt cache](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_prompt_cache_example.dart) | `genkit_llamadart_prompt_cache_example.dart /models/chat.gguf` | Same-pool native KV reuse after owner replacement; no chat/RNG resume |
| [Experimental bidi](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_bidi_example.dart) | `genkit_llamadart_bidi_example.dart /models/chat.gguf` | Two bounded native text turns through real Genkit `generateBidi` |
| [Live LoRA](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_lora_example.dart) | `genkit_llamadart_lora_example.dart /models/base.gguf /models/adapter.gguf` | Apply and clear a compatible ordinary LoRA on one native owner, without reloading weights |

For a one-shot agent request instead of the interactive prompt:

```bash
LLAMADART_PROMPT='What is the demo temperature in Seoul?' \
  dart run example/genkit_llamadart_agent_example.dart
```

Use `clear` in the interactive agent to reset history. History consumes the
4,096-token context; long chats need application-level history management.
Source/preparation examples use compile-time overrides:

```bash
dart run -DLLAMADART_MODEL_SOURCE=/models/chat.gguf \
  -DLLAMADART_MODEL_CACHE=/tmp/model-cache \
  example/genkit_llamadart_source_prepare_example.dart
```

An embedding override must be an **embedding** GGUF, not the chat model:

```bash
LLAMADART_MODEL_PATH=/models/embedding.gguf \
  dart run example/genkit_llamadart_embedding_example.dart
```

Raw token counts omit the chat template, tools and media. Scoring measures
immediate raw continuation probabilities; it is not chat confidence or a
multi-token answer score. See [inspection](https://github.com/leehack/genkit-llamadart/blob/main/doc/model-inspection.md),
[scoring](https://github.com/leehack/genkit-llamadart/blob/main/doc/next-token-scoring.md), [decisions](https://github.com/leehack/genkit-llamadart/blob/main/doc/decision-flows.md)
and [owner/LoRA limitations](https://github.com/leehack/genkit-llamadart/blob/main/doc/runtime-owners.md).

## Images and speech

These preview examples require compatible native engines. They emit complete
results; transcription is whole-file, WAV synthesis is not incrementally
playable audio, and image generation returns a complete PNG. For typed-engine
imports in your own application, add `llamadart` explicitly as well as
`genkit` and `genkit_llamadart`.

| Example | Command | Models/setup |
| --- | --- | --- |
| [Image input](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_multimodal_example.dart) | `dart run example/genkit_llamadart_multimodal_example.dart /models/vision.gguf /models/mmproj.gguf image.png` | Supply a vision model and its **matching** projector; no weights are downloaded |
| [Transcription](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_transcription_example.dart) | `dart run example/genkit_llamadart_transcription_example.dart input.wav` | Downloads pinned Qwen3-ASR model/projector, about 1 GB; use a short trusted WAV |
| [Speech synthesis](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_speech_example.dart) | `dart run example/genkit_llamadart_speech_example.dart output.wav` | Downloads pinned Qwen3-TTS model/projector, about 1.5 GB; writes “Hello from Genkit.” as a complete WAV |
| [Image generation](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_image_example.dart) | `dart run example/genkit_llamadart_image_example.dart output.png` | Downloads pinned SDXS, about 683 MB; enable its native runtime first |

Transcription/speech accept local model and projector paths after the WAV path;
image generation accepts a local SDXS path after the output path. The output
commands overwrite the named file, so choose a new path when retaining outputs.
Image input accepts local PNG/JPEG files; remote input needs an explicit resolver
and URL policy. See [media input](https://github.com/leehack/genkit-llamadart/blob/main/doc/usage.md#image-and-audio-input).

For image generation, add this hook configuration to the application's
`pubspec.yaml`, then run `dart pub get` before the image command:

```yaml
hooks:
  user_defines:
    llamadart:
      llamadart_native_runtimes: [llama_cpp, stable_diffusion]
```

The model pairs, backend requirements, output limits and supported controls are
in the [speech/image guide](https://github.com/leehack/genkit-llamadart/blob/main/doc/media-models.md). These examples do not add
browser support or accept arbitrary model families through the Qwen adapters.

## Telemetry

The [observability example](https://github.com/leehack/genkit-llamadart/blob/main/example/genkit_llamadart_observability_example.dart) needs
an application-configured OTLP collector. It records model and runtime spans,
token usage and timing metrics, with prompt/output capture disabled:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 \
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
LLAMADART_MODEL_PATH=/models/chat.gguf \
  dart run example/genkit_llamadart_observability_example.dart
```

See [collector setup and privacy](https://github.com/leehack/genkit-llamadart/blob/main/doc/observability.md). When copying this
example into an app, add `genkit_otel` and `dartastic_opentelemetry` to its
package dependencies.
