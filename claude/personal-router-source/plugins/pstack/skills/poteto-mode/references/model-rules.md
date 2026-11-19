# Approved model rules

Use the current harness's validated `pstack-models.md` and loaded model instructions. These approved choices define task selection. They are not proof that any model identifier or effort control works in the current runtime.

| Task | Claude Code | Reasoning effort |
| --- | --- | --- |
| Narrow fact collection and obvious edits. | Haiku 5.5. | Medium. |
| Ordinary work, interpretation, and dependent code changes. | Sonnet 5.5. | Medium. |
| Hard diagnosis, design choices, and complex review. | Opus 5.5. | Medium. |
| Independent code review in a separate Claude Code process. | Opus 5.5. | High. |

Confirm exact accepted identifiers and model availability before later setup. Confirm that Claude's available Opus selection provides the approved model. Do not silently replace an unavailable selection. Use only supported model and effort controls.

For workflows explicitly requiring several models, preserve different-model review. Panel models, panel size, and treatment of reduced diversity remain deferred. Do not add a review workflow merely to exercise the diversity rule. `code-review` uses the installed skill as written. Keep other helper assignments unchanged.

## Storage and loading

Resolve the actual configuration directory at setup time. Keep `pstack-models.md` in Claude Code's configuration directory.

- Claude Code includes its own model file from its global `CLAUDE.md`.
- Preserve shared communication instructions.
- The local startup hook supplies the router instruction. Keep model loading separate. Add no duplicate router pointer to global instructions.

The review package does not create model configuration, modify global instructions, register effort agents, or enable startup loading. Later setup must prove actual loading and supported reasoning controls before claiming success.
