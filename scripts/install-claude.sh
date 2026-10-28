#!/usr/bin/env bash
# Run on the job computer, after Claude Code is installed. Puts pstack and the owner's skills in ~/.claude.
set -euo pipefail
src="$(cd "$(dirname "$0")/.." && pwd)/claude"
home_claude="$HOME/.claude"
mkdir -p "$home_claude"
cp -R "$src/." "$home_claude/"

# Third-party skill, pinned to the version on the owner's Mac.
git clone --quiet --depth 1 --branch skill-v4.3.1 https://github.com/pbakaus/impeccable "$RUNNER_TEMP/impeccable"
cp -R "$RUNNER_TEMP/impeccable/.claude/skills/impeccable" "$home_claude/skills/"

# The files name the owner's Mac home folder. Point them at this computer's home folder.
grep -rlZ "/Users/jahazelsanchez" "$home_claude" | xargs -0 --no-run-if-empty sed -i "s|/Users/jahazelsanchez|$HOME|g"

echo "@~/.claude/pstack-models.md" > "$home_claude/CLAUDE.md"
cat > "$home_claude/settings.json" <<JSON
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "^(startup|resume|clear|compact)$",
        "hooks": [{ "type": "command", "command": "python3 \"$home_claude/personal-router/session-start.py\"", "timeout": 5 }]
      }
    ]
  }
}
JSON
claude plugin marketplace add "$home_claude/personal-router-source"
claude plugin install pstack@personal-router

if grep -rq "/Users/" "$home_claude/skills" "$home_claude/personal-router-source" "$home_claude/personal-router"; then
  echo "A Mac path is left in the installed skills."; exit 1
fi
claude plugin list
echo "Installed $(ls "$home_claude/skills" | wc -l) skills and pstack."
