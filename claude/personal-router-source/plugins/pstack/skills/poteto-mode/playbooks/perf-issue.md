# Perf issue

Make one known slow thing faster, such as a page, a command, or a request. Tie every change to a measurement. Do not read the source instead of measuring. Route a sustained push of one score to a target to [Hillclimb](hillclimb.md).

1. Run `worktree` before repository edits.
2. Write the claim you expect to make and the result that would change the decision. Capture a baseline on the slow user path with the project's `verify` skill. If missing, run `create-verification-skill` first. For a web page, also record a Lighthouse report and the Core Web Vitals (the page's load, response, and layout-shift scores) from a production build. Save each raw report as a file. Vet the baseline with `benchmark-checklist`.
3. Find the limiter: the resource or code path that bounds the number. Take it from a profile in a separate run, then map it to source. Use `how` when code understanding is incomplete. Do not claim a ceiling without running it.
4. Choose fixes in this order, cheapest first: do not do the work, do not do it twice, do less of it, do it later, do it when the user is not looking, do it concurrently, do it cheaper. Stop at the first one that meets the target. When a fix crosses a function boundary, run `architect` first, then write the fix against the sketch.
5. Make one change at a time under `principle-sequence-verifiable-units`. After each change, measure with the same method as step 2 and vet the number with `benchmark-checklist`. Keep a change only when the number moves past the run-to-run spread and the tests pass. Revert it otherwise.
6. Compare the before and after reports directly. An inconclusive result, or a measurement of the wrong path, is not a pass. Report it as open.
7. Run `verify` through the original user path and the affected behavior.
8. Remove unneeded comments with the [comment rules](../../../agents/comment-sicko.md), then run `deslop`. Rerun checks and verification under the recheck rule in [shared conditions](../references/shared-conditions.md). Commit the changes.
9. Run independent `code-review` against the review base. Pass the slow path, the target, and the before and after numbers as the requirements. Resolve findings. Follow the fix-round rule in [shared conditions](../references/shared-conditions.md).
10. Run [Opening a PR](opening-a-pr.md). Pass the baseline number, the final number, the change in percent, and the report paths. Keep one primary number in the PR body.

## Skill references

- [worktree](/Users/jahazelsanchez/.claude/skills/worktree/SKILL.md).
- [create-verification-skill](/Users/jahazelsanchez/.claude/skills/create-verification-skill/SKILL.md).
- [benchmark-checklist](/Users/jahazelsanchez/.claude/skills/benchmark-checklist/SKILL.md).
- [how](/Users/jahazelsanchez/.claude/skills/how/SKILL.md).
- [architect](/Users/jahazelsanchez/.claude/skills/architect/SKILL.md).
- [principle-sequence-verifiable-units](/Users/jahazelsanchez/.claude/skills/principle-sequence-verifiable-units/SKILL.md).
- [deslop](/Users/jahazelsanchez/.claude/skills/deslop/SKILL.md).
- [code-review](/Users/jahazelsanchez/.claude/skills/code-review/SKILL.md).
- [comment rules](../../../agents/comment-sicko.md).
