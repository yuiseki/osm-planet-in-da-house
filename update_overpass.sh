#!/bin/bash
# update_overpass.sh
# Update the Overpass database from a locally pre-downloaded OSC file or a new planet PBF.
#
# Architecture:
#   - DB init:      8002_overpass.sh  (OVERPASS_MODE=init, OVERPASS_STOP_AFTER_INIT=true)
#   - Serve:        docker compose up overpass  (OVERPASS_MODE=clone, detects init_done)
#
# Usage (differential):
#   ./update_overpass.sh --osc /path/to/changes.osc.gz
#
# Usage (full reinit from new PBF - simplest for air-gap):
#   ./update_overpass.sh --pbf /path/to/new-planet.osm.pbf
#
# Usage (status only):
#   ./update_overpass.sh --status
#
# OSC files can be downloaded in advance from:
#   https://planet.openstreetmap.org/replication/day/
#
# NOTE: For differential, the Overpass dispatcher must be stopped before applying.

set -euo pipefail

CONTAINER="overpass_planet"
DB_DIR="${PWD}/data/overpass/db_planet"
OVERPASS_DATA="${PWD}/data/overpass"
MODE=""
INPUT_FILE=""

usage() {
  echo "Usage:"
  echo "  $0 --status                          # show replication state"
  echo "  $0 --osc /path/to/changes.osc.gz    # differential update"
  echo "  $0 --pbf /path/to/new-planet.osm.pbf  # full reinit"
  exit 1
}

[[ $# -eq 0 ]] && usage
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) MODE=status; shift ;;
    --osc)    MODE=diff;   INPUT_FILE="$2"; shift 2 ;;
    --pbf)    MODE=full;   INPUT_FILE="$2"; shift 2 ;;
    *)        usage ;;
  esac
done

if [ "${MODE}" = "status" ]; then
  echo "=== Overpass replication status ==="
  [ ! -f "${DB_DIR}/init_done" ] && echo "ERROR: DB not initialized. Run 8002_overpass.sh first." >&2 && exit 1
  if [ -f "${DB_DIR}/diffs/state.txt" ]; then
    echo "Replication state:"; cat "${DB_DIR}/diffs/state.txt"
  else
    echo "No state.txt yet."
  fi
  if [ -f "${DB_DIR}/changes.log" ]; then
    echo ""; echo "Recent changes.log (last 10 lines):"; tail -10 "${DB_DIR}/changes.log"
  fi
  echo ""
  docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$" \
    && echo "Container '${CONTAINER}' is running." \
    || echo "Container '${CONTAINER}' is NOT running. Start with: docker compose up -d overpass"
  exit 0
fi

if [ ! -f "${INPUT_FILE}" ]; then
  echo "ERROR: Input file not found: ${INPUT_FILE}" >&2
  exit 1
fi

if [ "${MODE}" = "diff" ]; then
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "ERROR: Container '${CONTAINER}' must be running to apply OSC." >&2
    exit 1
  fi

  OSC_NAME="$(basename "${INPUT_FILE}")"
  OSC_DIR="$(dirname "${INPUT_FILE}")"

  echo "Applying OSC to Overpass: ${OSC_NAME}"
  # The overpass-api update_overpass tool reads from stdin.
  # Stop dispatcher, apply changes, restart.
  docker exec "${CONTAINER}" sh -c "
    kill \$(cat /db/dispatcher.pid) 2>/dev/null || true
    sleep 2
    zcat /osc/${OSC_NAME} | /app/bin/update_overpass --db-dir=/db
    /app/bin/osm3s_query --db-dir=/db --flush
  " -v "${OSC_DIR}:/osc"
  # Restart serving
  docker compose restart overpass
  echo "Overpass differential update complete."

elif [ "${MODE}" = "full" ]; then
  echo "Full Overpass reinit from: ${INPUT_FILE}"
  echo "This will stop Overpass, delete the existing DB, and reimport (takes hours)."
  read -rp "Continue? [y/N] " confirm
  [[ "${confirm}" =~ ^[Yy]$ ]] || exit 0

  docker compose stop overpass

  # Replace symlinked PBF for 8002_overpass.sh
  cp "${INPUT_FILE}" "${OVERPASS_DATA}/planet-latest.osm.pbf"

  # Clear existing DB (keep directory structure)
  echo "Clearing existing Overpass DB..."
  rm -rf "${DB_DIR}/db" "${DB_DIR}/diffs" "${DB_DIR}/planet.osm.bz2" "${DB_DIR}/init_done"

  echo "Running Overpass init (8002_overpass.sh)..."
  bash "${PWD}/8002_overpass.sh"

  echo "Starting Overpass server..."
  docker compose up -d overpass
  echo "Overpass full reinit complete."
fi
