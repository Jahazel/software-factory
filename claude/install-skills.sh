#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
lock="$here/skills.lock"
dest="${1:?usage: install-skills.sh <skills-dir> [--runner]}"
runner="${2:-}"
mkdir -p "$dest"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

{ grep -vE '^[[:space:]]*(#|$)' "$lock" || true; } | while read -r name repo commit path where; do
  case "$where" in
    mac) [ "$runner" = "--runner" ] && continue ;;
    all) ;;
    *) echo "$name: where must be mac or all, not '$where'" >&2; exit 1 ;;
  esac
  marker="$dest/$name/.locked-commit"
  if [ -f "$marker" ] && [ "$(cat "$marker")" = "$commit" ]; then
    echo "$name: already at $commit"
    continue
  fi
  repo_dir="$tmp/$name"
  git init --quiet "$repo_dir"
  git -C "$repo_dir" fetch --quiet --depth 1 "https://github.com/$repo" "$commit"
  git -C "$repo_dir" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
  [ -f "$repo_dir/$path/SKILL.md" ] || { echo "$name: no SKILL.md at $repo@$commit:$path" >&2; exit 1; }
  rm -rf "${dest:?}/$name"
  cp -R "$repo_dir/$path" "$dest/$name"
  echo "$commit" > "$marker"
  echo "$name: installed $repo@$commit"
done
