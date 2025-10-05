docker run \
  --memory=64g \
  --memory-swap=64g \
  --shm-size=16g \
  --ulimit nofile=1048576:1048576 \
  --rm -it \
  --name valhalla_gis-ops \
  -e serve_tiles=False \
  -v $PWD/data/valhalla:/custom_files \
  ghcr.io/nilsnolde/docker-valhalla/valhalla:latest
