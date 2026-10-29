#!/usr/bin/env bash
# The orchestrator's fixed steps, as plain code. It releases claims that no live run holds, merges
# main into each open factory PR, reads every open issue with the trigger label, applies the skip
# rules and the cap, and claims the issues it starts. Each run looks at all PRs and candidates, so a
# lost or repeated event changes nothing.
# Usage: orchestrate.sh   Needs GH_TOKEN, FACTORY_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER,
# GITHUB_WORKFLOW_REF, GITHUB_RUN_ID, CAP, DRY_RUN, AGENT_CONFLICTS (space-separated path prefixes,
# may be empty). Writes jobs=<JSON array of claimed jobs> to GITHUB_OUTPUT. A job is
# {"issue":n,"branch":""} for new work, or {"issue":n,"branch":b,"pr":p,"main":sha} for a resolve
# worker that merges main into the open PR p on branch b.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$GITHUB_REPOSITORY"
owner="$GITHUB_REPOSITORY_OWNER"
trigger="agent:implement"
summary="${GITHUB_STEP_SUMMARY:-/dev/stderr}"
run_url="${GITHUB_SERVER_URL:-https://github.com}/$repo/actions/runs/$GITHUB_RUN_ID"

decide() { echo "$1: $2 ($3)"; echo "| $1 | $2 | $3 |" >> "$summary"; }

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

# Writes the summary heading and table head. Reads the global running.
summary_header() {
  echo "Workers running: $running. Cap: $CAP."
  {
    echo "## Orchestrator $( [ "$DRY_RUN" = true ] && echo '(dry run: no labels change, no worker starts, no PR changes)')"
    echo
    echo "Workers running: $running of $CAP."
    echo
    echo "| PR or issue | Decision | Reason |"
    echo "| --- | --- | --- |"
  } >> "$summary"
}

# POSTs a merge of main into branch $1 with FACTORY_TOKEN, so the push starts the PR's checks.
# Prints the HTTP status: 201 merged, 204 already up to date, 409 conflict.
merge_main() {
  GH_TOKEN="$FACTORY_TOKEN" gh api --include --method POST "repos/$repo/merges" -f base="$1" -f head=main 2>/dev/null \
    | awk 'NR == 1 { print $2 }' || true
}

# Prints the paths that conflict when main merges into branch $1. Read only: never pushes.
# Reuses one clone per run.
conflict_paths() {
  local dir="${RUNNER_TEMP:-/tmp}/caller"
  [ -d "$dir" ] || git clone --quiet --filter=blob:none "https://github.com/$repo" "$dir" || return 1
  git -C "$dir" fetch --quiet origin "+refs/heads/main:refs/remotes/origin/main" "+refs/heads/$1:refs/remotes/origin/$1" || return 1
  git -C "$dir" checkout --quiet --detach "origin/$1" || return 1
  git -C "$dir" -c user.name=factory -c user.email=factory@invalid merge --quiet --no-commit --no-ff origin/main >/dev/null 2>&1 || true
  git -C "$dir" diff --name-only --diff-filter=U
  git -C "$dir" merge --abort 2>/dev/null || git -C "$dir" reset --quiet --hard
}

# Brings each factory PR up to date with main, so its strict required checks can pass again.
# A PR whose issue a worker has is left alone. A conflict only under AGENT_CONFLICTS, or a repeated
# migration number there, gets a resolve job on fd 3 while places are free; any other conflict
# blocks the PR for the owner. A failed GitHub call is logged for that PR and never stops the run,
# so the issues are still picked.
refresh() {
  local prs pr issue branch blocked worker status paths shown repeated main free=$(( CAP - running ))
  # Resolve jobs name this main, so settle can check that the worker merged it.
  if ! main=$(gh api "repos/$repo/commits/main" --jq .sha); then
    decide "PRs" error "main could not be read; the next run retries"
    return 0
  fi
  # Logs a decision for PR $1 with reason $2. When a place is free, writes a resolve job to fd 3
  # and uses the place. Reads issue, branch, main, and free from refresh.
  resolve_job() {
    if [ "$free" -le 0 ]; then decide "PR #$1" hold "$2; needs a resolve worker; cap reached"
    else
      free=$(( free - 1 ))
      if [ "$DRY_RUN" = true ]; then decide "PR #$1" "would resolve" "$2; a worker would merge main"
      else decide "PR #$1" resolve "$2; a worker merges main"; fi
      jq -cn --argjson issue "$issue" --arg branch "$branch" --argjson pr "$1" --arg main "$main" \
        '{issue: $issue, branch: $branch, pr: $pr, main: $main}' >&3
    fi
  }
  if ! prs=$(factory_prs); then
    echo "::warning::Factory PR refresh skipped: the open PRs could not be listed."
    decide "PRs" error "the open factory PRs could not be listed; the next run retries"
    return 0
  fi
  while read -r pr issue branch blocked; do
    [ -n "$pr" ] || continue
    if [ "$blocked" = true ]; then decide "PR #$pr" skip "has agent:blocked"; continue; fi
    if ! worker=$(gh issue view "$issue" --repo "$repo" --json labels --jq '[.labels[].name] | index("agent:in-progress") != null'); then
      decide "PR #$pr" error "the labels of #$issue could not be read; the next run retries"; continue
    fi
    if [ "$worker" = true ]; then decide "PR #$pr" skip "a worker has #$issue"; continue; fi
    if [ "$DRY_RUN" = true ]; then
      status=$(gh api "repos/$repo/compare/$branch...main" --jq 'if .ahead_by == 0 then 204 else 201 end')
      [ "$status" = 204 ] || { decide "PR #$pr" "would refresh" "would merge main into $branch"; continue; }
    else
      status=$(merge_main "$branch")
    fi
    case "$status" in
      201|204)
        if [ "$status" = 201 ]; then decide "PR #$pr" refresh "merged main into $branch; checks run again"
        else decide "PR #$pr" refresh "up to date"; fi
        repeated=$(repeated_migrations "$branch") || repeated=""
        [ -z "$repeated" ] || resolve_job "$pr" "repeated migration number in $repeated"
        ;;
      409)
        if ! paths=$(conflict_paths "$branch") || [ -z "$paths" ]; then
          decide "PR #$pr" error "merges API returned 409, but the conflicting paths could not be listed; the next run retries"
          continue
        fi
        shown=$(head -3 <<<"$paths" | paste -sd, - | sed 's/,/, /g')
        if [ "$(classify_conflict <<<"$paths")" = agent ]; then
          resolve_job "$pr" "conflict only in $AGENT_CONFLICTS: $shown"
        else
          if block_pr "$pr" "Factory refresh blocked: merging main into this branch conflicts in $(paste -sd, - <<<"$paths" | sed 's/,/, /g')."; then
            decide "PR #$pr" blocked "conflict in $shown; the owner merges main by hand"
          else
            decide "PR #$pr" error "conflict in $shown, but the PR could not be blocked; the next run retries"
          fi
        fi
        ;;
      *) decide "PR #$pr" error "merges API returned ${status:-no status}; the next run retries" ;;
    esac
  done <<<"$prs"
}

# Prints the issues to start, one per line, after the skip rules and the cap. $1 is the number of
# resolve jobs from refresh; they take their places first.
pick() {
  local free=$(( CAP - running - $1 )) n issue labels labeler

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

    if [ "$(jq -r .author.login <<<"$issue")" != "$owner" ]; then decide "#$n" skip "not opened by the owner"
    elif [ "$labeler" != "$owner" ]; then decide "#$n" skip "label not added by the owner"
    elif [[ ",$labels," == *",agent:blocked,"* ]]; then decide "#$n" skip "has agent:blocked"
    elif [[ ",$labels," == *",agent:in-progress,"* ]]; then decide "#$n" skip "a worker already has it"
    elif [ -n "$open_pr" ]; then decide "#$n" skip "open PR #$open_pr closes it"
    elif [ -n "$blockers" ]; then decide "#$n" skip "blocked by $blockers"
    elif [ "$free" -le 0 ]; then decide "#$n" hold "cap reached; a later run takes it"
    else
      free=$(( free - 1 ))
      if [ "$DRY_RUN" = true ]; then decide "#$n" "would start" "would add agent:in-progress and start a worker"
      else decide "#$n" start "claims it and starts a worker"; echo "$n" >&3
      fi
    fi
  done 3>&1 >&2
}

# The task 7 planner goes here. It reads the issues to start and prints the ones that start now.
plan() { cat; }

# Reads job lines. Adds agent:in-progress to each job's issue with github.token, so the label
# change starts no workflow, and prints the job line. A resolve job claims the issue of its PR.
claim() {
  local job
  while read -r job; do
    [ -n "$job" ] || continue
    gh issue edit "$(jq .issue <<<"$job")" --repo "$repo" --add-label agent:in-progress >/dev/null || continue
    echo "$job"
  done
}

sweep
running=$(gh issue list --repo "$repo" --state open --label agent:in-progress --json number --jq length)
summary_header
resolves=$(refresh 3>&1 >&2)
started=$(pick "$(grep -c . <<<"$resolves" || true)" | plan | jq -c '{issue: ., branch: ""}')
# A dry run counts the places resolve jobs would take, but claims and starts nothing.
if [ "$DRY_RUN" = true ]; then jobs=""; else jobs=$(printf '%s\n%s\n' "$resolves" "$started" | claim); fi
echo "jobs=$(jq -sc . <<<"$jobs")" >> "${GITHUB_OUTPUT:-/dev/stdout}"
