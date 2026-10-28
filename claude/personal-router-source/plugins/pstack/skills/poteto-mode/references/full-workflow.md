# Full workflow guidance

Read this file when the entrypoint requires the full route or before starting a helper. Continue with the playbook selected in [the entrypoint](../SKILL.md).

## Principles

Read the full leaf skill for each principle you apply. Name the principle and the decision it changed. Cite only leaf files read in this session. Apply the approved scope and compatibility conditions even when an upstream principle is broader.

| Condition | Principle and application |
| --- | --- |
| Size a change or consider more abstraction. | [Laziness protocol](/Users/jahazelsanchez/.claude/skills/principle-laziness-protocol/SKILL.md). Make the smallest complete change that solves and verifies the task. |
| Write stateful logic or repeat shape assumptions. | [Model the domain](/Users/jahazelsanchez/.claude/skills/principle-model-the-domain/SKILL.md). Confirm the data structure first. Keep a clear existing structure. |
| Integrate a new requirement. | [Redesign from first principles](/Users/jahazelsanchez/.claude/skills/principle-redesign-from-first-principles/SKILL.md). Treat the requirement as foundational within the task's scope. |
| Sequence an addition or refactor. | [Subtract before you add](/Users/jahazelsanchez/.claude/skills/principle-subtract-before-you-add/SKILL.md). Remove unnecessary complexity in scope first. |
| Code is hard to trace. | [Minimize reader load](/Users/jahazelsanchez/.claude/skills/principle-minimize-reader-load/SKILL.md). Remove unhelpful layers and keep changing state local. |
| Handle external data or framework adapters. | [Boundary discipline](/Users/jahazelsanchez/.claude/skills/principle-boundary-discipline/SKILL.md). Validate at system boundaries and keep business logic separate. |
| Design types or signatures. | [Type system discipline](/Users/jahazelsanchez/.claude/skills/principle-type-system-discipline/SKILL.md). Prevent invalid combinations and derive types from authoritative sources. |
| An operation can retry or restart. | [Make operations idempotent](/Users/jahazelsanchez/.claude/skills/principle-make-operations-idempotent/SKILL.md). Recover partial state and avoid duplicate effects. |
| Replace an internal interface. | [Migrate callers then delete legacy APIs](/Users/jahazelsanchez/.claude/skills/principle-migrate-callers-then-delete-legacy-apis/SKILL.md). Migrate and remove together where compatibility permits. |
| Concurrent actors might write the same target. | [Separate before serializing shared state](/Users/jahazelsanchez/.claude/skills/principle-separate-before-serializing-shared-state/SKILL.md). Separate write targets first; enforce one writer where sharing is necessary. |
| Diagnose a bug. | [Fix root causes](/Users/jahazelsanchez/.claude/skills/principle-fix-root-causes/SKILL.md). Reproduce first and fix the cause within task scope. Keep `diagnosing-bugs` as the workflow. |
| Context fills with large outputs, long files, or repeated reads. | [Guard the context window](/Users/jahazelsanchez/.claude/skills/principle-guard-the-context-window/SKILL.md). Keep raw output out of the main thread under the focused-output rules in [working rules](working-rules.md). Do not start helpers for this. |
| Trust, report, or act on a measured number. | [Explain the number](/Users/jahazelsanchez/.claude/skills/principle-explain-the-number/SKILL.md). Name what limits the number and rule out other causes. Report the run count and spread with it. |
| The same edit, check, or analysis repeats in more than about five places, or a check must be rerun to be trusted. | [Build the lever](/Users/jahazelsanchez/.claude/skills/principle-build-the-lever/SKILL.md). Write the smallest script, codemod, or generator that does or checks the work. Make a few edits by hand when a reviewer can check them in the diff. |
| A correction or lesson repeats. | [Encode lessons in structure](/Users/jahazelsanchez/.claude/skills/principle-encode-lessons-in-structure/SKILL.md). Use an automatic rule when practical. Follow the workspace's durable-knowledge workflow for notes. |
| Face a new kind of UI interaction or architecture decision with no example in the codebase. | [Exhaust the design space](/Users/jahazelsanchez/.claude/skills/principle-exhaust-the-design-space/SKILL.md). Compare two or three competing options before committing. `architect` does this through `arena`. |
| Choose core types and data structures, or order groundwork against feature work. | [Foundational thinking](/Users/jahazelsanchez/.claude/skills/principle-foundational-thinking/SKILL.md). Get the data shape right before logic, and build shared groundwork first. |
| Run a planned rewrite or migration with explicit phase boundaries. | [Outcome-oriented execution](/Users/jahazelsanchez/.claude/skills/principle-outcome-oriented-execution/SKILL.md). Aim for the end state; planned, scoped, reversible breakage between phases is acceptable. Verify fully at the end. |

## Helpers

The main agent does all the work itself, at every change size: reading, implementing, refactoring, and checking. It starts no helpers, with two exceptions. The comment rules start one `comment-sicko` helper through `no-comments`. The independent code review runs in the other app. Start any other helper only when the work will not fit in the main agent's context window, when independent parts can run at the same time, or when the user asks.

When a helper runs, give it a short brief: the task, source paths, exact write scope, and the full current instructions. Run it in the background and continue independent work. Stop an abandoned helper and confirm that it stopped. The main agent inspects the actual result and writes its own summary. Read [model rules](model-rules.md) before choosing models or reasoning effort.

A required independent review stays incomplete when no independent reviewer can run. Keep any completed reviewer results. Self-review and passing automated checks do not replace the independent verdict. Keep merging and shipping closed. Continue work that does not depend on the review.

## Models and reasoning effort

Use [the approved model rules](model-rules.md). The runtime's validated `pstack-models.md` and loaded global rules supply model identifiers during later setup. Keep task-based selection.

Use high reasoning effort for independent code review. Use medium for all other tasks. Do not use xhigh or max. Confirm model and effort support before dispatch. A missing or unsupported model does not justify reporting a required review as complete.

