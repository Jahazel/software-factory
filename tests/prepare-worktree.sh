#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/checkout" "$work/evidence"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo '{"title":"Add docs","body":"Update docs.","author":{"login":"owner"},"labels":[],"comments":[{"author":{"login":"owner"},"createdAt":"t1","body":"Owner note: keep it short."},{"author":{"login":"owner"},"createdAt":"t2","body":"Factory worker blocked: do X\n<!-- factory-publish -->"}]}'
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GITHUB_REPOSITORY=owner/project GITHUB_REPOSITORY_OWNER=owner GITHUB_RUN_ID=5
git -C "$work/checkout" init --quiet -b main
git -C "$work/checkout" config user.name fixture
git -C "$work/checkout" config user.email fixture@example.invalid
echo original > "$work/checkout/README.md"
git -C "$work/checkout" add README.md
git -C "$work/checkout" commit --quiet -m initial
git init --bare --quiet "$work/origin.git"
git -C "$work/checkout" remote add origin "$work/origin.git"
git -C "$work/checkout" push --quiet -u origin main
branch=$(cd "$work/checkout" && bash "$root/scripts/prepare-issue.sh" 42 "$work/evidence/issue.md" "$work/new-task")
test "$branch" = factory/issue-42-add-docs-5
test "$(git -C "$work/checkout" branch --show-current)" = main
test "$(git -C "$work/new-task" branch --show-current)" = "$branch"
test "$(git -C "$work/new-task" rev-parse --git-dir)" != "$(git -C "$work/new-task" rev-parse --git-common-dir)"
echo changed > "$work/new-task/README.md"
test "$(cat "$work/checkout/README.md")" = original
grep -q '# Issue #42' "$work/evidence/issue.md"
grep -q 'Owner note: keep it short.' "$work/evidence/issue.md"
if grep -q 'Factory worker blocked' "$work/evidence/issue.md"; then echo 'FAIL: a factory comment reached the issue brief'; exit 1; fi
echo 'ok: new issue edits stay in its linked worktree'

git -C "$work/checkout" branch issue-43-existing
git -C "$work/checkout" push --quiet origin issue-43-existing
git -C "$work/checkout" branch -D issue-43-existing >/dev/null
branch=$(cd "$work/checkout" && bash "$root/scripts/prepare-issue.sh" 43 "$work/evidence/resolve.md" "$work/resolve-task" issue-43-existing)
test "$branch" = issue-43-existing
test "$(git -C "$work/resolve-task" branch --show-current)" = issue-43-existing
test "$(git -C "$work/resolve-task" rev-parse HEAD)" = "$(git -C "$work/checkout" rev-parse origin/issue-43-existing)"
test "$(git -C "$work/checkout" branch --show-current)" = main
echo 'ok: resolve work preserves the PR branch and leaves the primary checkout alone'
