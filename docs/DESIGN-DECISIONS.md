# Design decisions

I built the network with containerlab, which runs real routers FRRouting as containers on my system and with FRRouting I could cut a link and watch the routes change. Cloud servers with a VPN were another option, but they cost money and hide how the routing works.

each site have their own AS number and talk BGP. Each site is like a separate organisation, and BGP is the protocol that connects separate networks. HQ and Field Alpha also have a direct link to each other, which gives a second path. When I cut HQ's uplink to the core (the wan-cut test), no request failed, because traffic went through the other site.

HQ and Field Alpha each run their own k3s cluster. If one site dies, the other cluster keeps working. One big cluster across both sites could break when the link between them fails.

HAProxy sits in front of the sites. It checks every site every 0.5 seconds. HQ is the main site and Field Alpha is the backup. After 2 failed checks, HAProxy stops sending users to a site. The checks travel over the same virtual network that I break, so a network failure shows up directly in failover.

The app is described in Kubernetes YAML files, with one shared base and one small overlay for each site. This needs only Docker and everything is stored in git. Tools like Flux or Argo CD would keep fixing the clusters automatically, but they are more to set up, so I left them as a next step. The app namespace uses the restricted Pod Security setting, the containers run as a normal user with extra permissions removed, and a network policy blocks all incoming traffic except the one web port. These are cheap to add and good practice.

I used two sites instead of three because three clusters were too much for my laptop's memory. The design is the same, and a third site can be switched on by deleting the .lite file. The app is a simple web page that shows which site answered, with no database, because the project is about the network and the platform, and a database copied between sites is a separate, bigger problem.

I broke things on purpose and measured what users saw. Cutting one uplink caused no failed requests. A slow, lossy link caused 9 of 136 requests to fail but the site stayed up. A link that looked up but lost every packet caused about 0.9 seconds of outage. Cutting a whole site off caused about 1.7 to 1.9 seconds, and then Field Alpha served the traffic. Freezing the Kubernetes cluster was slowest, about 2.6 seconds, because requests to a frozen cluster wait until they time out. Rebuilding everything from nothing took 303 seconds.

Some things went wrong while I built it. The clock inside WSL jumped by 12 hours, so Kubernetes thought its own certificates were not valid yet. Restarting WSL fixed it. The app could not find its settings because they were created in the wrong namespace, and adding the namespace to each overlay fixed that. Downloading the app image inside the cluster was very slow, so the deploy script now downloads it once and loads it into each cluster.

If I had more time, I would add Flux or Argo CD, a database copied between the sites, and DNS-based failover instead of a single HAProxy.
