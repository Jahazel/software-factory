# software-factory
Reusable GitHub Actions software factory: label-triggered agent workers

| Path | What it is |
|---|---|
| `.github/workflows/worker.yml` | The reusable worker job. It runs the project's `.factory/setup.sh`, `.factory/smoke.sh`, and `.factory/worker-rules.md` unless the caller names other paths. |
| `.github/workflows/orchestrator.yml` | The reusable orchestrator. A project calls it when the owner adds a label. It claims issues, runs one worker each, and always releases the claims. |
| `scripts/orchestrate.sh` | The orchestrator's fixed steps: skip rules and the cap, one decision per labeled issue, and the claim. |
| `scripts/settle.sh` | Releases each claim after the workers end, then starts the orchestrator again. |
| `scripts/lib.sh` | Label rules the orchestrator and settle share: open PR check and claim release. |
| `prompts/worker.md` | The worker prompt. The project adds its own rules file. |
| `scripts/prepare-issue.sh` | Writes the issue file the worker reads and makes the issue branch. |
| `claude/` | A copy of pstack, the router hook, the model rules, and the owner's skills, laid out like `~/.claude`. |
| `scripts/sync-claude.sh` | Run on the owner's Mac to refresh `claude/` from `~/.claude`. |
| `scripts/install-claude.sh` | Runs on the job computer. Installs `claude/` into `~/.claude`, adds third-party skills, and turns pstack on. |
