#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/scripts/lib.sh"

expected="AUTHORIZATION: basic $(printf 'x-access-token:%s' secret-token | base64 | tr -d '\n')"
actual=$(GH_TOKEN=secret-token github_git config --get http.https://github.com/.extraheader)
[ "$actual" = "$expected" ] || { echo "FAIL github_git sends GH_TOKEN to github.com: got '$actual'"; exit 1; }
[ -z "$(git config --get http.https://github.com/.extraheader || true)" ] || { echo "FAIL the token leaked into git config"; exit 1; }
echo "ok github_git sends GH_TOKEN to github.com only for its own command"
