#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
fails=0
for label in agent:implement ready-for-agent; do
  if valid_trigger "$label"; then echo "ok: $label starts work"; else echo "FAIL: $label is refused"; fails=1; fi
done
for label in agent:in-progress agent:blocked ready-for-human gardening:report ""; do
  if valid_trigger "$label"; then echo "FAIL: \"$label\" is allowed"; fails=1; else echo "ok: \"$label\" is refused"; fi
done
exit "$fails"
