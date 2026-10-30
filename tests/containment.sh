#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
check() {
  if eval "$2"; then echo "ok: $1"; else echo "FAIL: $1"; fails=1; fi
}
job() { awk -v job="  $2:" '$0 == job { on = 1; next } on && /^  [a-z][a-z-]*:$/ { on = 0 } on && !/^ *#/' "$root/.github/workflows/$1"; }

check "the agent's work job exists and never names the owner's token" 'job worker.yml work | grep -q "Work the issue" && ! job worker.yml work | grep -q FACTORY_GITHUB_TOKEN'
check "the work job keeps no git credentials" 'job worker.yml work | grep -q "persist-credentials: false"'
check "the work job cannot write to GitHub" '! job worker.yml work | grep -qE ": write"'
check "the publish job holds the token and runs no agent" 'job worker.yml publish | grep -q FACTORY_GITHUB_TOKEN && ! job worker.yml publish | grep -qE "claude|CLAUDE_CODE_OAUTH_TOKEN"'
check "no prompt tells an agent to write to GitHub" '! grep -nE "git push origin|gh (pr|issue) (create|edit|comment|close)|--add-label" "$root"/prompts/*.md'
check "the planner reads issue text with no tools and without the tokens" \
  'grep -q "env -u FACTORY_TOKEN -u GH_TOKEN timeout 300 claude -p" "$root/scripts/orchestrate.sh" && grep -q -- "--tools \"\"" "$root/scripts/orchestrate.sh"'
exit "$fails"
