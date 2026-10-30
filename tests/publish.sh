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
  "api --paginate repos/o/r/issues/"*"/comments"*) echo "${COMMENTS:-}" ;;
  "pr create"*) sed 's/^/  body: /' "${@: -1}" >> "$GH_LOG"; echo "https://github.com/o/r/pull/50" ;;
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
outbox() {
  rm -rf "$work/out" "$work/tmp" "$work/agent"; mkdir -p "$work/out/comments" "$work/tmp"
  git clone --quiet "$work/origin.git" "$work/agent"
  git -C "$work/agent" config user.name agent; git -C "$work/agent" config user.email a@example.invalid
  git -C "$work/agent" switch --quiet -c "$branch"
  (cd "$work/agent" && eval "$1")
  git -C "$work/agent" add -A; git -C "$work/agent" commit --quiet -m change
  bash "$root/scripts/pack-outbox.sh" "$work/agent" "$work/out" "$branch" origin/main >/dev/null
  printf 'feat(x): add x\n\nAdds x.\n' > "$work/out/pr.md"
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
printf 'feat(x): add x\n\nAdds x. Closes #13\n' > "$work/out/pr.md"
run
check "a PR body that closes another issue is refused" 'grep -q "closes #13, which is not issue #12" "$GH_LOG" && ! remote_has "$branch"'

for body in 'Closes Other/repo#12' 'Fixes: https://github.com/other/repo/issues/12' 'resolves o/r#13'; do
  fresh 'echo d2 > app.txt'
  printf 'feat(x): add x\n\nAdds x. %s\n' "$body" > "$work/out/pr.md"
  run
  check "a PR body with \"$body\" is refused" 'grep -q "Factory publish refused: the PR body closes" "$GH_LOG" && ! remote_has "$branch"'
done

fresh 'echo d3 > app.txt'
printf 'feat(x): add x\n\nAdds x.\n\nCloses: o/r#12\n' > "$work/out/pr.md"
run
check "a PR body that closes this issue in long form gets no second Closes line" 'grep -q "body: Closes: o/r#12" "$GH_LOG" && ! grep -q "body: Closes #12" "$GH_LOG"'

fresh 'echo d4 > app.txt'
printf '\nSecond line.\n' > "$work/out/comments/01.md"
run
check "a comment with an empty first line is refused" 'grep -q "comments/01.md has an empty first line" "$GH_LOG" && ! remote_has "$branch"'

fresh 'echo d5 > app.txt'
git -C "$work/agent" switch --quiet --orphan lone
mkdir -p "$work/agent/.github/workflows"; echo evil > "$work/agent/.github/workflows/leak.yml"
git -C "$work/agent" add -A; git -C "$work/agent" commit --quiet -m lone; git -C "$work/agent" branch --quiet -f "$branch" lone
bash "$root/scripts/pack-outbox.sh" "$work/agent" "$work/out" "$branch" "$(git -C "$work/agent" rev-parse origin/main)" >/dev/null
run
check "a branch with no history in common with main is refused" 'grep -q "shares no history with main" "$GH_LOG" && ! remote_has "$branch"'

outbox 'echo e > app.txt'
run
second=0; OPEN_PR=50 run || second=$?
check "a second run with the PR open succeeds and opens no second PR" '[ "$second" = 0 ] && ! grep -q "pr create" "$GH_LOG" && grep -q "Published" "$work/run.log"'

git -C "$work/origin.git" update-ref -d "refs/heads/$branch"
outbox 'echo f > app.txt'
rm "$work/out/pr.md"; printf 'Factory worker blocked: the test needs a service.\n' > "$work/out/blocked.md"
run
check "a blocked worker with commits pushes them and blocks the issue" 'remote_has "$branch" && grep -q "labels\[\]=agent:blocked" "$GH_LOG" && ! grep -q "pr create" "$GH_LOG"'

git -C "$work/agent" switch --quiet --detach origin/main
git -C "$work/agent" branch --quiet -f "$branch" origin/main
outbox 'echo g > app.txt'
rm -f "$work/out/pr.md"
MODE=resolve OPEN_PR=50 BRANCH="$branch" run
check "a resolve push that drops the PR's commits is refused" 'grep -q "does not build on the PR" "$GH_LOG"'
exit "$fails"
