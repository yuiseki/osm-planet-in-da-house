docker run \
    --memory 20g \
    --memory-swap 20g \
    --memory-swappiness 10 \
    --shm-size=24g \
    --rm \
    -it \
    -e PBF_PATH=/nominatim/data/planet-latest.osm.pbf \
    -e IMPORT_WIKIPEDIA=true \
    -v $(pwd)/data/nominatim/flatnode:/nominatim/flatnode \
    -v $(pwd)/data/nominatim/postgres:/var/lib/postgresql/16/main \
    -v $(pwd)/data/nominatim/data:/nominatim/data \
    -v $(pwd)/data/nominatim/wikimedia-importance.csv.gz:/nominatim/wikimedia-importance.csv.gz \
    -v /everything/osm/planet/planet-latest.osm.pbf:/nominatim/data/planet-latest.osm.pbf:ro \
    -p 8001:8080 \
    --name nominatim_planet \
    mediagis/nominatim:5.1
