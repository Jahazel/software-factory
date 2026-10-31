#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ -f "${1:?Usage: check-pr.sh <outbox>}/pr.md" ] || { echo "$1/pr.md does not exist"; exit 1; }
reason=$(pr_body_refusal "$1")
[ -z "$reason" ] || { echo "$reason"; exit 1; }
