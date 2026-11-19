#!/usr/bin/env bash
# Apply the workload to every site from the manifests in this repo.
# Idempotent: safe to run repeatedly (acts as a manual reconcile).
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

# Preload the app image into every cluster. Pulling it from inside a fresh
# cluster is sometimes very slow; the host's Docker cache makes rebuilds
# fast and repeatable. Keep IMAGE in sync with apps/relief-beacon/base/deployment.yaml.
IMAGE="nginxinc/nginx-unprivileged:1.27-alpine"
docker image inspect "$IMAGE" >/dev/null 2>&1 || { log "pulling $IMAGE on the host"; docker pull "$IMAGE" >/dev/null; }
for s in "${SITES[@]}"; do
  c=$(ctr "$s-k3s")
  if ! docker exec "$c" k3s crictl images 2>/dev/null | grep nginx-unprivileged >/dev/null; then
    log "loading $IMAGE into $s"
    docker save "$IMAGE" | docker exec -i "$c" k3s ctr -n k8s.io images import - >/dev/null \
      || log "WARNING: preload into $s failed; the cluster will pull it itself"
  fi
done

for s in "${SITES[@]}"; do
  c=$(ctr "$s-k3s")
  log "deploying relief-beacon to $s"
  docker exec "$c" rm -rf /tmp/relief-beacon
  docker cp apps/relief-beacon "$c":/tmp/relief-beacon
  docker exec "$c" kubectl apply -k "/tmp/relief-beacon/overlays/$s"
done

for s in "${SITES[@]}"; do
  log "waiting for rollout on $s"
  docker exec "$(ctr "$s-k3s")" kubectl -n relief rollout status deploy/beacon --timeout=300s
done
