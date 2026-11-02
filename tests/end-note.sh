#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
init='{"type":"system","subtype":"init","model":"claude-opus-5-5"}'
max_turns='{"type":"result","subtype":"error_max_turns","is_error":true,"errors":["Reached maximum number of turns (1)"]}'
api_error='{"type":"result","subtype":"success","is_error":true,"result":"There'"'"'s an issue with the selected model (claude-x). It may not exist or you may not have access to it."}'
clean='{"type":"result","subtype":"success","is_error":false,"result":"pr feat(x): add x"}'

note() {
  local transcript_lines="$1" fill_outbox="${2:-:}"
  rm -rf "$work/out" "$work/t.jsonl"; mkdir -p "$work/out"
  [ "$transcript_lines" = no-transcript ] || printf '%s\n' "$transcript_lines" > "$work/t.jsonl"
  (cd "$work/out" && eval "$fill_outbox")
  write_end_note "$work/out" "$work/t.jsonl" https://run
}
check() {
  local name="$1" want="$2" got
  got=$(cat "$work/out/blocked.md" 2>/dev/null || echo "(no blocked.md)")
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n--- want\n%s\n--- got\n%s\n' "$name" "$want" "$got"; fails=1; fi
}

note "$init"$'\n'"$max_turns"
check "a turn limit names the limit" "Factory worker stopped: the agent ended with an error (error_max_turns): Reached maximum number of turns (1)

Run: https://run"

note "$init"$'\n'"$api_error"
check "an API error quotes Claude Code's message" "Factory worker stopped: the agent ended with an error: There's an issue with the selected model (claude-x). It may not exist or you may not have access to it.

Run: https://run"

note "$init"$'\n''{"type":"assistant","message":{"content":[{"type":"te'
check "a transcript cut off mid-line says the agent never finished" "Factory worker stopped: the agent ended with no final result, so a time limit, a crash, or a cancel stopped it.

Run: https://run"

note no-transcript
check "no transcript says the agent never started" "Factory worker stopped: the agent did not start.

Run: https://run"

note "$init"$'\n'"$clean"
check "a clean finish writes nothing" "(no blocked.md)"

note "$init"$'\n'"$api_error" 'echo "feat(x): add x" > pr.md'
check "an agent's PR is kept, with no block" "(no blocked.md)"

note "$init"$'\n'"$max_turns" 'echo "Factory worker blocked: the test needs a service." > blocked.md'
check "an agent's own blocked note is kept" "Factory worker blocked: the test needs a service."

long=$(printf 'y%.0s' {1..400})
note "$init"$'\n'"{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":true,\"result\":\"$long\\nsecond line\"}"
check "a long message keeps its first 300 characters of the first line" "Factory worker stopped: the agent ended with an error: $(printf 'y%.0s' {1..300})

Run: https://run"
exit "$fails"
