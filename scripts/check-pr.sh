#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
reason=$(pr_body_refusal "$1")
[ -z "$reason" ] || { echo "$reason"; exit 1; }
