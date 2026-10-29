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
  labeled=$(gh issue list --repo "$GITHUB_REPOSITORY" --state open --label agent:implement --limit 200 --json number --jq '[.[].number]')
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
