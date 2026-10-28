# Codex tool guide

Use tools available in the current harness. This guide translates workflow names; it grants no additional authorization. Follow the harness's stricter tool requirements. A fallback must support the operation and preserve required tracking and evidence.

## Tool mapping

| Workflow action | Preferred available tool | Fallback |
| --- | --- | --- |
| Run a command. | `exec_command`. Continue a running command session with `write_stdin`. | The harness's supported command tool. |
| Read a file. | The command tool with `cat` for short files or a selected section for long files. | The harness's file-reading tool. |
| Search contents or names. | `rg` or `rg --files`. | Another available search command. |
| Edit text. | `apply_patch`, then inspect the result. | The harness's supported file-editing tool. |
| Search or read the web. | The available web tool, such as `web.run`. | `curl` or `wget` for direct retrieval when supported. Cite the pages supporting the answer. |
| Use a skill. | The harness's skill tool. | Read the installed `SKILL.md` and its required references. Respect invocation settings. |
| Start or manage helpers. | The available agent tools. In T3 Code with Codex, use `collaboration` when exposed. | Another supported agent tool. A required independent review stays incomplete when no reviewer can run. |
| Track steps. | The available task-tracking tool. | An uncommitted local checklist. Use a task-specific file when sessions share a folder. |
| Ask a question. | Concise chat by default. | An available question tool when appropriate and permitted. Required answers must arrive before dependent work proceeds. |
| Inspect a website in T3 Code. | Call `preview_status` first, then `preview_open` if no usable preview is attached. Use preview navigation, snapshots, interactions, and capture tools. | Another browser system when preview tools are absent, explicitly unavailable, or the user requests it. Correct actionable preview errors before switching. |
| Inspect a website in another harness. | Its supported browser tool. | A supported alternative browser or a concrete user-performed check. Keep a required check incomplete until its result is observed. |
| Create or update a PR. | The harness's built-in PR tool when it supports the operation. | The supported repository command-line tool. Keep a consistent provider for remaining operations. |

Keep the playbook's steps first in the checklist. Add task-specific items afterward. Keep skipped steps and reasons visible. Blocked and inconclusive required checks remain incomplete.

For browser verification, capture the actual user action and resulting state. A screenshot alone does not prove that an interaction works. For command-line or service changes, run the relevant command or request and inspect its actual output and effects.

In T3 Code, register every PR created or worked on with `link_pull_request` when exposed. Use the full URL immediately after creation or starting work on an existing PR. Before finishing, use `list_thread_pull_requests` and link missing PRs from this work. Report a linking failure. Do not claim an attachment succeeded unless the tool confirms it.

## Waiting for long tasks

Follow the shared [waiting rule](working-rules.md#waiting-for-long-tasks). With `exec_command`, use `yield_time_ms: 30000`; continue its running session with `write_stdin` and `yield_time_ms: 60000`. Match the wait on any enclosing tool call to its supported limit, up to 60 seconds.

## Helpers

Codex has no Claude `subagent_type`. Start a fresh helper through the available agent tool. For ordinary playbook delegates, give the selected playbook path and `references/working-rules.md` instead of the full router. Require `poteto-mode/SKILL.md` only when the helper must choose its own playbook. Give exact source paths, scope, current instructions, and checks. Skills with their own reviewers keep their role instructions.

Calls run concurrently where supported. There is no separate requirement for a Claude `run_in_background` flag on Codex. Follow the harness's model override and stop rules. Give concurrent writers separate files or working copies. Inspect the actual result before accepting it.

Do not translate a Claude model label directly into a Codex model identifier. Use [model rules](model-rules.md) and the validated configuration for the current harness. If `inherit-parent` or `auto` is used in an authorized configuration, omit the model override. These aliases do not replace the user's approved task-based model selection.

## Skill mappings

| Named dependency | Personal mapping |
| --- | --- |
| A `pstack:` skill call. | Resolve the corresponding installed skill by its actual name. Preserve its invocation settings. The router's intended `pstack:poteto-mode` call still requires separate registration verification. |
| `plugin-dev:skill-development`. | Use [writing-for-agents](/Users/jahazelsanchez/.claude/skills/writing-for-agents/SKILL.md) and [SKILL-MECHANICS.md](/Users/jahazelsanchez/.claude/skills/writing-for-agents/SKILL-MECHANICS.md) in both Codex and Claude Code. |
| `no-comments`' comment reviewer. | For a medium or big change, start one fresh helper on the ordinary-work model at medium effort from [model rules](model-rules.md). On Codex, the helper reads [comment-sicko](agents/comment-sicko.md) in full. On Claude Code, use the existing local `comment-sicko` agent name. Preserve the review rules. The main agent inspects the result and handles accepted code fixes. For fix-round changes, the main agent applies the instructions itself, with no helper. |
| `no-comments`' design step. | Keep the installed, approved `codebase-design` adaptation. It makes a scoped sketch and compares alternatives only when needed. Do not add `architect` as a dependency. |
| `create-verification-skill`. | Use `.agents/skills/verify/SKILL.md` on Codex and `.claude/skills/verify/SKILL.md` on Claude Code. Keep supporting files beside it. Default to the project root, or the affected package in a repository with several packages. Work from the package or a descendant for package-local discovery. |
| `code-review`. | Use the installed skill as written. |
| `implement`. | Use the installed version that leaves changes uncommitted. The calling playbook owns cleanup, committing, independent review, and PR creation. |
| `prototype`. | Use the installed location, handoff, and archive-removal adaptations. `wayfinder` calls it for prototype tickets. |
| `how`. | Keep their internal roles and use current-harness tools. Select models by the approved task and specific-role rules. Explanation does not replace independent review. |

Apply these mappings to references inside skills as well as the router. An unresolved required dependency stays blocked. Report it with evidence rather than installing or repairing unrelated helpers automatically.
