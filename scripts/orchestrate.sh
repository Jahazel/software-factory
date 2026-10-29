#!/usr/bin/env bash
# The orchestrator's fixed steps, as plain code. It reads every open issue with the trigger label,
# applies the skip rules and the cap, and prints one decision per issue.
# Each run looks at all candidates, so a lost or repeated label event changes nothing.
# Usage: orchestrate.sh   Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER, CAP, DRY_RUN.
set -euo pipefail
repo="$GITHUB_REPOSITORY"
owner="$GITHUB_REPOSITORY_OWNER"
trigger="agent:implement"
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

# Open PRs that close an issue: by GitHub's link, by a "Closes #n" line, or by a worker branch issue-<n>-.
open_prs=$(gh pr list --repo "$repo" --state open --limit 200 --json number,headRefName,body,closingIssuesReferences)

running=$(gh issue list --repo "$repo" --state open --label agent:in-progress --json number --jq length)
free=$(( CAP - running ))
echo "Workers running: $running. Cap: $CAP. Free places: $(( free > 0 ? free : 0 ))."

{
  echo "## Orchestrator $( [ "$DRY_RUN" = true ] && echo '(dry run: no labels change, no worker starts)')"
  echo
  echo "Workers running: $running of $CAP."
  echo
  echo "| Issue | Decision | Reason |"
  echo "| --- | --- | --- |"
} >> "$summary"

decide() { echo "#$1: $2 ($3)"; echo "| #$1 | $2 | $3 |" >> "$summary"; }

for n in $(gh issue list --repo "$repo" --state open --label "$trigger" --json number --jq 'sort_by(.number) | .[].number'); do
  issue=$(gh issue view "$n" --repo "$repo" --json author,labels)
  labels=$(jq -r '[.labels[].name] | join(",")' <<<"$issue")
  # Who added the trigger label last. Only the owner's label counts.
  labeler=$(gh api --paginate "repos/$repo/issues/$n/events" \
    --jq "[.[] | select(.event == \"labeled\" and .label.name == \"$trigger\")] | last | .actor.login // \"\"" | tail -1)
  open_pr=$(jq -r --argjson n "$n" '[.[] | select((.closingIssuesReferences | map(.number) | index($n)) or (.body | test("(?i)\\b(closes|fixes|resolves) #\($n)\\b")) or (.headRefName | startswith("issue-\($n)-")))] | .[0].number // ""' <<<"$open_prs")

  if [ "$(jq -r .author.login <<<"$issue")" != "$owner" ]; then decide "$n" skip "not opened by the owner"
  elif [ "$labeler" != "$owner" ]; then decide "$n" skip "label not added by the owner"
  elif [[ ",$labels," == *",agent:blocked,"* ]]; then decide "$n" skip "has agent:blocked"
  elif [[ ",$labels," == *",agent:in-progress,"* ]]; then decide "$n" skip "a worker already has it"
  elif [ -n "$open_pr" ]; then decide "$n" skip "open PR #$open_pr closes it"
  elif [ "$free" -le 0 ]; then decide "$n" hold "cap reached; a later run takes it"
  else
    free=$(( free - 1 ))
    if [ "$DRY_RUN" = true ]; then decide "$n" "would start" "would add agent:in-progress and start a worker"
    else echo "Real runs are not built yet."; exit 1
    fi
  fi
done
