# Design decisions

Each entry has a reason and an alternative. Rewrite these in your own words
once you have run the lab; they are the most defensible part of the project.

## 1. Emulate the network with containerlab + FRR

**Why:** real routing protocols, link failures and `tc netem` impairment on a
laptop, with the topology as a YAML file.
**Alternative:** cloud VMs with a managed VPN. Realistic, but it costs money
and hides the routing behaviour this course is about.

## 2. eBGP everywhere, with a site-to-site triangle

**Why:** one ASN per site models independent administrative domains, and the
triangle gives a path that survives the loss of the core.
**Alternative:** OSPF. Simpler inside one domain, but BGP is what connects
separately-run sites.

## 3. One k3s cluster per site

**Why:** a failure domain per site. A cluster that spans sites would turn a WAN
cut into an etcd quorum problem.
**Alternative:** one stretched cluster. Fewer clusters to manage, worse
failure behaviour.

## 4. HAProxy at the edge instead of DNS failover

**Why:** health checks cross the emulated WAN, so network faults directly
affect failover, and the behaviour is easy to measure.
**Alternative:** a DNS-based global load balancer (for example k8gb).
Closer to real multi-site setups, but DNS caching makes timing harder to
measure and it needs more RAM.

## 5. Apply manifests with kustomize from the host

**Why:** needs only Docker, no extra tooling, and the repo is the single source
of truth. `make deploy` is a manual reconcile.
**Alternative:** Flux or Argo CD for continuous reconciliation. Listed as the
next step.

## 6. Stateless workload

**Why:** the project's subject is the network and the platform. Stateful
replication is a separate problem that would need more time and memory.
**Alternative:** CloudNativePG across sites, which adds RPO measurement.
