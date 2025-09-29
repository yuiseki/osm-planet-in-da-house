docker run \
  --memory=64g \
  --memory-swap=64g \
  --shm-size=16g \
  --name valhalla_gis-ops \
  --rm -it \
  -v $PWD/data:/custom_files \
  ghcr.io/nilsnolde/docker-valhalla/valhalla:latest
