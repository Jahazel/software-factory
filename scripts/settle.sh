#!/usr/bin/env bash
# Runs after the workers, on its own computer, even when a worker failed. Checks each resolve job's
# PR, releases each claim from what GitHub shows (open PR, agent:blocked), then starts the
# orchestrator once more for held issues. That run claims nothing when no issue waits, so the chain
# stops there.
# Usage: settle.sh   Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_WORKFLOW_REF, GITHUB_RUN_ID,
# AGENT_CONFLICTS, JOBS (the decide job's JSON array).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
run_url="${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
while read -r pr branch main; do
  settle_resolve "$pr" "$branch" "$main" "$run_url" || echo "PR #$pr: the resolve check failed; the owner checks the PR"
done < <(jq -r '.[] | select(.branch != "") | "\(.pr) \(.branch) \(.main)"' <<<"$JOBS")
for n in $(jq -r '.[].issue' <<<"$JOBS"); do settle_issue "$n" "$run_url"; done
gh workflow run "$(caller_file)" --repo "$GITHUB_REPOSITORY"
echo "Started $(caller_file) again to pick up held issues."
