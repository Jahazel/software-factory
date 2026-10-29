#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
export AGENT_CONFLICTS="migrations/"
fails=0
busy='[{"kind":"pr","issue":350,"pr":381,"title":"Security headers","files":["next.config.ts","migrations/0017_x.sql"]},
       {"kind":"worker","issue":355,"pr":null,"title":"Login copy","files":[]}]'
check() {
  local name="$1" want="$2" got
  got=$(jq -n --argjson candidates "$cands" --argjson free "$free" --argjson busy "$busy" --argjson holds "$holds" \
      --arg failure "${failure:-}" --argjson dry_run "${dry:-false}" '$ARGS.named' | plan_decisions \
    | jq -r '"\(.issue) \(.decision) (\(.reason))\(if .start then " START" else "" end)"')
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n--- want\n%s\n--- got\n%s\n' "$name" "$want" "$got"; fails=1; fi
}
starts="claims it and starts a worker"

cands='[360,361,362]' free=2 holds='[]' \
check "no holds: the cap takes the first free candidates" \
"360 start ($starts) START
361 start ($starts) START
362 hold (cap reached; a later run takes it)"

cands='[360,361]' free=1 holds='[{"issue":360,"overlaps":["PR #381"],"files":["next.config.ts"]}]' \
check "a hold on an open PR lets the next candidate take the place" \
"360 hold (overlaps PR #381: next.config.ts)
361 start ($starts) START"

cands='[360]' free=1 holds='[{"issue":360,"overlaps":["#355"],"files":["src/app/login/page.tsx"]}]' \
check "a hold on a running worker's issue counts" \
"360 hold (overlaps #355: src/app/login/page.tsx)"

cands='[360,361]' free=2 holds='[{"issue":361,"overlaps":["#360"],"files":["src/a.ts"]}]' \
check "a hold on an earlier candidate that starts counts" \
"360 start ($starts) START
361 hold (overlaps #360: src/a.ts)"

cands='[360,361]' free=1 holds='[{"issue":360,"overlaps":["#361"],"files":["src/a.ts"]}]' \
check "a hold on a later candidate is ignored, so the older issue wins" \
"360 start (planner hold ignored: no overlap with an open PR, a running worker, or an earlier candidate that starts) START
361 hold (cap reached; a later run takes it)"

cands='[360,361]' free=2 holds='[{"issue":360,"overlaps":["PR #381"],"files":["next.config.ts"]},{"issue":361,"overlaps":["#360"],"files":["src/a.ts"]}]' \
check "a hold on a candidate that is itself held is ignored" \
"360 hold (overlaps PR #381: next.config.ts)
361 start (planner hold ignored: no overlap with an open PR, a running worker, or an earlier candidate that starts) START"

cands='[360]' free=1 holds='[{"issue":360,"overlaps":["PR #999","#998"],"files":["src/a.ts"]}]' \
check "a hold on an unknown PR or issue is ignored" \
"360 start (planner hold ignored: no overlap with an open PR, a running worker, or an earlier candidate that starts) START"

cands='[360]' free=1 holds='[{"issue":360,"overlaps":["PR #381"],"files":["migrations/0017_y.sql","migrations/meta/_journal.json"]}]' \
check "a hold with files only under agent-conflicts paths is ignored" \
"360 start (planner hold ignored: it names no file outside migrations/) START"

cands='[360]' free=1 holds='[{"issue":360,"overlaps":["PR #381"],"files":[]}]' \
check "a hold with no files is ignored" \
"360 start (planner hold ignored: it names no file outside migrations/) START"

cands='[360]' free=1 holds='[{"issue":360,"overlaps":["PR #999","PR #381","#355"],"files":["migrations/0017_y.sql","a.ts","b.ts","c.ts","d.ts"]}]' \
check "the reason names only the known targets and at most 3 files outside agent-conflicts paths" \
"360 hold (overlaps PR #381, #355: a.ts, b.ts, c.ts)"

cands='[360]' free=1 holds='[{"issue":42,"overlaps":["PR #381"],"files":["next.config.ts"]}]' \
check "a hold for an issue that is not a candidate changes nothing" \
"360 start ($starts) START"

cands='[360]' free=1 holds='[{"issue":360,"overlaps":["PR #381"],"files":["next.config.ts"]},{"issue":360,"overlaps":["#355"],"files":["src/b.ts"]}]' \
check "two holds for one candidate are joined" \
"360 hold (overlaps PR #381, #355: next.config.ts, src/b.ts)"

cands='[360,361,362]' free=2 holds=null failure='invalid output' \
check "planner failure: the first candidate starts and the rest hold" \
"360 start (planner unavailable: invalid output; started the first candidate only) START
361 hold (planner unavailable: invalid output; started the first candidate only)
362 hold (planner unavailable: invalid output; started the first candidate only)"

cands='[360,361]' free=0 holds=null failure='invalid output' \
check "planner failure still obeys the cap" \
"360 hold (cap reached; a later run takes it)
361 hold (planner unavailable: invalid output; started the first candidate only)"

cands='[360]' free=1 holds='[]' failure='' dry=true \
check "dry run says would start" \
"360 would start (would add agent:in-progress and start a worker) START"

cands='[]' free=1 holds='[]' check "no candidates prints nothing" ""

check_holds() {
  local name="$1" want="$2" got
  got=$(valid_holds <<<"$3" | jq -c . 2>/dev/null) || got=FAIL
  if [ "$got" = "$want" ]; then echo "ok: holds: $name"
  else printf 'FAIL: holds: %s: want %s, got %s\n' "$name" "$want" "$got"; fails=1; fi
}
check_holds "a valid answer" '[{"issue":360,"overlaps":["PR #381"],"files":["a.ts"]}]' \
  '{"is_error":false,"structured_output":{"holds":[{"issue":360,"overlaps":["PR #381"],"files":["a.ts"]}]}}'
check_holds "no holds" '[]' '{"is_error":false,"structured_output":{"holds":[]}}'
check_holds "an error result" FAIL '{"is_error":true,"structured_output":{"holds":[]}}'
check_holds "no structured output" FAIL '{"is_error":false,"result":"{\"holds\":[]}"}'
check_holds "holds is not an array" FAIL '{"is_error":false,"structured_output":{"holds":{"360":[]}}}'
check_holds "a hold with a text issue number" FAIL '{"is_error":false,"structured_output":{"holds":[{"issue":"360","overlaps":[],"files":[]}]}}'
check_holds "a hold with a fraction" FAIL '{"is_error":false,"structured_output":{"holds":[{"issue":360.5,"overlaps":[],"files":[]}]}}'
check_holds "a hold without files" FAIL '{"is_error":false,"structured_output":{"holds":[{"issue":360,"overlaps":["PR #381"]}]}}'
check_holds "a hold with a number in overlaps" FAIL '{"is_error":false,"structured_output":{"holds":[{"issue":360,"overlaps":[381],"files":[]}]}}'
check_holds "not JSON" FAIL 'Error: rate limited'
exit "$fails"
