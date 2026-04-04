#!/bin/bash
# update_nominatim.sh
# Update Nominatim from a locally pre-downloaded OSC file or a new planet PBF.
#
# Usage (differential - recommended for air-gap):
#   ./update_nominatim.sh --osc /path/to/changes.osc.gz
#
# Usage (full reimport with new PBF):
#   ./update_nominatim.sh --pbf /path/to/new-planet.osm.pbf
#
# PREREQUISITE for differential:
#   Nominatim must have been imported with FREEZE=false (set in docker-compose.yml).
#   If imported with FREEZE=true, planet_osm_ways/rels tables were dropped permanently.
#   In that case, use --pbf to do a full reimport (deletes and recreates the DB).
#
# OSC files can be downloaded in advance from:
#   https://planet.openstreetmap.org/replication/day/

set -euo pipefail

CONTAINER="nominatim_planet"
NOMINATIM_DATA="${PWD}/data/nominatim/data"
MODE=""
INPUT_FILE=""

usage() {
  echo "Usage:"
  echo "  $0 --osc /path/to/changes.osc.gz   # differential update"
  echo "  $0 --pbf /path/to/new-planet.osm.pbf  # full reimport"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --osc)  MODE=diff; INPUT_FILE="$2"; shift 2 ;;
    --pbf)  MODE=full; INPUT_FILE="$2"; shift 2 ;;
    *)      usage ;;
  esac
done

[ -z "${MODE}" ] && usage

if [ ! -f "${INPUT_FILE}" ]; then
  echo "ERROR: Input file not found: ${INPUT_FILE}" >&2
  exit 1
fi

if [ "${MODE}" = "diff" ]; then
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "ERROR: Container '${CONTAINER}' is not running." >&2
    echo "Start with: docker compose up -d nominatim" >&2
    exit 1
  fi

  # Copy OSC into the nominatim data volume so the container can read it
  OSC_NAME="$(basename "${INPUT_FILE}")"
  cp "${INPUT_FILE}" "${NOMINATIM_DATA}/${OSC_NAME}"

  echo "Applying OSC to Nominatim: ${OSC_NAME}"
  docker exec -u nominatim "${CONTAINER}" \
    nominatim replication --osm-dir /nominatim/data --once

  rm -f "${NOMINATIM_DATA}/${OSC_NAME}"
  echo "Nominatim differential update complete."

elif [ "${MODE}" = "full" ]; then
  echo "Full Nominatim reimport from: ${INPUT_FILE}"
  echo "WARNING: This will stop Nominatim and delete the existing database."
  read -rp "Continue? [y/N] " confirm
  [[ "${confirm}" =~ ^[Yy]$ ]] || exit 0

  docker compose stop nominatim

  # Replace PBF in nominatim data directory
  cp "${INPUT_FILE}" "${NOMINATIM_DATA}/planet-latest.osm.pbf"

  # Delete postgres data to trigger reimport on next start
  echo "Deleting existing Nominatim database..."
  rm -rf "${PWD}/data/nominatim/planet/postgres"/*

  echo "Starting Nominatim reimport (this will take many hours)..."
  docker compose up nominatim
fi
