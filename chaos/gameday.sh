#!/usr/bin/env bash
# Game day: inject a fault, measure user-visible impact, heal, record.
#
#   chaos/gameday.sh <scenario> [site]
#
# Scenarios
#   site-isolate       hard cut: carrier down on every WAN link of <site>
#   silent-blackhole   100% packet loss on every WAN link (link stays "up")
#   wan-cut            only the uplink to the core fails (tests rerouting)
#   wan-degrade        250 ms delay + 15% loss on the uplink (tests tolerance)
#   cluster-freeze     the site's Kubernetes node is frozen (tests app failover)
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

SCEN="${1:?usage: gameday.sh <scenario> [site]}"
SITE="${2:-hq}"
BASE_S="${BASE_S:-6}"
OBSERVE_S="${OBSERVE_S:-25}"
HEAL_S="${HEAL_S:-20}"

R="$SITE-r"
EDGE="$(ctr edge)"

inject() { :; }
heal() { :; }

case "$SCEN" in
  site-isolate)
    inject() { for i in "${WAN_IFS[@]}"; do nsx "$R" ip link set "$i" down; done; }
    heal()   { for i in "${WAN_IFS[@]}"; do nsx "$R" ip link set "$i" up; done; }
    ;;
  silent-blackhole)
    inject() { for i in "${WAN_IFS[@]}"; do nsx "$R" tc qdisc replace dev "$i" root netem loss 100%; done; }
    heal()   { for i in "${WAN_IFS[@]}"; do nsx "$R" tc qdisc del dev "$i" root 2>/dev/null || true; done; }
    ;;
  wan-cut)
    inject() { nsx "$R" ip link set eth1 down; }
    heal()   { nsx "$R" ip link set eth1 up; }
    ;;
  wan-degrade)
    inject() { nsx "$R" tc qdisc replace dev eth1 root netem delay 250ms 50ms loss 15%; }
    heal()   { nsx "$R" tc qdisc del dev eth1 root 2>/dev/null || true; }
    ;;
  cluster-freeze)
    inject() { docker pause "$(ctr "$SITE-k3s")" >/dev/null; }
    heal()   { docker unpause "$(ctr "$SITE-k3s")" >/dev/null 2>&1 || true; }
    ;;
  *)
    echo "unknown scenario: $SCEN" >&2
    exit 2
    ;;
esac

mkdir -p results/raw
STAMP=$(date +%Y%m%d-%H%M%S)
CSV="results/raw/${STAMP}-${SCEN}-${SITE}.csv"
: > "$CSV"

probe() {
  local now out site
  now=$(date +%s%3N)
  if out=$(docker exec "$EDGE" wget -q -T 1 -S -O /dev/null http://127.0.0.1:8080/ 2>&1); then
    site=$(printf '%s\n' "$out" | awk -F': *' 'tolower($1) ~ /x-site/ {gsub(/\r/,"",$2); print $2; exit}')
    echo "$now,1,${site:-unknown}"
  else
    echo "$now,0,none"
  fi
}

probe_loop() { while :; do probe >> "$CSV"; done; }

PROBE_PID=""
cleanup() {
  [ -n "$PROBE_PID" ] && kill "$PROBE_PID" 2>/dev/null || true
  heal
}
trap cleanup EXIT

log "scenario=$SCEN site=$SITE  (raw log: $CSV)"
probe_loop &
PROBE_PID=$!

log "baseline for ${BASE_S}s"
sleep "$BASE_S"

INJECT_MS=$(date +%s%3N)
log "INJECT"
inject
log "observing for ${OBSERVE_S}s"
sleep "$OBSERVE_S"

log "HEAL"
heal
log "recovery window ${HEAL_S}s"
sleep "$HEAL_S"

kill "$PROBE_PID" 2>/dev/null || true
wait "$PROBE_PID" 2>/dev/null || true
PROBE_PID=""

read -r OUTAGE FAILED TOTAL AFTER < <(awk -F, -v inj="$INJECT_MS" '
  $1 < inj { next }
  { n++; if ($2 == 0) f++; if ($2 == 1) last = $3 }
  ff == "" && $2 == 0 { ff = $1; next }
  ff != "" && rec == "" && $2 == 1 { rec = $1; after = $3 }
  END {
    if (ff == "") out = 0; else if (rec == "") out = "UNRECOVERED"; else out = rec - ff;
    printf "%s %d %d %s\n", out, f, n, (after != "" ? after : (last != "" ? last : "none"))
  }' "$CSV")

[ -f results/results.csv ] || echo "timestamp,scenario,target,outage_ms,failed_probes,total_probes,served_by_after" > results/results.csv
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),$SCEN,$SITE,$OUTAGE,$FAILED,$TOTAL,$AFTER" >> results/results.csv

log "RESULT: outage=${OUTAGE}ms failed=${FAILED}/${TOTAL} served_by_after=${AFTER}"
scripts/render-results.sh
