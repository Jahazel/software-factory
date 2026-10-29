#!/usr/bin/env bash
# Usage: bash tests/pick.sh   Exits 1 when a case fails.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_REPOSITORY=o/r GITHUB_REPOSITORY_OWNER=o GITHUB_RUN_ID=0 GITHUB_STEP_SUMMARY=/dev/null
source "$root/scripts/orchestrate.sh"
gh() {
  case "$*" in
    "issue list"*) echo 7 ;;
    "api repos/o/r/issues/7") [ "$FAIL" != issue ] || return 1
      echo '{"user":{"login":"o"},"labels":[{"name":"agent:implement"}],"sub_issues_summary":{"total":0}}' ;;
    *"/events"*) [ "$FAIL" != events ] || return 1; echo o ;;
    *"/blocked_by"*) [ "$FAIL" != blockers ] || return 1 ;;
  esac
}
closing_pr() { [ "$FAIL" != pr ] || return 1; }
fails=0
check() {
  local name="$1" want="$2" got
  got=$(pick 2>&1 | paste -sd'|' -)
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1; fi
}
skip="#7: skip (could not read the issue from GitHub; the next run retries)"
FAIL=none check "an issue that passes every rule is a candidate" "7"
FAIL=issue check "a failed issue read skips the issue" "$skip"
FAIL=events check "a failed label-history read skips the issue" "$skip"
FAIL=blockers check "a failed blocked-by read skips the issue" "$skip"
FAIL=pr check "a failed open-PR read skips the issue" "$skip"
exit "$fails"
