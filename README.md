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
| `tests/` | Plain bash tests for the pure rules. Run `for t in tests/*.sh; do bash "$t"; done`. |
| `claude/` | A copy of pstack, the router hook, the model rules, and the owner's skills, including shared `worktree` setup, laid out like `~/.claude`. |
| `scripts/sync-claude.sh` | Run on the owner's Mac to refresh `claude/` from `~/.claude`. |
| `scripts/install-claude.sh` | Runs on the job computer. Installs `claude/` into `~/.claude`, adds third-party skills, and turns pstack on. |
