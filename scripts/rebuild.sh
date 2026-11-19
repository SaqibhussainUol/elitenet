#!/usr/bin/env bash
# Destroy everything, rebuild from code, and record how long it took.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

mkdir -p results
[ -f results/rebuild.csv ] || echo "timestamp,seconds" > results/rebuild.csv

log "destroying lab"
scripts/destroy.sh || true

start=$(date +%s)
scripts/up.sh
elapsed=$(( $(date +%s) - start ))

echo "$(date -Iseconds),$elapsed" >> results/rebuild.csv
log "REBUILT FROM ZERO IN ${elapsed}s"
scripts/render-results.sh
