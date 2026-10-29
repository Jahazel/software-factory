#!/usr/bin/env bash
# Rules that the orchestrator, the settle job, and prepare-issue share. Source this file; it runs nothing.
# Needs GH_TOKEN and GITHUB_REPOSITORY.

# Prints the number of an open PR that closes issue $1, or nothing. A PR counts by GitHub's link,
# by a "Closes #n" line, or by a worker branch issue-<n>-.
closing_pr() {
  gh pr list --repo "$GITHUB_REPOSITORY" --state open --limit 200 \
    --json number,headRefName,body,closingIssuesReferences \
    | jq -r --argjson n "$1" '[.[] | select((.closingIssuesReferences | map(.number) | index($n)) or (.body | test("(?i)\\b(closes|fixes|resolves) #\($n)\\b")) or (.headRefName | startswith("issue-\($n)-")))] | .[0].number // ""'
}

# Prints the text the worker and the planner read for issue $1: title, labels, body, and the parent
# issue's title and body when the body has a "## Parent" section.
issue_brief() {
  local json parent
  json=$(gh issue view "$1" --repo "$GITHUB_REPOSITORY" --json title,body,labels) || return 1
  echo "# Issue #$1: $(jq -r .title <<<"$json")"
  echo
  echo "Labels: $(jq -r '[.labels[].name] | join(", ")' <<<"$json")"
  echo
  jq -r .body <<<"$json"
  parent=$(jq -r .body <<<"$json" | awk '/^## Parent/{f=1;next} f && match($0,/#[0-9]+/){print substr($0,RSTART+1,RLENGTH-1); exit}')
  [ -n "$parent" ] || return 0
  json=$(gh issue view "$parent" --repo "$GITHUB_REPOSITORY" --json title,body) || return 1
  echo
  echo "# Parent issue #$parent: $(jq -r .title <<<"$json")"
  echo
  jq -r .body <<<"$json"
}

# Prints one line per factory PR, by PR number: <pr> <issue> <branch> <has agent:blocked: true|false>
# A factory PR is an open PR into main, from this repo, on branch issue-<n>-*, where open issue n has
# agent:implement. The label keeps out the owner's own PRs, which use the same branch names.
factory_prs() {
  local labeled
  labeled=$(gh issue list --repo "$GITHUB_REPOSITORY" --state open --label agent:implement --limit 200 --json number --jq '[.[].number]') || return 1
  gh pr list --repo "$GITHUB_REPOSITORY" --state open --base main --limit 200 \
    --json number,headRefName,isCrossRepository,labels \
    | jq -r --argjson labeled "$labeled" '[.[] | select(.isCrossRepository | not)
        | (.headRefName | capture("^issue-(?<n>[0-9]+)-").n // empty | tonumber) as $n
        | select($labeled | index($n)) | . + {issue: $n}]
      | sort_by(.number) | .[]
      | "\(.number) \(.issue) \(.headRefName) \([.labels[].name] | index("agent:blocked") != null)"'
}

# Reads conflicting paths on stdin. Prints "agent" when the list is not empty and every path starts
# with one of the space-separated prefixes in AGENT_CONFLICTS, else "owner".
classify_conflict() {
  local path prefix prefixes any=false matched
  read -ra prefixes <<<"${AGENT_CONFLICTS:-}"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    any=true matched=false
    for prefix in ${prefixes[@]+"${prefixes[@]}"}; do
      [[ "$path" == "$prefix"* ]] && matched=true
    done
    [ "$matched" = true ] || { echo owner; return; }
  done
  if [ "$any" = true ]; then echo agent; else echo owner; fi
}

# Reads the planner's claude --output-format json document on stdin. Prints its holds array when
# every hold has an integer issue and string lists overlaps and files. Any other shape returns 1,
# so a half-valid answer is never partly used.
valid_holds() {
  jq -ec 'select(.is_error == false and (.structured_output | type == "object")
      and (.structured_output.holds | type == "array" and all(.[];
        type == "object"
        and (.issue | type == "number" and . == floor)
        and (.overlaps | type == "array" and all(.[]; type == "string"))
        and (.files | type == "array" and all(.[]; type == "string")))))
    | .structured_output.holds' 2>/dev/null
}

# Reads {candidates (oldest first), free, busy, holds, failure, dry_run} on stdin; holds is null when
# the planner failed. Prints one {issue, decision, reason, start} line per candidate, in order.
# A hold on a newer or held candidate is ignored, so the older issue wins and no two holds wait on
# each other.
plan_decisions() {
  jq -c --arg ignore "${AGENT_CONFLICTS:-}" '
    def dedupe: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);
    . as {candidates: $cands, free: $free, busy: $busy, holds: $holds, failure: $failure, dry_run: $dry}
    | ($ignore | split(" ") | map(select(. != ""))) as $prefixes
    | ($busy | map(.pr | select(. != null))) as $prs
    | ($busy | map(.issue)) as $issues
    | def open_pr: test("^PR #[0-9]+$") and (.[4:] | tonumber) as $p | $prs | any(. == $p);
      def busy_issue: test("^#[0-9]+$") and (.[1:] | tonumber) as $m | $issues | any(. == $m);
      def earlier_candidate($n; $held): test("^#[0-9]+$") and (.[1:] | tonumber) as $m
        | $m < $n and ($cands | any(. == $m)) and ($held | any(. == $m) | not);
      def outside_agent_conflicts: . as $f | $prefixes | any(. as $p | $f | startswith($p)) | not;
    (if $dry then {decision: "would start", reason: "would add agent:in-progress and start a worker"}
     else {decision: "start", reason: "claims it and starts a worker"} end) as $start
    | {decision: "hold", reason: "cap reached; a later run takes it"} as $cap
    | "planner unavailable: \($failure); started the first candidate only" as $unavailable
    | reduce $cands[] as $n ({free: $free, held: [], out: []};
        . as $s
        | def start_or_cap($why): if $s.free > 0 then $start + $why else $cap end;
        ($holds // [] | map(select(.issue == $n))) as $mine
        | ($mine | map(.overlaps[]) | dedupe
            | map(select(open_pr or busy_issue or earlier_candidate($n; $s.held)))) as $targets
        | ($mine | map(.files[]) | dedupe | map(select(outside_agent_conflicts))) as $files
        | ($s.out == []) as $first
        | (if $holds == null then
             if $first then start_or_cap({reason: $unavailable}) else {decision: "hold", reason: $unavailable} end
           elif $mine == [] then start_or_cap({})
           elif $targets == [] then
             start_or_cap({reason: "planner hold ignored: no overlap with an open PR, a running worker, or an earlier candidate that starts"})
           elif $files == [] then
             start_or_cap({reason: "planner hold ignored: it names no file\(if $prefixes == [] then "" else " outside \($prefixes | join(", "))" end)"})
           else {decision: "hold", reason: "overlaps \($targets | join(", ")): \($files[:3] | join(", "))", planned: true} end) as $d
        | ($d.decision != "hold") as $go
        | .free -= (if $go then 1 else 0 end)
        | .held += (if $d.planned then [$n] else [] end)
        | .out += [{issue: $n, decision: $d.decision, reason: $d.reason, start: $go}])
    | .out[]'
}

# Reads file names on stdin. Prints each leading number that two or more names share, such as
# 0017 for 0017_a.sql and 0017_b.sql. Names that do not start with a digit are ignored.
repeated_numbers() {
  sed -nE 's/^([0-9]+)_.*/\1/p' | sort | uniq -d
}

# Prints "<path>: <numbers>" for each AGENT_CONFLICTS path where branch $1 repeats a leading file
# number that main does not repeat. A clean merge can bring in such a pair with no text conflict.
# Returns 1 when a folder cannot be read.
repeated_migrations() {
  local prefix prefixes on_branch on_main numbers
  read -ra prefixes <<<"${AGENT_CONFLICTS:-}"
  for prefix in ${prefixes[@]+"${prefixes[@]}"}; do
    on_branch=$(gh api "repos/$GITHUB_REPOSITORY/contents/${prefix%/}?ref=$1" --jq '.[] | select(.type == "file") | .name' | repeated_numbers) || return 1
    on_main=$(gh api "repos/$GITHUB_REPOSITORY/contents/${prefix%/}?ref=main" --jq '.[] | select(.type == "file") | .name' | repeated_numbers) || return 1
    numbers=$(comm -23 <(grep . <<<"$on_branch" || true) <(grep . <<<"$on_main" || true) | paste -sd, - | sed 's/,/, /g')
    [ -z "$numbers" ] || echo "$prefix: $numbers"
  done
}

# Comments on PR $1 with the first line $2, unless the same comment is already there, and adds
# agent:blocked to it. Safe to run again after a partial failure.
block_pr() {
  local comments
  comments=$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$1/comments" --jq '.[].body') || return 1
  if ! grep -qxF "$2" <<<"$comments"; then
    gh api "repos/$GITHUB_REPOSITORY/issues/$1/comments" -f body="$2

Merge main by hand, then remove \`agent:blocked\` from this PR." >/dev/null || return 1
  fi
  gh api "repos/$GITHUB_REPOSITORY/issues/$1/labels" -f 'labels[]=agent:blocked' >/dev/null
}

# Checks a resolve job's PR $1 on branch $2 after its worker ended. The branch must hold main as of
# decide ($3) and no repeated migration number. Otherwise the PR is blocked, so the next refresh
# does not start the same paid resolve worker again. $4 is the run link. Returns 1 when GitHub
# cannot answer; nothing is blocked then.
settle_resolve() {
  local pr="$1" branch="$2" main="$3" run_url="$4" blocked missing repeated
  blocked=$(gh api "repos/$GITHUB_REPOSITORY/issues/$pr" --jq '[.labels[].name] | index("agent:blocked") != null') || return 1
  if [ "$blocked" = true ]; then echo "PR #$pr: resolve worker blocked it"; return; fi
  missing=$(gh api "repos/$GITHUB_REPOSITORY/compare/$branch...$main" --jq .ahead_by) || return 1
  if [ "$missing" = 0 ]; then
    repeated=$(repeated_migrations "$branch") || return 1
    if [ -z "$repeated" ]; then echo "PR #$pr: resolved"; return; fi
  fi
  block_pr "$pr" "Factory resolve worker did not finish: the branch is still missing main or repeats a migration number. Run: $run_url" || return 1
  echo "PR #$pr: resolve worker did not finish; added agent:blocked"
}

# The caller's workflow file, such as factory-orchestrator.yml. Inside a called workflow,
# GITHUB_WORKFLOW_REF names the caller.
caller_file() {
  local ref="${GITHUB_WORKFLOW_REF%@*}"
  echo "${ref##*/}"
}

# Releases the claim on issue $1. Safe to run twice: the second run finds no claim and stops.
# Open PR or agent:blocked: remove agent:in-progress.
# Neither: the worker ended without an answer. Comment once with the run link $2, add
# agent:blocked, then remove agent:in-progress. A failed worker never becomes a candidate again.
settle_issue() {
  local n="$1" run_url="$2" labels pr
  labels=$(gh issue view "$n" --repo "$GITHUB_REPOSITORY" --json labels --jq '[.labels[].name] | join(",")')
  if [[ ",$labels," != *",agent:in-progress,"* ]]; then echo "#$n: no claim to release"; return; fi
  pr=$(closing_pr "$n")
  if [ -n "$pr" ]; then
    echo "#$n: PR #$pr is open; claim released"
  elif [[ ",$labels," == *",agent:blocked,"* ]]; then
    echo "#$n: worker blocked; claim released"
  else
    if ! gh issue view "$n" --repo "$GITHUB_REPOSITORY" --json comments --jq '.comments[].body' | grep -qF "$run_url"; then
      gh issue comment "$n" --repo "$GITHUB_REPOSITORY" --body "Factory worker failed: the worker ended with no PR and no blocked comment. Run: $run_url

To retry, remove \`agent:blocked\`, then remove and add \`agent:implement\`." >/dev/null
    fi
    gh issue edit "$n" --repo "$GITHUB_REPOSITORY" --add-label agent:blocked >/dev/null
    echo "#$n: worker failed; added agent:blocked"
  fi
  gh issue edit "$n" --repo "$GITHUB_REPOSITORY" --remove-label agent:in-progress >/dev/null
}
