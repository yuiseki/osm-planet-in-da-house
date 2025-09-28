docker run \
  --memory=80g \
  --memory-swap=80g \
  --shm-size=64g \
  --ulimit nofile=1048576:1048576 \
  --rm -it \
  -e PBF_PATH=/nominatim/data/planet-latest.osm.pbf \
  -e NOMINATIM_FLATNODE_FILE=/nominatim/flatnode/flatnode.file \
  -e IMPORT_WIKIPEDIA=true \
  -v $(pwd)/data/nominatim/flatnode:/nominatim/flatnode \
  -v $(pwd)/data/nominatim/postgres:/var/lib/postgresql/16/main \
  -v $(pwd)/data/nominatim/data:/nominatim/data \
  --name nominatim_planet \
  --entrypoint bash mediagis/nominatim:5.1 -lc '
    set -euo pipefail

    /app/config.sh

    id -u nominatim >/dev/null 2>&1 || useradd -m -r -s /usr/sbin/nologin nominatim

    service postgresql start || true
    echo "Waiting for PostgreSQL to become ready..."
    for i in $(seq 1 3600); do
      pg_isready -h 127.0.0.1 -p 5432 -U postgres >/dev/null 2>&1 && break
      sleep 1
    done
    pg_isready -h 127.0.0.1 -p 5432 -U postgres >/dev/null 2>&1 || {
      echo "PostgreSQL did not become ready in time."; exit 1; }

    sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='\''nominatim'\''" | grep -q 1 || \
      sudo -u postgres createuser -s nominatim
    sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='\''www-data'\''" | grep -q 1 || \
      sudo -u postgres createuser -SDR www-data

    chown -R nominatim:nominatim /nominatim || true
    cd /nominatim

    if sudo -u nominatim nominatim admin --project-dir /nominatim --check-database >/dev/null 2>&1; then
      echo "Database already valid. Skipping import."
      touch /var/lib/postgresql/16/main/import-finished
      exit 0
    fi

    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='\''nominatim'\''" | grep -q 1; then
      echo "Dropping existing database nominatim..."
      sudo -u postgres psql -c "DROP DATABASE IF EXISTS nominatim WITH (FORCE);"
    fi

    if [ -f /var/lib/postgresql/16/main/import-finished ]; then
      echo "Import already finished. Nothing to do."; exit 0; fi

    sudo -E -u nominatim nominatim import \
      --project-dir /nominatim \
      --osm-file "$PBF_PATH" \
      --osm2pgsql-cache 0 \
      --threads 16 \
      --no-updates

    touch /var/lib/postgresql/16/main/import-finished
  '
