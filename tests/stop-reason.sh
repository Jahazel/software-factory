#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
fails=0
check() {
  local name="$1" want="$2" facts="$3" got
  got=$(stop_reason <<<"$facts")
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1; fi
}
check "no closed factory PR" "" '{"closed_prs": [], "cleared_at": ""}'
check "a closed PR with no clearing stops the issue" "PR #40 was closed without merge" \
  '{"closed_prs": [{"pr": 40, "closed_at": "2026-10-30T10:00:00Z"}], "cleared_at": ""}'
check "a PR closed before the owner cleared the block no longer stops" "" \
  '{"closed_prs": [{"pr": 40, "closed_at": "2026-10-30T10:00:00Z"}], "cleared_at": "2026-10-30T11:00:00Z"}'
check "a PR closed after the clearing stops again" "PR #41 was closed without merge" \
  '{"closed_prs": [{"pr": 40, "closed_at": "2026-10-30T10:00:00Z"}, {"pr": 41, "closed_at": "2026-10-30T12:00:00Z"}], "cleared_at": "2026-10-30T11:00:00Z"}'
check "the newest closed PR is named" "PR #41 was closed without merge" \
  '{"closed_prs": [{"pr": 41, "closed_at": "2026-10-30T12:00:00Z"}, {"pr": 40, "closed_at": "2026-10-30T10:00:00Z"}], "cleared_at": ""}'
exit "$fails"
