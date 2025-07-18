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