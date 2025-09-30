docker run \
  --memory=80g \
  --memory-swap=80g \
  --shm-size=64g \
  --ulimit nofile=1048576:1048576 \
  --rm -it \
  --name nominatim_planet_admin \
  -e PBF_PATH=/nominatim/data/planet-latest.osm.pbf \
  -e NOMINATIM_FLATNODE_FILE=/nominatim/flatnode/flatnode.file \
  -e IMPORT_STYLE=admin \
  -e IMPORT_WIKIPEDIA=false \
  -v $(pwd)/data/nominatim/planet_admin/flatnode:/nominatim/flatnode \
  -v $(pwd)/data/nominatim/planet_admin/postgres:/var/lib/postgresql/16/main \
  -v $(pwd)/data/nominatim/planet_admin/data:/nominatim/data \
  -p 8001:8080 \
  mediagis/nominatim:5.1
