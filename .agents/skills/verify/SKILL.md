---
name: verify
description: Verify software-factory CLI behavior for bounded review rounds and orchestration rules using isolated fixtures.
---

# Factory verification

## Launch

Run from the factory repository root. Require Python 3, Bash, Git, and jq.
The commands are short-lived; no server or dependency install is needed.
Read `features/README.md` and the relevant feature recipe.

## Reuse

Each test creates isolated temporary state. Run affected recipes after behavior
changes. Reuse a passing result only for unchanged behavior at its recorded revision.

## Doctor

Run `python3 --version`, `bash --version`, `git --version`, and `jq --version`.
Check `git status --short` to identify the revision and local changes under test.

## Drive

Run `bash tests/review.sh` for the review command. It invokes the real supervisor
through its CLI with a fake external `claude` executable. It checks completed and
failed reports, warning, shared timeout, descendant cleanup, round ordering,
concurrent refusal, and interruption. Seconds are shortened for these fixtures.
Run `for t in tests/*.sh; do bash "$t" || exit; done` for all local CLI checks.

## Evidence

Save the command, output and exit status in a file outside the fixture directories,
such as `/tmp/factory-bounded-reviews/verify.log`. Read the final assertions and exit
status. The fake executable replaces the external paid model boundary only.
Local proof does not establish Claude authentication, model behavior, skill
selection, or the live GitHub Actions environment. A real issue run is needed for
those checks. Do not dispatch an issue just to claim local verification.

## Cleanup

Tests remove their temporary files and stop the processes they start. Keep the
verification log. Never kill by process name or remove another run's state.
