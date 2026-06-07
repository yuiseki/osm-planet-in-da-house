PLANETILER_AI_DATA = /everything/src/github.com/yuiseki/planetiler-ai/data
PLANETILER_IMAGE = ghcr.io/onthegomap/planetiler:latest
PLANETILER_MEMORY = --memory 90g --memory-swap -1
PLANETILER_JAVA = -XX:+UseZGC -Xms28g -Xmx28g

PLANETILER_RUN = docker run \
	-u `id -u`:`id -g` \
	$(PLANETILER_MEMORY) \
	-e JAVA_TOOL_OPTIONS="$(PLANETILER_JAVA)" \
	-v $(PWD)/data:/data \
	$(PLANETILER_IMAGE)

.PHONY: docker-pull
docker-pull:
	docker pull $(PLANETILER_IMAGE)
	docker pull maptiler/tileserver-gl:latest
	docker pull mediagis/nominatim:5.1
	docker pull ghcr.io/nilsnolde/docker-valhalla/valhalla:latest
	docker pull wiktorn/overpass-api

.PHONY: tileserver-setup-fonts
tileserver-setup-fonts:
	cp -r $(PLANETILER_AI_DATA)/fonts data/planetiler/fonts

.PHONY: planetiler-build
planetiler-build:
	@echo "=== planetiler-build start: $$(date -Iseconds) ==="
	$(PLANETILER_RUN) \
		--area=planet \
		--bounds=planet \
		--download \
		--fetch-wikidata \
		--nodemap-type=sparsearray \
		--nodemap-storage=mmap \
		--output=/data/planetiler/planet.mbtiles \
		--force
	@echo "=== planetiler-build end: $$(date -Iseconds) ==="

.PHONY: planetiler-update
planetiler-update: planetiler-build
	docker compose restart tileserver
