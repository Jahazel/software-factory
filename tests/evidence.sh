#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/scripts/lib.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
out="$work/out"
png() { printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR' >"$out/evidence/$1"; }
jpg() { printf '\xff\xd8\xff\xe0\0\x10JFIF' >"$out/evidence/$1"; }
webp() { printf 'RIFF\x24\0\0\0WEBPVP8 ' >"$out/evidence/$1"; }
webm() { printf '\x1a\x45\xdf\xa3\x9f\x42\x86\x81\x01\x42\x82\x84webm' >"$out/evidence/$1"; }
fresh_outbox() { rm -rf "$out"; mkdir -p "$out/evidence"; printf 'feat(x): add x\n\n%s\n' "$1" >"$out/pr.md"; }
check() {
  local name="$1" want="$2" got status=0
  got=$(bash "$root/scripts/check-pr.sh" "$out") || status=$?
  if { [ -z "$want" ] && [ -z "$got" ] && [ "$status" = 0 ]; } || { [ -n "$want" ] && [[ "$got" == *"$want"* ]] && [ "$status" = 1 ]; }; then
    echo "ok: $name"
  else
    printf 'FAIL: %s\n  want [%s]\n  got  [%s] (exit %s)\n' "$name" "$want" "$got" "$status"; fails=1
  fi
}
four=$'## Problem\nx\n## Summary\nx\n## Evidence\nx\n## Merge Danger\nx'

fresh_outbox "$four"; rmdir "$out/evidence"
check "an outbox with no evidence folder and no references passes" ""

fresh_outbox "$four"$'\n![The saved form](./saved.png)'; png saved.png
check "a referenced png passes" ""

fresh_outbox "$four"$'\n![The saved form](./saved.png)'; printf 'hello' >"$out/evidence/saved.png"
check "a text file named .png is refused" "evidence/saved.png is not a png file"

fresh_outbox "$four"$'\n![a](./a.jpg)\n![b](./b.webp)\n![c](./c.webm)'; jpg a.jpg; webp b.webp; webm c.webm
check "a referenced jpg, webp, and webm pass" ""

fresh_outbox "$four"$'\n![a](./a.jpg)'; png a.jpg
check "png bytes named .jpg are refused" "evidence/a.jpg is not a jpg file"

fresh_outbox "$four"$'\n![c](./c.webm)'; printf '\x1a\x45\xdf\xa3\x9f\x42\x86\x81\x01\x42\x82\x88matroska' >"$out/evidence/c.webm"
check "a Matroska file named .webm is refused" "evidence/c.webm is not a webm file"
printf '\x1a\x45\xdf\xa3\x07\x76\x56\x26\xd0' >"$out/evidence/c.webm"
check "webm bytes half a byte off are refused" "evidence/c.webm is not a webm file"

for name in a.gif a.jpeg A.PNG 'a b.png' .hidden.png -a.png 'a..png' noext; do
  fresh_outbox "$four"; png "$name"
  check "the name \"$name\" is refused" "evidence/$name has a name the factory does not accept"
done

fresh_outbox "$four"; mkdir "$out/evidence/sub"
check "a folder inside evidence/ is refused" "evidence/sub is not a plain file"

fresh_outbox "$four"$'\n![a](./a.png)'; png real.png; ln -s real.png "$out/evidence/a.png"
check "a symbolic link inside evidence/ is refused" "evidence/a.png is not a plain file"

fresh_outbox "$four"; rmdir "$out/evidence"; mkdir "$work/elsewhere"; ln -s "$work/elsewhere" "$out/evidence"
check "evidence/ as a symbolic link is refused" "evidence is not a folder"

fresh_outbox "$four"$'\n![a](./a.png)'; png a.png; truncate -s 10485759 "$out/evidence/a.png"
check "a file one byte under 10 MB passes" ""
truncate -s 10485760 "$out/evidence/a.png"
check "a file of 10 MB is refused" "evidence/a.png is not under 10485760 bytes"

refs=""; for i in $(seq 1 20); do refs+=$'\n'"![s$i](./s$i.png)"; done
fresh_outbox "$four$refs"; for i in $(seq 1 20); do png "s$i.png"; done
check "20 files pass" ""
png s21.png
check "21 files are refused" "evidence/ holds 21 files; the limit is 20"

fresh_outbox "$four"$'\n![a](./a.png)\n![b](./b.png)'; png a.png
check "a reference with no file is refused" "pr.md refers to ./b.png, which is not in evidence/"

fresh_outbox "$four"$'\n![a](./a.png)'; rmdir "$out/evidence"
check "a reference with no evidence folder is refused" "pr.md refers to ./a.png, which is not in evidence/"

fresh_outbox "$four"$'\n![a](./a.png)'; png a.png; png b.png
check "a file no reference shows is refused" "evidence/b.png is not referred to in pr.md"

fresh_outbox "$four"$'\n![a](./a.png) and [again](./a.png)\n```text\n![x](./x.png)\n```\nRun `![y](./y.png)`.\n![remote](https://example.test/r.png)'; png a.png
check "a file referred to twice passes, and fenced, inline-code, and remote references do not count" ""

fresh_outbox "$four"$'\n[the guide](./docs/guide.md)'
check "a ./ link that is not an image is not a reference" ""
fresh_outbox "$four"$'\n![a shot](./shots/a.png)'
check "an image in a folder is refused as a missing file" "pr.md refers to ./shots/a.png, which is not in evidence/"

fresh_outbox "$four"$'\n![the body](./../pr.md)'
check "a reference that leaves evidence/ is refused" "pr.md refers to ./../pr.md, which is not in evidence/"

prompt="$root/prompts/worker.md"
if grep -q "at most $evidence_max_files files" "$prompt" && grep -q "under $((evidence_max_bytes / 1048576)) MB" "$prompt" \
  && grep -q '{{OUTBOX}}/evidence/' "$prompt"; then
  echo "ok: the worker prompt states the evidence limits lib.sh enforces"
else
  echo "FAIL: the worker prompt states the evidence limits lib.sh enforces"; fails=1
fi

exit "$fails"
