docker run \
  --rm -it \
  --name nominatim_monaco_init \
  -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  -e NOMINATIM_FLATNODE_FILE=/nominatim/flatnode/flatnode.file \
  -e IMPORT_WIKIPEDIA=true \
  -v $(pwd)/data/nominatim/monaco/flatnode:/nominatim/flatnode \
  -v $(pwd)/data/nominatim/monaco/postgres:/var/lib/postgresql/16/main \
  -v $(pwd)/data/nominatim/monaco/data:/nominatim/data \
  mediagis/nominatim:5.1
