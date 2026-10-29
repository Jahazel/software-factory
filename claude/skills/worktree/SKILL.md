---
name: worktree
description: Prepare or reuse a task branch and Git worktree before editing repository files, including code, documentation, configuration, and tests. Use when a playbook requires an isolated working folder or before starting repository edits.
---

# Worktree

Use one branch and worktree per task. A worktree is a separate working folder for the same Git repository. Read-only work and scratch files outside a repository need no worktree. Files outside Git repositories stay in their existing locations.

## Launch another task

When the harness binds a new thread to its working folder at launch, apply the branch, base, and ownership rules below to its worktree launch options. Let the harness create and bind the folder. Keep checkout creation commands out of the task prompt. The new agent verifies and reuses the prepared folder through this skill.

## Prepare the task folder

1. Read the repository instructions. Inspect `git status --short`, the current branch, `git rev-parse --show-toplevel`, `git rev-parse --git-dir`, `git rev-parse --git-common-dir`, and `git worktree list --porcelain`. Different Git directory and common directory paths identify a linked worktree. Identify which branch belongs to this task from the request and existing work. For an existing pull request, use its head branch.
2. Reuse a linked worktree when its non-default branch belongs to this task. Confirm ownership from the task context; an arbitrary linked worktree is not enough. If the task branch already has a linked worktree, use that folder. Repeat calls from nested playbooks reuse it. Keep the branch name of an existing pull request.
3. Otherwise, choose a descriptive task branch, such as `issue-81-short-description`, `docs-<topic>`, or the branch name supplied by the playbook. Use the harness's worktree operation when available. Otherwise, use `git worktree add <path> -b <branch> <base>` for a new branch, or `git worktree add <path> <branch>` for an existing unoccupied task branch. Put the folder outside the main checkout, under `~/.worktrees/<repo>/<branch>`, unless the harness or repository specifies another location. For new tasks, fetch and use the remote default branch; in a local-only repository, use its local default branch. For ongoing tasks, preserve their existing commits as the base. Identify the actual default branch rather than assuming `main`.
4. Preserve existing edits and other sessions' folders. Do not switch the main checkout's branch, reset it, stash its changes, or delete a branch or worktree. If current uncommitted changes belong to this task, transfer only the task's explicit files and changes to its worktree and verify the contents before continuing. Leave the source changes intact. If ownership is unclear, or the required branch is occupied by the main checkout, report the conflict and stop before editing. Never attach another session's branch or substitute a detached checkout for the task branch.
5. Follow the repository's worktree setup instructions. When the harness already completed setup, verify it and reuse the result. Install dependencies only when the task needs them. Bring over ignored local configuration only when the project requires it. Keep private files out of commits and tool output. Documentation-only edits do not need application setup unless their checks require it.
6. Run commands and edit files from the task worktree. Read its local instructions. Confirm its path, branch, and status before the first edit. Report the working folder and branch with full file paths.

Done when the task has a linked worktree on its own non-default branch, its required files are present, and all repository edits target that folder. If setup fails, keep the step incomplete and report the cause.

Committing, pushing, opening a pull request, merging, and removing the worktree follow the calling workflow and its authorization. Worktree setup does not perform them.
