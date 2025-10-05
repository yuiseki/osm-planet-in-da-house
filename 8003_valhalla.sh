docker run \
  --memory=64g \
  --memory-swap=64g \
  --shm-size=16g \
  --ulimit nofile=1048576:1048576 \
  --rm -it \
  --name valhalla_planet \
  -e serve_tiles=False \
  -v $PWD/data/valhalla:/custom_files \
  ghcr.io/valhalla/valhalla-scripted:latest
