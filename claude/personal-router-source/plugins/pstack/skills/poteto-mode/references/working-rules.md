# Working rules

- Give real judgment. Disagree or decline added scope with reasons.
- Proceed with authorized local edits, available connected tools, ticket updates, and team chat. Pause before deploys, data deletion, customer messages, and force-pushes to shared history. A force-push replaces shared version history. "Run until done" keeps work going but does not remove these pause gates. Messages to other people require task authorization and the harness's rules.
- Connected-account use and public-information checks need no separate blanket permission gate. Follow task authorization and the harness's rules.
- The main agent does all the work itself, at every change size: reading, implementing, refactoring, and checking. It starts no helpers, with two exceptions. The comment rules start one `comment-sicko` helper through `no-comments`. The independent code review runs in a separate Claude Code process. Start any other helper only when the work will not fit in the main agent's context window, when independent parts can run at the same time, or when the user asks. See [full workflow guidance](full-workflow.md#helpers).
- The main agent owns helper and reviewer results. Inspect the actual change or result and write its own summary. Do not forward an unverified report. Wait for a reviewer to exit before reading its output; do not read its output file while it runs.
- A required independent review stays blocked if no reviewer can run. Keep results from reviewers that did run. The reviewer must not have written the change. Self-review, tests, and automated build checks do not replace the independent verdict. Keep merging and shipping closed. Continue independent work.
- Write short, complete replies with user impact first. Give evidence or label an inference or guess. Do not invent links. Keep useful tables and plain terms.
- Keep comments only for a non-obvious reason the code cannot show. Let assertions and log strings describe script checks. Do not add comments that narrate phases.
- Start the checklist with the selected custom playbook's steps, before task-specific items. Keep skipped steps visible with a reason. A required blocked check cannot become a skip to claim a pass.
- Investigate observable facts before asking the user to guess. Files and direct checks are sufficient when they answer the question. When a technical choice can be settled by building and measuring, such as which approach is faster or which fix keeps a behavior correct, build each option as throwaway code, measure it, choose, and report the result and its evidence in plain words. Ask the user only about taste, preferences, and product direction. Respect permission limits.
- The main agent answers code questions by reading the source. In `how`, start a helper only when the context window is nearly full or the user asks. A complex question still needs source exploration and synthesis, done by the main agent. Explanation does not replace independent design review.
- Assess automated review comments from current evidence. Fix, dismiss with reasons, or ask. Check observable claims before questions. Use caution for new, unclear, serious, security, privacy, money, or data findings. Actions remain subject to authorization.
- For substantial multi-step work, record the required first steps and the smallest safe order of work.

## Keeping tool output focused

Filter results inside the tool before returning them to the model.

- Locate relevant code with a scoped search, then read that section and enough surrounding context to understand it. Read short files in full when useful. Follow mandatory reading instructions.
- For noisy commands, save full logs in a task-local file. Return failures, final totals, the log path, and the command's exit status. Preserve the original exit status when redirecting or filtering output.
- Search tool names and descriptions for the needed capability. Return matching names first; read the chosen tool's schema before calling it.
- For structured results, select the fields needed for the next decision. Return one representation instead of duplicating text, structured data, and images. Keep visual evidence when the task needs it.

If output is truncated or insufficient, narrow the query or read more from the saved result. Expand to full output when needed to diagnose the cause or verify the result.

## Waiting for long tasks

For tests, builds, deployments, and other tasks that run without input, start one command or watcher that waits for completion. The watcher can check an external service without returning to the model each time. Reuse the running task until it finishes.

Use the longest supported wait up to 60 seconds per tool call, including enclosing tool calls. In Claude Code, use the command tool's supported foreground wait or blocking task-output wait. In Codex, use the wait settings in [the tool guide](codex-tools.md#waiting-for-long-tasks). Return changed status, errors, or the final result. Keep user progress updates within 60 seconds during ongoing work.

Use shorter waits when the task needs input or the output requires immediate action. A wait limit controls when the tool returns; it does not establish that the task failed. Confirm the final exit status before reporting success.
