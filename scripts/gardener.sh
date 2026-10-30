#!/usr/bin/env bash
# Opens this week's gardening report issue. The gardener worker reads the issue as its input and
# writes its report into it. Tests source this file; it then sets up the functions but runs nothing.
# Usage: gardener.sh   Needs GH_TOKEN (the owner's token, so the worker accepts the issue as the
# owner's), GITHUB_REPOSITORY, GITHUB_EVENT_NAME, SCHEDULE (the cron line that fired; empty when
# started by hand), TIME_ZONE, HOUR. Writes issue=<n> to GITHUB_OUTPUT, or issue=0 when no pass
# runs now.
set -euo pipefail
repo="${GITHUB_REPOSITORY:-}"

# GitHub cron runs in UTC, so a project that wants one local hour all year lists both UTC hours.
cron_local_hour() {
  local cron_line="$1" utc_offset="$2" utc_hour sign
  utc_hour=$(awk '{ print $2 }' <<<"$cron_line")
  sign="${utc_offset:0:1}1"
  echo $(( (10#$utc_hour + sign * 10#${utc_offset:1:2} + 24) % 24 ))
}

window_start() {
  gh issue list --repo "$repo" --state all --label gardening:report --limit 1 --json createdAt \
    --jq '.[0].createdAt // (now - 604800 | todate)'
}

[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
out="${GITHUB_OUTPUT:-/dev/stdout}"
today=$(TZ="$TIME_ZONE" date +%F)
title="Gardening report $today"

if [ "$GITHUB_EVENT_NAME" = schedule ]; then
  local_hour=$(cron_local_hour "$SCHEDULE" "$(TZ="$TIME_ZONE" date +%z)")
  if [ "$local_hour" != "$HOUR" ]; then
    echo "This cron fires at $local_hour:00 in $TIME_ZONE today, not $HOUR:00. The other cron runs the pass."
    echo "issue=0" >> "$out"; exit 0
  fi
  existing=$(gh issue list --repo "$repo" --state all --label gardening:report --limit 5 --json number,title \
    | jq -r --arg title "$title" 'map(select(.title == $title)) | .[0].number // ""')
  if [ -n "$existing" ]; then
    echo "Issue #$existing already holds today's pass."
    echo "issue=0" >> "$out"; exit 0
  fi
fi

gh label create gardening:report --repo "$repo" --color 0E8A16 \
  --description "The weekly gardener's report" >/dev/null 2>&1 || true

since=$(window_start)
url=$(gh issue create --repo "$repo" --label gardening:report --title "$title" --body "**Type:** Gardening report. The weekly gardener writes its report here.

Window: PRs merged since $since.")
echo "Opened $url. Window starts $since."
echo "issue=${url##*/}" >> "$out"
