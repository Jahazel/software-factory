#!/usr/bin/env bash
# Run on the job computer, in the project checkout. Writes the issue file the worker reads,
# makes the issue branch, and prints the branch name for later steps.
# Usage: prepare-issue.sh <issue> <out-file>   Needs GH_TOKEN and GITHUB_REPOSITORY_OWNER.
set -euo pipefail
issue="$1"
out="$2"
repo="$GITHUB_REPOSITORY"
owner="$GITHUB_REPOSITORY_OWNER"

json=$(gh issue view "$issue" --repo "$repo" --json number,title,body,labels,author,comments)
author=$(jq -r .author.login <<<"$json")
if [ "$author" != "$owner" ]; then
  echo "Issue #$issue was opened by $author, not the owner $owner. The worker takes only the owner's issues."
  exit 1
fi

{
  echo "# Issue #$issue: $(jq -r .title <<<"$json")"
  echo
  echo "Labels: $(jq -r '[.labels[].name] | join(", ")' <<<"$json")"
  echo
  jq -r .body <<<"$json"
  parent=$(jq -r .body <<<"$json" | awk '/^## Parent/{f=1;next} f && match($0,/#[0-9]+/){print substr($0,RSTART+1,RLENGTH-1); exit}')
  if [ -n "$parent" ]; then
    echo
    echo "# Parent issue #$parent: $(gh issue view "$parent" --repo "$repo" --json title --jq .title)"
    echo
    gh issue view "$parent" --repo "$repo" --json body --jq .body
  fi
  echo
  echo "# The owner's comments"
  jq -r --arg owner "$owner" '.comments[] | select(.author.login == $owner) | "\n## \(.createdAt)\n\n\(.body)"' <<<"$json"
} > "$out"

slug=$(jq -r .title <<<"$json" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40 | sed -E 's/-+$//')
branch="issue-$issue-$slug"
git switch --create "$branch"
echo "$branch"
