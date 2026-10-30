#!/usr/bin/env bash
# Usage: bash tests/pick.sh   Exits 1 when a case fails.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_REPOSITORY=o/r GITHUB_REPOSITORY_OWNER=o GITHUB_RUN_ID=0 GITHUB_STEP_SUMMARY=/dev/null
TRIGGER_LABEL=ready-for-agent DRY_RUN=false
source "$root/scripts/orchestrate.sh"
gh() {
  case "$*" in
    "issue list"*) echo 7 ;;
    "api repos/o/r/issues/7") [ "$FAIL" != issue ] || return 1
      echo "{\"user\":{\"login\":\"o\"},\"labels\":[{\"name\":\"ready-for-agent\"}$LABELS],\"sub_issues_summary\":{\"total\":0}}" ;;
    *"/events"*) [ "$FAIL" != events ] || return 1
      echo '{"event":"labeled","label":"ready-for-agent","actor":"o","at":"2026-10-30T09:00:00Z"}'
      [ -z "$CLEARED" ] || echo "{\"event\":\"unlabeled\",\"label\":\"agent:blocked\",\"actor\":\"o\",\"at\":\"$CLEARED\"}" ;;
    *"/blocked_by"*) [ "$FAIL" != blockers ] || return 1 ;;
  esac
}
closing_pr() { [ "$FAIL" != pr ] || return 1; }
closed_factory_prs() { [ "$FAIL" != closed ] || return 1; echo "$CLOSED"; }
block_issue() { echo "block_issue $1 $2" >&2; }
fails=0
check() {
  local name="$1" want="$2" got
  got=$(pick 2>&1 | paste -sd'|' -)
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1; fi
}
skip="#7: error (the issue could not be read; the next run retries)"
LABELS="" CLOSED="[]" CLEARED=""
FAIL=none check "an issue that passes every rule is a candidate" "7"
FAIL=issue check "a failed issue read skips the issue" "$skip"
FAIL=events check "a failed label-history read skips the issue" "$skip"
FAIL=blockers check "a failed blocked-by read skips the issue" "$skip"
FAIL=pr check "a failed open-PR read skips the issue" "$skip"
FAIL=closed check "a failed closed-PR read skips the issue" "$skip"
stopped='#7: skip (stopped: PR #40 was closed without merge)'
CLOSED='[{"pr":40,"closed_at":"2026-10-30T10:00:00Z"}]'
FAIL=none check "a closed factory PR stops the issue and blocks it once" \
  "block_issue 7 Factory stopped: PR #40 was closed without merge.|$stopped"
CLEARED="2026-10-30T11:00:00Z" FAIL=none check "the owner removing agent:blocked after the close clears the stop" "7"
LABELS=',{"name":"agent:blocked"}' CLEARED="" FAIL=none check "a stopped issue that is already blocked is not blocked again" "#7: skip (has agent:blocked)"
LABELS="" CLEARED="" DRY_RUN=true FAIL=none check "a dry run reports the stop and writes nothing" "$stopped"
exit "$fails"
