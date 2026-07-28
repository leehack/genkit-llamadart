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
- keep each test file focused on one behavior or a tightly related lifecycle
- group related cases when they benefit from shared setup
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
dart test -t real-model
```

Real-model smoke tests with local files:

```bash
LLAMADART_INTEGRATION_MODEL_PATH=/models/tiny-chat.gguf \
LLAMADART_INTEGRATION_EMBED_MODEL_PATH=/models/tiny-embed.gguf \
dart test -t real-model
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
LLAMADART_AUTO_DOWNLOAD_TEST_MODELS=1 dart test -t real-model
dart pub publish --dry-run
```

The full CI job runs after `flutter pub upgrade`, so it exercises the latest
compatible dependency set. A focused compatibility job pins the direct runtime
dependencies to their supported lower bounds, then runs analysis and the fast
test suite. This keeps both ends executable without duplicating the latest
dependency checks.

## Releasing

Merging a guarded release-preparation PR is the publication approval boundary.
The merge creates the matching GitHub tag, dispatches the existing publish
workflow, and waits for both pub.dev and the GitHub Release.

Before the first automated release, configure pub.dev admin settings for this
package to allow GitHub Actions publishing from `leehack/genkit-llamadart`
using the tag pattern `v{{version}}`.

Release flow:

1. create a same-repository branch named `release/vX.Y.Z`
2. update `version:` in `pubspec.yaml`
3. promote `CHANGELOG.md` so its first heading is
   `## X.Y.Z - YYYY-MM-DD`
4. open a release-preparation PR that changes only `pubspec.yaml` and
   `CHANGELOG.md`
5. complete review and CI, then merge the PR

The optional `release-prep` label can authorize a nonstandard same-repository
branch. Ordinary merged PRs are detected and skipped.

After a qualifying merge, the release-on-prep workflow:

- verifies the branch or label gate and the two-file release diff
- verifies the branch, package, and changelog versions agree
- creates `vX.Y.Z` at the exact merge commit
- explicitly dispatches the publish workflow using the tag
- waits until the package version and GitHub Release are public

The explicit dispatch lets the repository's short-lived `GITHUB_TOKEN` trigger
the downstream workflow without a personal access token. Rerunning a failed
release-on-prep job safely reuses a matching tag, and repairs a missing GitHub
Release when the pub.dev version is already live.

The publish workflow then:

- verifies the tag matches `pubspec.yaml`
- verifies latest-compatible dependencies in the full job and lower-bound
  dependencies in a focused compatibility job
- reruns formatting, analysis, pana, all tagged real-model tests, and
  `dart pub publish --dry-run`
- publishes to pub.dev using GitHub OIDC trusted publishing
- creates a GitHub release for the tag after a successful publish
