docker run \
  --memory=64g \
  --memory-swap=64g \
  --shm-size=16g \
  --rm -it \
  --name overpass_japan_kanto_init \
  -e OVERPASS_MODE=init \
  -e OVERPASS_STOP_AFTER_INIT=true \
  -e OVERPASS_META=yes \
  -e OVERPASS_RULES_LOAD=50 \
  -e OVERPASS_PLANET_URL=https://download.geofabrik.de/asia/japan/kanto-latest.osm.pbf \
  -e OVERPASS_PLANET_PREPROCESS='mv /db/planet.osm.bz2 /db/planet.osm.pbf && osmium cat -o /db/planet.osm.bz2 /db/planet.osm.pbf && rm /db/planet.osm.pbf' \
  -v $(pwd)/data/overpass/db_japan_kanto/:/db \
  wiktorn/overpass-api

