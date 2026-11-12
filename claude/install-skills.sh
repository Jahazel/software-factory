#!/usr/bin/env bash
# Installs the third-party skills in skills.lock, each at its locked commit.
# Usage: install-skills.sh <skills-dir> [--runner]
# --runner skips rows whose "where" column is "mac".
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
lock="$here/skills.lock"
dest="${1:?usage: install-skills.sh <skills-dir> [--runner]}"
runner="${2:-}"
mkdir -p "$dest"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

grep -vE '^[[:space:]]*(#|$)' "$lock" | while read -r name repo commit path where; do
  if [ "$runner" = "--runner" ] && [ "$where" = "mac" ]; then continue; fi
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
