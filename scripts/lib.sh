#!/usr/bin/env bash
# Rules that the orchestrator and the settle job share. Source this file; it runs nothing.
# Needs GH_TOKEN and GITHUB_REPOSITORY.

# Prints the number of an open PR that closes issue $1, or nothing. A PR counts by GitHub's link,
# by a "Closes #n" line, or by a worker branch issue-<n>-.
closing_pr() {
  gh pr list --repo "$GITHUB_REPOSITORY" --state open --limit 200 \
    --json number,headRefName,body,closingIssuesReferences \
    | jq -r --argjson n "$1" '[.[] | select((.closingIssuesReferences | map(.number) | index($n)) or (.body | test("(?i)\\b(closes|fixes|resolves) #\($n)\\b")) or (.headRefName | startswith("issue-\($n)-")))] | .[0].number // ""'
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

# Reads file names on stdin. Prints each leading number that two or more names share, such as
# 0017 for 0017_a.sql and 0017_b.sql. Names that do not start with a digit are ignored.
repeated_numbers() {
  sed -nE 's/^([0-9]+)_.*/\1/p' | sort | uniq -d
}

# Prints "<path>: <numbers>" for each AGENT_CONFLICTS path on branch $1 that holds two files with
# the same leading number. A clean merge can bring in such a pair with no text conflict.
repeated_migrations() {
  local prefix prefixes numbers
  read -ra prefixes <<<"${AGENT_CONFLICTS:-}"
  for prefix in ${prefixes[@]+"${prefixes[@]}"}; do
    numbers=$(gh api "repos/$GITHUB_REPOSITORY/contents/${prefix%/}?ref=$1" --jq '.[] | select(.type == "file") | .name' 2>/dev/null \
      | repeated_numbers | paste -sd, - | sed 's/,/, /g' || true)
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
# does not start the same paid resolve worker again. $4 is the run link.
settle_resolve() {
  local pr="$1" branch="$2" main="$3" run_url="$4" missing repeated
  if [ "$(gh api "repos/$GITHUB_REPOSITORY/issues/$pr" --jq '[.labels[].name] | index("agent:blocked") != null')" = true ]; then
    echo "PR #$pr: resolve worker blocked it"; return
  fi
  missing=$(gh api "repos/$GITHUB_REPOSITORY/compare/$branch...$main" --jq .ahead_by)
  repeated=$(repeated_migrations "$branch")
  if [ "$missing" = 0 ] && [ -z "$repeated" ]; then echo "PR #$pr: resolved"; return; fi
  block_pr "$pr" "Factory resolve worker did not finish: the branch is still missing main or repeats a migration number. Run: $run_url"
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
