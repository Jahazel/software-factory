#!/usr/bin/env bash
# Usage: bash tests/repeated-numbers.sh   Exits 1 when a case fails.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
fails=0
check() {
  local want="$1" names="$2" got
  got=$(printf '%s' "$names" | repeated_numbers | paste -sd' ' -)
  if [ "$got" = "$want" ]; then echo "ok: [$want] <- $(tr '\n' ' ' <<<"$names")"
  else echo "FAIL: want [$want], got [$got] <- $(tr '\n' ' ' <<<"$names")"; fails=1; fi
}
check "" $'0015_drop_leads.sql\n0016_forged.sql\n'
check "0017" $'0016_a.sql\n0017_b.sql\n0017_c.sql\n'
check "0017 0018" $'0017_a.sql\n0018_b.sql\n0017_c.sql\n0018_d.sql\n'
check "" $'_journal.json\nREADME.md\n'
check "" ''
exit "$fails"
