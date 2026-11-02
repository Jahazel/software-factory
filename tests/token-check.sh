#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
fine_grained="github_pat_11ABCDEFG0aBcDeFgHiJkL_mNoPqRsTuVwXyZ0123456789aBcDeFgHiJkLmNoPqRsTuVwXyZ01234"
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
check "a fine-grained token is named" "FACTORY_TOKEN" "GH_TOKEN=$actions" "FACTORY_TOKEN=$fine_grained"
for prefix in ghp gho ghu ghr; do
  check "a $prefix token is named" "OTHER" "OTHER=${prefix}_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789"
done
check "a token inside a longer value is named, once per variable" "GIT_CONFIG_VALUE_0" \
  "GIT_CONFIG_VALUE_0=AUTHORIZATION: bearer $fine_grained and $fine_grained"
check "a token on a later line of a value is named, not its lines" "MULTI" $'MULTI=first line\n'"$fine_grained"
check "each leaking variable is named" "A,B" "A=$fine_grained" "SAFE=x" "B=$classic"
got=$(printf '%s\0' "X=$fine_grained" | leaked_token_names)
if [[ "$got" != *github_pat_* ]]; then echo "ok: the token value is never printed"; else echo "FAIL: the token value was printed"; fails=1; fi

lib="$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
guard() {
  local path="$1"; shift
  env -i PATH="$path" "$@" bash -c 'source "$1"; fail_on_leaked_token "the test step"; echo "the step went on"' _ "$lib" 2>&1
}
out=$(guard "$PATH" GH_TOKEN="$actions") && [ "$out" = "the step went on" ] \
  && echo "ok: a clean environment lets the step go on" || { echo "FAIL: a clean environment stopped the step: $out"; fails=1; }
if out=$(guard "$PATH" FACTORY_TOKEN="$fine_grained"); then echo "FAIL: a leaked token did not stop the step"; fails=1
elif [ "$out" = "::error::A personal GitHub token is in FACTORY_TOKEN, in the test step. The step stopped." ]; then
  echo "ok: a leaked token stops the step and names only the variable"
else echo "FAIL: unexpected message: $out"; fails=1; fi
mkdir -p "$work/bin"; printf '#!/bin/sh\nexit 3\n' > "$work/bin/env"; chmod +x "$work/bin/env"
if guard "$work/bin:$PATH" >/dev/null; then echo "FAIL: a failed env -0 let the step go on"; fails=1
else echo "ok: a failed env -0 stops the step"; fi
exit "$fails"
