#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
fails=0
pat="github_pat_11ABCDEFG0aBcDeFgHiJkL_mNoPqRsTuVwXyZ0123456789aBcDeFgHiJkLmNoPqRsTuVwXyZ01234"
classic="ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789"
actions="ghs_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789"
check() {
  local name="$1" want="$2" got
  shift 2
  got=$(printf '%s\0' "$@" | leaked_token_names)
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1; fi
}
check "the Actions token and the Claude token are allowed" "" \
  "GH_TOKEN=$actions" "CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789" "HOME=/home/runner"
check "a fine-grained token is named" "FACTORY_TOKEN" "GH_TOKEN=$actions" "FACTORY_TOKEN=$pat"
check "a classic token is named" "OTHER" "OTHER=$classic"
check "a token inside a longer value is named, once per variable" "GIT_CONFIG_VALUE_0" \
  "GIT_CONFIG_VALUE_0=AUTHORIZATION: bearer $pat and $pat"
check "a token on a later line of a value is named, not its lines" "MULTI" $'MULTI=first line\n'"$pat"
check "each leaking variable is named" "A,B" "A=$pat" "SAFE=x" "B=$classic"
got=$(printf '%s\0' "X=$pat" | leaked_token_names)
if [[ "$got" != *github_pat_* ]]; then echo "ok: the token value is never printed"; else echo "FAIL: the token value was printed"; fails=1; fi
exit "$fails"
