export OVERPASS_PLANET_PREPROCESS="osmium cat /data/planet.osm.pbf -o /db/planet.osm.bz2 --overwrite"

docker run \
    -d \
    --memory=80g \
    -e OVERPASS_META=yes \
    -e OVERPASS_MODE=init \
    -e OVERPASS_PLANET_URL=file:///db/planet.osm.bz2 \
    -e OVERPASS_DIFF_URL=https://planet.openstreetmap.org/replication/minute/ \
    -e OVERPASS_RULES_LOAD=10 \
    -e OVERPASS_PLANET_PREPROCESS \
    -v ./data/planet-latest.osm.pbf:/data/planet.osm.pbf:ro \
    -v ./data/overpass_db_planet/:/db \
    -p 8003:80 \
    --name overpass_planet \
    wiktorn/overpass-api
