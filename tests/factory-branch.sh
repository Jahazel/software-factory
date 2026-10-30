#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
fails=0
check() {
  local name="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1; fi
}
check "the name holds the issue, a slug, and the run" "factory/issue-42-add-docs-for-the-api-123" "$(factory_branch 42 'Add docs: for the API!' 123)"
check "the slug stops at 40 characters" "factory/issue-7-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-9" "$(factory_branch 7 "$(printf 'a%.0s' {1..60})" 9)"
check "a branch of this issue and run is valid" "ok" "$(valid_factory_branch factory/issue-42-add-docs-123 42 123 && echo ok)"
check "another run's branch is refused" "" "$(valid_factory_branch factory/issue-42-add-docs-124 42 123 && echo ok)"
check "another issue's branch is refused" "" "$(valid_factory_branch factory/issue-43-add-docs-123 42 123 && echo ok)"
check "an owner branch is refused" "" "$(valid_factory_branch issue-42-add-docs 42 123 && echo ok)"
check "a resolve branch of this issue is valid with no run" "ok" "$(valid_factory_branch factory/issue-42-add-docs-9 42 && echo ok)"
check "a path trick is refused" "" "$(valid_factory_branch 'factory/issue-42-x/../main-123' 42 123 && echo ok)"
exit "$fails"
