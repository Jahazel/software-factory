#!/usr/bin/env bash
# The orchestrator's fixed steps, as plain code. It releases claims that no live run holds, reads
# every open issue with the trigger label, applies the skip rules and the cap, and claims the
# issues it starts. Each run looks at all candidates, so a lost or repeated label event changes nothing.
# Usage: orchestrate.sh   Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER, GITHUB_WORKFLOW_REF,
# GITHUB_RUN_ID, CAP, DRY_RUN. Writes issues=<JSON array of claimed issues> to GITHUB_OUTPUT.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$GITHUB_REPOSITORY"
owner="$GITHUB_REPOSITORY_OWNER"
trigger="agent:implement"
summary="${GITHUB_STEP_SUMMARY:-/dev/stderr}"
run_url="${GITHUB_SERVER_URL:-https://github.com}/$repo/actions/runs/$GITHUB_RUN_ID"

decide() { echo "#$1: $2 ($3)"; echo "| #$1 | $2 | $3 |" >> "$summary"; }

# A claim with no other orchestrator run alive has no worker behind it: its run died before settle.
sweep() {
  local others
  others=$(for status in queued in_progress; do
    gh run list --repo "$repo" --workflow "$(caller_file)" --status "$status" --json databaseId --jq '.[].databaseId'
  done | grep -vx "$GITHUB_RUN_ID" || true)
  [ -z "$others" ] || return 0
  for n in $(gh issue list --repo "$repo" --state open --label agent:in-progress --json number --jq '.[].number'); do
    if [ "$DRY_RUN" = true ]; then echo "#$n: would release a stuck claim"; else settle_issue "$n" "$run_url"; fi
  done
}

# Prints the issues to start, one per line, after the skip rules and the cap.
pick() {
  local running free n issue labels labeler
  running=$(gh issue list --repo "$repo" --state open --label agent:in-progress --json number --jq length)
  free=$(( CAP - running ))
  echo "Workers running: $running. Cap: $CAP. Free places: $(( free > 0 ? free : 0 ))." >&2
  {
    echo "## Orchestrator $( [ "$DRY_RUN" = true ] && echo '(dry run: no labels change, no worker starts)')"
    echo
    echo "Workers running: $running of $CAP."
    echo
    echo "| Issue | Decision | Reason |"
    echo "| --- | --- | --- |"
  } >> "$summary"

  for n in $(gh issue list --repo "$repo" --state open --label "$trigger" --json number --jq 'sort_by(.number) | .[].number'); do
    issue=$(gh issue view "$n" --repo "$repo" --json author,labels)
    labels=$(jq -r '[.labels[].name] | join(",")' <<<"$issue")
    # Who added the trigger label last. Only the owner's label counts.
    labeler=$(gh api --paginate "repos/$repo/issues/$n/events" \
      --jq "[.[] | select(.event == \"labeled\" and .label.name == \"$trigger\")] | last | .actor.login // \"\"" | tail -1)
    # Open issues that GitHub lists under "Blocked by". Work on a blocked issue waits for them.
    blockers=$(gh api --paginate "repos/$repo/issues/$n/dependencies/blocked_by" \
      --jq '.[] | select(.state == "open") | "#\(.number)"' | paste -sd, - | sed 's/,/, /g')
    open_pr=$(closing_pr "$n")

    if [ "$(jq -r .author.login <<<"$issue")" != "$owner" ]; then decide "$n" skip "not opened by the owner"
    elif [ "$labeler" != "$owner" ]; then decide "$n" skip "label not added by the owner"
    elif [[ ",$labels," == *",agent:blocked,"* ]]; then decide "$n" skip "has agent:blocked"
    elif [[ ",$labels," == *",agent:in-progress,"* ]]; then decide "$n" skip "a worker already has it"
    elif [ -n "$open_pr" ]; then decide "$n" skip "open PR #$open_pr closes it"
    elif [ -n "$blockers" ]; then decide "$n" skip "blocked by $blockers"
    elif [ "$free" -le 0 ]; then decide "$n" hold "cap reached; a later run takes it"
    else
      free=$(( free - 1 ))
      if [ "$DRY_RUN" = true ]; then decide "$n" "would start" "would add agent:in-progress and start a worker"
      else decide "$n" start "claims it and starts a worker"; echo "$n" >&3
      fi
    fi
  done 3>&1 >&2
}

# The task 7 planner goes here. It reads the issues to start and prints the ones that start now.
plan() { cat; }

# Adds agent:in-progress with github.token, so the label change starts no workflow.
claim() {
  local n
  while read -r n; do
    gh issue edit "$n" --repo "$repo" --add-label agent:in-progress >/dev/null
    echo "$n"
  done
}

sweep
started=$(pick | plan | claim)
echo "issues=$(jq -cn '[$ARGS.positional[] | tonumber]' --args $started)" >> "${GITHUB_OUTPUT:-/dev/stdout}"
