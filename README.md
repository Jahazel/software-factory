# software-factory
Reusable GitHub Actions software factory: label-triggered agent workers

| Path | What it is |
|---|---|
| `.github/workflows/worker.yml` | The reusable worker job. It runs the project's `.factory/setup.sh`, `.factory/smoke.sh`, and `.factory/worker-rules.md` unless the caller names other paths. |
| `.github/workflows/orchestrator.yml` | The reusable orchestrator. A project calls it when the owner adds a label. It merges main into the open factory PRs, claims issues, runs one worker each, and always releases the claims. |
| `scripts/orchestrate.sh` | The orchestrator's fixed steps: the PR refresh, skip rules, the planner and the cap, one decision per PR or labeled issue, and the claim. |
| `scripts/settle.sh` | Checks each resolve job's PR, releases each claim after the workers end, then starts the orchestrator again. |
| `scripts/lib.sh` | Rules the orchestrator and settle share: issue briefs, factory PRs, open PR check, conflict classes, planner answer checks and plan decisions, repeated migration numbers, PR blocks, resolve checks, and claim release. |
| `prompts/worker.md` | The worker prompt. The project adds its own rules file. |
| `prompts/resolve.md` | The resolve worker prompt: merge main into an open factory PR, fix a conflict or repeated migration number the project rules allow, push. |
| `prompts/planner.md`, `prompts/planner.schema.json` | The planner prompt and its answer shape: which candidate issues to hold because they would change the same files as work in flight. |
| `prompts/merge-main.md` | The "Merge the newest main" steps that both prompts include. |
| `scripts/prepare-issue.sh` | Writes the issue file and prepares the task's branch and linked worktree before project setup. |
| `.github/workflows/gardener.yml` | The reusable weekly gardener. A project calls it on a schedule. It opens a `Gardening report <date>` issue, then runs one worker with `prompts/gardener.md` on that issue. |
| `scripts/gardener.sh` | The gardener's fixed steps: run only on the cron that matches the local hour, find the window, and open the report issue. |
| `prompts/gardener.md` | The gardener prompt: read the merged PRs and their `Review findings`, block the worst repeated pattern in at most one PR, file up to three refactor ideas, and write the report. |
| `tests/` | Plain bash tests for the pure rules. Run `for t in tests/*.sh; do bash "$t"; done`. |
| `claude/` | A copy of pstack, the router hook, the model rules, and the owner's skills, including shared `worktree` setup, laid out like `~/.claude`. |
| `scripts/sync-claude.sh` | Run on the owner's Mac to refresh `claude/` from `~/.claude`. |
| `scripts/install-claude.sh` | Runs on the job computer. Installs `claude/` into `~/.claude`, adds third-party skills, and turns pstack on. |

## Factory reviews

The installer overlays `factory/skills/code-review` after the personal skills.
Refreshing `claude/` does not change the factory policy. Reviews focus on the issue
and defects introduced by its change. Unrelated discoveries stay in Open items.

`scripts/review.py` runs the two review axes together. Each round warns at five
minutes and stops at ten minutes. A worker gets an initial round and one fix round.
Timeouts, failed reviewers, and remaining serious findings block the worker.
The small, low-risk review exemption remains. These are provisional limits based
on five measured rounds of 46–85 seconds, excluding fixing and verification.

The worker artifact retains `reviews/round-*/` with prompts, report JSON (including
reviewer token usage), errors, and elapsed time. Implementation and verification
remain in the worker transcript; the review timer does not limit those stages.
