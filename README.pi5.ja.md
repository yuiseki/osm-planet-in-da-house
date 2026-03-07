# Raspberry Pi 5 での Plan A メモ

この媒体では、`data/overpass/db_planet` にある既存の planet 規模 Overpass DB を
Raspberry Pi 5 へ持ち込んで起動評価する。

2026-03-07 時点で確認できている事実:

- 対象ホスト `192.168.0.90` は `Raspberry Pi 5 Model B Rev 1.0`
- Docker / Docker Compose は導入済み
- `wiktorn/overpass-api` は arm64 ネイティブではなく amd64 イメージ
- Pi 側で `docker run --platform=linux/amd64 wiktorn/overpass-api uname -m` は `x86_64` で通り、qemu による emulation は利用可能

## まずやること

1. USB SSD を Raspberry Pi へ接続して任意の場所へ mount する
2. このディレクトリへ移動する
3. preflight を通す

```bash
cd /path/to/osm-planet-in-da-house
./pi5_overpass_portable.sh preflight
```

mount point は `/portable` 固定ではなくてよい。スクリプトが自身の場所から DB を見つける。

## 起動

まずは Overpass 単体だけを評価する。Nominatim や Valhalla は含めない。

```bash
./pi5_overpass_portable.sh up
./pi5_overpass_portable.sh status
./pi5_overpass_portable.sh query
```

既定ポートは `8002`。

- status: `http://127.0.0.1:8002/api/status`
- interpreter: `http://127.0.0.1:8002/api/interpreter`

停止:

```bash
./pi5_overpass_portable.sh down
```

ログ確認:

```bash
./pi5_overpass_portable.sh logs
```

## 現在の既定値

Pi 5 8GB 上で `node(id)` healthcheck が 15 秒前後で 504 になる問題を避けるため、
2026-03-07 の実測で改善した値を既定にしている。

- `OVERPASS_MEM_LIMIT=6g`
- `OVERPASS_SHM_SIZE=2g`
- `OVERPASS_FASTCGI_PROCESSES=4`
- `OVERPASS_RATE_LIMIT=1`
- `OVERPASS_MAX_TIMEOUT=60000`
- `OVERPASS_TIME=30000`
- `OVERPASS_SPACE=4294967296`
- `OVERPASS_USE_AREAS=false`

この構成で確認できた挙動:

- `/api/status` は 200
- image 組み込み healthcheck は `healthy`
- `node(12579184562)` は約 0.9 秒で 200
- `node(2377723)` は約 0.8 秒で 200
- `node(1)` は約 0.7 秒で 200
- bbox query は約 1.6 秒で 200

必要なら環境変数で上書きする。

```bash
OVERPASS_SHM_SIZE=3g OVERPASS_SPACE=8589934592 ./pi5_overpass_portable.sh up
```

## 注意点

- 現状は amd64 コンテナを arm64 上で emulation 実行する。性能面では不利
- feasibility 評価の第一段階は「起動できるか」「`/api/status` が安定するか」「簡単な query が返るか」
- `OVERPASS_USE_AREAS=false` が既定。areas 更新ループは Pi に重いので、まずは基本 API を優先する
- `docker compose up` 時に memory limit の警告が出る場合がある。Pi 側カーネル設定によっては `mem_limit` は実効しない
- 完全なオフライン運用をする場合、update 用の `OVERPASS_DIFF_URL` は設定しない
