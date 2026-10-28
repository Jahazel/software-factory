---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
---

Implement the work described by the user in the spec or tickets.

If the user passes a ticket reference, fetch it from the issue tracker and state its title before starting. If the reference is ambiguous, ask.

Before changing any code, check whether you are in a linked worktree: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` print different paths. If you are, and its branch is not the default branch (usually `main`), work there.

Otherwise, create a new worktree for the ticket and do all work inside it. Use the harness's worktree tool if it has one. If not, fetch and run `git worktree add ~/.worktrees/<repo>/<branch> -b <branch> origin/<default>`. Name the branch after the ticket, such as `issue-81-short-description`. Never switch branches in the main checkout, and never commit implementation work directly to the default branch.

Call the Skill tool with "tdd" where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

If the project has a `verify` skill, call the Skill tool with "verify" to drive the changed feature the way a user does. Fix what it finds and run it again until it passes. Save the proof it produces.

Leave the changes uncommitted. Hand them back to the caller for cleanup, committing, and code review.
