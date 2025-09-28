docker run \
  --memory=64g \
  --memory-swap=64g \
  --shm-size=16g \
  --rm -it \
  --name overpass_monaco_init \
  -e OVERPASS_MODE=init \
  -e OVERPASS_META=yes \
  -e OVERPASS_PLANET_URL=http://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  -e OVERPASS_DIFF_URL=http://download.openstreetmap.fr/replication/europe/monaco/minute/ \
  -e OVERPASS_RULES_LOAD=50 \
  -v $(pwd)/data/overpass/db_monaco/:/db \
  wiktorn/overpass-api

