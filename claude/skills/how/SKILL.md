---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models."
---

# How

On Codex, read the [platform mapping](../poteto-mode/references/codex-tools.md), including its per-skill notes, before following this skill.

On GitHub Copilot, read the [platform mapping](../poteto-mode/references/copilot-tools.md), including its per-skill notes, before following this skill.

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

## Step 1. Assess complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (one module, a small utility, or a narrow question): read the relevant source and explain it.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, or a full architectural overview): identify the main parts, read each part, and explain how they fit together.

The main agent explores and writes the explanation. Start a helper only when the context window is nearly full or the user asks for a helper. Use one read-only helper for one distinct angle, then write the explanation yourself. Start more helpers only when the user asks for them. Do not start a separate synthesizer.

When a helper is needed, use the `how explainer` model from [Models](#models). Set `model` to that role's value from `pstack-models.md`, or to the default if the sheet or role is missing. Leave `model` unset when the value is `auto` or `inherit-parent`. If the tool rejects a slug, use the default and say so. If it rejects the default, use the closest valid slug of the same family from its error message.

## Step 2. Explain

Use `references/explainer-prompt.md` as the response outline. Read the code and supporting evidence yourself. Give enough context to build a working mental model, without turning the answer into annotated source code.

## Step 3. Present

Present the explanation. Keep the project's terms and name the files and runtime steps that answer the question.

## Output Format

The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.

## Models

Role defaults, stamped from `plugins/pstack/models.json` (edit there, rerun `tools/generate.mjs`). A matching role line in the `pstack-models.md` override sheet overrides each at runtime; `/setup-pstack` writes it and lists its path per runtime.

- how explorer: `opus`
- how explainer: `opus`

## Reasoning effort

A role value in the override sheet may name a reasoning effort after its model, as in `opus @xhigh`. Levels on Claude Code: `low`, `medium`, `high`, `xhigh`, `max`. Which ones apply depends on the model. A value without `@` takes the sheet's `default effort` line, a level or `session`, and `session` when the sheet has no such line. `session` sets no effort, so the dispatch is the usual one. Strip the suffix before reading the model: `inherit-parent` or `auto` still omits `model` at every level, and a model name is passed as `model`. On Claude Code, a level picks the effort agent from the `subagent_type` you would otherwise use. `pstack:poteto-agent` becomes `subagent_type: "pstack:poteto-agent-<level>"`. `general-purpose`, or no `subagent_type`, becomes `subagent_type: "pstack:effort-<level>"`. The effort agents set only `effort`, so the model you pass still decides the model. On Codex, pass the level as `spawn_agent`'s `reasoning_effort` and keep the usual instructions.
