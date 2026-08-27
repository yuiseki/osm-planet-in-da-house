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

## 起動時に自動で立ち上げる (pi5-deck)

`systemd/overpass-pi5.service` と `systemd/overpass-pi5.default` を配備する。

```
sudo install -m644 systemd/overpass-pi5.service /etc/systemd/system/
sudo install -m644 systemd/overpass-pi5.default /etc/default/overpass-pi5
sudo systemctl daemon-reload && sudo systemctl enable --now overpass-pi5.service
```

SSD は fstab に **`nofail` 付きで**書く。SSD を抜いた状態でも起動が止まらないようにするため。

```
UUID=<uuid>  /mnt/tiny_1tb  ext4  defaults,nofail,x-systemd.device-timeout=10  0  2
```

unit の `RequiresMountsFor=/mnt/tiny_1tb` がこの行から生成される `mnt-tiny_1tb.mount` を参照する。
**これが要る**。Docker は compose の `restart: unless-stopped` によって自前でコンテナを起こすので、
放っておくとマウント前に起動して DB の代わりに空のディレクトリを掴む。データが消えたように見える
壊れ方をするので、`ExecStartPre` で一度 down してから up する。

実測 (Raspberry Pi 5 / 4GB / USB3.0 SSD、再起動直後):

| クエリ | 時間 | 要素数 |
|---|---|---|
| 渋谷のカフェ 300m | 0.30〜1.32s | 62 |
| 広島のカフェ 1km | 1.98s | 60 |
| ニューヨークのカフェ | 2.04s | 52 |
| 東京 5km 圏のカフェ | 2.39s | 2093 |
| 広島 bbox 全ノード | 1.50s | 3038 |

### area クエリを使う

`OVERPASS_USE_AREAS` は supervisord の 2 つのプログラムを一括で制御する。

```
[program:dispatcher_areas]  area クエリに応答する。軽い
[program:areas_rules]       rules_loop.sh。area の再計算。Pi には重い
```

`false` を既定にしているのは後者を避けるためだが、前者まで止まるので
`area[...]` を使うクエリが `The dispatcher is turned off` で失敗する。
DB 側の area データ (`area_blocks.bin` ほか、母艦で構築したもの) は
コピーされていて揃っているので、生成し直す必要はない。

`pi5_overpass_areas_dispatcher.sh` が前者だけを起動し、居なければ入れ直す。
`systemd/overpass-areas-pi5.service` で常駐させる。

```bash
install -Dm755 pi5_overpass_areas_dispatcher.sh ~/bin/overpass-areas-dispatcher.sh
sudo cp systemd/overpass-areas-pi5.service /etc/systemd/system/
sudo systemctl enable --now overpass-areas-pi5.service
```

判定に落とし穴がある。`dispatcher --areas --status` は areas dispatcher が
動いていなくても成功するので、死活判定には使えない。スクリプトはホスト側の
`ps` でプロセスの有無を見ている。コンテナ内に `ps` も `pkill` も無い。

pi5-w-1 (8GB, arm64) での実測は area クエリ 0.61s / bbox 0.24s。

### amd64 をエミュレートしないこと

`wiktorn/overpass-api` には **arm64 イメージがある**ので `OVERPASS_PLATFORM=linux/arm64` で動く。
amd64 機で作った DB をそのまま読めることを確認済み (どちらも 64bit リトルエンディアン)。起動は約8秒。

`linux/amd64` + qemu で動かそうとすると **Pi 5 では失敗する**。qemu-user はホストより小さいゲスト
ページサイズをエミュレートできず、Pi 5 の既定カーネルは **16KB ページ** (`getconf PAGESIZE` = 16384、
`uname -r` が `-rpi-2712`)。4KB 整列を要求するオブジェクトのマップに失敗し、nginx が
`libcrypto.so.3: failed to map segment from shared object` で起動しない。
**素の `sh` は動いてしまう**ので「エミュレーションは効いている」と見えるのが厄介。
`kernel=kernel8.img` で 4KB ページのカーネルに切り替えれば動くはずだが、arm64 で足りるので不要。

### 4GB 機向けの設定

リポジトリ既定 (`OVERPASS_MEM_LIMIT=6g` / `OVERPASS_SHM_SIZE=2g`) は 8GB 機向け。pi5-deck では
地図アプリが約250MB、pi-hear が約150MB 常駐しているので `overpass-pi5.default` のとおり絞る。
`OVERPASS_SPACE` を既定の 4GB から 1GB に下げているのは、4GB を要求するクエリ1本で機械ごと
落ちるのを防ぐため。この設定で空きメモリは 3.1Gi のままだった。

なお `mem_limit` は cgroup の都合で「Limitation discarded」と警告が出て効かないことがある。
`OVERPASS_SPACE` のほうが実効的な歯止めになる。
