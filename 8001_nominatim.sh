docker run \
  --memory=80g \
  --memory-swap=80g \
  --shm-size=64g \
  --ulimit nofile=1048576:1048576 \
  --rm -it \
  --name nominatim_planet \
  -e THREADS=16 \
  -e FREEZE=true \
  -e PBF_PATH=/nominatim/data/planet-latest.osm.pbf \
  -e IMPORT_WIKIPEDIA=/nominatim/data/wikimedia-importance.csv.gz \
  -e NOMINATIM_FLATNODE_FILE=/nominatim/flatnode/flatnode.file \
  -v $(pwd)/data/nominatim/planet/flatnode:/nominatim/flatnode \
  -v $(pwd)/data/nominatim/planet/postgres:/var/lib/postgresql/16/main \
  -v $(pwd)/data/nominatim/data:/nominatim/data \
  -p 8001:8080 \
  mediagis/nominatim:5.1
