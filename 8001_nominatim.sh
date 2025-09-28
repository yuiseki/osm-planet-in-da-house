docker run \
  --memory=80g \
  --memory-swap=80g \
  --shm-size=64g \
  --ulimit nofile=1048576:1048576 \
  --rm -it \
  --name nominatim_init \
  -e PBF_PATH=/nominatim/data/planet-latest.osm.pbf \
  -e NOMINATIM_FLATNODE_FILE=/nominatim/flatnode/flatnode.file \
  -e IMPORT_WIKIPEDIA=true \
  -v $(pwd)/data/nominatim/flatnode:/nominatim/flatnode \
  -v $(pwd)/data/nominatim/postgres:/var/lib/postgresql/16/main \
  -v $(pwd)/data/nominatim/data:/nominatim/data \
  --entrypoint bash mediagis/nominatim:5.1 -lc '
    set -euo pipefail

    sudo chown -R postgres:postgres /var/lib/postgresql || true

    id -u nominatim >/dev/null 2>&1 || useradd -m -r -s /usr/sbin/nologin nominatim

    /app/config.sh
    /app/init.sh
  '
