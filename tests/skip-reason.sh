#!/usr/bin/env bash
# Usage: bash tests/skip-reason.sh   Exits 1 when a case fails.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
fails=0
check() {
  local name="$1" want="$2" facts="$3" got
  got=$(jq -c '{owner: "jahazel", author: "jahazel", labeler: "jahazel", labels: ["agent:implement"],
      sub_issues: 0, open_pr: "", blockers: "", stopped: ""} + .' <<<"$facts" | skip_reason)
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1; fi
}
check "an issue that passes every rule is a candidate" "" '{}'
check "not opened by the owner" "not opened by the owner" '{"author": "someone"}'
check "label added by someone else" "label not added by the owner" '{"labeler": "someone"}'
check "a gardening report" "a gardening report; the gardener's PR is its work" '{"labels": ["agent:implement", "gardening:report"]}'
check "a person must do the work" "has ready-for-human" '{"labels": ["agent:implement", "ready-for-human"]}'
check "a label first in the list still counts" "has ready-for-human" '{"labels": ["ready-for-human", "agent:implement"]}'
check "a parent issue or spec" "has 3 sub-issues" '{"sub_issues": 3}'
check "blocked label" "has agent:blocked" '{"labels": ["agent:implement", "agent:blocked"]}'
check "the owner closed a factory PR" "stopped: PR #40 was closed without merge" '{"stopped": "PR #40 was closed without merge"}'
check "a block comes before the stop" "has agent:blocked" '{"labels": ["agent:implement", "agent:blocked"], "stopped": "PR #40 was closed without merge"}'
check "already claimed" "a worker already has it" '{"labels": ["agent:implement", "agent:in-progress"]}'
check "an open PR closes it" "open PR #12 closes it" '{"open_pr": "12"}'
check "open blocking issues" "blocked by #4, #5" '{"blockers": "#4, #5"}'
check "the owner rules come first" "not opened by the owner" '{"author": "someone", "labels": ["agent:implement", "ready-for-human"]}'
exit "$fails"
