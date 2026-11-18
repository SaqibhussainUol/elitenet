# Runbook


```bash
make up
make status
```



This lab has not been run end to end by its author yet. If `make up` fails,
start here.

**`containerlab: command not found`**
Install containerlab (https://containerlab.dev/install/).

**A k3s container exits right after start**
`docker logs clab-fieldnet-hq-k3s`. The wrapper waits for `/tmp/net-ready`,
which is created by the topology's `exec` steps. If `ip` or `sh` is missing
from the k3s image, switch that node to a Debian/Ubuntu image and install k3s
inside it, or assign the address with `nsenter` from the host.

**Cluster never becomes Ready**
Run `docker exec clab-fieldnet-hq-k3s kubectl get nodes` and check the node
IP: it must be 10.1.0.10. Make sure the host has enough free RAM.

**BGP sessions not Established**
`docker exec clab-fieldnet-core vtysh -c 'show ip bgp summary'`.
Check interface addresses with `docker exec clab-fieldnet-core ip addr`.
Peers must match the addressing table in docs/ARCHITECTURE.md.

**Edge never healthy**
`docker exec clab-fieldnet-edge wget -qO- http://10.1.0.10:30080/healthz`.
If this fails, test hop by hop: edge to core (10.9.0.1), core to hq-r
(10.0.1.2), hq-r to the node (10.1.0.10).

**`tc` or `nsenter` fails in game days**
Install `iproute2` and `util-linux` on the host. On WSL2 the default kernel
may lack the netem module; use a normal Linux VM instead.

**Image pulls are slow on first run**
Expected: three k3s node images, FRR, HAProxy and nginx. Later runs reuse
the cache.
