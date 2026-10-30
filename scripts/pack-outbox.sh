#!/usr/bin/env bash
# Usage: pack-outbox.sh <worktree> <outbox> <branch> <base>   base: the commit the worktree started from.
set -uo pipefail
worktree="$1" outbox="$2" branch="$3" base="$4"
mkdir -p "$outbox"
if ! head=$(git -C "$worktree" rev-parse --verify --quiet "refs/heads/$branch"); then
  echo "Branch $branch is gone; nothing to pack."; exit 0
fi
if [ "$(git -C "$worktree" rev-list --count "$base..$head")" = 0 ]; then
  echo "Branch $branch has no commits past $base; nothing to pack."; exit 0
fi
if git -C "$worktree" bundle create "$outbox/head.bundle" "refs/heads/$branch" "^$base"; then
  echo "Packed $branch at $head."
else
  echo "::warning::The bundle for $branch could not be written."
fi
