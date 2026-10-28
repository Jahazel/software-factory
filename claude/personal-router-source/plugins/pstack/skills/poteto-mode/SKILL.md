---
name: poteto-mode
description: Route coordinated changes across files, function interface changes, meaningful design choices, bugs with unknown causes, performance problems, and work with dependent stages through the personal playbooks. Use for poteto, /poteto-mode, or requests for this workflow.
---

# Poteto mode

## Check task size first

Inspect the request and affected files before loading additional workflow guidance. Reuse current findings. Classify the expected complete change, including needed follow-up edits.

A change is small when it touches one file, changes fewer than about 20 lines, does not change how other code calls a function, and does not touch security, privacy, money, authentication, or stored data. A docs-only change is small whatever its size.

- For a small change, continue below with the selected playbook and required shared rules. Load a referenced skill only when its step applies after the small-change exemptions. Explicit user requests and separately required skills still apply.
- For a medium or big change, an uncertain size, an unknown bug cause, or a performance investigation, read [full workflow guidance](references/full-workflow.md) before proceeding. Shared conditions define the medium and big routes. Loading full guidance does not change the size exemptions.
- Recheck the size when scope changes and inspect the actual changes before completion. Load the full guidance as soon as the small-change conditions no longer hold. Complete the newly required steps before handoff.

## Platform adaptation

On Codex, read [the tool guide](references/codex-tools.md) before following a playbook or calling a helper. On Claude Code, use available native tools and installed skill names. Resolve the current runtime's supported agent types and model names before dispatch.

Use the runtime's skill tool when available. Otherwise read the installed skill and its required references. Respect invocation settings. A skill named here is a reference to an existing skill, not a request to install another copy.

Read each router file once per task. Do not reprint router text in replies or briefs.

Read the project's instructions and use its glossary when present. Shared personal workflows apply across projects. Project code, project-specific checks, and generated verification skills belong to the affected project.

## Non-negotiables

- Follow the task's authorization and the harness's tool restrictions. A playbook cannot authorize an otherwise restricted action.
- Read [working rules](references/working-rules.md) and [shared conditions](references/shared-conditions.md) before executing a playbook. Reuse current findings and completed checks. Repeat affected checks after changes. Apply the exemptions in shared conditions before loading skills for the selected steps.
- Read the code directly by default. Run `how` only for a big change that spans several subsystems, for an architecture or ownership question that direct reading cannot settle, or when the user asks. Use existing findings when current and sufficient. A complex question needs source exploration and synthesis. Explanation does not replace independent design review.
- Observe facts before asking the user to guess. Use files and direct checks when sufficient. When a technical choice can be settled by building and measuring, such as which approach is faster or which fix keeps a behavior correct, build each option as throwaway code, measure it, choose, and report the result and its evidence in plain words. Ask the user only about taste, preferences, and product direction.
- Keep a checklist whose first items are the selected playbook's steps verbatim. Use [step tracking](references/step-tracking.md) to record completed, reused, substituted, not-applicable, and blocked steps. Add task-specific items after them. Check the record before reporting completion.
- For substantial multi-step work, record the required first steps and the smallest safe order of work.
- Verify changed behavior through its actual user path. Use the project's verification skill. If absent, use [create-verification-skill](/Users/jahazelsanchez/.claude/skills/create-verification-skill/SKILL.md), then run the generated skill. Keep evidence of the action and resulting state.
- Apply the comment rules before code review and [deslop](/Users/jahazelsanchez/.claude/skills/deslop/SKILL.md) before code commits. A PR with code changes needs independent [code-review](/Users/jahazelsanchez/.claude/skills/code-review/SKILL.md) of committed changes against the review base. Confirm that the review base resolves and that the committed difference is nonempty. Small and medium changes follow their rules in shared conditions.
- Defects found along the way: report each one with evidence and impact. Repair it in the current change only when the requested task cannot work without the repair. For a confirmed project bug, one with a repeatable failure or direct evidence, create one ticket in the tracker named in the project's `docs/agents/issue-tracker.md`. Give the evidence, the impact, and where it was found. In a public repository, keep private details out of the ticket. Without a configured tracker, list the bug in the reply. Keep a suspected bug in the reply, with no ticket. List a defect in the router or an installed skill in the reply's open items, and leave the installed files unchanged.
- Comment rules: for a medium or big change, run [no-comments](/Users/jahazelsanchez/.claude/skills/no-comments/SKILL.md) once on the change's diff before code review. It starts one fresh `comment-sicko` helper on the ordinary-work model at medium effort from [model rules](references/model-rules.md). On Claude Code, the agent type is `comment-sicko`. The main agent judges the helper's report and makes the accepted fixes. For fix-round changes, the main agent applies [the comment-review instructions](references/agents/comment-sicko.md) to the changed lines itself.

## Autonomy

Proceed with authorized reversible work. Give real judgment and push back on added scope when it does not earn its cost. Connected tools do not need a separate blanket permission gate. Messages to other people still require the task's authorization and the harness's rules.

Pause before deployments, data deletion, customer messages, or force-pushes to shared history. An instruction to continue until done does not remove these gates. For an authorized deployment, use the hosting provider's existing skill, or official documentation when no skill exists.

Keep existing code-check hooks unchanged. Their later reassessment is a separate decision.

## Helpers

The main agent does all the work itself, at every change size: reading, implementing, refactoring, and checking. It starts no helpers, with two exceptions. The comment rules start one `comment-sicko` helper through `no-comments`. The independent code review runs in the other app. Start any other helper only when the work will not fit in the main agent's context window, when independent parts can run at the same time, or when the user asks. Before starting a helper, read [full workflow guidance](references/full-workflow.md#helpers) and [model rules](references/model-rules.md).

## Playbooks

Select one playbook from the task's outcome. Open it and copy its steps to the checklist before work. For a larger task, apply the appropriate playbook to each bounded unit. When no playbook fits, explain the gap and propose a scoped plan rather than inventing an installed dependency.

| Outcome | Playbook |
| --- | --- |
| Settle an idea or open decisions before implementation. | [Planning](playbooks/planning.md). |
| Design a screen, its flow, and its motion before implementation. | [Design](playbooks/design.md). |
| Build new or changed behavior from an agreed specification. | [Feature](playbooks/feature.md). |
| Reproduce and correct a reported defect, including slowness. | [Bug fix](playbooks/bug-fix.md). |
| Answer a question from evidence without implementation. | [Investigation](playbooks/investigation.md). |
| Change structure while preserving behavior. | [Refactoring](playbooks/refactoring.md). |
| Open authorized changes for review after checks. | [Opening a PR](playbooks/opening-a-pr.md). |
| Fix or report on an open PR when the user asks. | [Babysit](playbooks/babysit.md). |

Planning, Design, and Investigation wait for the user's implementation request before changing real code. Their decision output does not itself require a PR. Implementation playbooks use Opening a PR within the task's authorization.

## Writing the reply

Apply [unslop](/Users/jahazelsanchez/.claude/skills/unslop/SKILL.md) to all writing. Use short, complete sentences with one idea each. State user impact first. Define unfamiliar terms. Use the project's vocabulary. Give evidence or label assumptions. Keep the reply content required by the selected playbook.

Keep comments for non-obvious reasons that code cannot express. Use assertions and log messages to describe checks. Report actual verification limits and open work. Link only artifacts that exist and were inspected.
