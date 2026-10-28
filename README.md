# software-factory
Reusable GitHub Actions software factory: label-triggered agent workers

| Path | What it is |
|---|---|
| `.github/workflows/worker.yml` | The reusable worker job. A project calls it with its own setup and proof scripts. |
| `claude/` | A copy of pstack, the router hook, the model rules, and the owner's skills, laid out like `~/.claude`. |
| `scripts/sync-claude.sh` | Run on the owner's Mac to refresh `claude/` from `~/.claude`. |
| `scripts/install-claude.sh` | Runs on the job computer. Installs `claude/` into `~/.claude`, adds third-party skills, and turns pstack on. |
