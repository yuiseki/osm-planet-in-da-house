docker run \
    --rm \
    -it \
    -dt \
    -v $PWD/data:/custom_files \
    -p 8002:8002 \
    --name valhalla_gis-ops \
    ghcr.io/nilsnolde/docker-valhalla/valhalla:latest
