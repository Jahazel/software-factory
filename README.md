# software-factory
Reusable GitHub Actions software factory: label-triggered agent workers

| Path | What it is |
|---|---|
| `.github/workflows/worker.yml` | The reusable worker. Its `work` job runs the project's `.factory/setup.sh`, `.factory/smoke.sh`, and `.factory/worker-rules.md` unless the caller names other paths, and runs the agent with read-only GitHub access. Its `publish` job, on another computer, is the only one that holds `FACTORY_GITHUB_TOKEN`. |
| `.github/workflows/orchestrator.yml` | The reusable orchestrator. A project calls it when the owner adds its `trigger-label` (`agent:implement` while the owner starts each run, `ready-for-agent` once triage alone starts runs). It merges main into the open factory PRs, claims issues, runs one worker each, and always releases the claims. |
| `scripts/orchestrate.sh` | The orchestrator's fixed steps: the PR refresh, the facts for the skip rules, the planner and the cap, one decision per PR or labeled issue, and the claim. |
| `scripts/settle.sh` | Checks each resolve job's PR, releases each claim after the workers end, then starts the orchestrator again. |
| `scripts/lib.sh` | Rules the orchestrator, settle, and publish share: skip rules, the closed-PR stop, issue briefs, factory branches and PRs, open PR check, conflict classes, planner answer checks and plan decisions, the PR heading rule, repeated migration numbers, paths the factory never pushes, issue and PR blocks, resolve checks, and claim release. |
| `prompts/worker.md` | The worker prompt. The project adds its own rules file. |
| `prompts/resolve.md` | The resolve worker prompt: merge main into an open factory PR, and fix a conflict or repeated migration number the project rules allow. |
| `scripts/pack-outbox.sh` | Runs in the work job after the agent. Adds the branch's new commits to the agent's outbox as a git bundle. |
| `scripts/publish.sh` | Runs in the publish job. Checks the outbox as untrusted data, then pushes the branch, opens the PR (as a draft when the outbox asks), files the follow-ups issue, and posts comments and blocks. It refuses changes under `.github/`, symbolic links, submodules, a PR that closes another issue, a PR body whose `##` headings break the `pr` skill's order, and a push that is not this run's branch. |
| `scripts/check-pr.sh` | The agent runs it on its outbox before it stops. It runs publish's PR heading check and prints the reason publish would refuse, or that `pr.md` is missing. The worker job passes its path as `FACTORY_PR_CHECK`. |
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

## Factory PRs and stops

A factory PR is an open PR on a `factory/issue-<n>-<slug>-<run>` branch. Only the publish job pushes
`factory/` branches, so the owner's own `issue-<n>-*` branches are never refreshed or resolved. An
owner branch with an open PR still makes the orchestrator skip its issue.

When the owner closes a factory PR without merging it, the next run adds `agent:blocked` with the
comment `Factory stopped: PR #<p> was closed without merge.` and starts no worker. To retry any
blocked issue, the owner removes `agent:blocked`.

## Moving a caller to this version

The caller workflows call this repo `@main`, and `trigger-label` has no default. A caller that does
not pass it fails from the moment this version merges. Do these steps in order:

1. Wait until the project has no open PR on an `issue-<n>-` factory branch and no issue with
   `agent:in-progress`. Factory PRs from older versions use that branch name, and this version no
   longer refreshes or resolves them.
2. Merge this version, then at once merge the caller change: `trigger-label: agent:implement`, the
   `unlabeled` event for `agent:blocked`, read-only permissions for the worker and gardener jobs,
   and `workflow_dispatch` inputs for `dry-run` and `trigger-label`.
3. Start the caller's orchestrator by hand with `dry-run: true` and `trigger-label: ready-for-agent`.
   Read the summary: it lists what stage 2 would start.
4. Make a new `FACTORY_GITHUB_TOKEN`, because older agent jobs could read the old one. Keep its
   Workflows permission: a refresh pushes main's workflow changes into factory branches.
5. To start stage 2, change the caller's `trigger-label` to `ready-for-agent`.

## Factory reviews

The installer overlays `factory/skills/code-review` after the personal skills.
Refreshing `claude/` does not change the factory policy. Reviews focus on the issue
and defects introduced by its change. Unrelated discoveries stay in Open items, and
the publish job files them as one `Follow-ups from PR #<n>` issue with `ready-for-human`.

`scripts/review.py` runs the two review axes together. Each round warns at five
minutes and stops at ten minutes. A worker gets an initial round and two fix rounds.
Timeouts, failed reviewers, and serious findings left after the last round open the
PR as a draft, with a `Review not finished` section; they do not block the worker.
Like pstack's unattended runs, a worker never waits on a product question: it makes its
best guess, lists it under `Decisions to confirm`, and opens a draft PR. It blocks only
at a real dead end, such as a bug it cannot reproduce.
The small, low-risk review exemption remains. These are provisional limits based
on five measured rounds of 46–85 seconds, excluding fixing and verification.

The worker artifact retains `reviews/round-*/` with prompts, report JSON (including
reviewer token usage), errors, and elapsed time. Implementation and verification
remain in the worker transcript; the review timer does not limit those stages.
