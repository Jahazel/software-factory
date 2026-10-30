#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_REPOSITORY=o/r GITHUB_REPOSITORY_OWNER=o GITHUB_RUN_ID=0 GITHUB_STEP_SUMMARY=/dev/null TRIGGER_LABEL=ready-for-agent
source "$root/scripts/orchestrate.sh"
DRY_RUN=false AGENT_CONFLICTS=migrations/ CAP=2
calls=$(mktemp)
busy_items() { [ "$BUSY" != fail ] || return 1; echo "$BUSY"; }
planner_holds() {
  echo called >> "$calls"
  [ "$HOLDS" != fail ] || { echo "the Claude call failed or timed out" >&2; return 1; }
  echo "$HOLDS"
}
fails=0
cands="" running=0 reserved=0 busy="[]"
check() {
  local name="$1" out starts log
  : > "$calls"
  out=$(mktemp)
  starts=$(printf '%s\n' $cands | BUSY="$busy" HOLDS="${holds:-[]}" plan "$reserved" 3>&1 >"$out" | paste -sd' ' -)
  log=$(paste -sd'|' - < "$out")
  if [ "$(wc -l < "$calls" | tr -d ' ')" = "$2" ] && [ "$starts" = "$3" ] && [ "$log" = "$4" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  calls %s (want %s)\n  starts [%s] (want [%s])\n  log %s\n  want %s\n' \
    "$name" "$(wc -l < "$calls" | tr -d ' ')" "$2" "$starts" "$3" "$log" "$4"; fails=1; fi
}
pr='[{"kind":"pr","issue":350,"pr":381,"title":"t","files":["next.config.ts"]}]'
start="start (claims it and starts a worker)"
cap="hold (cap reached; a later run takes it)"

cands="7 8" running=1 reserved=1 busy="$pr" \
check "no free place: no call" 0 "" "#7: $cap|#8: $cap"
cands="7 8" running=1 reserved=0 busy='[]' \
check "nothing busy and one free place: no call" 0 "7" "#7: $start|#8: $cap"
cands="7" running=0 reserved=0 busy='[]' \
check "nothing busy and one candidate: no call" 0 "7" "#7: $start"
cands="7 8" running=0 reserved=0 busy='[]' \
check "nothing busy, two candidates, two places: one call" 1 "7 8" "#7: $start|#8: $start"
cands="7 8" running=1 reserved=0 busy="$pr" holds='[{"issue":7,"overlaps":["PR #381"],"files":["next.config.ts"]}]' \
check "busy work: one call, and a hold moves the place to the next issue" 1 "8" \
  "#7: hold (overlaps PR #381: next.config.ts)|#8: $start"
cands="7 8" running=0 reserved=0 busy="$pr" holds=fail \
check "planner failure: the first candidate starts, the rest hold" 1 "7" \
  "::warning::Planner unavailable: the Claude call failed or timed out. Only the first candidate may start.|#7: start (planner unavailable: the Claude call failed or timed out; started the first candidate only)|#8: hold (planner unavailable: the Claude call failed or timed out; started the first candidate only)"
cands="7 8" running=0 reserved=0 busy=fail \
check "busy work cannot be listed: no call, the first candidate starts" 0 "7" \
  "::warning::Planner unavailable: the work in flight could not be listed. Only the first candidate may start.|#7: start (planner unavailable: the work in flight could not be listed; started the first candidate only)|#8: hold (planner unavailable: the work in flight could not be listed; started the first candidate only)"
cands="" running=0 reserved=0 busy="$pr" \
check "no candidates: nothing" 0 "" ""
exit "$fails"
