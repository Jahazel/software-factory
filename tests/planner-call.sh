#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
mkdir "$work/bin"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *git/trees/main*) [ -z "${TREE_FAILS:-}" ] || { echo "HTTP 502: Bad Gateway" >&2; exit 1; }
    echo '["src/a.ts","next.config.ts"]' ;;
  "issue view"*) echo '{"title":"Add a header","body":"Change next.config.ts.","labels":[]}' ;;
  *) echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
EOF
cat > "$work/bin/claude" <<'EOF'
#!/usr/bin/env bash
env > "$STUB_DIR/env"; cat > "$STUB_DIR/stdin"; printf '%s\n' "$*" > "$STUB_DIR/args"
case "$CLAUDE_STUB" in
  ok) echo '{"is_error":false,"structured_output":{"holds":[{"issue":7,"overlaps":["PR #3"],"files":["next.config.ts"]}]}}' ;;
  junk) echo 'not json' ;;
  fail) exit 1 ;;
esac
EOF
chmod +x "$work/bin/gh" "$work/bin/claude"
{ echo 'GITHUB_REPOSITORY_OWNER=o GITHUB_RUN_ID=0; source "$ROOT/scripts/orchestrate.sh"'
  echo 'planner_holds "[7]" "[{\"kind\":\"pr\",\"issue\":2,\"pr\":3,\"title\":\"t\",\"files\":[\"next.config.ts\"]}]"'
} > "$work/call.sh"
fails=0
run() {
  PATH="$work/bin:$PATH" STUB_DIR="$work" CLAUDE_STUB="$1" ROOT="$root" GITHUB_REPOSITORY=o/r \
    GH_TOKEN=gh-secret FACTORY_TOKEN=factory-secret CLAUDE_CODE_OAUTH_TOKEN=claude-secret AGENT_CONFLICTS="migrations/" \
    bash "$work/call.sh" 2>"$work/err"
}
check() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else printf 'FAIL: %s: want [%s], got [%s]\n' "$1" "$2" "$3"; fails=1; fi
}

got=$(run ok) || got="exit $?"
check "a valid answer prints the holds" '[{"issue":7,"overlaps":["PR #3"],"files":["next.config.ts"]}]' "$got"
check "the call gets no GitHub token" "" "$(grep -E '^(GH_TOKEN|FACTORY_TOKEN|GITHUB_TOKEN)=' "$work/env" || true)"
check "the call keeps the Claude sign-in" "CLAUDE_CODE_OAUTH_TOKEN=claude-secret" "$(grep '^CLAUDE_CODE_OAUTH_TOKEN=' "$work/env")"
check "the call has no tools and asks for the schema" "yes" \
  "$(grep -q -- '--tools  --max-turns' "$work/args" && grep -q -- '--json-schema' "$work/args" && echo yes || echo no)"
check "the input is the prompt, then the JSON document" '[[7],["src/a.ts","next.config.ts"],["migrations/"]]' \
  "$(sed -n '/^{/,$p' "$work/stdin" | jq -c '[[.candidates[].issue], .tree, .ignore]')"
check "the prompt comes first" "yes" "$(head -1 "$work/stdin" | grep -q 'software factory' && echo yes || echo no)"

got=$(run junk) && got="exit 0" || got="exit $?: $(cat "$work/err")"
check "an answer that is not valid JSON fails with a reason" "exit 1: invalid output" "$got"
got=$(run fail) && got="exit 0" || got="exit $?: $(cat "$work/err")"
check "a failed call fails with a reason" "exit 1: the Claude call failed or timed out" "$got"
got=$(TREE_FAILS=1 run ok) && got="exit 0" || got="exit $?: $(cat "$work/err")"
check "a failed GitHub read gives the planner's reason, not GitHub's error text" "exit 1: the files on main could not be listed" "$got"
exit "$fails"
