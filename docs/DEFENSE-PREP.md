# Defense prep

If your teacher asks you to explain or demo the project, be able to answer
these without notes. The one-line hints point at where the answer lives.

1. Why one ASN per site? (`docs/DESIGN-DECISIONS.md`, entry 2)
2. What happens, step by step, when `hq-r`'s uplink to the core goes down?
   (`wan-cut`: BGP withdraws the direct route, the path via a neighbouring
   site takes over)
3. `silent-blackhole` (link stays "up", 100% loss) recovered as fast as
   `site-isolate` (link down). Why? (the entry point's health checks detect
   both within about a second; BGP's 3 s hold timer only affects rerouting,
   not user-facing failover. Check your own RESULTS.md numbers.)
4. How does the entry point decide HQ is down? (two failed checks, 500 ms apart)
5. What does `cluster-freeze` prove that a network fault does not?
6. How is the platform rebuilt from nothing? (`scripts/up.sh`)
7. What is the weakest point of this design? (single-node clusters, stateless
   app, one entry point)
8. How would you add stateful data, and what would RPO be?
9. What do the NetworkPolicy and Pod Security settings protect against?
10. Why kustomize overlays instead of three copies of the manifests?
11. What would change if the sites were real cloud regions?
12. How accurate are your RTO numbers, and why? (probe timeout, about 1 s)

## Demo script (5 minutes)

1. `make status`: show BGP sessions, three clusters, HQ serving.
2. Start `watch -n0.5 'docker exec clab-fieldnet-edge wget -qO- http://127.0.0.1:8080/whoami'`.
3. In a second terminal, `make chaos SCEN=site-isolate SITE=hq`.
4. Show the answer switch from HQ to FIELD-ALPHA, then back after healing.
5. Open `RESULTS.md` and read the outage number.
