#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/scripts/lib.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
check_body() {
  local name="$1" body="$2" want="$3" got
  rm -rf "$work/out"; mkdir "$work/out"
  printf 'feat(x): add x\n\n%s\n' "$body" > "$work/out/pr.md"
  [ -z "${DRAFT:-}" ] || touch "$work/out/draft"
  got=$(pr_body_refusal "$work/out")
  if { [ -z "$want" ] && [ -z "$got" ]; } || { [ -n "$want" ] && [[ "$got" == *"$want"* ]]; }; then
    echo "ok: $name"
  else
    printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1
  fi
}
check() {
  local name="$1" want="$2" section body=""
  shift 2
  for section in "$@"; do body+="## $section"$'\ntext\n'; done
  check_body "$name" "$body" "$want"
}
check "the four pr sections in order pass" "" "Problem" "Summary" "Evidence" "Merge Danger"
check "a body with no Evidence is refused" 'the PR body has no "## Evidence" section' "Problem" "Summary" "Merge Danger"
check "Summary before Problem is refused" '"## Problem" out of order' "Summary" "Problem" "Evidence" "Merge Danger"
check "the PR #425 shape is refused at its first unknown section" '"## Verification" section, which a factory PR may not use' "Summary" "Test seams" "Verification" "Decisions" "Review findings" "Open items"
check "an unknown section is refused" '"## Verification" section, which a factory PR may not use' "Problem" "Summary" "Verification" "Evidence" "Merge Danger"
check "a repeated section is refused" '"## Summary" twice' "Problem" "Summary" "Summary" "Evidence" "Merge Danger"
check "a refusal lists what was found and the allowed order" 'found: Problem, Summary, Merge Danger; allowed, in this order: Decisions to confirm, Review not finished, Problem, Summary, Evidence, Merge Danger, Decisions, Test seams, Review findings, Open items' "Problem" "Summary" "Merge Danger"
DRAFT=1 check "every section in order passes in a draft PR" "" "Decisions to confirm" "Review not finished" "Problem" "Summary" "Evidence" "Merge Danger" "Decisions" "Test seams" "Review findings" "Open items"
check "a lead section is refused in a ready PR" '"## Decisions to confirm", which belongs only in a draft PR' "Decisions to confirm" "Problem" "Summary" "Evidence" "Merge Danger"
DRAFT=1 check "a lead section after Problem is refused in a draft PR" '"## Decisions to confirm" out of order' "Problem" "Decisions to confirm" "Summary" "Evidence" "Merge Danger"

four=$'## Problem\nx\n## Summary\nx\n## Evidence\nx\n## Merge Danger\nx'
check_body "a ## line inside a code fence is not a section" "$four"$'\n```text\n## Fake\n```\n~~~\n## Fake\n~~~' ""
check_body "### and ##x lines are not sections" "$four"$'\n### Before\n##NoSpace' ""
check_body "trailing spaces and a carriage return after a heading pass" $'## Problem  \r\nx\n## Summary\t\nx\n## Evidence\nx\n## Merge Danger \r\nx' ""
check_body "the title line is not part of the body" $'## Summary\nx\n## Evidence\nx\n## Merge Danger\nx' 'no "## Problem" section'
check_body "a tilde fence line inside a backtick fence does not close it" "$four"$'\n```\n~~~\n## Fake\n```' ""
check_body "a shorter backtick line inside a longer fence does not close it" "$four"$'\n````markdown\n```\n## Fake\n```\n````' ""
check_body "a fence line with a language name does not close a fence" "$four"$'\n```md\n```python\n## Fake\n```' ""
check_body "inline triple backticks do not open a fence" "$four"$'\n```x``` is inline code.\n## Verification' '"## Verification" section, which a factory PR may not use'
check_body "a shorter tilde line inside a longer tilde fence does not close it" "$four"$'\n~~~~\n~~~\n## Fake\n~~~~' ""
check_body "a fence line indented four spaces does not close a fence" "$four"$'\n```\n    ```\n## Fake\n```' ""
check_body "a fence that never closes hides the headings after it" "$four"$'\n```\n## Fake' ""
check_body "a tab after ## still makes a section" "$four"$'\n##\tVerification' '"## Verification" section, which a factory PR may not use'
check_body "a heading indented up to three spaces is a section" "$four"$'\n   ## Verification' '"## Verification" section, which a factory PR may not use'
check_body "closing # marks are not part of the heading" $'## Problem ##\nx\n## Summary\nx\n## Evidence #\nx\n## Merge Danger\nx' ""
check "a draft-only refusal lists the allowed order" 'allowed, in this order: Decisions to confirm, Review not finished, Problem, Summary, Evidence, Merge Danger, Decisions, Test seams, Review findings, Open items' "Review not finished" "Problem" "Summary" "Evidence" "Merge Danger"

rm -rf "$work/out"; mkdir "$work/out"
out=$(bash "$root/scripts/check-pr.sh" "$work/out" 2>&1) && code=0 || code=$?
if [ "$code" = 1 ] && [ "$out" = "$work/out/pr.md does not exist" ]; then echo "ok: check-pr.sh names a missing pr.md"; else echo "FAIL: check-pr.sh with no pr.md: exit $code, [$out]"; fails=1; fi

check_body "setup: a body with no Problem" $'## Summary\nx\n## Evidence\nx\n## Merge Danger\nx' 'no "## Problem"'
out=$(bash "$root/scripts/check-pr.sh" "$work/out") && code=0 || code=$?
if [ "$code" = 1 ] && [ "$out" = "$(pr_body_refusal "$work/out")" ]; then echo "ok: check-pr.sh exits 1 and prints the publish reason"; else echo "FAIL: check-pr.sh on a bad body: exit $code, [$out]"; fails=1; fi
check_body "setup: a good body" "$four" ""
out=$(bash "$root/scripts/check-pr.sh" "$work/out") && code=0 || code=$?
if [ "$code" = 0 ] && [ -z "$out" ]; then echo "ok: check-pr.sh is silent on a good body"; else echo "FAIL: check-pr.sh on a good body: exit $code, [$out]"; fails=1; fi

template=$(awk '/^```markdown$/ { f = 1; next } f && /^```$/ { exit } f && /^## / { sub(/^## /, ""); print }' "$root/claude/skills/pr/SKILL.md")
required=$(printf '%s\n' "${pr_required_headings[@]}")
if [ -n "$template" ] && [ "$template" = "$required" ]; then echo "ok: the required sections match the pr skill's template"; else printf 'FAIL: pr skill template [%s] differs from required [%s]\n' "$template" "$required"; fails=1; fi
prose_list() { local s; s=$(printf '`%s`, ' "$@"); s=${s%, }; if [ $# = 2 ]; then echo "${s/, / and }"; else echo "${s%, *}, and ${s##*, }"; fi; }
check_prompt() { grep -qF -- "$2" "$root/prompts/$1.md" && echo "ok: $1.md lists $2" || { echo "FAIL: $1.md does not list $2"; fails=1; }; }
check_prompt worker "$(prose_list "${pr_lead_headings[@]}")"
for prompt in worker gardener; do
  check_prompt "$prompt" "$(prose_list "${pr_required_headings[@]}")"
  check_prompt "$prompt" "$(prose_list "${pr_tail_headings[@]}")"
done
exit "$fails"
