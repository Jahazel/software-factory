#!/usr/bin/env bash
# Usage: bash tests/classify-conflict.sh   Exits 1 when a case fails.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/lib.sh"
# An unquoted prefix loop would expand "migrations/*" against this folder.
cd "$(mktemp -d)" && mkdir -p migrations/0042_a.sql
fails=0
check() {
  local want="$1" prefix_list="$2" paths="$3" got
  got=$(printf '%s' "$paths" | AGENT_CONFLICTS="$prefix_list" classify_conflict)
  if [ "$got" = "$want" ]; then echo "ok: $want <- [$prefix_list] $(tr '\n' ' ' <<<"$paths")"
  else echo "FAIL: want $want, got $got <- [$prefix_list] $(tr '\n' ' ' <<<"$paths")"; fails=1; fi
}
check agent "migrations/" $'migrations/0042_a.sql\nmigrations/meta/_journal.json\n'
check owner "migrations/" $'migrations/0042_a.sql\nsrc/lib/db.ts\n'
check owner "migrations/" $'src/lib/db.ts\n'
check owner "migrations/" ''
check owner "" $'migrations/0042_a.sql\n'
check agent "migrations/ drizzle/" $'migrations/0042_a.sql\ndrizzle/meta/x.json\n'
check owner "migrations/" $'old-migrations/0042_a.sql\n'
check owner "migrations/*" $'migrations/0042_a.sql\n'
exit "$fails"
