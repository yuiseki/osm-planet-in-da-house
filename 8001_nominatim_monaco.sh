docker run \
  --memory=80g \
  --memory-swap=80g \
  --shm-size=64g \
  --ulimit nofile=1048576:1048576 \
  --rm -it \
  --name nominatim_monaco \
  -e THREADS=16 \
  -e FREEZE=true \
  -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  -e IMPORT_WIKIPEDIA=/nominatim/data/wikimedia-importance.csv.gz \
  -e NOMINATIM_FLATNODE_FILE=/nominatim/flatnode/flatnode.file \
  -v $(pwd)/data/nominatim/monaco/flatnode:/nominatim/flatnode \
  -v $(pwd)/data/nominatim/monaco/postgres:/var/lib/postgresql/16/main \
  -v $(pwd)/data/nominatim/data:/nominatim/data \
  -p 8001:8080 \
  mediagis/nominatim:5.1
