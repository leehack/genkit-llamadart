# Contributing

Thanks for improving `genkit_llamadart`.

## Local Setup

```bash
dart pub get
```

Make sure the native `llamadart` prerequisites for your platform are installed.
For runtime setup and platform notes, see https://llamadart.leehack.com/.

## Project Layout

See [ARCHITECTURE.md](ARCHITECTURE.md) for package layering and the matching
test layout. End-user guides live under `doc/`; README is the pub.dev entrypoint.

## Code and Documentation

- Keep ordinary code comments for non-obvious constraints, compatibility or
  safety decisions. Avoid narrating assignments, loops or assertions.
- Write Dartdoc for every exported API, including constructors, fields, enum
  values and methods. Explain defaults, ownership, accepted inputs, errors and
  platform differences when they matter; do not repeat the signature.
- Keep README focused on installation, the first successful request, feature
  requirements and navigation. Put detailed guidance under `doc/` and runnable
  examples under `example/`.
- Update affected package skills with public API changes. Compile documentation
  examples and run `dart doc --dry-run` before claiming docs are ready.

## Testing Conventions

- mirror `lib/src/` under `test/`
- keep each test file focused on one behavior or a tightly related lifecycle
- group related cases when they benefit from shared setup
- place shared helpers in a nearby `test_support/` directory
- prefer unit tests first, then Genkit integration tests, then real-model smoke tests
- Test an observable contract or a plausible failure: conversion, request
  routing, unsupported input, resource ownership, cancellation or telemetry.
  A test should fail if that behavior is removed or miswired.
- Do not test constructor field assignments or Dart's static type system.
  Remove duplicate tests when the same assertion is covered through a stronger
  production path; preserve that assertion in the retained test.
- Keep tiny real-model tests for native integration, parsing and measurements
  that fakes cannot establish. Share assertions with existing model sessions
  instead of repeatedly loading a model just to assert nonempty output.
- Use coverage to find untested risks, not as a reason to add execution-only
  tests. Test unsupported/version-skew branches when the feature depends on
  runtime capabilities.

## Agent Skills

`skills/` is published to consumers' coding agents. A public API or behavior
change updates the affected `SKILL.md` in the same PR;
`test/tooling/package_documentation_test.dart` validates skill metadata and analyzes Dart
examples from README, guides and skills in one analyzer run.

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

Optional native LiteRT media qualification uses a locally supplied multimodal
bundle and fixtures; it does not download a large model in default CI:

```bash
LLAMADART_INTEGRATION_LITERT_MODEL_PATH=/models/gemma-4-E2B-it.litertlm \
LLAMADART_INTEGRATION_LITERT_IMAGE_PATH=/fixtures/image.png \
LLAMADART_INTEGRATION_LITERT_AUDIO_PATH=/fixtures/audio.wav \
dart test test/integration/genkit/plugin/real_litert_capabilities_test.dart
```

Use a bundle with confirmed built-in image and audio encoders, a valid PNG and
16 kHz mono PCM WAV. The test exercises CPU text, image and audio generation
without a projector, and unsupported strict JSON and embedding requests. Native
runtime setup follows llamadart's platform instructions. For a standalone Dart
validation override, point `LLAMADART_LITERT_LM_LIB_DIR` to the verified pinned
runtime bundle; llamadart 0.11.1 uses `litert-lm-native` v0.17.0-8.
Without these three fixture paths this targeted test is explicitly skipped.
Browser tests of the adapter guards use deterministic runtimes and can run with
`dart test -p chrome test/integration/genkit/plugin/runtime_capabilities_test.dart`;
they validate Web guards, not real Web inference or deployment.

## Test Models

The default auto-downloaded models are intentionally tiny and CPU-friendly:

- chat: `SmolLM2-135M-Instruct-Q2_K.gguf` (~88 MB)
- embeddings: `jina-embeddings-v2-small-en-Q2_K.gguf` (~20 MB)

They are meant for smoke testing package behavior, not for judging output
quality. See [ARCHITECTURE.md](ARCHITECTURE.md#real-model-smoke-tests) for
their sources and verification.

### Real tool-model qualification

Run this optional production Genkit tool-loop qualification before releasing
tool-adapter changes:

```bash
LLAMADART_AUTO_DOWNLOAD_TOOL_MODEL=1 \
dart test test/integration/genkit/plugin/real_model_tool_calling_test.dart -j 1
```

This separate opt-in downloads Qwen3-1.7B-Q4_K_M (~1.1 GB), not the default tiny
CI fixtures. Revision `d7f544eead698dbd1f15126ef60b45a1e1933222` and SHA-256
`b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897`
are verified before loading, including local paths supplied through
`LLAMADART_INTEGRATION_TOOL_MODEL_PATH`. The test uses native llama.cpp CPU,
4096-token context, greedy sampling and seed 42. Record OS/architecture,
resolved llamadart version, native artifact and result in PR/release evidence.

The model must request a real tool, receive its result through Genkit, and
return the verification code supplied only by the handler. It covers `auto`,
`required`, `none`, truncation, cancellation and recovery. Genkit 1.0 retains
`required` on every turn, so explicit application middleware switches to `none`
after the tool result to permit a final answer. Adapter semantics are unchanged.

Malformed and disallowed calls use deterministic negative fixtures through
`Genkit.generate` in `rejects_invalid_tool_calls_test.dart`; no handler may run.
Streamed deltas may be incomplete, but final calls must have valid object
arguments and must not be token-limited. With `toolChoice.none`, inline
tool-looking text stays inert. This native run does not qualify Web/mobile.

The default real-model suite skips this fixture unless its own opt-in/path is
supplied. It is discoverable through the `tool-model` tag.


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
Release when the pub.dev version is already live. Matching lightweight and
annotated tags are accepted; a tag pointing at another commit is rejected.
An active publish run for the same tag is allowed to finish before a retry
attempts another dispatch. Release runs are serialized per PR and publish runs
per tag, so an ordinary PR cannot displace a queued release.

Lookup errors stop automation: only HTTP 404 means a release surface is absent.
Authentication, rate-limit, network, and server errors require investigation
before retrying. Polling settings are checked before tag creation or dispatch.
A failed workflow dispatch can be retried after fixing its
cause; the matching tag is reused. The workflow still requires both public
release surfaces before reporting success.

The release-gate replay tests run the workflow's actual shell snippets against
fake external commands. Run them with:

```bash
python3 -B -m unittest discover -s .github -p 'test_*.py'
actionlint .github/workflows/*.yml
shellcheck -s bash .github/release_helpers.sh
```

These tests do not create tags or publish packages. Verify GitHub token dispatch
and pub.dev OIDC in the actual approved release workflow.

The publish workflow then:

- verifies the tag matches `pubspec.yaml`
- verifies latest-compatible dependencies in the full job and lower-bound
  dependencies in a focused compatibility job
- reruns formatting, analysis, pana, all tagged real-model tests, and
  `dart pub publish --dry-run`
- publishes to pub.dev using GitHub OIDC trusted publishing
- creates a GitHub release for the tag after a successful publish
