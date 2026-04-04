#!/bin/bash
# update_all.sh
# Orchestrate OSM data updates for Nominatim, Overpass, and Valhalla.
# Designed for air-gap environments: all data must be provided locally.
#
# --- Modes ---
#
# (1) New PBF only (recommended for air-gap):
#   ./update_all.sh --new-pbf /path/to/new-planet.osm.pbf
#
#   Derives an OSC change file from old vs new PBF using osmium derive-changes,
#   then applies it to Nominatim and Overpass. Valhalla is rebuilt from new PBF.
#   Requires the previous planet PBF to still exist at the planet directory.
#   Disk space: both old and new PBF must be present simultaneously (~180GB each).
#
# (2) Pre-downloaded OSC + new PBF:
#   ./update_all.sh --osc /path/to/changes.osc.gz --new-pbf /path/to/new-planet.osm.pbf
#
#   Uses the provided OSC directly (skips derive step). Faster if you already have it.
#
# (3) Full reimport from new PBF:
#   ./update_all.sh --full --new-pbf /path/to/new-planet.osm.pbf
#
#   Reimports all services from scratch. Use when differential is not possible
#   (e.g. Nominatim was imported with FREEZE=true, or the old PBF is lost).
#
# Flags:
#   --skip-nominatim    Skip Nominatim update
#   --skip-overpass     Skip Overpass update
#   --skip-valhalla     Skip Valhalla rebuild

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANET_DIR="/data/www/html/static/openstreetmap/planet"
PLANET_PBF="${PLANET_DIR}/planet-latest.osm.pbf"
OSMIUM_IMAGE="ghcr.io/osmcode/osmium-tool"

NEW_PBF=""
OSC_FILE=""
FULL_MODE=false
SKIP_NOMINATIM=false
SKIP_OVERPASS=false
SKIP_VALHALLA=false

usage() {
  echo "Usage:"
  echo "  $0 --new-pbf NEW.osm.pbf                    # derive OSC then update"
  echo "  $0 --osc changes.osc.gz --new-pbf NEW.osm.pbf  # use given OSC"
  echo "  $0 --full --new-pbf NEW.osm.pbf             # full reimport"
  echo ""
  echo "  [--skip-nominatim] [--skip-overpass] [--skip-valhalla]"
  exit 1
}

[[ $# -eq 0 ]] && usage
while [[ $# -gt 0 ]]; do
  case "$1" in
    --new-pbf)         NEW_PBF="$2"; shift 2 ;;
    --osc)             OSC_FILE="$2"; shift 2 ;;
    --full)            FULL_MODE=true; shift ;;
    --skip-nominatim)  SKIP_NOMINATIM=true; shift ;;
    --skip-overpass)   SKIP_OVERPASS=true; shift ;;
    --skip-valhalla)   SKIP_VALHALLA=true; shift ;;
    *)                 echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[ -z "${NEW_PBF}" ] && usage
[ ! -f "${NEW_PBF}" ] && echo "ERROR: File not found: ${NEW_PBF}" >&2 && exit 1
[ -n "${OSC_FILE}" ] && [ ! -f "${OSC_FILE}" ] && echo "ERROR: File not found: ${OSC_FILE}" >&2 && exit 1

LOG_FILE="${SCRIPT_DIR}/data/update_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "${SCRIPT_DIR}/data"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "===== OSM Update started: $(date) ====="

# --- Derive OSC from old vs new PBF if needed ---
DERIVED_OSC=""
if [ "${FULL_MODE}" = false ] && [ -z "${OSC_FILE}" ]; then
  if [ ! -f "${PLANET_PBF}" ]; then
    echo "ERROR: Previous planet PBF not found at ${PLANET_PBF}." >&2
    echo "Cannot derive changes. Use --full for a full reimport." >&2
    exit 1
  fi
  DERIVED_OSC="${PLANET_DIR}/derived-changes-$(date +%Y%m%d).osc.gz"
  echo ""
  echo "----- Deriving OSC from old vs new PBF -----"
  echo "Old: ${PLANET_PBF}"
  echo "New: ${NEW_PBF}"
  docker run --rm \
    -v "${PLANET_DIR}:/planet" \
    -v "$(dirname "${NEW_PBF}"):/new:ro" \
    "${OSMIUM_IMAGE}" \
    osmium derive-changes \
      /planet/planet-latest.osm.pbf \
      "/new/$(basename "${NEW_PBF}")" \
      --output "/planet/$(basename "${DERIVED_OSC}")" \
      --overwrite
  OSC_FILE="${DERIVED_OSC}"
  echo "Derived: ${OSC_FILE}"
fi

# --- Replace planet-latest.osm.pbf ---
echo ""
echo "----- [1/4] Updating planet-latest.osm.pbf -----"
cp "${NEW_PBF}" "${PLANET_PBF}"
echo "Replaced: ${PLANET_PBF}"

# --- Nominatim ---
if [ "${SKIP_NOMINATIM}" = false ]; then
  echo ""
  echo "----- [2/4] Updating Nominatim -----"
  if [ "${FULL_MODE}" = true ]; then
    "${SCRIPT_DIR}/update_nominatim.sh" --pbf "${NEW_PBF}"
  else
    "${SCRIPT_DIR}/update_nominatim.sh" --osc "${OSC_FILE}"
  fi
else
  echo "----- [2/4] Skipping Nominatim -----"
fi

# --- Overpass ---
if [ "${SKIP_OVERPASS}" = false ]; then
  echo ""
  echo "----- [3/4] Updating Overpass -----"
  if [ "${FULL_MODE}" = true ]; then
    "${SCRIPT_DIR}/update_overpass.sh" --pbf "${NEW_PBF}"
  else
    "${SCRIPT_DIR}/update_overpass.sh" --osc "${OSC_FILE}"
  fi
else
  echo "----- [3/4] Skipping Overpass -----"
fi

# --- Valhalla ---
if [ "${SKIP_VALHALLA}" = false ]; then
  echo ""
  echo "----- [4/4] Rebuilding Valhalla tiles -----"
  "${SCRIPT_DIR}/update_valhalla.sh" --pbf "${PLANET_PBF}"
else
  echo "----- [4/4] Skipping Valhalla -----"
fi

# --- Cleanup derived OSC ---
if [ -n "${DERIVED_OSC}" ] && [ -f "${DERIVED_OSC}" ]; then
  echo ""
  echo "Cleaning up derived OSC: ${DERIVED_OSC}"
  rm -f "${DERIVED_OSC}"
fi

echo ""
echo "===== OSM Update complete: $(date) ====="
echo "Log: ${LOG_FILE}"
