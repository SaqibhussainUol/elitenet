#!/usr/bin/env bash
# Build the whole platform from code: network -> clusters -> workload.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

log "deploying network topology ($TOPO, ${#SITES[@]} sites)"
$SUDO containerlab deploy -t "$TOPO" --reconfigure

scripts/wait-ready.sh
scripts/deploy.sh

log "waiting for the global entry point to see a healthy site"
for i in $(seq 1 60); do
  if docker exec "$(ctr edge)" wget -q -T 1 -O- http://127.0.0.1:8080/whoami >/dev/null 2>&1; then
    log "platform is serving traffic"
    exit 0
  fi
  [ "$i" -eq 60 ] && { log "TIMEOUT: edge never became healthy (see docs/RUNBOOK.md)"; exit 1; }
  sleep 2
done
