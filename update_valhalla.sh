#!/bin/bash
# update_valhalla.sh
# Rebuild Valhalla routing tiles from a new planet PBF or an OSC-updated PBF.
#
# Valhalla does not support incremental tile updates natively.
# All update modes result in a full tile rebuild from a PBF.
#
# Usage (new planet PBF):
#   ./update_valhalla.sh --pbf /path/to/new-planet.osm.pbf
#
# Usage (OSC applied to current planet first, then rebuild):
#   ./update_valhalla.sh --osc /path/to/changes.osc.gz
#
# For --osc, update_planet.sh is called first to produce an updated planet PBF,
# then tiles are rebuilt from it.

set -euo pipefail

PLANET_DIR="/data/www/html/static/openstreetmap/planet"
PLANET_PBF="${PLANET_DIR}/planet-latest.osm.pbf"
VALHALLA_DATA="${PWD}/data/valhalla"
CONTAINER="valhalla_planet"
MODE=""
INPUT_FILE=""

usage() {
  echo "Usage:"
  echo "  $0 --pbf /path/to/new-planet.osm.pbf  # full replace then rebuild"
  echo "  $0 --osc /path/to/changes.osc.gz       # apply diff to planet then rebuild"
  exit 1
}

[[ $# -eq 0 ]] && usage
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pbf)  MODE=full; INPUT_FILE="$2"; shift 2 ;;
    --osc)  MODE=diff; INPUT_FILE="$2"; shift 2 ;;
    *)      usage ;;
  esac
done

if [ ! -f "${INPUT_FILE}" ]; then
  echo "ERROR: Input file not found: ${INPUT_FILE}" >&2
  exit 1
fi

# Step 1: update planet PBF
if [ "${MODE}" = "full" ]; then
  echo "Updating planet PBF (full replace)..."
  "${PWD}/update_planet.sh" --pbf "${INPUT_FILE}"
elif [ "${MODE}" = "diff" ]; then
  echo "Updating planet PBF (differential)..."
  "${PWD}/update_planet.sh" --osc "${INPUT_FILE}"
fi

# Step 2: copy updated PBF to Valhalla data directory
echo "Copying planet PBF to Valhalla data directory..."
cp "${PLANET_PBF}" "${VALHALLA_DATA}/planet-latest.osm.pbf"

# Step 3: stop running container
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "Stopping Valhalla container..."
  docker compose stop valhalla
fi

# Step 4: remove old tiles
echo "Removing old Valhalla tiles..."
rm -rf "${VALHALLA_DATA}/valhalla_tiles" "${VALHALLA_DATA}/valhalla_tiles.tar"

# Step 5: rebuild tiles
echo "Rebuilding Valhalla tiles (this may take many hours for planet scale)..."
docker run \
  --rm \
  --name valhalla_planet_build \
  -v "${VALHALLA_DATA}:/custom_files" \
  -e use_tiles_ignore_pbf=False \
  -e force_rebuild=True \
  -e serve_tiles=False \
  -e server_threads=8 \
  ghcr.io/valhalla/valhalla-scripted:latest

# Step 6: restart server
echo "Starting Valhalla server..."
docker compose up -d valhalla
echo "Valhalla update complete."
