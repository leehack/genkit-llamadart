# CI selection

Known root prose files skip both test suites and the lower-bound job's
Flutter/dependency setup. Latest-compatible dependency resolution, formatting,
analysis, Pana and publish dry-run still run. All other inputs retain both
latest-compatible and lower-bound coverage, including the real-model suite.
Only superseded PR runs are cancelled; main pushes remain independent.

Only pull requests are narrowed; main pushes and manual runs (where supported)
keep full validation. The selector compares the PR merge base with its head,
counts both sides of renames and deletions, and keeps all checks for empty or
unavailable diffs. Existing jobs always start and report their original status
names; unselected steps are skipped, while selected failures/cancellation retain
normal GitHub Actions job results. No separate aggregate is needed.

Run the selector regression checks with:

```sh
python3 -B -m unittest discover -s .github -p 'test_select_ci.py'
```

Update the selection rules and dependency cases when adding packages or changing
example dependencies. Savings from narrowed PRs are projections until observed
in hosted runs; full-input PRs intentionally retain the existing work.
