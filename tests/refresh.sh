#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cat > "$work/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "gh $*" >> "$GH_LOG"
case "$*" in
  "api repos/o/r/commits/main"*) echo mainsha ;;
  "pr list"*) echo '[{"number":381,"headRefName":"factory/issue-350-x-1","body":"Closes #350","closingIssuesReferences":[{"number":350}],"isCrossRepository":false,"labels":[]}]' ;;
  "issue view"*) echo false ;;
  *"repos/o/r/merges"*) printf 'HTTP/2.0 %s\n' "$MERGE_STATUS" ;;
  *"/contents/migrations"*) echo "" ;;
esac
GH
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GH_LOG="$work/gh.log"
GITHUB_REPOSITORY=o/r GITHUB_REPOSITORY_OWNER=o GITHUB_RUN_ID=0 GITHUB_STEP_SUMMARY=/dev/null TRIGGER_LABEL=ready-for-agent
source "$root/scripts/orchestrate.sh"
DRY_RUN=false AGENT_CONFLICTS=migrations/ FACTORY_TOKEN=t
fails=0
check() {
  local name="$1" merge_status="$2" cap="$3" want_jobs="$4" want_log="$5" jobs log
  : > "$GH_LOG"
  jobs=$(MERGE_STATUS="$merge_status" CAP="$cap" running=0 refresh 3>&1 >"$work/out" | paste -sd' ' -)
  log=$(paste -sd'|' - < "$work/out")
  if grep -qE "/(labels|comments)|issue edit" "$GH_LOG"; then echo "FAIL: $name: refresh blocked the PR"; fails=1
  elif [ "$jobs" = "$want_jobs" ] && [ "$log" = "$want_log" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  jobs [%s]\n  want [%s]\n  log  %s\n  want %s\n' "$name" "$jobs" "$want_jobs" "$log" "$want_log"; fails=1; fi
}
job='{"issue":350,"mode":"resolve","branch":"factory/issue-350-x-1","pr":381,"main":"mainsha"}'
check "any merge conflict gets a resolve worker, not a block" 409 1 "$job" \
  "PR #381: resolve (merging main conflicts; a worker merges main)"
check "a conflict with no free place waits for one" 409 0 "" \
  "PR #381: hold (merging main conflicts; needs a resolve worker; cap reached)"
check "a clean merge needs no worker" 201 1 "" \
  "PR #381: refresh (merged main into factory/issue-350-x-1; checks run again)"
exit "$fails"
