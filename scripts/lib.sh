#!/usr/bin/env bash
# Rules that the orchestrator, the settle job, prepare-issue, publish, check-pr, and the worker job share. Source this file; it runs nothing.
# Its GitHub rules need GH_TOKEN and GITHUB_REPOSITORY.
publish_marker="<!-- factory-publish -->"
closed_pr_lookback=200
retry_hint="To retry, remove \`agent:blocked\`."
evidence_max_files=20
evidence_max_bytes=10485760

# Prints the number of an open PR that closes issue $1, or nothing. A PR counts by GitHub's link,
# by a factory branch factory/issue-<n>-, or by an owner branch issue-<n>-.
closing_pr() {
  gh pr list --repo "$GITHUB_REPOSITORY" --state open --limit 200 \
    --json number,headRefName,closingIssuesReferences \
    | jq -r --argjson n "$1" '[.[] | select((.closingIssuesReferences | map(.number) | index($n)) or (.headRefName | test("^(factory/)?issue-\($n)-")))] | .[0].number // ""'
}

# Fails when label $1 is one the factory or the owner uses for something other than starting work.
valid_trigger() {
  case "$1" in agent:in-progress|agent:blocked|ready-for-human|gardening:*|"") return 1 ;; esac
}

# The factory's branch for new work on issue $1 with title $2 in run $3.
factory_branch() {
  local slug
  slug=$(tr '[:upper:]' '[:lower:]' <<<"$2" | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40 | sed -E 's/-+$//')
  echo "factory/issue-$1-$slug-$3"
}

# Succeeds when $1 is a factory branch of issue $2, and of run $3 when $3 is given.
valid_factory_branch() {
  [[ "$1" =~ ^factory/issue-$2-[a-z0-9-]*[a-z0-9]$ ]] || return 1
  [ -z "${3:-}" ] || [[ "$1" == *"-$3" ]]
}

# Reads branch names on stdin. Prints the factory branch of issue $1 with the highest run number,
# or nothing. Run IDs grow over time, so the highest is the newest.
newest_factory_branch() {
  local b
  while IFS= read -r b; do
    if valid_factory_branch "$b" "$1" && [[ "$b" =~ -([0-9]+)$ ]]; then echo "${BASH_REMATCH[1]} $b"; fi
  done | sort -k1,1n | tail -1 | cut -d' ' -f2-
}

# Prints the pushed factory branch that a retry of issue $1 continues, or nothing for new work from
# main: the issue's newest factory branch, when no PR from this repo ever used it. A used branch
# had a PR that merged or that the owner closed, so its work is not reused, and no older branch is.
# Returns 1 when GitHub cannot be read.
continue_branch() {
  local refs newest used
  refs=$(gh api --paginate "repos/$GITHUB_REPOSITORY/git/matching-refs/heads/factory/issue-$1-" \
    --jq '.[].ref | ltrimstr("refs/heads/")') || return 1
  newest=$(newest_factory_branch "$1" <<<"$refs")
  [ -n "$newest" ] || return 0
  used=$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$newest" --state all --limit 200 \
    --json number,isCrossRepository --jq '[.[] | select(.isCrossRepository | not)] | length') || return 1
  [ "$used" != 0 ] || echo "$newest"
}

# Reads one labeled issue's facts as JSON on stdin: owner, author, labeler (who last added the
# trigger label), labels, sub_issues (count), open_pr, blockers, stopped (stop_reason). Prints why
# the orchestrator skips the issue, or nothing when it is a candidate.
skip_reason() {
  jq -r 'if .author != .owner then "not opened by the owner"
      elif .labeler != .owner then "label not added by the owner"
      elif .labels | index("gardening:report") then "a gardening report; the gardener'\''s PR is its work"
      elif .labels | index("ready-for-human") then "has ready-for-human"
      elif .sub_issues > 0 then "has \(.sub_issues) sub-issues"
      elif .labels | index("agent:blocked") then "has agent:blocked"
      elif .stopped != "" then "stopped: \(.stopped)"
      elif .labels | index("agent:in-progress") then "a worker already has it"
      elif .open_pr != "" then "open PR #\(.open_pr) closes it"
      elif .blockers != "" then "blocked by \(.blockers)"
      else "" end'
}

# Prints the text the worker and the planner read for issue $1: title, labels, body, and the parent
# issue's title and body when the body has a "## Parent" section.
issue_brief() {
  local json parent
  json=$(gh issue view "$1" --repo "$GITHUB_REPOSITORY" --json title,body,labels) || return 1
  echo "# Issue #$1: $(jq -r .title <<<"$json")"
  echo
  echo "Labels: $(jq -r '[.labels[].name] | join(", ")' <<<"$json")"
  echo
  jq -r .body <<<"$json"
  parent=$(jq -r .body <<<"$json" | awk '/^## Parent/{f=1;next} f && match($0,/#[0-9]+/){print substr($0,RSTART+1,RLENGTH-1); exit}')
  [ -n "$parent" ] || return 0
  json=$(gh issue view "$parent" --repo "$GITHUB_REPOSITORY" --json title,body) || return 1
  echo
  echo "# Parent issue #$parent: $(jq -r .title <<<"$json")"
  echo
  jq -r .body <<<"$json"
}

# Prints one line per factory PR, by PR number: <pr> <issue> <branch> <has agent:blocked: true|false>
# A factory PR is an open PR into main, from this repo, on a factory/issue-<n>- branch.
factory_prs() {
  local prs
  prs=$(gh pr list --repo "$GITHUB_REPOSITORY" --state open --base main --limit 200 \
    --json number,headRefName,isCrossRepository,labels) || return 1
  jq -r '[.[] | select(.isCrossRepository | not)
        | (.headRefName | capture("^factory/issue-(?<n>[0-9]+)-").n // empty | tonumber) as $n
        | . + {issue: $n}]
      | sort_by(.number) | .[]
      | "\(.number) \(.issue) \(.headRefName) \([.labels[].name] | index("agent:blocked") != null)"' <<<"$prs"
}

# Prints issue $1's factory PRs that were closed without merge, as [{pr, closed_at}].
closed_factory_prs() {
  gh pr list --repo "$GITHUB_REPOSITORY" --state closed --base main --limit "$closed_pr_lookback" \
    --json number,headRefName,mergedAt,closedAt,isCrossRepository \
    | jq -c --argjson n "$1" '[.[] | select((.isCrossRepository | not) and .mergedAt == null
        and (.headRefName | test("^factory/issue-\($n)-"))) | {pr: .number, closed_at: .closedAt}]'
}

# Reads {closed_prs: [{pr, closed_at}], cleared_at} on stdin: the closed factory PRs of one issue,
# and when the owner last removed agent:blocked from it ("" for never). Prints why the factory must
# not retry the issue, or nothing.
stop_reason() {
  jq -r '[.cleared_at as $c | .closed_prs[] | select(.closed_at > $c)] | max_by(.closed_at)
    | if . == null then "" else "PR #\(.pr) was closed without merge" end'
}

# Prints the paths between commits $1 and $2 (in the current repo) that the factory never pushes for
# an agent, one "<path>: <why>" line each. A pushed workflow file runs with the repo's secrets.
tree_violations() {
  [ -n "$1" ] || { echo "tree_violations: no base commit" >&2; return 1; }
  python3 -c '
import subprocess, sys
parts = subprocess.run(["git", "diff", "--raw", "--no-renames", "-z", sys.argv[1], sys.argv[2]],
                       check=True, stdout=subprocess.PIPE).stdout.split(b"\0")
for meta, path in zip(parts[0::2], parts[1::2]):
    old_mode, new_mode = meta.decode().lstrip(":").split()[:2]
    try:
        name = path.decode()
    except UnicodeDecodeError:
        print(path.decode(errors="backslashreplace") + ": file name is not UTF-8")
        continue
    if name.startswith(".github/"): print(f"{name}: under .github/")
    elif name == ".gitmodules" or "160000" in (old_mode, new_mode): print(f"{name}: submodule")
    elif "120000" in (old_mode, new_mode): print(f"{name}: symbolic link")
' "$1" "$2"
}

# Reads text on stdin and prints each issue that a GitHub closing keyword in it names, one per
# line: the number for an issue in $GITHUB_REPOSITORY, the raw reference for any other repo. It
# reads bytes. The keyword must start a word, so `onClose` or `disclosed` is no keyword. Only
# spacing, a colon, or markdown emphasis (`*`, `_`) may follow it, so a sentence that ends in
# "close." does not close the number that starts the next one.
closing_refs() {
  local ref repo_lc
  repo_lc=$(tr '[:upper:]' '[:lower:]' <<<"$GITHUB_REPOSITORY")
  { LC_ALL=C tr '\n\t\r' '   ' | LC_ALL=C grep -aoiE '(^|[^A-Za-z0-9])(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]*_:]*((https?://)?(www\.)?github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+|[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+|#[0-9]+|gh-[0-9]+)' || true; } \
    | LC_ALL=C sed -E 's/^[^A-Za-z]?[A-Za-z]+[[:space:]*_:]*//' | while IFS= read -r ref; do
      case "$(tr '[:upper:]' '[:lower:]' <<<"$ref")" in
        "#"*|gh-*|"$repo_lc#"*|*"github.com/$repo_lc/issues/"*) echo "${ref##*[#/-]}" ;;
        *) echo "$ref" ;;
      esac
    done
}

# Reads conflicting paths on stdin. Prints "agent" when the list is not empty and every path starts
# with one of the space-separated prefixes in AGENT_CONFLICTS, else "owner".
classify_conflict() {
  local path prefix prefixes any=false matched
  read -ra prefixes <<<"${AGENT_CONFLICTS:-}"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    any=true matched=false
    for prefix in ${prefixes[@]+"${prefixes[@]}"}; do
      [[ "$path" == "$prefix"* ]] && matched=true
    done
    [ "$matched" = true ] || { echo owner; return; }
  done
  if [ "$any" = true ]; then echo agent; else echo owner; fi
}

# Reads the planner's claude --output-format json document on stdin. Prints its holds array when
# every hold has an integer issue and string lists overlaps and files. Any other shape returns 1,
# so a half-valid answer is never partly used.
valid_holds() {
  jq -ec 'select(.is_error == false and (.structured_output | type == "object")
      and (.structured_output.holds | type == "array" and all(.[];
        type == "object"
        and (.issue | type == "number" and . == floor)
        and (.overlaps | type == "array" and all(.[]; type == "string"))
        and (.files | type == "array" and all(.[]; type == "string")))))
    | .structured_output.holds' 2>/dev/null
}

# Reads {candidates (oldest first), free, busy, holds, failure, dry_run} on stdin; holds is null when
# the planner failed. Prints one {issue, decision, reason, start} line per candidate, in order.
# A hold on a newer or held candidate is ignored, so the older issue wins and no two holds wait on
# each other.
plan_decisions() {
  jq -c --arg ignore "${AGENT_CONFLICTS:-}" '
    def dedupe: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);
    . as {candidates: $cands, free: $free, busy: $busy, holds: $holds, failure: $failure, dry_run: $dry}
    | ($ignore | split(" ") | map(select(. != ""))) as $prefixes
    | ($busy | map(.pr | select(. != null))) as $prs
    | ($busy | map(.issue)) as $issues
    | def open_pr: test("^PR #[0-9]+$") and (.[4:] | tonumber) as $p | $prs | any(. == $p);
      def busy_issue: test("^#[0-9]+$") and (.[1:] | tonumber) as $m | $issues | any(. == $m);
      def earlier_candidate($n; $held): test("^#[0-9]+$") and (.[1:] | tonumber) as $m
        | $m < $n and ($cands | any(. == $m)) and ($held | any(. == $m) | not);
      def outside_agent_conflicts: . as $f | $prefixes | any(. as $p | $f | startswith($p)) | not;
    (if $dry then {decision: "would start", reason: "would add agent:in-progress and start a worker"}
     else {decision: "start", reason: "claims it and starts a worker"} end) as $start
    | {decision: "hold", reason: "cap reached; a later run takes it"} as $cap
    | "planner unavailable: \($failure); started the first candidate only" as $unavailable
    | reduce $cands[] as $n ({free: $free, held: [], out: []};
        . as $s
        | def start_or_cap($why): if $s.free > 0 then $start + $why else $cap end;
        ($holds // [] | map(select(.issue == $n))) as $mine
        | ($mine | map(.overlaps[]) | dedupe
            | map(select(open_pr or busy_issue or earlier_candidate($n; $s.held)))) as $targets
        | ($mine | map(.files[]) | dedupe | map(select(outside_agent_conflicts))) as $files
        | ($s.out == []) as $first
        | (if $holds == null then
             if $first then start_or_cap({reason: $unavailable}) else {decision: "hold", reason: $unavailable} end
           elif $mine == [] then start_or_cap({})
           elif $targets == [] then
             start_or_cap({reason: "planner hold ignored: no overlap with an open PR, a running worker, or an earlier candidate that starts"})
           elif $files == [] then
             start_or_cap({reason: "planner hold ignored: it names no file\(if $prefixes == [] then "" else " outside \($prefixes | join(", "))" end)"})
           else {decision: "hold", reason: "overlaps \($targets | join(", ")): \($files[:3] | join(", "))", planned: true} end) as $d
        | ($d.decision != "hold") as $go
        | .free -= (if $go then 1 else 0 end)
        | .held += (if $d.planned then [$n] else [] end)
        | .out += [{issue: $n, decision: $d.decision, reason: $d.reason, start: $go}])
    | .out[]'
}

# Reads file names on stdin. Prints each leading number that two or more names share, such as
# 0017 for 0017_a.sql and 0017_b.sql. Names that do not start with a digit are ignored.
repeated_numbers() {
  sed -nE 's/^([0-9]+)_.*/\1/p' | sort | uniq -d
}

# Prints "<path>: <numbers>" for each AGENT_CONFLICTS path where branch $1 repeats a leading file
# number that main does not repeat. A clean merge can bring in such a pair with no text conflict.
# Returns 1 when a folder cannot be read.
repeated_migrations() {
  local prefix prefixes on_branch on_main numbers
  read -ra prefixes <<<"${AGENT_CONFLICTS:-}"
  for prefix in ${prefixes[@]+"${prefixes[@]}"}; do
    on_branch=$(gh api "repos/$GITHUB_REPOSITORY/contents/${prefix%/}?ref=$1" --jq '.[] | select(.type == "file") | .name' | repeated_numbers) || return 1
    on_main=$(gh api "repos/$GITHUB_REPOSITORY/contents/${prefix%/}?ref=main" --jq '.[] | select(.type == "file") | .name' | repeated_numbers) || return 1
    numbers=$(comm -23 <(grep . <<<"$on_branch" || true) <(grep . <<<"$on_main" || true) | paste -sd, - | sed 's/,/, /g')
    [ -z "$numbers" ] || echo "$prefix: $numbers"
  done
}

# Comments on PR $1 with the first line $2, unless the same comment is already there, and adds
# agent:blocked to it. Safe to run again after a partial failure.
block_pr() {
  local comments
  comments=$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$1/comments" --jq '.[].body') || return 1
  if ! grep -qxF "$2" <<<"$comments"; then
    gh api "repos/$GITHUB_REPOSITORY/issues/$1/comments" -f body="$2

Merge main by hand, then remove \`agent:blocked\` from this PR." >/dev/null || return 1
  fi
  gh api "repos/$GITHUB_REPOSITORY/issues/$1/labels" -f 'labels[]=agent:blocked' >/dev/null
}

# Checks a resolve job's PR $1 on branch $2 after its worker ended. The branch must hold main as of
# decide ($3) and no repeated migration number. Otherwise the PR is blocked, so the next refresh
# does not start the same paid resolve worker again. $4 is the run link. Returns 1 when GitHub
# cannot answer; nothing is blocked then.
settle_resolve() {
  local pr="$1" branch="$2" main="$3" run_url="$4" blocked missing repeated
  blocked=$(gh api "repos/$GITHUB_REPOSITORY/issues/$pr" --jq '[.labels[].name] | index("agent:blocked") != null') || return 1
  if [ "$blocked" = true ]; then echo "PR #$pr: resolve worker blocked it"; return; fi
  missing=$(gh api "repos/$GITHUB_REPOSITORY/compare/$branch...$main" --jq .ahead_by) || return 1
  if [ "$missing" = 0 ]; then
    repeated=$(repeated_migrations "$branch") || return 1
    if [ -z "$repeated" ]; then echo "PR #$pr: resolved"; return; fi
  fi
  block_pr "$pr" "Factory resolve worker did not finish: the branch is still missing main or repeats a migration number. Run: $run_url" || return 1
  echo "PR #$pr: resolve worker did not finish; added agent:blocked"
}

# The caller's workflow file, such as factory-orchestrator.yml. Inside a called workflow,
# GITHUB_WORKFLOW_REF names the caller.
caller_file() {
  local ref="${GITHUB_WORKFLOW_REF%@*}"
  echo "${ref##*/}"
}

# Comments on issue $1 with the first line $2, unless the same comment is already there, and adds
# agent:blocked.
block_issue() {
  local comments
  comments=$(gh api --paginate "repos/$GITHUB_REPOSITORY/issues/$1/comments" --jq '.[].body') || return 1
  if ! grep -qxF "$2" <<<"$comments"; then
    gh api "repos/$GITHUB_REPOSITORY/issues/$1/comments" -f body="$2

$retry_hint" >/dev/null || return 1
  fi
  gh api "repos/$GITHUB_REPOSITORY/issues/$1/labels" -f 'labels[]=agent:blocked' >/dev/null
}

# Releases the claim on issue $1. Safe to run twice: the second run finds no claim and stops.
# Open PR or agent:blocked: remove agent:in-progress.
# Neither: the worker ended without an answer. Comment once with the run link $2, add
# agent:blocked, then remove agent:in-progress. A failed worker never becomes a candidate again.
settle_issue() {
  local n="$1" run_url="$2" labels pr
  labels=$(gh issue view "$n" --repo "$GITHUB_REPOSITORY" --json labels --jq '[.labels[].name] | join(",")')
  if [[ ",$labels," != *",agent:in-progress,"* ]]; then echo "#$n: no claim to release"; return; fi
  pr=$(closing_pr "$n")
  if [ -n "$pr" ]; then
    echo "#$n: PR #$pr is open; claim released"
  elif [[ ",$labels," == *",agent:blocked,"* ]]; then
    echo "#$n: worker blocked; claim released"
  else
    block_issue "$n" "Factory worker failed: the worker ended with no PR and no blocked comment. Run: $run_url"
    echo "#$n: worker failed; added agent:blocked"
  fi
  gh issue edit "$n" --repo "$GITHUB_REPOSITORY" --remove-label agent:in-progress >/dev/null
}

write_end_note() {
  local outbox="$1" transcript="$2" run_url="$3" note f
  for f in pr.md blocked.md; do [ ! -e "$outbox/$f" ] && [ ! -L "$outbox/$f" ] || return 0; done
  [ -f "$transcript" ] || transcript=/dev/null
  note=$(jq -nrR '[inputs | fromjson? | select(type == "object")] as $lines
    | ($lines | map(select(.type == "result")) | last) as $r
    | if ($lines | length) == 0 then "the agent did not start"
      elif $r == null then "the agent ended with no final result, so a time limit, a crash, or a cancel stopped it"
      elif $r.is_error != true then empty
      else "the agent ended with an error"
        + (if ($r.subtype // "success") == "success" then "" else " (\($r.subtype))" end)
        + (($r.result // ($r.errors // [] | join("; "))) | tostring | split("\n")[0] // "" | .[:300] | sub("\\s+$"; "")
           | if . == "" then "" else ": \(.)" end)
      end
    | if test("[.!?]$") then . else "\(.)." end' <"$transcript")
  [ -z "$note" ] || printf 'Factory worker stopped: %s Run: %s\n\n%s\n' "$note" "$run_url" "$retry_hint" >"$outbox/blocked.md"
}

leaked_token_names() {
  local pair names=""
  local personal_token_pattern='(^|[^A-Za-z0-9_-])(github_pat_[A-Za-z0-9_]{20,}|gh[pour]_[A-Za-z0-9]{30,})'
  while IFS= read -r -d '' pair; do
    [[ "$pair" =~ $personal_token_pattern ]] && names+="${names:+,}${pair%%=*}"
  done
  echo "$names"
}

fail_on_leaked_token() {
  local leaked
  leaked=$(set -o pipefail; env -0 | leaked_token_names) || { echo "::error::Could not read the environment in $1. The step stopped."; exit 1; }
  [ -z "$leaked" ] || { echo "::error::A personal GitHub token is in $leaked, in $1. The step stopped."; exit 1; }
}

pr_lead_headings=("Decisions to confirm" "Review not finished")
pr_required_headings=(Problem Summary Evidence "Merge Danger")
pr_tail_headings=(Decisions "Test seams" "Review findings" "Open items")

# Prints the body of outbox $1's pr.md, the lines after the title and blank line, without its
# fenced code blocks.
pr_body_text() {
  tail -n +3 "$1/pr.md" | awk '
    { line = $0; sub(/[ \t\r]+$/, "", line); sub(/^ ? ? ?/, "", line) }
    fence != "" { if (line ~ /^(`+|~+)$/ && substr(line, 1, 1) == substr(fence, 1, 1) && length(line) >= length(fence)) fence = ""; next }
    match(line, /^(```+|~~~+)/) { m = substr(line, 1, RLENGTH); if (m ~ /^~/ || index(substr(line, RLENGTH + 1), "`") == 0) { fence = m; next } }
    { print }'
}

pr_body_refusal() {
  local allowed=("${pr_lead_headings[@]}" "${pr_required_headings[@]}" "${pr_tail_headings[@]}")
  local found name required i j last=-1 seen=" " hint
  found=$(pr_body_text "$1" | awk '
    { sub(/[ \t\r]+$/, ""); line = $0; sub(/^ ? ? ?/, "", line) }
    line ~ /^##[ \t]+[^ \t]/ { sub(/^##[ \t]+/, "", line); sub(/[ \t]+#+$/, "", line); print line }')
  hint="; found: $(paste -sd, - <<<"$found" | sed 's/,/, /g'); allowed, in this order: $(printf '%s\n' "${allowed[@]}" | paste -sd, - | sed 's/,/, /g')"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    i=-1
    for j in "${!allowed[@]}"; do [ "${allowed[$j]}" != "$name" ] || { i=$j; break; }; done
    [ "$i" -ge 0 ] || { echo "the PR body has a \"## $name\" section, which a factory PR may not use$hint"; return; }
    [[ "$seen" != *" $i "* ]] || { echo "the PR body has \"## $name\" twice$hint"; return; }
    [ "$i" -gt "$last" ] || { echo "the PR body has \"## $name\" out of order$hint"; return; }
    [ "$i" -ge "${#pr_lead_headings[@]}" ] || [ -e "$1/draft" ] || { echo "the PR body has \"## $name\", which belongs only in a draft PR$hint"; return; }
    seen+="$i "; last=$i
  done <<<"$found"
  for required in "${pr_required_headings[@]}"; do
    grep -qxF -- "$required" <<<"$found" || { echo "the PR body has no \"## $required\" section$hint"; return; }
  done
}

# Prints the type that file $1's first bytes show: png, jpg, webp, webm, or nothing.
evidence_type() {
  local hex lead
  hex=$(od -An -v -N64 -tx1 "$1" | tr -d ' \n')
  case "$hex" in
    89504e470d0a1a0a*) echo png ;;
    ffd8ff*) echo jpg ;;
    52494646????????57454250*) echo webp ;;
    1a45dfa3*7765626d*) lead=${hex%%7765626d*}; [ $((${#lead} % 2)) = 1 ] || echo webm ;;
  esac
}

# Prints each name that outbox $1's pr.md shows as an image ![alt](./name), once, outside code:
# the references gh rewrites to the uploaded file.
evidence_refs() {
  pr_body_text "$1" | sed 's/`[^`]*`//g' | { grep -oE '!\[[^]]*\]\(\./[^)[:space:]]+\)' || true; } | sed -E 's/^.*\]\(\.\/(.*)\)$/\1/' | awk '!seen[$0]++'
}

# Prints why outbox $1's evidence/ folder cannot go into the PR, or nothing. A subshell keeps the
# shopt change local.
evidence_refusal() (
  shopt -s dotglob nullglob
  local dir="$1/evidence" f name files=() names="" refs ref
  if [ -e "$dir" ]; then
    [ -d "$dir" ] && [ ! -L "$dir" ] || { echo "evidence is not a folder"; exit 0; }
    files=("$dir"/*)
  fi
  for f in ${files[@]+"${files[@]}"}; do names+="${f##*/}"$'\n'; done
  [ "${#files[@]}" -le "$evidence_max_files" ] || { echo "evidence/ holds ${#files[@]} files; the limit is $evidence_max_files"; exit 0; }
  for f in ${files[@]+"${files[@]}"}; do
    name=${f##*/}
    [ -f "$f" ] && [ ! -L "$f" ] || { echo "evidence/$name is not a plain file"; exit 0; }
    [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*\.(png|jpg|webp|webm)$ && "$name" != *..* ]] \
      || { echo "evidence/$name has a name the factory does not accept: use letters, digits, \".\", \"_\", and \"-\", and end in .png, .jpg, .webp, or .webm"; exit 0; }
    [ "$(wc -c <"$f")" -lt "$evidence_max_bytes" ] || { echo "evidence/$name is not under $evidence_max_bytes bytes"; exit 0; }
    [ "$(evidence_type "$f")" = "${name##*.}" ] || { echo "evidence/$name is not a ${name##*.} file"; exit 0; }
  done
  refs=$(evidence_refs "$1")
  while IFS= read -r ref; do
    [ -z "$ref" ] || grep -qxF -- "$ref" <<<"$names" || { echo "pr.md refers to ./$ref, which is not in evidence/"; exit 0; }
  done <<<"$refs"
  for f in ${files[@]+"${files[@]}"}; do
    grep -qxF -- "${f##*/}" <<<"$refs" || { echo "evidence/${f##*/} is not referred to in pr.md"; exit 0; }
  done
)
