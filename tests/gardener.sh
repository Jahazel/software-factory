#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/scripts/gardener.sh"
source "$root/scripts/lib.sh"
fails=0
expect() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else echo "FAIL: $1: got [$2], want [$3]"; fails=1; fi
}

expect "summer time: the 12:00 UTC cron is 07:00 in Chicago" "$(cron_local_hour '0 12 * * 1' -0500)" 7
expect "summer time: the 13:00 UTC cron is 08:00 in Chicago" "$(cron_local_hour '0 13 * * 1' -0500)" 8
expect "winter time: the 13:00 UTC cron is 07:00 in Chicago" "$(cron_local_hour '0 13 * * 1' -0600)" 7
expect "winter time: the 12:00 UTC cron is 06:00 in Chicago" "$(cron_local_hour '0 12 * * 1' -0600)" 6
expect "an offset east of UTC wraps past midnight" "$(cron_local_hour '0 22 * * 1' +0530)" 3

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cat > "$work/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$*" in
  "pr list"*) echo '[{"number":401,"headRefName":"issue-400-gardening-report-2026-11-02","body":"Closes #400\nCloses #390","closingIssuesReferences":[],"isCrossRepository":false,"labels":[]}]' ;;
  "issue list"*) [ "${LABELED:-}" = yes ] && echo '[400]' || echo '[]' ;;
esac
GH
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GITHUB_REPOSITORY=o/r

expect "the orchestrator skips the report issue: its open PR closes it" "$(closing_pr 400)" 401
expect "the gardener PR closes the lesson it handles" "$(closing_pr 390)" 401
expect "before the start label, the gardener PR is not a factory PR" "$(factory_prs)" ""
expect "after the start label, the factory refreshes the gardener PR" "$(LABELED=yes factory_prs)" "401 400 issue-400-gardening-report-2026-11-02 false"
exit "$fails"
