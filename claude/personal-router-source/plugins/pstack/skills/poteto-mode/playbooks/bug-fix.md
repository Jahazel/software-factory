# Bug fix

1. Run `diagnosing-bugs`. It reproduces the failure, investigates the cause, fixes it, adds a suitable regression test, and removes temporary debugging code. During diagnosis, use `how` if code understanding is needed. Use `git log` and `git blame` when historical decisions constrain the fix. Establish the repeatable failure before investigating causes. When the cause is confirmed and the fix crosses a function boundary (the change alters how one part of the code calls another, or it creates code that several parts will call), run `architect` on the fix before writing it. Then write the fix and its regression test against the sketch.
2. Run `verify` through the original user path and affected behavior. If missing, run `create-verification-skill` first.
3. Remove unneeded comments with the [comment rules](../references/agents/comment-sicko.md), then run `deslop`.
4. Rerun the original reproduction. Rerun checks and verification under the recheck rule in [shared conditions](../references/shared-conditions.md). Commit the changes.
5. Run independent `code-review` against the review base. Pass the bug report and reproduction evidence as the requirements. Resolve findings. Follow the fix-round rule in [shared conditions](../references/shared-conditions.md).
6. Run [Opening a PR](opening-a-pr.md). Pass the cause and failing and passing evidence.

## Skill references

- [architect](/Users/jahazelsanchez/.claude/skills/architect/SKILL.md).
- [code-review](/Users/jahazelsanchez/.claude/skills/code-review/SKILL.md).
- [create-verification-skill](/Users/jahazelsanchez/.claude/skills/create-verification-skill/SKILL.md).
- [deslop](/Users/jahazelsanchez/.claude/skills/deslop/SKILL.md).
- [diagnosing-bugs](/Users/jahazelsanchez/.claude/skills/diagnosing-bugs/SKILL.md).
- [how](/Users/jahazelsanchez/.claude/skills/how/SKILL.md).
- [comment rules](../references/agents/comment-sicko.md).
