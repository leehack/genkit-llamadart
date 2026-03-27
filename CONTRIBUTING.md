# Contributing

Thanks for improving `genkit_llamadart`.

## Local Setup

```bash
dart pub get
```

Make sure the native `llamadart` prerequisites for your platform are installed.
For runtime setup and platform notes, see https://llamadart.leehack.com/.

## Project Layout

See `ARCHITECTURE.md` for the package layering rules.

- `lib/src/api/`: public package-facing types
- `lib/src/core/`: runtime and `llamadart` internals
- `lib/src/integration/genkit/`: Genkit adapter layer

The test tree mirrors this layout.

## Testing Conventions

- mirror `lib/src/` under `test/`
- keep one `test()` per file
- place shared helpers in a nearby `test_support/` directory
- prefer unit tests first, then Genkit integration tests, then real-model smoke tests

## Test Commands

Fast local checks:

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
dart test -x real-model
```

Real-model smoke tests with auto-download:

```bash
LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1 \
dart test test/integration/genkit/plugin/real_model_generate_returns_text_test.dart

LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1 \
dart test test/integration/genkit/actions/embedder_action/real_model_embed_returns_vector_test.dart
```

Real-model smoke tests with local files:

```bash
LLAMADART_INTEGRATION_MODEL_PATH=/models/tiny-chat.gguf \
dart test -t real-model test/integration/genkit/plugin/real_model_generate_returns_text_test.dart

LLAMADART_INTEGRATION_EMBED_MODEL_PATH=/models/tiny-embed.gguf \
dart test -t real-model test/integration/genkit/actions/embedder_action/real_model_embed_returns_vector_test.dart
```

Optional environment variables for smoke tests:

- `LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1`: download the default tiny models automatically
- `LLAMADART_TEST_MODEL_DIR`: override the local GGUF cache directory
- `HUGGING_FACE_HUB_TOKEN`: optional token for authenticated or rate-limited Hugging Face access

Auto-downloaded smoke-test models are cached under
`.dart_tool/llamadart_test_models` by default.

## Test Models

The default auto-downloaded models are intentionally tiny and CPU-friendly:

- chat: `SmolLM2-135M-Instruct-Q2_K.gguf` (~88 MB)
- embeddings: `jina-embeddings-v2-small-en-Q2_K.gguf` (~20 MB)

They are meant for smoke testing package behavior, not for judging output
quality.

## Before Opening A PR

Run:

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
dart test -x real-model
LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1 dart test test/integration/genkit/plugin/real_model_generate_returns_text_test.dart
LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1 dart test test/integration/genkit/actions/embedder_action/real_model_embed_returns_vector_test.dart
dart pub publish --dry-run
```

## Releasing

Publishing is automated from GitHub tags.

Before the first automated release, configure pub.dev admin settings for this
package to allow GitHub Actions publishing from `leehack/genkit-llamadart`
using the tag pattern `v{{version}}`.

Release flow:

1. update `version:` in `pubspec.yaml`
2. update `CHANGELOG.md`
3. merge to `main`
4. create and push a matching tag like `v1.1.0`

```bash
git tag v1.1.0
git push origin v1.1.0
```

The publish workflow then:

- verifies the tag matches `pubspec.yaml`
- reruns formatting, analysis, pana, tests, and `dart pub publish --dry-run`
- publishes to pub.dev using GitHub OIDC trusted publishing
- creates a GitHub release for the tag after a successful publish
