#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
GITHUB_REPOSITORY=o/r
gh() {
  case "$*" in
    "pr list"*) echo '[
      {"number": 3, "headRefName": "factory/issue-5-add-x-77", "isCrossRepository": false, "labels": []},
      {"number": 4, "headRefName": "issue-5-add-x", "isCrossRepository": false, "labels": []},
      {"number": 2, "headRefName": "factory/issue-6-y-1", "isCrossRepository": false, "labels": [{"name": "agent:blocked"}]},
      {"number": 9, "headRefName": "factory/issue-8-z-1", "isCrossRepository": true, "labels": []}]' ;;
    *) echo "unexpected gh call: $*" >&2; return 1 ;;
  esac
}
want=$'2 6 factory/issue-6-y-1 true\n3 5 factory/issue-5-add-x-77 false'
got=$(factory_prs)
if [ "$got" = "$want" ]; then echo "ok: only same-repo factory/ branches count, with no label read"
else printf 'FAIL: factory_prs\n  want [%s]\n  got  [%s]\n' "$want" "$got"; exit 1; fi
