#!/usr/bin/env bash
# pi5 の Overpass で area クエリを使えるようにする。
#
# なぜ必要か:
#   OVERPASS_USE_AREAS は supervisord の 2 つのプログラムを同時に制御する。
#     [program:dispatcher_areas]  area クエリに応答する。軽い
#     [program:areas_rules]       rules_loop.sh。area の再計算。Pi には重い
#   README.pi5.ja.md が false を既定にしているのは後者を避けるため。
#   前者まで止まるのは巻き添えで、止めたかったものではない。
#   このスクリプトは前者だけを起動し、後者には触れない。
#
#   area データ本体 (area_blocks.bin 16G ほか) は母艦からコピー済みで、
#   生成し直す必要はない。起動していないだけだった。
#
# 死活監視も兼ねる。dispatcher が落ちたり、コンテナが作り直されたりすると
# docker exec で起動したプロセスは消えるので、定期的に確認して入れ直す。
set -uo pipefail

CONTAINER="${OVERPASS_CONTAINER_NAME:-overpass_planet_pi5}"
INTERVAL="${AREAS_CHECK_INTERVAL:-60}"

log() { printf '[overpass-areas] %s\n' "$*"; }

areas_alive() {
  # `dispatcher --areas --status` は areas dispatcher が動いていなくても
  # 成功してしまう (共有メモリのファイルを読むだけで応答する)。
  # 死活判定には使えないので、ホスト側からプロセスの有無を見る。
  # コンテナ内に ps は無いが、ホストからは qemu 越しでも args が見える。
  # grep 自身に一致しないよう先頭文字を文字クラスにしている。
  ps -eo args 2>/dev/null | grep -q -- '[d]ispatcher --areas --db-dir'
}

container_up() {
  [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = "true" ]
}

start_areas() {
  # 前回の異常終了で共有メモリのファイルが残っていると起動に失敗する。
  # entrypoint はコンテナ起動時にしか掃除しないので、ここでも面倒を見る。
  if ! docker exec "$CONTAINER" test -S /dev/shm/osm3s_areas 2>/dev/null; then
    docker exec "$CONTAINER" sh -c '[ -e /dev/shm/osm3s_areas ] && rm -f /dev/shm/osm3s_areas' 2>/dev/null
  fi
  # 重複クエリの扱いはコンテナ本体の dispatcher と揃える。ここだけ既定の no
  # にしていると、base 側が通る同一クエリを areas 側が
  # Dispatcher_Client::request_read_and_idx::duplicate_query で弾き、
  # /osm3s_areas とだけ書かれたエラーが出て原因が分かりにくい。
  local dup
  dup="$(docker inspect "$CONTAINER" \
    --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null |
    sed -n 's/^OVERPASS_ALLOW_DUPLICATE_QUERIES=//p' | head -1)"
  dup="${dup:-no}"
  docker exec -u overpass -d "$CONTAINER" \
    /app/bin/dispatcher --areas --db-dir=/db/db \
    --allow-duplicate-queries="$dup" 2>/dev/null
}

while true; do
  if container_up; then
    if areas_alive; then
      :
    else
      log "areas dispatcher is down; starting"
      start_areas
      sleep 5
      if areas_alive; then
        log "areas dispatcher is up"
      else
        log "failed to start areas dispatcher; will retry in ${INTERVAL}s"
      fi
    fi
  else
    log "container ${CONTAINER} is not running; waiting"
  fi
  sleep "$INTERVAL"
done
