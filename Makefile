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

PLANET_PBF = data/planetiler/planet-latest.osm.pbf

# Download source files that planetiler needs (except OSM PBF which is handled separately)
.PHONY: planetiler-download-sources
planetiler-download-sources:
	@mkdir -p data/sources
	@if [ ! -f data/sources/lake_centerline.shp.zip ]; then \
		echo "Downloading lake_centerline.shp.zip..."; \
		curl -L -o data/sources/lake_centerline.shp.zip \
			https://github.com/acalcutt/osm-lakelines/releases/download/v12/lake_centerline.shp.zip; \
	else \
		echo "lake_centerline.shp.zip already exists, skipping."; \
	fi
	@if [ ! -f data/sources/water-polygons-split-3857.zip ]; then \
		echo "Downloading water-polygons-split-3857.zip (~750MB)..."; \
		curl -L -o data/sources/water-polygons-split-3857.zip \
			https://osmdata.openstreetmap.de/download/water-polygons-split-3857.zip; \
	else \
		echo "water-polygons-split-3857.zip already exists, skipping."; \
	fi
	@if [ ! -f data/sources/natural_earth_vector.sqlite.zip ]; then \
		echo "Downloading natural_earth_vector.sqlite.zip..."; \
		curl -L -o data/sources/natural_earth_vector.sqlite.zip \
			https://naciscdn.org/naturalearth/packages/natural_earth_vector.sqlite.zip; \
	else \
		echo "natural_earth_vector.sqlite.zip already exists, skipping."; \
	fi

.PHONY: planetiler-build
planetiler-build:
	@echo "=== planetiler-build start: $$(date -Iseconds) ==="
	$(PLANETILER_RUN) \
		--area=planet \
		--bounds=planet \
		--osm-path=/data/planetiler/planet-latest.osm.pbf \
		--lake_centerlines_path=/data/sources/lake_centerline.shp.zip \
		--water_polygons_path=/data/sources/water-polygons-split-3857.zip \
		--natural_earth_path=/data/sources/natural_earth_vector.sqlite.zip \
		--nodemap-type=sparsearray \
		--nodemap-storage=mmap \
		--output=/data/planetiler/planet.mbtiles \
		--force
	@echo "=== planetiler-build end: $$(date -Iseconds) ==="

.PHONY: planetiler-update
planetiler-update: planetiler-build
	docker compose restart tileserver
