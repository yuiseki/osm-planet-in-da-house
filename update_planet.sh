#!/bin/bash
# update_planet.sh
# Update planet-latest.osm.pbf from a locally pre-downloaded OSC change file.
#
# Usage (differential):
#   ./update_planet.sh --osc /path/to/changes.osc.gz
#
# Usage (full replace with new PBF):
#   ./update_planet.sh --pbf /path/to/new-planet.osm.pbf
#
# OSC files can be downloaded in advance from:
#   https://planet.openstreetmap.org/replication/day/
#
# osmium-tool is used for both modes (runs inside Docker, no install needed).

set -euo pipefail

PLANET_DIR="/data/www/html/static/openstreetmap/planet"
PLANET_PBF="${PLANET_DIR}/planet-latest.osm.pbf"
OSMIUM_IMAGE="ghcr.io/osmcode/osmium-tool"
MODE=""
INPUT_FILE=""

usage() {
  echo "Usage:"
  echo "  $0 --osc /path/to/changes.osc.gz   # differential update"
  echo "  $0 --pbf /path/to/new-planet.osm.pbf  # full replace"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --osc)  MODE=diff;  INPUT_FILE="$2"; shift 2 ;;
    --pbf)  MODE=full;  INPUT_FILE="$2"; shift 2 ;;
    *)      usage ;;
  esac
done

[ -z "${MODE}" ] && usage

if [ ! -f "${INPUT_FILE}" ]; then
  echo "ERROR: Input file not found: ${INPUT_FILE}" >&2
  exit 1
fi

INPUT_DIR="$(dirname "${INPUT_FILE}")"
INPUT_NAME="$(basename "${INPUT_FILE}")"

if [ "${MODE}" = "full" ]; then
  echo "Replacing planet PBF with: ${INPUT_FILE}"
  cp "${INPUT_FILE}" "${PLANET_PBF}"
  echo "Done. Updated: ${PLANET_PBF}"

elif [ "${MODE}" = "diff" ]; then
  echo "Applying changes: ${INPUT_FILE} -> ${PLANET_PBF}"
  WORK_DIR="${PLANET_DIR}"
  TEMP_PBF="${PLANET_DIR}/planet-updated.osm.pbf"

  docker run --rm \
    -v "${PLANET_DIR}:/planet" \
    -v "${INPUT_DIR}:/osc" \
    "${OSMIUM_IMAGE}" \
    osmium apply-changes \
      /planet/planet-latest.osm.pbf \
      "/osc/${INPUT_NAME}" \
      --output /planet/planet-updated.osm.pbf \
      --overwrite

  mv "${TEMP_PBF}" "${PLANET_PBF}"
  echo "Done. Updated: ${PLANET_PBF}"
fi
