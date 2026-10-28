# Approved model rules

Use the current harness's validated `pstack-models.md` and loaded model instructions. These approved choices define task selection. They are not proof that any model identifier or effort control works in the current runtime.

| Task | Codex | Claude Code | Reasoning effort |
| --- | --- | --- | --- |
| Narrow fact collection and obvious edits. | GPT-6 Luna, intended identifier `gpt-6-luna`. | Haiku 5.5. | Medium. |
| Ordinary work, interpretation, and dependent code changes. | The user's GPT-6.1 model. | Sonnet 5.5. | Medium. |
| Hard diagnosis, design choices, and complex review. | The user's GPT-6.1 model. | Opus 5.5. | Medium. |
| Independent code review in the opposite app. | The user's GPT-6.1 model. | Opus 5.5. | High. |

Confirm exact accepted identifiers and model availability before later setup. Confirm that Claude's available Opus selection provides the approved model. Do not silently replace an unavailable selection. Use only supported model and effort controls.

For workflows explicitly requiring several models, preserve different-model review. Panel models, panel size, and treatment of reduced diversity remain deferred. Do not add a review workflow merely to exercise the diversity rule. `code-review` uses the installed skill as written. Keep other helper assignments unchanged.

## Storage and loading

Resolve the actual configuration directories at setup time. Keep a separate `pstack-models.md` in each harness's configuration directory.

- Codex copies its model rules and default effort into its global `AGENTS.md`. Keep that section synchronized with its model file. Mark the section as applying only to Codex sessions.
- Claude Code includes its own model file from its global `CLAUDE.md`.
- Preserve shared communication instructions. Claude Code must use its own model rules even when its global instructions include Codex's global file.
- The local startup hook supplies the router instruction. Keep model loading separate. Add no duplicate router pointer to global instructions.

The review package does not create model configuration, modify global instructions, register effort agents, or enable startup loading. Later setup must prove actual loading and supported reasoning controls before claiming success.
