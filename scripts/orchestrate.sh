#!/usr/bin/env bash
# The orchestrator's fixed steps, as plain code: release dead claims, merge main into the open
# factory PRs, skip, plan, cap, and claim. Each run looks at all PRs and candidates, so a lost or
# repeated event changes nothing. Tests source this file; it then sets up the functions and globals
# but runs no step.
# Usage: orchestrate.sh   Needs GH_TOKEN, FACTORY_TOKEN, CLAUDE_CODE_OAUTH_TOKEN, GITHUB_REPOSITORY,
# GITHUB_REPOSITORY_OWNER, GITHUB_WORKFLOW_REF, GITHUB_RUN_ID, CAP, DRY_RUN, AGENT_CONFLICTS
# (space-separated path prefixes, may be empty). Writes jobs=<JSON array of claimed jobs> to
# GITHUB_OUTPUT. A job is {"issue":n,"branch":""} for new work, or
# {"issue":n,"branch":b,"pr":p,"main":sha} for a resolve worker that merges main into the open PR p
# on branch b.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
prompts="$(dirname "${BASH_SOURCE[0]}")/../prompts"
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
        repeated=$(repeated_migrations "$branch") || { repeated=""; decide "PR #$pr" error "the folders in $AGENT_CONFLICTS could not be read; repeated migration numbers not checked"; }
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

# Prints the candidate issues, oldest first, one per line: the labeled issues that pass the skip rules.
pick() {
  local n issue labeler blockers open_pr reason

  for n in $(gh issue list --repo "$repo" --state open --label "$trigger" --json number --jq 'sort_by(.number) | .[].number'); do
    if ! { issue=$(gh api "repos/$repo/issues/$n") &&
      # Who added the trigger label last. Only the owner's label counts.
      labeler=$(gh api --paginate "repos/$repo/issues/$n/events" \
        --jq "[.[] | select(.event == \"labeled\" and .label.name == \"$trigger\")] | last | .actor.login // \"\"" | tail -1) &&
      # Open issues that GitHub lists under "Blocked by". Work on a blocked issue waits for them.
      blockers=$(gh api --paginate "repos/$repo/issues/$n/dependencies/blocked_by" \
        --jq '.[] | select(.state == "open") | "#\(.number)"' | paste -sd, - | sed 's/,/, /g') &&
      open_pr=$(closing_pr "$n"); }; then
      decide "#$n" error "the issue could not be read; the next run retries"; continue
    fi

    reason=$(jq -c --arg owner "$owner" --arg labeler "$labeler" --arg open_pr "$open_pr" --arg blockers "$blockers" \
      '{owner: $owner, author: .user.login, labeler: $labeler, labels: [.labels[].name],
        sub_issues: (.sub_issues_summary.total // 0), open_pr: $open_pr, blockers: $blockers}' <<<"$issue" | skip_reason)
    if [ -n "$reason" ]; then decide "#$n" skip "$reason"; else echo "$n" >&3; fi
  done 3>&1 >&2
}

# Prints the work in flight as a JSON array: each factory PR with the files it changes, and each
# claimed issue without a factory PR (a new-work worker) with its title only.
busy_items() {
  local prs pr issue branch blocked files title items=() pr_issues workers
  prs=$(factory_prs) || return 1
  while read -r pr issue branch blocked; do
    [ -n "$pr" ] || continue
    files=$(gh api --paginate "repos/$repo/pulls/$pr/files" --jq '.[].filename' | jq -Rsc 'split("\n") | map(select(. != ""))') || return 1
    title=$(gh api "repos/$repo/pulls/$pr" --jq .title) || return 1
    items+=("$(jq -cn --argjson issue "$issue" --argjson pr "$pr" --arg title "$title" --argjson files "$files" \
      '{kind: "pr", issue: $issue, pr: $pr, title: $title, files: $files}')")
  done <<<"$prs"
  pr_issues=$(awk '{ print $2 }' <<<"$prs" | jq -Rsc 'split("\n") | map(select(. != "") | tonumber)')
  workers=$(gh issue list --repo "$repo" --state open --label agent:in-progress --json number,title \
    | jq -c --argjson skip "$pr_issues" '.[] | select(.number as $n | $skip | index($n) | not)
        | {kind: "worker", issue: .number, pr: null, title: .title, files: []}') || return 1
  printf '%s\n' ${items[@]+"${items[@]}"} "$workers" | jq -sc .
}

# Asks Claude which candidates ($1, JSON array) would change the same files as the busy work ($2)
# or an older candidate. Prints the holds JSON array. On failure prints one reason on stderr and
# returns 1.
planner_holds() {
  local tree briefs doc out
  tree=$(gh api "repos/$repo/git/trees/main?recursive=1" \
    --jq '[.tree[] | select(.type == "blob") | .path | select(startswith("docs/") | not)]') \
    || { echo "the files on main could not be listed" >&2; return 1; }
  briefs=$(for n in $(jq '.[]' <<<"$1"); do
      issue_brief "$n" | jq -Rsc --argjson n "$n" '{issue: $n, brief: .}' || exit 1
    done | jq -sc .) || { echo "an issue could not be read" >&2; return 1; }
  doc=$(jq -cn --argjson candidates "$briefs" --argjson busy "$2" --argjson tree "$tree" --arg ignore "${AGENT_CONFLICTS:-}" \
    '{candidates: $candidates, busy: $busy, tree: $tree, ignore: ($ignore | split(" ") | map(select(. != "")))}') \
    || { echo "the planner input could not be built" >&2; return 1; }
  out=$({ cat "$prompts/planner.md"; echo; echo "$doc"; } \
    | env -u FACTORY_TOKEN -u GH_TOKEN timeout 300 claude -p --model claude-sonnet-5-5 --effort medium \
        --tools "" --max-turns 3 --no-session-persistence --output-format json \
        --json-schema "$(cat "$prompts/planner.schema.json")" 2>/dev/null) \
    || { echo "the Claude call failed or timed out" >&2; return 1; }
  valid_holds <<<"$out" || { echo "invalid output" >&2; return 1; }
}

# With nothing busy, the first candidate always starts, so only a second free place lets holds matter.
planner_can_change_plan() {
  local busy="$1" free="$2" cands="$3"
  [ "$busy" != '[]' ] || { [ "$free" -gt 1 ] && [ "$(jq length <<<"$cands")" -gt 1 ]; }
}

# Reads the candidates on stdin, oldest first, and prints the ones that start now, one per line.
# $1 is the number of resolve jobs from refresh; they take their places first.
plan() {
  local cands free busy='[]' holds='[]' failure="" err decisions d
  cands=$(jq -sc .)
  [ "$cands" != "[]" ] || return 0
  free=$(( CAP - running - $1 ))
  err=$(mktemp)
  if [ "$free" -gt 0 ]; then
    if ! busy=$(busy_items); then
      busy='[]' holds=null failure="the work in flight could not be listed"
    elif planner_can_change_plan "$busy" "$free" "$cands"; then
      holds=$(planner_holds "$cands" "$busy" 2>"$err") || { holds=null failure=$(tail -1 "$err"); cat "$err" >&2; }
    fi
  fi
  rm -f "$err"
  failure="${failure:-no reason given}"
  [ "$holds" != null ] || echo "::warning::Planner unavailable: $failure. Only the first candidate may start."
  if ! decisions=$(jq -n --argjson candidates "$cands" --argjson free "$free" --argjson busy "$busy" \
      --argjson holds "$holds" --arg failure "$failure" --argjson dry_run "$DRY_RUN" \
      '$ARGS.named' | plan_decisions); then
    decide "Issues" error "the plan could not be computed; nothing starts; the next run retries"
    return 0
  fi
  while read -r d; do
    decide "#$(jq .issue <<<"$d")" "$(jq -r .decision <<<"$d")" "$(jq -r .reason <<<"$d")"
    [ "$(jq .start <<<"$d")" != true ] || jq .issue <<<"$d" >&3
  done <<<"$decisions"
}

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

[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
sweep
running=$(gh issue list --repo "$repo" --state open --label agent:in-progress --json number --jq length)
summary_header
resolves=$(refresh 3>&1 >&2)
started=$(pick | plan "$(grep -c . <<<"$resolves" || true)" 3>&1 >&2 | jq -c '{issue: ., branch: ""}')
# A dry run counts the places resolve jobs would take, but claims and starts nothing.
if [ "$DRY_RUN" = true ]; then jobs=""; else jobs=$(printf '%s\n%s\n' "$resolves" "$started" | claim); fi
echo "jobs=$(jq -sc . <<<"$jobs")" >> "${GITHUB_OUTPUT:-/dev/stdout}"
