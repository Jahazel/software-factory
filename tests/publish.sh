#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$GH_LOG"
case "$*" in
  "issue view 12 "*"--json author"*) echo owner ;;
  "issue view 12 "*"--json labels"*) echo "${REPORT:-false}" ;;
  "issue view 30 "*) echo "${LESSON:-}" ;;
  "pr list "*"--head"*) echo "${OPEN_PR:-}" ;;
  "api --paginate repos/o/r/issues/"*"/comments"*) jq -r "${@: -1}" <<<"${COMMENTS:-[]}" ;;
  "pr view "*"closingIssuesReferences"*) echo "{\"closingIssuesReferences\": ${LINKED:-[]}}" ;;
  "pr close"*) ;;
  "issue list "*) echo "${ISSUES:-[]}" ;;
  "pr create"*)
    body=$(sed -n 's/.*--body-file \([^ ]*\).*/\1/p' <<<"$*")
    sed 's/^/  body: /' "$body" >> "$GH_LOG"
    while [ $# -gt 0 ]; do
      if [ "$1" = --attach ]; then
        if [ -f "$2" ] && [ "${2%/*}" = "$PWD" ]; then echo "  attach: ${2##*/}" >> "$GH_LOG"; else echo "  attach-bad: $2" >> "$GH_LOG"; fi
        shift
      fi
      shift
    done
    echo "https://github.com/o/r/pull/50"
    exit "${ATTACH_EXIT:-0}" ;;
esac
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GH_LOG="$work/gh.log" GH_TOKEN=test-token
export GITHUB_REPOSITORY=o/r GITHUB_REPOSITORY_OWNER=owner GITHUB_RUN_ID=77 ISSUE=12 RUN_URL=https://run
export PUBLISH_REMOTE="$work/origin.git" RUNNER_TEMP="$work/tmp"

git init --quiet --bare -b main "$work/origin.git"
git clone --quiet "$work/origin.git" "$work/seed" 2>/dev/null
git -C "$work/seed" config user.name fixture; git -C "$work/seed" config user.email f@example.invalid
mkdir -p "$work/seed/.github/workflows"; echo ci > "$work/seed/.github/workflows/ci.yml"; echo a > "$work/seed/app.txt"
git -C "$work/seed" add -A; git -C "$work/seed" commit --quiet -m base; git -C "$work/seed" push --quiet origin main

branch=factory/issue-12-add-x-77
write_pr() { printf 'feat(x): add x\n\n## Problem\n\nx is missing.\n\n## Summary\n\nAdds x.\n\n## Evidence\n\nA test.\n\n## Merge Danger\n\nTwo-way.\n%s' "${1:-}" > "$work/out/pr.md"; }
outbox() {
  rm -rf "$work/out" "$work/tmp" "$work/agent"; mkdir -p "$work/out/comments" "$work/tmp"
  git clone --quiet "$work/origin.git" "$work/agent"
  git -C "$work/agent" config user.name agent; git -C "$work/agent" config user.email a@example.invalid
  git -C "$work/agent" switch --quiet -c "$branch"
  (cd "$work/agent" && eval "$1")
  git -C "$work/agent" add -A; git -C "$work/agent" commit --quiet -m change
  bash "$root/scripts/pack-outbox.sh" "$work/agent" "$work/out" "$branch" origin/main >/dev/null
  write_pr
}
fails=0
check() {
  local name="$1" cond="$2"
  if eval "$cond"; then echo "ok: $name"; else echo "FAIL: $name"; sed 's/^/  /' "$GH_LOG"; fails=1; fi
}
run() { : > "$GH_LOG"; MODE="${MODE:-new}" BRANCH="${BRANCH:-$branch}" PROMPT="${PROMPT:-worker.md}" bash "$root/scripts/publish.sh" "$work/out" >"$work/run.log" 2>&1; }
fresh() { git -C "$work/origin.git" update-ref -d "refs/heads/$branch" 2>/dev/null || true; outbox "$1"; }
remote_has() { git -C "$work/origin.git" rev-parse --verify --quiet "refs/heads/$1" >/dev/null; }

outbox 'echo b > app.txt'
printf 'Problem in plain words: x is missing.\n' > "$work/out/comments/01.md"
run
check "a clean outbox pushes the branch" 'remote_has "$branch"'
check "it opens one PR for the branch" 'grep -q "gh pr create --repo o/r --base main --head $branch --title feat(x): add x" "$GH_LOG"'
check "it posts the restatement, marked as the factory's" 'grep -q "factory-publish" "$GH_LOG"'
check "a PR with no draft file opens ready for review" 'grep -q "pr create" "$GH_LOG" && ! grep -q -- "--draft" "$GH_LOG"'
check "a PR with no follow-ups file opens no follow-up issue" '! grep -q "issue create" "$GH_LOG"'

git -C "$work/origin.git" update-ref -d "refs/heads/$branch"
outbox 'echo evil > .github/workflows/leak.yml'
run
check "a workflow change is not pushed" '! remote_has "$branch"'
check "a workflow change blocks the issue" 'grep -q "Factory publish refused: the change touches files only the owner may change: .github/workflows/leak.yml" "$GH_LOG" && grep -q "labels\[\]=agent:blocked" "$GH_LOG"'
check "a refused outbox opens no PR" '! grep -q "pr create" "$GH_LOG"'

outbox 'echo c > app.txt'
BRANCH=factory/issue-12-add-x-78 run
check "another run's branch is refused" 'grep -q "is not this run" "$GH_LOG" && ! remote_has factory/issue-12-add-x-78'

outbox 'echo d > app.txt'
write_pr $'Closes #13\n'
run
check "a PR body that closes another issue is refused" 'grep -q "closes #13, which is not issue #12" "$GH_LOG" && ! remote_has "$branch"'

for body in 'Closes Other/repo#12' 'Fixes: https://github.com/other/repo/issues/12' 'resolves o/r#13'; do
  fresh 'echo d2 > app.txt'
  write_pr "$body"$'\n'
  run
  check "a PR body with \"$body\" is refused" 'grep -q "Factory publish refused: the PR body closes" "$GH_LOG" && ! remote_has "$branch"'
done

fresh 'echo d10 > app.txt'
printf 'feat(x): add x\n\n## Summary\n\nAdds x.\n' > "$work/out/pr.md"
run
check "a PR body without the pr skill's sections is refused before the push" 'grep -q "Factory publish refused: the PR body has no \"## Problem\" section" "$GH_LOG" && grep -q "labels\[\]=agent:blocked" "$GH_LOG" && ! remote_has "$branch" && ! grep -q "pr create" "$GH_LOG"'

fresh 'echo d3 > app.txt'
write_pr $'\nCloses: o/r#12\n'
run
check "a PR body that closes this issue in long form gets no second Closes line" 'grep -q "body: Closes: o/r#12" "$GH_LOG" && ! grep -q "body: Closes #12" "$GH_LOG"'

fresh 'echo d4 > app.txt'
printf '\nSecond line.\n' > "$work/out/comments/01.md"
run
check "a comment with an empty first line is refused" 'grep -q "comments/01.md has an empty first line" "$GH_LOG" && ! remote_has "$branch"'

fresh 'echo d6 > app.txt'
git -C "$work/agent" commit --quiet --allow-empty -m 'Tidy up. Closes #13'
bash "$root/scripts/pack-outbox.sh" "$work/agent" "$work/out" "$branch" origin/main >/dev/null
run
check "a commit message that closes another issue is refused" 'grep -q "a commit message closes #13, which is not issue #12" "$GH_LOG" && ! remote_has "$branch"'

fresh 'echo d7 > app.txt'
LINKED='[{"number": 13, "repository": {"name": "r", "owner": {"login": "o"}}}]' run
check "a PR that GitHub links to another issue is closed and the issue blocked" 'grep -q "gh pr close $branch" "$GH_LOG" && grep -q "GitHub says the PR closes #13" "$GH_LOG" && grep -q "labels\[\]=agent:blocked" "$GH_LOG"'

fresh 'echo d8 > app.txt'
git -C "$work/seed" rm --quiet .github/workflows/ci.yml; git -C "$work/seed" commit --quiet -m "drop ci"; git -C "$work/seed" push --quiet origin main
run
check "a branch whose .github/ differs from main's is refused" 'grep -q "differs from main" "$GH_LOG" && ! remote_has "$branch"'
git -C "$work/seed" revert --quiet --no-edit HEAD; git -C "$work/seed" push --quiet origin main

fresh 'echo d9 > app.txt'
printf '## Summary\nAll good.\n' > "$work/out/comments/01.md"
COMMENTS='[{"body": "Earlier note.\n## Summary\nOld."}]' run
check "a comment is posted when only a later line of an older comment matches its first line" 'grep -q "comments -f body=## Summary" "$GH_LOG"'

fresh 'echo d5 > app.txt'
git -C "$work/agent" switch --quiet --orphan lone
mkdir -p "$work/agent/.github/workflows"; echo evil > "$work/agent/.github/workflows/leak.yml"
git -C "$work/agent" add -A; git -C "$work/agent" commit --quiet -m lone; git -C "$work/agent" branch --quiet -f "$branch" lone
bash "$root/scripts/pack-outbox.sh" "$work/agent" "$work/out" "$branch" "$(git -C "$work/agent" rev-parse origin/main)" >/dev/null
run
check "a branch with no history in common with main is refused" 'grep -q "shares no history with main" "$GH_LOG" && ! remote_has "$branch"'

fresh 'echo h > app.txt'
touch "$work/out/draft"
printf 'feat(x): add x\n\n## Decisions to confirm\n\nA guess.\n\n%s\n' "$(tail -n +3 "$work/out/pr.md")" > "$work/out/pr.md"
printf -- '- The upload screen logs the raw error.\n' > "$work/out/follow-ups.md"
run
check "a draft file opens the PR as a draft, with its lead section" 'grep -q "gh pr create --repo o/r --base main --head $branch --draft" "$GH_LOG"'
check "follow-ups open one ready-for-human issue named after the PR" 'grep -q "gh issue create --repo o/r --title Follow-ups from PR #50 --label ready-for-human" "$GH_LOG"'
rerun=0; ISSUES='[{"title": "Follow-ups from PR #50"}]' OPEN_PR=50 run || rerun=$?
check "a second run succeeds and opens no second follow-ups issue" '[ "$rerun" = 0 ] && grep -q "gh issue list" "$GH_LOG" && ! grep -q "issue create" "$GH_LOG"'

fresh 'echo i > app.txt'
printf '\n- x\n' > "$work/out/follow-ups.md"
run
check "a follow-ups file with an empty first line is refused" 'grep -q "follow-ups.md has an empty first line" "$GH_LOG" && ! remote_has "$branch"'

outbox 'echo e > app.txt'
run
second=0; OPEN_PR=50 run || second=$?
check "a second run with the PR open succeeds and opens no second PR" '[ "$second" = 0 ] && ! grep -q "pr create" "$GH_LOG" && grep -q "Published" "$work/run.log"'

png() { printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR' >"$work/out/evidence/$1"; }
fresh 'echo j > app.txt'
mkdir "$work/out/evidence"; png saved.png; png empty.png
write_pr $'\n![The saved form](./saved.png)\n![The empty form](./empty.png)\n'
run
check "evidence files are attached from gh's current folder, one --attach each" '[ "$(grep -c "  attach: " "$GH_LOG")" = 2 ] && grep -q "  attach: saved.png" "$GH_LOG" && grep -q "  attach: empty.png" "$GH_LOG" && ! grep -q "attach-bad" "$GH_LOG"'
check "the body keeps its ./name references for gh to rewrite" 'grep -q "body: !\[The saved form\](./saved.png)" "$GH_LOG"'

fresh 'echo k > app.txt'
run
check "an outbox with no evidence folder opens the PR with no --attach" 'grep -q "pr create" "$GH_LOG" && ! grep -q -- "--attach" "$GH_LOG"'

fresh 'echo l > app.txt'
mkdir "$work/out/evidence"; printf 'not a picture' >"$work/out/evidence/saved.png"
write_pr $'\n![The saved form](./saved.png)\n'
run
check "a bad evidence file blocks the issue with the reason, before the push" 'grep -q "Factory publish refused: evidence/saved.png is not a png file" "$GH_LOG" && grep -q "issues/12/labels -f labels\[\]=agent:blocked" "$GH_LOG" && ! remote_has "$branch" && ! grep -q "pr create" "$GH_LOG"'

fresh 'echo m > app.txt'
mkdir "$work/out/evidence"; png saved.png
write_pr $'\n![The saved form](./saved.png)\n'
printf -- '- A loose end.\n' > "$work/out/follow-ups.md"
partial=0; ATTACH_EXIT=1 run || partial=$?
check "a partial upload keeps the PR, notes it on the PR, and blocks nothing" '[ "$partial" = 0 ] && grep -q "PR #50 is open" "$work/run.log" && grep -q "issues/50/comments -f body=Factory publish: gh reported an error after it opened this PR" "$GH_LOG" && ! grep -q "labels\[\]=agent:blocked" "$GH_LOG" && grep -q "issue create" "$GH_LOG"'

fresh 'echo o > app.txt'
failed=0; ATTACH_EXIT=1 run || failed=$?
check "a failed gh pr create with no evidence still exits 1" '[ "$failed" = 1 ] && ! grep -q "after it opened this PR" "$GH_LOG"'

git -C "$work/origin.git" update-ref -d "refs/heads/$branch"
outbox 'echo f > app.txt'
rm "$work/out/pr.md"; printf 'Factory worker blocked: the test needs a service.\n' > "$work/out/blocked.md"
run
check "a blocked worker with commits pushes them and blocks the issue" 'remote_has "$branch" && grep -q "labels\[\]=agent:blocked" "$GH_LOG" && ! grep -q "pr create" "$GH_LOG"'

git -C "$work/origin.git" update-ref -d "refs/heads/$branch"
outbox 'echo n > app.txt'
rm "$work/out/pr.md"; printf 'Factory worker blocked: no service.\n' > "$work/out/blocked.md"
mkdir "$work/out/evidence"; printf 'not a picture' >"$work/out/evidence/x.png"
run
check "a blocked worker's evidence folder is ignored" 'grep -q "body=Factory worker blocked: no service." "$GH_LOG" && ! grep -q "refused" "$GH_LOG"'

git -C "$work/agent" switch --quiet --detach origin/main
git -C "$work/agent" branch --quiet -f "$branch" origin/main
outbox 'echo g > app.txt'
rm -f "$work/out/pr.md"
MODE=resolve OPEN_PR=50 BRANCH="$branch" run
check "a resolve push that drops the PR's commits is refused" 'grep -q "does not build on the pushed head of $branch" "$GH_LOG"'
old=factory/issue-12-add-x-50
# Pushes $old: main plus one commit that writes $1 (default old), as a run that blocked left it.
seed_old() {
  git -C "$work/seed" switch --quiet --detach main
  echo "${1:-old}" > "$work/seed/old.txt"; git -C "$work/seed" add -A; git -C "$work/seed" commit --quiet -m old
  git -C "$work/seed" push --quiet --force origin "HEAD:refs/heads/$old"; git -C "$work/seed" switch --quiet main
}
# A continue run's outbox: the agent starts from the pushed $old and runs $1 (nothing when empty).
continued() {
  rm -rf "$work/out" "$work/tmp" "$work/agent"; mkdir -p "$work/out/comments" "$work/tmp"
  git clone --quiet "$work/origin.git" "$work/agent"
  git -C "$work/agent" config user.name agent; git -C "$work/agent" config user.email a@example.invalid
  git -C "$work/agent" switch --quiet -c "$old" "origin/$old"
  if [ -n "$1" ]; then
    (cd "$work/agent" && eval "$1")
    git -C "$work/agent" add -A; git -C "$work/agent" commit --quiet -m more
  fi
  bash "$root/scripts/pack-outbox.sh" "$work/agent" "$work/out" "$old" "origin/$old" >/dev/null
  write_pr
}
cont() { MODE=continue BRANCH="$old" run; }
tip() { git -C "$work/origin.git" rev-parse "refs/heads/$1"; }

seed_old; continued 'echo p > app.txt'
printf 'Factory note.\n' > "$work/out/comments/01.md"
cont
check "a continue run pushes onto an earlier run's branch and opens the PR from it" '[ "$(tip "$old")" = "$(git -C "$work/agent" rev-parse HEAD)" ] && grep -q "gh pr create --repo o/r --base main --head $old" "$GH_LOG"'
check "a continue run posts its comments on the issue" 'grep -q "issues/12/comments -f body=Factory note." "$GH_LOG"'

seed_old; before=$(tip "$old"); continued ''
cont
check "a continue run with no new commit opens the PR from the pushed head" '[ "$(tip "$old")" = "$before" ] && grep -q "gh pr create --repo o/r --base main --head $old" "$GH_LOG" && ! grep -q "Pushed" "$work/run.log"'

git -C "$work/seed" push --quiet --force origin "main:refs/heads/$old"; continued ''
cont
check "a continued branch with nothing past main is refused" 'grep -q "Factory publish refused: the branch holds no commits past main" "$GH_LOG" && ! grep -q "pr create" "$GH_LOG"'

seed_old; continued 'echo q > app.txt'
seed_old rewritten; moved=$(tip "$old")
cont
check "a continue head that drops the pushed commits is refused" 'grep -q "does not build on the pushed head of $old" "$GH_LOG" && [ "$(tip "$old")" = "$moved" ]'

seed_old; continued ''
git -C "$work/origin.git" update-ref -d "refs/heads/$old"
cont
check "a continued branch that is gone is refused" 'grep -q "branch $old is gone from GitHub" "$GH_LOG" && ! grep -q "pr create" "$GH_LOG"'

seed_old; continued ''
MODE=continue BRANCH=factory/issue-13-add-x-50 run
check "a continue run on another issue's branch is refused" 'grep -q "is not a factory branch of issue #12" "$GH_LOG" && ! grep -q "pr create" "$GH_LOG"'

seed_old; continued ''
git -C "$work/seed" rm --quiet .github/workflows/ci.yml; git -C "$work/seed" commit --quiet -m "drop ci"; git -C "$work/seed" push --quiet origin main
cont
check "a pushed head whose .github/ differs from main's is refused" 'grep -q "differs from main" "$GH_LOG" && ! grep -q "pr create" "$GH_LOG"'
git -C "$work/seed" revert --quiet --no-edit HEAD >/dev/null; git -C "$work/seed" push --quiet origin main

seed_old; continued 'echo r > app.txt'
rm "$work/out/head.bundle"
cont
check "a continue run whose commits did not reach the outbox is refused" 'grep -q "Factory publish refused: the PR has no commits" "$GH_LOG" && ! grep -q "pr create" "$GH_LOG"'

seed_old; continued ''
git -C "$work/agent" switch --quiet --detach; git -C "$work/agent" branch --quiet -D "$old"
bash "$root/scripts/pack-outbox.sh" "$work/agent" "$work/out" "$old" "origin/$old" >/dev/null
cont
check "a continue run whose branch is gone locally is refused" 'grep -q "Factory publish refused: the PR has no commits" "$GH_LOG"'

for leftover in 'echo s > app.txt' 'echo t > new.txt' 'git switch --quiet --detach && echo u > app.txt && git commit --quiet -am detached'; do
  seed_old; continued ''
  (cd "$work/agent" && eval "$leftover")
  bash "$root/scripts/pack-outbox.sh" "$work/agent" "$work/out" "$old" "origin/$old" >/dev/null
  cont
  check "a continue run that left work off the branch ($leftover) is refused" 'grep -q "Factory publish refused: the PR has no commits" "$GH_LOG" && ! grep -q "pr create" "$GH_LOG"'
done

seed_old; before=$(tip "$old"); continued ''
rm "$work/out/pr.md"; printf 'Factory worker blocked: still no service.\n' > "$work/out/blocked.md"
cont
check "a continue run that blocks again with no commit only blocks the issue" '[ "$(tip "$old")" = "$before" ] && grep -q "body=Factory worker blocked: still no service." "$GH_LOG" && ! grep -q "refused" "$GH_LOG"'
exit "$fails"
