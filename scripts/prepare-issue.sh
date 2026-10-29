#!/usr/bin/env bash
# Run on the job computer, in the project checkout. Writes the issue file the worker reads,
# makes the issue branch or switches to the open PR's branch, and prints the branch name.
# Usage: prepare-issue.sh <issue> <out-file> [<branch>]   Needs GH_TOKEN and GITHUB_REPOSITORY_OWNER.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
issue="$1"
out="$2"
existing="${3:-}"
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
  git switch --quiet --create "$existing" "origin/$existing"
  echo "$existing"
  exit 0
fi
slug=$(jq -r .title <<<"$json" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40 | sed -E 's/-+$//')
branch="issue-$issue-$slug"
git switch --create "$branch"
echo "$branch"
