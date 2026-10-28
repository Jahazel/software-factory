# Planning

1. Run `teach` when the idea touches existing code. It runs `how` and `why` and explains in plain words what exists, how it works, and why it was built that way. Wait for the user's questions and answer them before step 2. Skip this step when the idea adds new code that touches no existing system.
2. Run `grill-with-docs` for a focused idea, or `wayfinder` for a large idea with open decisions across sessions.
3. Run `to-spec` when decisions are settled and no agreed specification exists.
4. Run `to-tickets` when the work needs several buildable tickets.
5. When the specification names Paper artboards, export each one to `docs/design/<feature>/` in the project: an image from Paper `export` with default settings, and a `.jsx` file from `get_jsx` with `includeNodeIds: false`. Land the files through [Opening a PR](opening-a-pr.md). Add a `## Design` section to each ticket that links the files for its screens, so coding sessions build from the files and leave Paper closed. Done when every ticket that changes a screen links its files.
6. Recommend the next implementation playbook under the shared handoff rule. Pass the agreed specification or ready ticket and relevant findings when the user requests implementation. That playbook runs [Opening a PR](opening-a-pr.md) after its checks and review.

## Skill references

- [grill-with-docs](/Users/jahazelsanchez/.claude/skills/grill-with-docs/SKILL.md).
- [how](/Users/jahazelsanchez/.claude/skills/how/SKILL.md).
- [teach](/Users/jahazelsanchez/.claude/skills/teach/SKILL.md).
- [to-spec](/Users/jahazelsanchez/.claude/skills/to-spec/SKILL.md).
- [to-tickets](/Users/jahazelsanchez/.claude/skills/to-tickets/SKILL.md).
- [wayfinder](/Users/jahazelsanchez/.claude/skills/wayfinder/SKILL.md).
- [why](/Users/jahazelsanchez/.claude/skills/why/SKILL.md).
