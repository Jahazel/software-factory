#!/usr/bin/env bash
# Run on the owner's Mac. Refreshes claude/ from ~/.claude: pstack, the router hook, the model rules, and the skills.
# The job computer installs this copy with scripts/install-claude.sh.
set -euo pipefail
src="$HOME/.claude"
dest="$(cd "$(dirname "$0")/.." && pwd)/claude"
rm -rf "$dest"
mkdir -p "$dest"
# Symlinked skills are third-party installs; install-claude.sh gets them from their own repos.
# synced/ holds Anthropic's document skills, which workers do not use.
# impeccable, find-skills, and security-audit are third-party copies, not links. Workers do not use
# find-skills or security-audit; install-claude.sh gets impeccable at a pinned version.
rsync -a --no-links --exclude .DS_Store --exclude synced/ --exclude __pycache__/ \
  --exclude /skills/impeccable/ --exclude /skills/find-skills/ --exclude /skills/security-audit/ \
  "$src/skills" "$dest/"
rsync -a --exclude .DS_Store --exclude __pycache__/ "$src/personal-router-source" "$src/personal-router" "$src/pstack-models.md" "$src/agents" "$dest/"
echo "Synced $(ls "$dest/skills" | wc -l | tr -d ' ') skills, $(ls "$dest/agents" | wc -l | tr -d ' ') agents, and pstack into $dest"
