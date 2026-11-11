#!/usr/bin/env bash
# Usage: bash tests/continue-branch.sh   Exits 1 when a case fails.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_REPOSITORY=o/r GITHUB_REPOSITORY_OWNER=o GITHUB_RUN_ID=0 GITHUB_STEP_SUMMARY=/dev/null
TRIGGER_LABEL=ready-for-agent DRY_RUN=false
source "$root/scripts/orchestrate.sh"
# REFS: the issue's factory branch names, one per line. PRS: JSON of the PRs whose head is the
# asked branch, keyed by branch. FAIL: refs or prs makes that read fail.
gh() {
  case "$*" in
    "api --paginate repos/o/r/git/matching-refs/heads/factory/issue-7- "*) [ "$FAIL" != refs ] || return 1
      [ -z "$REFS" ] || printf '%s\n' "$REFS" ;;
    "pr list --repo o/r --head "*) [ "$FAIL" != prs ] || return 1
      jq -c --arg b "$6" '.[$b] // []' <<<"$PRS" | jq -r "${@: -1}" ;;
    *) echo "unexpected gh call: $*" >&2; return 1 ;;
  esac
}
fails=0
check() {
  local name="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1; fi
}
jobs_for() { echo 7 | to_jobs 3>&1 >/dev/null 2>&1; }
log_for() { echo 7 | to_jobs 3>/dev/null 2>&1 | paste -sd'|' -; }

check "the highest run number wins, compared as numbers" factory/issue-7-a-1000 \
  "$(printf '%s\n' factory/issue-7-a-100 factory/issue-7-a-999 factory/issue-7-a-1000 | newest_factory_branch 7)"
check "another issue's branch and an owner branch are ignored" factory/issue-7-a-5 \
  "$(printf '%s\n' factory/issue-70-a-9000 issue-7-mine-8000 factory/issue-7-a-5 'factory/issue-7-A B-9999' | newest_factory_branch 7)"
check "no branch prints nothing" "" "$(newest_factory_branch 7 </dev/null)"

new='{"issue":7,"mode":"new","branch":""}'
FAIL="" REFS="" PRS='{}'
check "no pushed factory branch starts new work from main" "$new" "$(jobs_for)"
check "new work logs no decision of its own" "" "$(log_for)"

REFS=factory/issue-7-add-x-100
check "a pushed branch that no PR used is continued" '{"issue":7,"mode":"continue","branch":"factory/issue-7-add-x-100"}' "$(jobs_for)"
check "a continue is logged" "#7: continue (factory/issue-7-add-x-100 holds an earlier run's work)" "$(log_for)"
check "a dry run logs what it would continue" "#7: would continue (factory/issue-7-add-x-100 holds an earlier run's work)" "$(DRY_RUN=true log_for)"

REFS=$'factory/issue-7-add-x-100\nfactory/issue-7-add-x-300\nfactory/issue-7-add-x-200'
check "of several branches the newest is continued" '{"issue":7,"mode":"continue","branch":"factory/issue-7-add-x-300"}' "$(jobs_for)"

PRS='{"factory/issue-7-add-x-300": [{"number": 40, "isCrossRepository": false}]}'
check "a newest branch that had a PR (closed or merged) gives new work, never an older branch" "$new" "$(jobs_for)"

PRS='{"factory/issue-7-add-x-300": [{"number": 41, "isCrossRepository": true}]}'
check "a fork's PR with the same branch name does not count" '{"issue":7,"mode":"continue","branch":"factory/issue-7-add-x-300"}' "$(jobs_for)"

PRS='{}'
for read in refs prs; do
  FAIL=$read
  check "a failed $read read writes no job" "" "$(jobs_for)"
  check "a failed $read read is logged for a retry" "#7: error (its factory branches could not be read; the next run retries)" "$(log_for)"
done
exit "$fails"
