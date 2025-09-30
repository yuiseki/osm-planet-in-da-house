docker run \
  --rm -it \
  --name nominatim_monaco \
  -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  -e NOMINATIM_FLATNODE_FILE=/nominatim/flatnode/flatnode.file \
  -e IMPORT_WIKIPEDIA=false \
  -v $(pwd)/data/nominatim/monaco/flatnode:/nominatim/flatnode \
  -v $(pwd)/data/nominatim/monaco/postgres:/var/lib/postgresql/16/main \
  -v $(pwd)/data/nominatim/monaco/data:/nominatim/data \
  -p 8001:8080 \
  mediagis/nominatim:5.1
