#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
COMPOSE_FILE="${REPO_DIR}/docker-compose.pi5.yml"

usage() {
  cat <<'EOF'
Usage:
  ./pi5_overpass_portable.sh preflight
  ./pi5_overpass_portable.sh config
  ./pi5_overpass_portable.sh up
  ./pi5_overpass_portable.sh down
  ./pi5_overpass_portable.sh status
  ./pi5_overpass_portable.sh logs
  ./pi5_overpass_portable.sh query

Environment overrides:
  OVERPASS_DB_DIR
  OVERPASS_PORT
  OVERPASS_MEM_LIMIT
  OVERPASS_SHM_SIZE
  OVERPASS_FASTCGI_PROCESSES
  OVERPASS_RATE_LIMIT
  OVERPASS_MAX_TIMEOUT
  OVERPASS_TIME
  OVERPASS_SPACE
  OVERPASS_USE_AREAS
  OVERPASS_RULES_LOAD
EOF
}

log() {
  printf '[pi5-overpass] %s\n' "$*" >&2
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing command: %s\n' "$1" >&2
    exit 1
  fi
}

detect_db_dir() {
  local candidates=()
  if [[ -n "${OVERPASS_DB_DIR:-}" ]]; then
    candidates+=("${OVERPASS_DB_DIR}")
  fi
  candidates+=(
    "${REPO_DIR}/data/overpass/db_planet/db_planet"
    "${REPO_DIR}/data/overpass/db_planet"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}/init_done" && -d "${candidate}/db" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  printf 'could not find initialized Overpass DB under %s\n' "${REPO_DIR}/data/overpass" >&2
  exit 1
}

setup_env() {
  local db_dir

  export OVERPASS_IMAGE="${OVERPASS_IMAGE:-wiktorn/overpass-api}"
  export OVERPASS_PLATFORM="${OVERPASS_PLATFORM:-linux/amd64}"
  export OVERPASS_CONTAINER_NAME="${OVERPASS_CONTAINER_NAME:-overpass_planet_pi5}"
  db_dir="$(detect_db_dir)"
  export OVERPASS_DB_DIR="${db_dir}"
  export OVERPASS_PORT="${OVERPASS_PORT:-8002}"
  export OVERPASS_MEM_LIMIT="${OVERPASS_MEM_LIMIT:-6g}"
  export OVERPASS_SHM_SIZE="${OVERPASS_SHM_SIZE:-2g}"
  export OVERPASS_FASTCGI_PROCESSES="${OVERPASS_FASTCGI_PROCESSES:-4}"
  export OVERPASS_RATE_LIMIT="${OVERPASS_RATE_LIMIT:-1}"
  export OVERPASS_MAX_TIMEOUT="${OVERPASS_MAX_TIMEOUT:-60000}"
  export OVERPASS_TIME="${OVERPASS_TIME:-30000}"
  export OVERPASS_SPACE="${OVERPASS_SPACE:-4294967296}"
  export OVERPASS_USE_AREAS="${OVERPASS_USE_AREAS:-false}"
  export OVERPASS_RULES_LOAD="${OVERPASS_RULES_LOAD:-10}"
  export OVERPASS_UPDATE_SLEEP="${OVERPASS_UPDATE_SLEEP:-3600}"
  export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-overpass-pi5}"
}

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

run_query() {
  curl -fsS -G \
    --data-urlencode 'data=[out:json][timeout:25];node(35.681236,139.767125,35.681336,139.767225);out 1;' \
    "http://127.0.0.1:${OVERPASS_PORT}/api/interpreter"
}

preflight() {
  require_cmd docker
  require_cmd curl

  log "repo=${REPO_DIR}"
  log "db=${OVERPASS_DB_DIR}"
  du -sh "${OVERPASS_DB_DIR}"

  if [[ "$(uname -m)" == "aarch64" ]]; then
    log "checking amd64 emulation on arm64 host"
    docker run --rm --platform="${OVERPASS_PLATFORM}" "${OVERPASS_IMAGE}" uname -m
  fi

  compose config >/dev/null
  log "preflight passed"
}

status() {
  compose ps
  printf '\n'
  curl -fsS "http://127.0.0.1:${OVERPASS_PORT}/api/status" | sed -n '1,20p'
}

main() {
  local command="${1:-preflight}"
  setup_env

  case "${command}" in
    preflight)
      preflight
      ;;
    config)
      compose config
      ;;
    up)
      preflight
      compose up -d overpass
      log "container started, check ./pi5_overpass_portable.sh status"
      ;;
    down)
      compose down
      ;;
    status)
      status
      ;;
    logs)
      compose logs -f overpass
      ;;
    query)
      run_query
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
