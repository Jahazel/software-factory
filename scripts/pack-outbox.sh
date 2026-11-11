#!/usr/bin/env bash
# Usage: pack-outbox.sh <worktree> <outbox> <branch> <base>   base: the commit the worktree started from.
# Writes no-commits only when the branch holds no commit past base, the worktree is on it, and no
# change is left uncommitted, so a missing bundle for any other reason never reads as "nothing new".
set -uo pipefail
worktree="$1" outbox="$2" branch="$3" base="$4"
mkdir -p "$outbox"
rm -f "$outbox/no-commits"
if ! head=$(git -C "$worktree" rev-parse --verify --quiet "refs/heads/$branch"); then
  echo "Branch $branch is gone; nothing to pack."; exit 0
fi
if [ "$(git -C "$worktree" rev-list --count "$base..$head")" = 0 ]; then
  if [ "$(git -C "$worktree" rev-parse HEAD)" = "$head" ] && left=$(git -C "$worktree" status --porcelain) && [ -z "$left" ]; then
    touch "$outbox/no-commits"
  else
    echo "::warning::The worktree is not on $branch or holds uncommitted changes, so publish opens no PR from the pushed head."
  fi
  echo "Branch $branch has no commits past $base; nothing to pack."; exit 0
fi
if git -C "$worktree" bundle create "$outbox/head.bundle" "refs/heads/$branch" "^$base"; then
  echo "Packed $branch at $head."
else
  echo "::warning::The bundle for $branch could not be written."
fi
