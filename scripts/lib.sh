#!/usr/bin/env bash
# Shared helpers. Source this file; do not run it.
LAB="${LAB:-fieldnet}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Lite mode (two sites, about 3 GB RAM) is on when a file named .lite exists
# in the repo root, or when LITE=1 is set. Delete .lite for the full 3 sites.
# shellcheck disable=SC2034  # variables are used by the scripts that source this file
if [ "${LITE:-0}" = "1" ] || [ -f "$ROOT/.lite" ]; then
  LITE=1
  SITES=(hq fa)
  TOPO="network/fieldnet-lite.clab.yml"
  WAN_IFS=(eth1 eth3)
else
  LITE=0
  SITES=(hq fa fb)
  TOPO="network/fieldnet.clab.yml"
  WAN_IFS=(eth1 eth3 eth4)
fi

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# ctr hq-k3s -> clab-fieldnet-hq-k3s
ctr() { echo "clab-${LAB}-$1"; }

# nsx <node> <cmd...>: run a command inside a node's network namespace
# using the host's tools (so images don't need tc/iproute2 installed).
nsx() {
  local pid
  pid=$(docker inspect -f '{{.State.Pid}}' "$(ctr "$1")")
  $SUDO nsenter -t "$pid" -n "${@:2}"
}

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
