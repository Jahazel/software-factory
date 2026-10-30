# Feature

1. Run `worktree` before repository edits.
2. Reuse Planning's findings. Run `how` if the explanation is missing, outdated, or incomplete for the work. Apply the git history rule in shared conditions when it applies.
3. Run `create-verification-skill` if the project lacks `verify`.
4. Run `architect` when the change crosses a function boundary: the change alters how one part of the code calls another, or it creates code that several parts will call. Its synthesized sketch and rationale become the contract for step 5. Skip this step for a change inside one function, screen, or component.
5. Run `implement` on one ready ticket or agreed specification. The main agent runs it. It handles `tdd`, code checks, and `verify`, then leaves changes uncommitted. When step 4 ran, build against its sketch and follow its implement and scrap rules. When the ticket links a `motion.md`, build each motion row with `animate`.
6. Remove unneeded comments with the [comment rules](../references/agents/comment-sicko.md), then run `deslop`.
7. Rerun checks and verification under the recheck rule. Commit the changes.
8. Run independent `code-review` against the review base. Resolve findings. Follow the fix-round rule in [shared conditions](../references/shared-conditions.md).
9. Run [Opening a PR](opening-a-pr.md).

## Skill references

- [worktree](/Users/jahazelsanchez/.claude/skills/worktree/SKILL.md).
- [animate](/Users/jahazelsanchez/.claude/skills/animate/SKILL.md).
- [architect](/Users/jahazelsanchez/.claude/skills/architect/SKILL.md).
- [code-review](/Users/jahazelsanchez/.claude/skills/code-review/SKILL.md).
- [create-verification-skill](/Users/jahazelsanchez/.claude/skills/create-verification-skill/SKILL.md).
- [deslop](/Users/jahazelsanchez/.claude/skills/deslop/SKILL.md).
- [how](/Users/jahazelsanchez/.claude/skills/how/SKILL.md).
- [implement](/Users/jahazelsanchez/.claude/skills/implement/SKILL.md).
- [comment rules](../references/agents/comment-sicko.md).
- [tdd](/Users/jahazelsanchez/.claude/skills/tdd/SKILL.md).
