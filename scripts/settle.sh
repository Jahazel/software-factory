#!/usr/bin/env bash
# Runs after the workers, on its own computer, even when a worker failed. Releases each claim from
# what GitHub shows (open PR, agent:blocked), then starts the orchestrator once more for held issues.
# That run claims nothing when no issue waits, so the chain stops there.
# Usage: settle.sh   Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_WORKFLOW_REF, GITHUB_RUN_ID, ISSUES (JSON array).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
run_url="${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
for n in $(jq -r '.[]' <<<"$ISSUES"); do settle_issue "$n" "$run_url"; done
gh workflow run "$(caller_file)" --repo "$GITHUB_REPOSITORY"
echo "Started $(caller_file) again to pick up held issues."
