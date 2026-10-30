#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git -C "$work" init --quiet -b main
git -C "$work" config user.name fixture
git -C "$work" config user.email fixture@example.invalid
mkdir -p "$work/.github/workflows" "$work/src"
echo a > "$work/src/a.txt"; echo ci > "$work/.github/workflows/ci.yml"
git -C "$work" add -A; git -C "$work" commit --quiet -m base
base=$(git -C "$work" rev-parse HEAD)
fails=0
check() {
  local name="$1" want="$2" got
  got=$(cd "$work" && tree_violations "$base" HEAD | paste -sd'|' -)
  if [ "$got" = "$want" ]; then echo "ok: $name"
  else printf 'FAIL: %s\n  want [%s]\n  got  [%s]\n' "$name" "$want" "$got"; fails=1; fi
  git -C "$work" reset --quiet --hard "$base"
}
commit() { git -C "$work" add -A; git -C "$work" commit --quiet -m change; }
echo b > "$work/src/a.txt"; commit; check "an app change is allowed" ""
echo evil > "$work/.github/workflows/leak.yml"; commit; check "a new workflow is refused" ".github/workflows/leak.yml: under .github/"
git -C "$work" mv .github/workflows/ci.yml src/ci.yml; commit; check "a move out of .github/ is refused" ".github/workflows/ci.yml: under .github/"
ln -s /etc/passwd "$work/src/link"; commit; check "a symbolic link is refused" "src/link: symbolic link"
echo '[submodule "x"]' > "$work/.gitmodules"; commit; check "a submodule file is refused" ".gitmodules: submodule"
blob=$(echo x | git -C "$work" hash-object -w --stdin)
git -C "$work" update-index --add --cacheinfo "100644,$blob,src/bad"$'\xff'".txt"; git -C "$work" commit --quiet -m change
check "a file name that is not UTF-8 is refused" 'src/bad\xff.txt: file name is not UTF-8'
git -C "$work" switch --quiet --orphan lone; echo evil > "$work/x.yml"; git -C "$work" add x.yml; git -C "$work" commit --quiet -m lone
if (cd "$work" && tree_violations "" HEAD) >/dev/null 2>&1; then echo "FAIL: an empty base is not an error"; fails=1; else echo "ok: an empty base is an error"; fi
exit "$fails"
