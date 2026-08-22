#!/usr/bin/env bash
#
# 持ち運んだ Nominatim のデータベースを Raspberry Pi 5 で配る。
# pi5_overpass_portable.sh と同じ作りで、違いは PostgreSQL を抱えていること。

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
COMPOSE_FILE="${REPO_DIR}/docker-compose.nominatim.pi5.yml"

usage() {
  cat <<'EOF'
Usage:
  ./pi5_nominatim_portable.sh preflight
  ./pi5_nominatim_portable.sh config
  ./pi5_nominatim_portable.sh up
  ./pi5_nominatim_portable.sh down
  ./pi5_nominatim_portable.sh status
  ./pi5_nominatim_portable.sh logs
  ./pi5_nominatim_portable.sh query

Environment overrides:
  NOMINATIM_DATASET     planet_admin (既定) / planet / monaco
  NOMINATIM_PG_DIR      上の自動検出を上書きする
  NOMINATIM_PORT
  NOMINATIM_MEM_LIMIT
  NOMINATIM_SHM_SIZE
  NOMINATIM_THREADS
  NOMINATIM_IMAGE
  NOMINATIM_PLATFORM
EOF
}

log() {
  printf '[pi5-nominatim] %s\n' "$*" >&2
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing command: %s\n' "$1" >&2
    exit 1
  fi
}

detect_pg_dir() {
  local candidates=()
  if [[ -n "${NOMINATIM_PG_DIR:-}" ]]; then
    candidates+=("${NOMINATIM_PG_DIR}")
  fi
  local dataset="${NOMINATIM_DATASET:-planet_admin}"
  candidates+=(
    "${REPO_DIR}/data/nominatim/${dataset}/postgres"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    # import-finished はエントリポイントがインポートを飛ばす判定にも使う印。
    # これが無いものを渡すと、配るつもりが planet の再インポートを始める。
    if [[ -e "${candidate}/import-finished" && -e "${candidate}/PG_VERSION" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  printf 'could not find an imported Nominatim cluster under %s\n' \
    "${REPO_DIR}/data/nominatim" >&2
  exit 1
}

setup_env() {
  local pg_dir
  pg_dir="$(detect_pg_dir)"
  export NOMINATIM_PG_DIR="${pg_dir}"
  export NOMINATIM_IMAGE="${NOMINATIM_IMAGE:-mediagis/nominatim:5.1}"
  export NOMINATIM_PLATFORM="${NOMINATIM_PLATFORM:-linux/arm64}"
  export NOMINATIM_CONTAINER_NAME="${NOMINATIM_CONTAINER_NAME:-nominatim_pi5}"
  export NOMINATIM_PORT="${NOMINATIM_PORT:-8001}"
  export NOMINATIM_MEM_LIMIT="${NOMINATIM_MEM_LIMIT:-2g}"
  export NOMINATIM_SHM_SIZE="${NOMINATIM_SHM_SIZE:-256m}"
  export NOMINATIM_THREADS="${NOMINATIM_THREADS:-2}"
  export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-nominatim-pi5}"
}

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

run_query() {
  curl -fsS -G --data-urlencode 'q=Hiroshima' --data-urlencode 'format=jsonv2' \
    "http://127.0.0.1:${NOMINATIM_PORT}/search"
}

# 前回クリーンに落ちていないクラスタには postmaster.pid が残る。PostgreSQL は
# 起動時にこれを見て「まだ動いている」と判断すると起動を拒む。持ち運んだ複製で
# あれば中のプロセスは存在しないので、消してよい。元データは触らないこと。
clear_stale_pid() {
  local pid_file="${NOMINATIM_PG_DIR}/postmaster.pid"
  if [[ -e "${pid_file}" ]]; then
    log "removing stale ${pid_file}"
    rm -f "${pid_file}" 2>/dev/null || sudo rm -f "${pid_file}"
  fi
}

preflight() {
  require_cmd docker
  require_cmd curl

  log "repo=${REPO_DIR}"
  log "cluster=${NOMINATIM_PG_DIR}"
  log "PG_VERSION=$(cat "${NOMINATIM_PG_DIR}/PG_VERSION" 2>/dev/null || echo '?')"
  du -sh "${NOMINATIM_PG_DIR}" 2>/dev/null || true

  # データベースは PostgreSQL のメジャーバージョンに縛られる。イメージが
  # 別のバージョンを積んでいると、マウント先が食い違って空のクラスタに見え、
  # 配るつもりが planet の再インポートを始めることになる。
  local want got
  want="$(cat "${NOMINATIM_PG_DIR}/PG_VERSION" 2>/dev/null || true)"
  got="$(docker run --rm --platform="${NOMINATIM_PLATFORM}" --entrypoint sh \
           "${NOMINATIM_IMAGE}" -c 'ls -d /var/lib/postgresql/*/ 2>/dev/null | head -1' \
         2>/dev/null | sed 's|.*postgresql/||; s|/||' || true)"
  log "cluster PG=${want:-?}  image PG=${got:-?}"
  if [[ -n "${want}" && -n "${got}" && "${want}" != "${got}" ]]; then
    printf 'PostgreSQL version mismatch: cluster is %s but %s ships %s\n' \
      "${want}" "${NOMINATIM_IMAGE}" "${got}" >&2
    exit 1
  fi

  compose config >/dev/null
  log "preflight passed"
}

status() {
  compose ps
  printf '\n'
  curl -fsS "http://127.0.0.1:${NOMINATIM_PORT}/status" || true
}

main() {
  local command="${1:-preflight}"
  setup_env

  case "${command}" in
    preflight) preflight ;;
    config)    compose config ;;
    up)
      preflight
      clear_stale_pid
      compose up -d nominatim
      log "container started, check ./pi5_nominatim_portable.sh status"
      ;;
    down)      compose down ;;
    status)    status ;;
    logs)      compose logs -f nominatim ;;
    query)     run_query ;;
    help|-h|--help) usage ;;
    *) usage >&2; exit 1 ;;
  esac
}

main "$@"
