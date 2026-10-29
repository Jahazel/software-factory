#!/usr/bin/env bash
# Usage: prepare-issue.sh <issue> <out-file> <worktree> [<branch>]
set -euo pipefail
source "$(dirname "$0")/lib.sh"
issue="$1"
out="$2"
worktree="$3"
existing="${4:-}"
repo="$GITHUB_REPOSITORY"
owner="$GITHUB_REPOSITORY_OWNER"

json=$(gh issue view "$issue" --repo "$repo" --json title,author,comments)
author=$(jq -r .author.login <<<"$json")
if [ "$author" != "$owner" ]; then
  echo "Issue #$issue was opened by $author, not the owner $owner. The worker takes only the owner's issues."
  exit 1
fi

{
  issue_brief "$issue"
  echo
  echo "# The owner's comments"
  jq -r --arg owner "$owner" '.comments[] | select(.author.login == $owner) | "\n## \(.createdAt)\n\n\(.body)"' <<<"$json"
} > "$out"

if [ -n "$existing" ]; then
  git fetch --quiet origin "+refs/heads/$existing:refs/remotes/origin/$existing"
  git worktree add --quiet -b "$existing" "$worktree" "origin/$existing"
  echo "$existing"
  exit 0
fi
slug=$(jq -r .title <<<"$json" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40 | sed -E 's/-+$//')
branch="issue-$issue-$slug"
git worktree add --quiet -b "$branch" "$worktree" HEAD
echo "$branch"
