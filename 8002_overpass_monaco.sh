docker run \
    -d \
    -e OVERPASS_META=yes \
    -e OVERPASS_MODE=init \
    -e OVERPASS_PLANET_URL=http://download.geofabrik.de/europe/monaco-latest.osm.bz2 \
    -e OVERPASS_DIFF_URL=http://download.openstreetmap.fr/replication/europe/monaco/minute/ \
    -e OVERPASS_RULES_LOAD=10 \
    -v ./data/overpass/db_monaco/:/db \
    -p 8003:80 \
    --name overpass_monaco \
    wiktorn/overpass-api

