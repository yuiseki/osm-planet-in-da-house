# osm-planet-in-da-house

OpenStreetMapの惑星データ全体をローカル環境で実行するための手順です。

## 推奨マシンスペック

- **メモリ:** 96GB 以上
- **ストレージ:** 500GB 以上の空き容量がある高速なSSD (NVMe推奨)
- **CPU:** マルチコアCPU

## 必要なパッケージ

- `docker`
- `docker-compose`
- `make`
- `aria2c`

## 実行手順

1.  **Dockerイメージの取得**

    以下のコマンドを実行して、必要なDockerイメージを事前にダウンロードします。

    ```bash
    make docker-pull
    ```

2.  **OpenStreetMap惑星データのダウンロード**

    `aria2c`を使用して、最新の惑星データをダウンロードします。これには数時間かかることがあります。

    ```bash
    ./00_download_planet.sh
    ```

3.  **データ処理**

    ダウンロードしたデータをPlanetilerで処理し、地図タイルなどを生成します。この処理には非常に時間がかかります。

    ```bash
    ./01_runworld.sh
    ```
    *注意: このスクリプトは大量のメモリ（90GB）を消費します。*

4.  **サービスの起動**

    すべてのデータ処理が完了したら、以下のコマンドでタイルサーバーや検索エンジンなどのサービスを起動します。

    ```bash
    docker compose up
    ```

    起動後、以下のエンドポイントにアクセスできます。
    - TileServer: `http://localhost:8000` - ベクトルタイル配信
    - Nominatim: `http://localhost:8001` - ジオコーディングと逆ジオコーディング
    - Valhalla: `http://localhost:8002` - ルート探索
    - Overpass: `http://localhost:8003` - 高度な空間クエリ

    **注意:** デフォルトでは、Nominatimは`admin`（行政境界）のみ、Overpass APIはモナコのデータのみを対象としています。これらの設定は`docker-compose.yml`で変更可能です。

## データ更新（エアギャップ対応）

すべての更新スクリプトはインターネット不要で、ローカルファイルのみで動作します。

### 基本的な使い方（新しい PBF を持ち込む場合）

新しい planet PBF ファイルを入手したら、以下の1コマンドで全サービスを更新できます。

```bash
./update_all.sh --new-pbf /path/to/new-planet.osm.pbf
```

内部で `osmium derive-changes` を使い、前回構築時の PBF との差分 OSC を自動生成し、  
Nominatim・Overpass には差分のみを適用します。Valhalla はタイル全再ビルドになります。

**ディスク要件**: 旧 PBF と新 PBF を同時に保持する必要があります（惑星スケールで各 ~90GB）。

### オプション

```bash
# Valhalla の再ビルドをスキップ（時間節約）
./update_all.sh --new-pbf /path/to/new-planet.osm.pbf --skip-valhalla

# 全サービスをフル再インポート（差分適用が使えない場合）
./update_all.sh --full --new-pbf /path/to/new-planet.osm.pbf
```

### 個別更新

```bash
# Planet PBF のみ差分更新
./update_planet.sh --osc /path/to/changes.osc.gz
./update_planet.sh --pbf /path/to/new-planet.osm.pbf

# Nominatim のみ（FREEZE=false でインポートされている必要あり）
./update_nominatim.sh --osc /path/to/changes.osc.gz
./update_nominatim.sh --pbf /path/to/new-planet.osm.pbf  # フル再インポート

# Overpass のみ
./update_overpass.sh --status
./update_overpass.sh --osc /path/to/changes.osc.gz
./update_overpass.sh --pbf /path/to/new-planet.osm.pbf   # フル再初期化

# Valhalla のみ（常にタイル全再ビルド）
./update_valhalla.sh --pbf /path/to/new-planet.osm.pbf
```

### Nominatim 差分更新の前提条件

`FREEZE=true` でインポートしたデータベースは update テーブルが削除されており、差分更新不可です。  
`docker-compose.yml` の `FREEZE=false`（現在の設定）でインポートし直してください。

```bash
rm -rf data/nominatim/planet/postgres
docker compose up nominatim
```

### Overpass の更新アーキテクチャ

DB構築とサーブは意図的に分離されています。

1. `8002_overpass.sh` でローカル PBF から DB を構築（`init_done` マーカーを生成して停止）
2. `docker compose up overpass` で起動すると `clone` モードが `init_done` を検出し、サーバーを起動

差分更新は `update_overpass.sh --osc` で、フル再初期化は `update_overpass.sh --pbf` で行います。

## Raspberry Pi 5 持ち込み評価

Raspberry Pi 5 向けの Overpass 単体起動メモは `README.pi5.ja.md` を参照してください。
