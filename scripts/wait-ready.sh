#!/usr/bin/env bash
# Wait until every site's k3s node reports Ready.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

for s in "${SITES[@]}"; do
  log "waiting for $s cluster"
  for i in $(seq 1 100); do
    if docker exec "$(ctr "$s-k3s")" kubectl get nodes --no-headers 2>/dev/null | grep -q ' Ready'; then
      log "$s ready"
      break
    fi
    [ "$i" -eq 100 ] && { log "TIMEOUT waiting for $s (docker logs $(ctr "$s-k3s"))"; exit 1; }
    sleep 3
  done
done
