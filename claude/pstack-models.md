# Personal router model rules

default effort: medium

Apply these rules only in Claude Code sessions. Select helpers by task. Use high effort for code review. Use medium effort for all other tasks. Never use xhigh or max effort.

Narrow helpers: model=haiku (Haiku 5.5), effort=medium.
Ordinary helpers: model=sonnet (Sonnet 5.5), effort=medium.
Hard helpers: model=claude-opus-5-5, effort=medium.

Run `code-review` as the installed skill describes. `architect` and `arena` use pstack's default panel: one runner each on `opus`, `fable`, `sonnet`, and `haiku`, and a cross-judge chosen from the same four, all at medium effort. Other multi-model panel choices and sizes remain deferred. Do not substitute a model silently. If the required model or effort cannot run, keep the required work incomplete.

Session startup supplies the router instruction separately. This file does not register a skill, enable a hook, or change a running session's settings.

On Claude Code 2.1.300, pass explicit model and effort on each non-fork helper invocation. Confirm the Agent tool schema in that session. If it rejects the exact Opus ID, do not silently use an alias without checking its actual model. CLAUDE_CODE_EFFORT_LEVEL can override per-call effort. Keep Codex-only model instructions out of Claude selection even when shared instructions include them.
