#!/usr/bin/env bash
# Usage: publish.sh <outbox>   Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER,
# GITHUB_RUN_ID, ISSUE, MODE (new or resolve), BRANCH, PROMPT, RUN_URL.
# Outbox files: head.bundle (from pack-outbox.sh), pr.md (title line, blank line, body), draft
# (opens the PR as a draft), follow-ups.md (one ready-for-human issue for the PR's Open items),
# comments/*.md, blocked.md; the gardener also writes issues/*.md ("title: ..." and "labels: ..."
# lines, a blank line, the body), report.md, and close.
# Exit 0 after a refusal: it blocks the issue or PR. Exit 1 when GitHub fails: settle then blocks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
repo="$GITHUB_REPOSITORY"
max_bytes=60000
gardener_labels="gardening:refactor-idea gardening:cleanup"

text_refusal() {
  local f
  for f in "$1"/pr.md "$1"/follow-ups.md "$1"/blocked.md "$1"/report.md "$1"/comments/*.md "$1"/issues/*.md; do
    [ -e "$f" ] || continue
    [ -f "$f" ] && [ ! -L "$f" ] || { echo "${f#"$1"/} is not a plain file"; return; }
    [ "$(wc -c <"$f")" -le "$max_bytes" ] || { echo "${f#"$1"/} is larger than $max_bytes bytes"; return; }
    [ -n "$(head -1 "$f" | tr -d '[:space:]')" ] || { echo "${f#"$1"/} has an empty first line"; return; }
  done
}

# Reads closing references (from closing_refs) on stdin; $1 names where they came from.
closing_refusal() {
  local n labels
  for n in $(grep -vx "$ISSUE" | sort -u); do
    [[ "$n" =~ ^[0-9]+$ ]] || { echo "$1 closes $n, which is not in this repo"; return; }
    [ "$PROMPT" = gardener.md ] || { echo "$1 closes #$n, which is not issue #$ISSUE"; return; }
    labels=$(gh issue view "$n" --repo "$repo" --json state,labels --jq 'select(.state == "OPEN") | [.labels[].name] | join(",")') || return 1
    [[ ",$labels," == *",gardening:lesson,"* ]] || { echo "$1 closes #$n, which is not an open gardening:lesson issue"; return; }
  done
}

post_once() {
  local first comments
  first=$(head -1 "$2")
  comments=$(gh api --paginate "repos/$repo/issues/$1/comments" --jq '.[].body | split("\n")[0]') || return 1
  grep -qxF "$first" <<<"$comments" && return 0
  gh api "repos/$repo/issues/$1/comments" -f body="$(cat "$2")

$publish_marker" >/dev/null
}

block_target() {
  post_once "$1" "$2" || return 1
  gh api "repos/$repo/issues/$1/labels" -f 'labels[]=agent:blocked' >/dev/null
}

refuse_and_exit() {
  local note
  note=$(mktemp)
  echo "Factory publish refused: $2. Run: $RUN_URL" >"$note"
  echo "Refused: $2"
  block_target "$1" "$note" || exit 1
  exit 0
}

pgit() {
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="http.https://github.com/.extraheader" \
    GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')" \
    git -C "$work" -c core.hooksPath=/dev/null "$@"
}

fetch_and_check_branch() {
  local bundle="$1" remote_tip base violations reason
  pgit fetch --quiet origin "+refs/heads/main:refs/remotes/origin/main" || return 1
  remote_tip=$(pgit ls-remote origin "refs/heads/$BRANCH" | awk '{ print $1 }') || return 1
  [ -z "$remote_tip" ] || pgit fetch --quiet origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" || return 1
  pgit bundle verify --quiet "$bundle" >/dev/null 2>&1 || { echo "the commits could not be read"; return; }
  pgit fetch --quiet "$bundle" "+refs/heads/$BRANCH:refs/factory/head" 2>/dev/null || { echo "the bundle holds no branch $BRANCH"; return; }
  base=$(pgit merge-base refs/remotes/origin/main refs/factory/head) || { echo "the branch shares no history with main"; return; }
  violations=$(cd "$work" && tree_violations "$base" refs/factory/head) || { echo "the changed files could not be checked"; return; }
  [ -z "$violations" ] || { echo "the change touches files only the owner may change: $(paste -sd, - <<<"$violations" | sed 's/,/, /g')"; return; }
  # A push runs the pushed commit's workflows, so a branch from an older main could run removed ones.
  pgit diff --quiet refs/remotes/origin/main refs/factory/head -- .github .gitmodules || { echo "the branch's .github/ differs from main's"; return; }
  reason=$(pgit log --format=%B "$base..refs/factory/head" | closing_refs | closing_refusal "a commit message") || return 1
  [ -z "$reason" ] || { echo "$reason"; return; }
  if [ "$MODE" = resolve ]; then
    pgit merge-base --is-ancestor "refs/remotes/origin/$BRANCH" refs/factory/head || echo "the new head does not build on the PR's head; the factory never force-pushes"
  elif [ -n "$remote_tip" ] && [ "$remote_tip" != "$(pgit rev-parse refs/factory/head)" ]; then
    echo "branch $BRANCH already holds other commits"
  fi
}

# Prints the number of the open PR on BRANCH, after it opens one when none is open.
open_pr() {
  local pr_file="$1" draft="$2" body existing url
  existing=$(gh pr list --repo "$repo" --head "$BRANCH" --state open --json number --jq '.[0].number // ""') || return 1
  [ -z "$existing" ] || { echo "$existing"; return 0; }
  body=$(mktemp)
  tail -n +3 "$pr_file" >"$body"
  # Not grep -q: its early exit fails the pipe under pipefail and adds a second Closes line.
  closing_refs <"$body" | grep -x "$ISSUE" >/dev/null || printf '\nCloses #%s\n' "$ISSUE" >>"$body"
  url=$(gh pr create --repo "$repo" --base main --head "$BRANCH" ${draft:+--draft} \
    --title "$(head -1 "$pr_file" | sed -E 's/^#+ *//')" --body-file "$body") || return 1
  [[ "$url" =~ /pull/([0-9]+)$ ]] || { echo "gh pr create printed no PR URL: $url" >&2; return 1; }
  echo "${BASH_REMATCH[1]}"
}

file_follow_ups() {
  local pr="$1" title="Follow-ups from PR #$1" body found
  found=$(gh issue list --repo "$repo" --state all --label ready-for-human --limit 500 --json title) || return 1
  [ -z "$(jq -r --arg t "$title" '.[] | select(.title == $t) | .title' <<<"$found")" ] || return 0
  gh label create ready-for-human --repo "$repo" --color D93F0B --description "Needs the owner; the factory never starts it" >/dev/null 2>&1 || true
  body=$(mktemp)
  { echo "Found while working #$ISSUE in PR #$pr, outside that issue's scope. The factory never starts this issue; the owner decides what to do with each item."; echo; cat "$2"; } >"$body"
  gh issue create --repo "$repo" --title "$title" --label ready-for-human --body-file "$body" >/dev/null || return 1
  echo "Filed $title."
}

# Prints GitHub's own list of the issues the open PR on BRANCH closes, in closing_refs form.
linked_issues() {
  gh pr view "$BRANCH" --repo "$repo" --json closingIssuesReferences \
    | jq -r --arg repo "$repo" '.closingIssuesReferences[]
      | if ("\(.repository.owner.login)/\(.repository.name)" | ascii_downcase) == ($repo | ascii_downcase)
        then .number else "\(.repository.owner.login)/\(.repository.name)#\(.number)" end'
}

create_issue() {
  local title labels keep=() label body
  title=$(sed -n '1s/^title: *//p' "$1")
  labels=$(sed -n '2s/^labels: *//p' "$1")
  [ -n "$title" ] || { echo "Skipped ${1##*/}: no title line."; return 0; }
  for label in ${labels//,/ }; do [[ " $gardener_labels " == *" $label "* ]] && keep+=(--label "$label"); done
  [ -z "$(gh issue list --repo "$repo" --state open --search "\"$title\" in:title" --json title | jq -r --arg t "$title" '.[] | select(.title == $t) | .title')" ] || return 0
  body=$(mktemp)
  tail -n +4 "$1" >"$body"
  gh issue create --repo "$repo" --title "$title" --body-file "$body" ${keep[@]+"${keep[@]}"} >/dev/null
}

[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
outbox="$1"
work=$(mktemp -d "${RUNNER_TEMP:-/tmp}/publish-XXXXXX")/clone

if [ "$MODE" = resolve ]; then
  target=$(gh pr list --repo "$repo" --head "$BRANCH" --state open --json number,isCrossRepository \
    --jq '[.[] | select(.isCrossRepository | not)] | .[0].number // ""')
  [ -n "$target" ] || { echo "No open PR on $BRANCH; nothing to publish."; exit 0; }
  valid_factory_branch "$BRANCH" "$ISSUE" || refuse_and_exit "$target" "branch $BRANCH is not a factory branch of issue #$ISSUE"
else
  target="$ISSUE"
  author=$(gh issue view "$ISSUE" --repo "$repo" --json author --jq .author.login)
  [ "$author" = "$GITHUB_REPOSITORY_OWNER" ] || { echo "Issue #$ISSUE was opened by $author, not the owner."; exit 1; }
  valid_factory_branch "$BRANCH" "$ISSUE" "$GITHUB_RUN_ID" || refuse_and_exit "$target" "branch $BRANCH is not this run's factory branch"
fi
if [ "$PROMPT" = gardener.md ]; then
  gh issue view "$ISSUE" --repo "$repo" --json labels --jq '[.labels[].name] | index("gardening:report") != null' | grep -qx true \
    || refuse_and_exit "$target" "a gardener run works only on a gardening:report issue"
fi
if [ ! -d "$outbox" ]; then echo "No outbox: the agent job ended early. Settle releases the claim."; exit 0; fi
outbox=$(cd "$outbox" && pwd)

reason=$(text_refusal "$outbox")
[ -z "$reason" ] || refuse_and_exit "$target" "$reason"
if [ -f "$outbox/pr.md" ]; then
  [ "$MODE" = new ] || refuse_and_exit "$target" "a resolve job opens no PR"
  [ -f "$outbox/head.bundle" ] || refuse_and_exit "$target" "the PR has no commits"
  reason=$(closing_refs <"$outbox/pr.md" | closing_refusal "the PR body") || exit 1
  [ -z "$reason" ] || refuse_and_exit "$target" "$reason"
  reason=$(pr_body_refusal "$outbox")
  [ -z "$reason" ] || refuse_and_exit "$target" "$reason"
fi
if [ -f "$outbox/head.bundle" ]; then
  git clone --quiet --filter=blob:none --no-checkout "${PUBLISH_REMOTE:-https://github.com/$repo}" "$work"
  reason=$(fetch_and_check_branch "$outbox/head.bundle") || exit 1
  [ -z "$reason" ] || refuse_and_exit "$target" "$reason"
fi

for f in "$outbox"/comments/*.md; do [ ! -f "$f" ] || [ "$MODE" != new ] || post_once "$target" "$f"; done
if [ -f "$outbox/head.bundle" ]; then
  pgit push --quiet origin "refs/factory/head:refs/heads/$BRANCH"
  echo "Pushed $BRANCH."
fi
if [ -f "$outbox/pr.md" ]; then
  pr=$(open_pr "$outbox/pr.md" "$([ ! -e "$outbox/draft" ] || echo draft)") || exit 1
  echo "PR #$pr is open."
  reason=$(linked_issues | closing_refusal "GitHub says the PR") || exit 1
  if [ -n "$reason" ]; then
    gh pr close "$BRANCH" --repo "$repo" >/dev/null
    refuse_and_exit "$target" "$reason; the PR is closed"
  fi
  [ ! -f "$outbox/follow-ups.md" ] || file_follow_ups "$pr" "$outbox/follow-ups.md" || exit 1
fi
if [ "$PROMPT" = gardener.md ]; then
  for f in "$outbox"/issues/*.md; do [ ! -f "$f" ] || create_issue "$f"; done
  [ ! -f "$outbox/report.md" ] || gh issue edit "$ISSUE" --repo "$repo" --body-file "$outbox/report.md" >/dev/null
fi
if [ -f "$outbox/blocked.md" ]; then
  block_target "$target" "$outbox/blocked.md"
  echo "Blocked #$target."
elif [ "$PROMPT" = gardener.md ] && [ -e "$outbox/close" ]; then
  gh issue close "$ISSUE" --repo "$repo" --reason completed >/dev/null
fi
echo "Published the outbox of #$ISSUE."
