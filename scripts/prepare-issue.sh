#!/usr/bin/env bash
# Usage: prepare-issue.sh <issue> <out-file> <worktree> [<branch>]
# Run inside the project checkout with GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER, and
# GITHUB_RUN_ID.
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
  jq -r --arg owner "$owner" --arg marker "$publish_marker" '.comments[] | select(.author.login == $owner and (.body | contains($marker) | not))
    | "\n## \(.createdAt)\n\n\(.body)"' <<<"$json"
} > "$out"

if [ -n "$existing" ]; then
  git fetch --quiet origin "+refs/heads/$existing:refs/remotes/origin/$existing"
  git worktree add --quiet -b "$existing" "$worktree" "origin/$existing"
  echo "$existing"
  exit 0
fi
branch=$(factory_branch "$issue" "$(jq -r .title <<<"$json")" "$GITHUB_RUN_ID")
git worktree add --quiet -b "$branch" "$worktree" HEAD
echo "$branch"
