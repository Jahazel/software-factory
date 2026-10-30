#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
GITHUB_REPOSITORY=O/R
fails=0
check() {
  local got
  got=$(printf '%s\n' "$2" | closing_refs | paste -sd'|' -)
  if [ "$got" = "$3" ]; then echo "ok: $1"; else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$1" "$3" "$got"; fails=1; fi
}
check "a plain reference" "Closes #12" "12"
check "every keyword form" "fix #1, fixed #2, fixes #3, resolve #4, resolved #5, close #6, closed #7" "1|2|3|4|5|6|7"
check "a colon after the keyword" "Fixes: #12" "12"
check "this repo by name, in any case" "closes o/r#12" "12"
check "this repo by link" "Resolves https://github.com/O/R/issues/12" "12"
check "another repo stays a raw reference" "Closes x/y#12 and fixes https://github.com/x/y/issues/3" "x/y#12|https://github.com/x/y/issues/3"
check "a mention without a keyword" "See #12" ""
exit "$fails"
