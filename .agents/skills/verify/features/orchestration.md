# Orchestration

The factory selects eligible tasks and prepares an isolated task worktree.

## Sub-features

- Planner decisions and calls.
- Conflict classification and repeated migration numbers.
- Task worktree preparation.

## How to get to it (user POV)

A caller repository invokes the reusable workflows in `.github/workflows/`.
Local fixture tests exercise the commands those workflows call.

## Driving it with Bash

Preconditions: Bash, Git, Python 3 and jq are available.
Run `for t in tests/*.sh; do bash "$t" || exit; done`.
Require every script to exit zero. Save the output and status.

## Gotchas

These fixtures do not dispatch GitHub workflows, create live issues or prove
remote credentials. Treat those paths as unverified by a local test run.
