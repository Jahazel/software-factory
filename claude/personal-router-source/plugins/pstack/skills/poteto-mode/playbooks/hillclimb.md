# Hillclimb

Push one measurable score to a target through repeated attempts. Each attempt is one change, one measurement, then keep or revert. Never stack untested changes. Never claim a win from reading code. Route a one-off speed fix to [Perf issue](perf-issue.md).

1. Run `worktree` before repository edits.
2. Choose the case and the score. Use `how` on the target when understanding is incomplete. Name the workload factors that move the score, such as data size, history, state, and concurrency. Pick a case that reproduces the user's complaint. If no case reproduces it, fix the reproduction first. Write the score, the direction that counts as better, and a stop rule that pairs a target with a minimum number of attempts, such as "at least 50% better than baseline and at least 10 attempts". Use the user's numbers when given. Otherwise agree them with the user.
3. Build one command that prints the score, under `principle-build-the-lever`. For a web page, a Lighthouse run or the project's `verify` skill can be the command. Run it on a hard case and an easy case and confirm that it tells them apart. Vet it with `benchmark-checklist`. Make it print its error count and a count of the work done, and report the median of several runs. Then freeze it: do not change it during the climb. Record the baseline score and a passing run of the tests that must keep passing.
4. Open a decision log with `show-me-your-work`: a local `decision.tsv` with one row per attempt (id, hypothesis, change, before, after, delta, tests, kept or reverted, note). Keep it out of the repository. Read it before each attempt.
5. Base each hypothesis on a named mechanism from step 2, such as "load X after first paint because it blocks first paint". For a speed score, order hypotheses by the fix order in [Perf issue](perf-issue.md) step 4.
6. Run one hypothesis per attempt under `principle-sequence-verifiable-units`. Make the change. Measure with the frozen command and run the tests. Keep the change only when the score moves past the noise and the tests pass. Otherwise revert it in full. Commit each kept change by itself and stage explicit paths. Log a row for every attempt.
7. After a stall, such as several reverts in a row, change the kind of fix, combine near misses, reread the source, or try a bolder idea before you stop. Correctness and simplicity outrank the score. Revert a win that breaks behavior. Keep a simplification that holds the score, under `principle-laziness-protocol`.
8. Stop when the stop rule is met, or when the remaining ideas cost more than they gain. Do not loosen the stop rule. Do not stop while cheap untried ideas remain. When stuck, tell the user.
9. Run `verify` through the affected user path. Remove unneeded comments with the [comment rules](../../../agents/comment-sicko.md), then run `deslop`. Rerun checks and verification under the recheck rule in [shared conditions](../references/shared-conditions.md). Commit the cleanup.
10. Run independent `code-review` against the review base. Pass the score, the target, and the decision log as the requirements. Resolve findings. Follow the fix-round rule in [shared conditions](../references/shared-conditions.md).
11. Run [Opening a PR](opening-a-pr.md) with the kept commits in the order they landed. Pass the score and target, the baseline and final scores with the change in percent, the attempts kept and reverted, each kept change in one line, the `decision.tsv` path, and the best next idea.

## Skill references

- [worktree](/Users/jahazelsanchez/.claude/skills/worktree/SKILL.md).
- [how](/Users/jahazelsanchez/.claude/skills/how/SKILL.md).
- [principle-build-the-lever](/Users/jahazelsanchez/.claude/skills/principle-build-the-lever/SKILL.md).
- [benchmark-checklist](/Users/jahazelsanchez/.claude/skills/benchmark-checklist/SKILL.md).
- [create-verification-skill](/Users/jahazelsanchez/.claude/skills/create-verification-skill/SKILL.md).
- [show-me-your-work](/Users/jahazelsanchez/.claude/skills/show-me-your-work/SKILL.md).
- [principle-sequence-verifiable-units](/Users/jahazelsanchez/.claude/skills/principle-sequence-verifiable-units/SKILL.md).
- [principle-laziness-protocol](/Users/jahazelsanchez/.claude/skills/principle-laziness-protocol/SKILL.md).
- [deslop](/Users/jahazelsanchez/.claude/skills/deslop/SKILL.md).
- [code-review](/Users/jahazelsanchez/.claude/skills/code-review/SKILL.md).
- [comment rules](../../../agents/comment-sicko.md).
