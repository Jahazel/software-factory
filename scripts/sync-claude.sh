#!/usr/bin/env bash
# Run on the owner's Mac. Refreshes claude/: skills and skills.lock from the Workspace home repo,
# and pstack, the router hook, the model rules, and agents from ~/.claude.
# The job computer installs this copy with scripts/install-claude.sh.
# Usage: sync-claude.sh [dest]. The Workspace drift check passes a temporary dest.
set -euo pipefail
workspace_claude="${WORKSPACE:-$HOME/Workspace}/.claude"
home_claude="$HOME/.claude"
dest="${1:-$(cd "$(dirname "$0")/.." && pwd)/claude}"
for f in skills.lock install-skills.sh; do
  [ -f "$workspace_claude/$f" ] || { echo "No $f in $workspace_claude. Set WORKSPACE to the home repo." >&2; exit 1; }
done
rm -rf "$dest"
mkdir -p "$dest"
# Locked third-party skills are installed on runners from skills.lock, not copied.
# synced/ and .trash/ belong to the Claude app's document-skill sync. Workers use neither find-skills nor logo-design.
excludes=(--exclude .DS_Store --exclude synced/ --exclude .trash/ --exclude __pycache__/ --exclude /skills/find-skills/ --exclude /skills/logo-design/)
while read -r name _; do excludes+=(--exclude "/skills/$name/"); done < <(grep -vE '^[[:space:]]*(#|$)' "$workspace_claude/skills.lock" || true)
rsync -a --no-links "${excludes[@]}" "$workspace_claude/skills" "$dest/"
cp "$workspace_claude/skills.lock" "$workspace_claude/install-skills.sh" "$dest/"
rsync -a --exclude .DS_Store --exclude __pycache__/ "$home_claude/personal-router-source" "$home_claude/personal-router" "$home_claude/pstack-models.md" "$home_claude/agents" "$dest/"
echo "Synced $(ls "$dest/skills" | wc -l | tr -d ' ') skills, $(ls "$dest/agents" | wc -l | tr -d ' ') agents, and pstack into $dest"
