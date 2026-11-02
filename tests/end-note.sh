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

run_end_note() {
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

stopped() { printf 'Factory worker stopped: %s Run: https://run\n\n%s' "$1" "$retry_hint"; }
error_result() { printf '{"type":"result","subtype":"success","is_error":true%s}' "$1"; }

run_end_note "$init"$'\n'"$max_turns"
check "a turn limit names the limit" "$(stopped "the agent ended with an error (error_max_turns): Reached maximum number of turns (1).")"

run_end_note "$init"$'\n'"$api_error"
check "an API error quotes Claude Code's message" "$(stopped "the agent ended with an error: There's an issue with the selected model (claude-x). It may not exist or you may not have access to it.")"

run_end_note "$init"$'\n'"$(error_result ',"result":"from result","errors":["from errors"]')"
check "the result text wins over the errors list" "$(stopped "the agent ended with an error: from result.")"

run_end_note "$init"$'\n'"$(error_result ',"result":"first line\nsecond line"')"
check "only the first line of the message is kept" "$(stopped "the agent ended with an error: first line.")"

for empty in ',"result":""' ',"errors":[]' ''; do
  run_end_note "$init"$'\n'"$(error_result "$empty")"
  check "an empty or missing message says only that the agent ended with an error" "$(stopped "the agent ended with an error.")"
done

run_end_note "$init"$'\n'"$(error_result ',"result":"Is the model right?"')"
check "a message that ends a sentence gets no extra period" "$(stopped "the agent ended with an error: Is the model right?")"

run_end_note "$init"$'\n'"$(error_result ',"result":"an early error"')"$'\n'"$clean"
check "the last result line decides" "(no blocked.md)"

run_end_note "$init"$'\n''{"type":"assistant","message":{"content":[{"type":"te'
check "a transcript cut off mid-line says the agent never finished" "$(stopped "the agent ended with no final result, so a time limit, a crash, or a cancel stopped it.")"

run_end_note no-transcript
check "no transcript says the agent never started" "$(stopped "the agent did not start.")"

run_end_note ""
check "an empty transcript says the agent never started" "$(stopped "the agent did not start.")"

run_end_note "$init"$'\n'"$clean"
check "a clean finish writes nothing" "(no blocked.md)"

run_end_note "$init"$'\n'"$api_error" 'echo "feat(x): add x" > pr.md'
check "an agent's PR is kept, with no block" "(no blocked.md)"

run_end_note "$init"$'\n'"$api_error" 'ln -s /nonexistent pr.md'
check "an agent's pr.md symlink is left for publish to refuse" "(no blocked.md)"

run_end_note "$init"$'\n'"$max_turns" 'echo "Factory worker blocked: the test needs a service." > blocked.md'
check "an agent's own blocked note is kept" "Factory worker blocked: the test needs a service."

long=$(printf 'y%.0s' {1..400})
run_end_note "$init"$'\n'"$(error_result ",\"result\":\"$long\"")"
check "a long message keeps its first 300 characters" "$(stopped "the agent ended with an error: $(printf 'y%.0s' {1..300}).")"

run_end_note "$init"$'\n'"$(error_result ',"result":"Stopped!  "')"
check "trailing spaces are trimmed, and ! ends the sentence" "$(stopped "the agent ended with an error: Stopped!")"

step_if=$(awk '$0 == "      - name: Note why the agent stopped" { on = 1; next } on && /^        if:/ { print; exit }' "$(dirname "$0")/../.github/workflows/worker.yml")
if [[ "$step_if" == *"inputs.branch == ''"* && "$step_if" == *"inputs.prompt == ''"* ]]; then
  echo "ok: the note step runs only for new-issue runs with the default prompt (no resolve, no gardener)"
else echo "FAIL: the note step's condition lets resolve or gardener runs through: $step_if"; fails=1; fi
exit "$fails"
