---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
---

Implement the work described by the user in the spec or tickets.

If the user passes a ticket reference, fetch it from the issue tracker and state its title before starting. If the reference is ambiguous, ask.

Run [worktree](/Users/jahazelsanchez/.claude/skills/worktree/SKILL.md) before repository edits.

Call the Skill tool with "tdd" where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

If the project has a `verify` skill, call the Skill tool with "verify" to drive the changed feature the way a user does. Fix what it finds and run it again until it passes. Save the proof it produces.

Leave the changes uncommitted. Hand them back to the caller for cleanup, committing, and code review.
