docker run \
  --memory=64g \
  --memory-swap=64g \
  --shm-size=16g \
  --rm -it \
  --name overpass_init \
  -e OVERPASS_MODE=init \
  -e OVERPASS_META=yes \
  -e OVERPASS_PLANET_URL=file:///data/planet.osm.pbf \
  -e OVERPASS_COMPRESSION=lz4 \
  -e OVERPASS_RULES_LOAD=50 \
  -e OVERPASS_PLANET_PREPROCESS='osmium cat /data/planet.osm.pbf -o /db/planet.osm.bz2 --overwrite' \
  -v $(pwd)/data/overpass/db_planet/:/db \
  -v $(pwd)/data/overpass/planet-latest.osm.pbf:/data/planet.osm.pbf:ro \
  wiktorn/overpass-api
