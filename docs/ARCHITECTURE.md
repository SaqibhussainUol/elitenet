# Architecture

## Components

| Node | Image | Role |
|---|---|---|
| core | FRR 10.2.1 | WAN core router, AS 65000 |
| hq-r, fa-r, fb-r | FRR 10.2.1 | site routers, AS 65001 / 65002 / 65003 |
| hq-k3s, fa-k3s, fb-k3s | rancher/k3s v1.31.4 | one single-node cluster per site |
| edge | HAProxy 3.0 | global entry point, health-checks all sites |

## Addressing

| Link | Subnet | Ends |
|---|---|---|
| core - hq-r | 10.0.1.0/30 | .1 core, .2 hq-r |
| core - fa-r | 10.0.2.0/30 | .1 core, .2 fa-r |
| core - fb-r | 10.0.3.0/30 | .1 core, .2 fb-r |
| hq-r - fa-r | 10.0.12.0/30 | .1 hq-r, .2 fa-r |
| fa-r - fb-r | 10.0.23.0/30 | .1 fa-r, .2 fb-r |
| fb-r - hq-r | 10.0.31.0/30 | .1 fb-r, .2 hq-r |
| edge LAN | 10.9.0.0/24 | .1 core, .10 edge |
| HQ LAN | 10.1.0.0/24 | .1 hq-r, .10 hq-k3s |
| Field Alpha LAN | 10.2.0.0/24 | .1 fa-r, .10 fa-k3s |
| Field Bravo LAN | 10.3.0.0/24 | .1 fb-r, .10 fb-k3s |

## Routing

Every router runs eBGP with a distinct private ASN. Each advertises its own
LAN. BGP timers are 1 s keepalive / 3 s hold so convergence is fast enough to
observe in a short game day. The shortest AS path wins, so traffic normally
goes edge - core - site. If an uplink fails, the route through a neighbouring
site (one extra AS hop) takes over.

## Traffic path

client -> edge:8080 (HAProxy) -> site NodePort 30080 -> beacon pods.

HAProxy marks a site down after two failed health checks (500 ms apart). HQ is
the primary; Field Alpha and Field Bravo are backups used only when HQ is down.

## Rebuild flow

`scripts/up.sh`: containerlab deploys the topology, the script waits for each
cluster to be Ready, applies the kustomize overlay for each site, then waits
for the entry point to report a healthy backend.
