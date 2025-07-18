docker run \
    --memory 20g \
    --memory-swap 20g \
    --memory-swappiness 10 \
    --shm-size=24g \
    --rm \
    -it \
    -e PBF_PATH=/nominatim/data/planet-latest.osm.pbf \
    -e IMPORT_STYLE=admin \
    -v nominatim-flatnode:/nominatim/flatnode \
    -v nominatim-postgresql:/var/lib/postgresql/16/main \
    -v ./data:/nominatim/data \
    -p 8001:8080 \
    --name nominatim_planet \
    mediagis/nominatim:5.1
