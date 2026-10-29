# Refactoring

Change structure without changing behavior. Route added behavior to Feature and corrected behavior to Bug fix. Report unrelated defects separately. Include a repair when the requested task cannot work without it.

1. Run `worktree` before repository edits.
2. Choose one structural goal. The agent may use `improve-codebase-architecture` when the goal is broad or unclear. The user chooses the candidate. Reuse current findings. The skill handles `codebase-design`, `grilling`, and relevant domain documentation internally.
3. Capture current behavior. Reuse suitable passing tests and `how` findings. Run `how` when understanding is incomplete. Add missing behavior checks before structural edits. Type and lint checks alone are insufficient. Apply the git history rule in shared conditions.
4. Reuse an agreed design. Use `codebase-design` directly when structural choices need work. Apply `principle-model-the-domain`. Compare alternatives only when the choice is unclear, disputed, or has meaningful tradeoffs.
5. Remove unnecessary code first with `principle-subtract-before-you-add` and `principle-laziness-protocol`. Make small changes and check each one. The main agent does the refactoring, with exact file scope, the agreed design, and behavior checks.
6. When replacing an internal interface, migrate callers and remove the old path in the same wave where compatibility permits. Apply `principle-migrate-callers-then-delete-legacy-apis`. Check renames in code, strings, documentation, and back-references. Report discovered bugs and missing features separately. Changes that add behavior go to Feature.
7. Run project `verify` through affected user paths. Use `create-verification-skill` first if needed. For broad changes, also replay the same inputs against old and new behavior and compare results and affected side effects.
8. Remove unneeded comments with the [comment rules](../references/agents/comment-sicko.md), then run `deslop`. Rerun checks and verification under the recheck rule in [shared conditions](../references/shared-conditions.md). Apply `principle-minimize-reader-load`: name where readers trace fewer calls or track less changing state. Name where the change makes the code easier to understand. Revert structural changes that provide no such benefit.
9. Save evidence and make small, ordered commits within task authorization. Run independent `code-review` against the review base with the structural goal and preserved behavior as requirements. Resolve findings. Follow the fix-round rule in [shared conditions](../references/shared-conditions.md).
10. Run [Opening a PR](opening-a-pr.md). Pass the structural change, preserved behavior, comparison evidence, readability benefit, and reverted work.

## Skill references

- [worktree](/Users/jahazelsanchez/.claude/skills/worktree/SKILL.md).
- [code-review](/Users/jahazelsanchez/.claude/skills/code-review/SKILL.md).
- [codebase-design](/Users/jahazelsanchez/.claude/skills/codebase-design/SKILL.md).
- [create-verification-skill](/Users/jahazelsanchez/.claude/skills/create-verification-skill/SKILL.md).
- [deslop](/Users/jahazelsanchez/.claude/skills/deslop/SKILL.md).
- [grilling](/Users/jahazelsanchez/.claude/skills/grilling/SKILL.md).
- [how](/Users/jahazelsanchez/.claude/skills/how/SKILL.md).
- [improve-codebase-architecture](/Users/jahazelsanchez/.claude/skills/improve-codebase-architecture/SKILL.md).
- [comment rules](../references/agents/comment-sicko.md).
- [principle-laziness-protocol](/Users/jahazelsanchez/.claude/skills/principle-laziness-protocol/SKILL.md).
- [principle-migrate-callers-then-delete-legacy-apis](/Users/jahazelsanchez/.claude/skills/principle-migrate-callers-then-delete-legacy-apis/SKILL.md).
- [principle-minimize-reader-load](/Users/jahazelsanchez/.claude/skills/principle-minimize-reader-load/SKILL.md).
- [principle-model-the-domain](/Users/jahazelsanchez/.claude/skills/principle-model-the-domain/SKILL.md).
- [principle-subtract-before-you-add](/Users/jahazelsanchez/.claude/skills/principle-subtract-before-you-add/SKILL.md).
