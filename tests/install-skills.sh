#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
setup() {
  rm -rf "$work/claude" "$work/skills"; mkdir -p "$work/claude" "$work/skills"
  cp "$root/claude/install-skills.sh" "$work/claude/"
  printf '%s\n' "# comment" "" "$@" > "$work/claude/skills.lock"
}
at_commit() { mkdir -p "$work/skills/$1"; echo "$2" > "$work/skills/$1/.locked-commit"; }
check() {
  local name="$1" want_status="$2" want_out="$3" out status=0
  out=$(bash "$work/claude/install-skills.sh" "$work/skills" "${@:4}" 2>&1 | paste -sd'|' -) || status=$?
  if [ "$status" = "$want_status" ] && [ "$out" = "$want_out" ]; then echo "ok: $name"
  else echo "FAIL: $name: status $status, output '$out'"; fails=1; fi
}

setup "a o/a c1 p mac" "b o/b c2 p all"; at_commit a c1; at_commit b c2
check "skills at their commit are left alone" 0 "a: already at c1|b: already at c2"
check "runners skip mac rows" 0 "b: already at c2" --runner

setup
check "a lock with only comments installs nothing" 0 ""

setup "a o/a c1 p Mac"
check "an unknown where value stops the install" 1 "a: where must be mac or all, not 'Mac'"

exit "$fails"
