#!/usr/bin/env bash
# One-screen health summary: BGP, clusters, entry-point backends.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

echo "== BGP sessions on core =="
docker exec "$(ctr core)" vtysh -c 'show ip bgp summary' 2>/dev/null | sed -n '1,12p'

echo
echo "== Clusters =="
for s in "${SITES[@]}"; do
  printf '%-4s ' "$s"
  docker exec "$(ctr "$s-k3s")" kubectl -n relief get deploy beacon --no-headers 2>/dev/null \
    || echo "(not reachable)"
done

echo
echo "== Entry point backends (HAProxy) =="
docker exec "$(ctr edge)" wget -qO- 'http://127.0.0.1:8404/stats;csv' 2>/dev/null \
  | awk -F, '$2 ~ /^(hq|fa|fb)$/ {printf "%-4s %s\n", $2, $18}' \
  || echo "(edge not reachable)"

echo
printf 'Currently served by: '
docker exec "$(ctr edge)" wget -qO- http://127.0.0.1:8080/whoami 2>/dev/null || echo "NOBODY (outage)"
