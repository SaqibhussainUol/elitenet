.RECIPEPREFIX = >
SHELL := /bin/bash

SCEN ?= site-isolate
SITE ?= hq

.PHONY: help up deploy status chaos gameday-all rebuild destroy results lint

help:
> @echo "make up                 build network + clusters + workload from code"
> @echo "make status             BGP, clusters, entry-point health"
> @echo "make deploy             re-apply the workload (manual reconcile)"
> @echo "make chaos SCEN=... SITE=...   run one game day (see chaos/gameday.sh)"
> @echo "make gameday-all        run the full scenario suite"
> @echo "make rebuild            destroy + rebuild from zero, timed"
> @echo "make results            regenerate RESULTS.md"
> @echo "make destroy            tear everything down"
> @echo "make lint               yamllint + shellcheck (needs both installed)"

up:
> scripts/up.sh

deploy:
> scripts/deploy.sh

status:
> scripts/status.sh

chaos:
> chaos/gameday.sh $(SCEN) $(SITE)

gameday-all:
> chaos/gameday.sh wan-cut hq
> chaos/gameday.sh wan-degrade hq
> chaos/gameday.sh silent-blackhole hq
> chaos/gameday.sh site-isolate hq
> chaos/gameday.sh cluster-freeze hq

rebuild:
> scripts/rebuild.sh

results:
> scripts/render-results.sh

destroy:
> scripts/destroy.sh

lint:
> yamllint -c .yamllint .
> shellcheck -S warning scripts/*.sh chaos/*.sh
