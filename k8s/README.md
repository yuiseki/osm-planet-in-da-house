# k8s 運用メモ

このリポジトリの docker compose 相当を kubeadm 単一ノードへデプロイした構成の運用メモ。

## デプロイ/起動

```bash
kubectl apply -f k8s
```

## 停止

```bash
kubectl delete -f k8s
```

## 再起動（Deployment の Rollout）

```bash
kubectl rollout restart deployment/nominatim deployment/overpass deployment/valhalla
kubectl rollout restart deployment/taginfo
```

## 状態確認

```bash
kubectl get pods -o wide
kubectl get deployments
kubectl get services
```

## Pod を作り直す場合

```bash
kubectl delete pod -l app=nominatim
kubectl delete pod -l app=overpass
kubectl delete pod -l app=valhalla
kubectl delete pod -l app=taginfo
```

## ログ確認

```bash
kubectl logs -f deployment/nominatim
kubectl logs -f deployment/overpass
kubectl logs -f deployment/valhalla
kubectl logs -f deployment/taginfo
```

## 直接アクセス（NodePort）

- nominatim: http://<node-ip>:30111
- overpass: http://<node-ip>:30112
- valhalla: http://<node-ip>:30113
- taginfo: http://<node-ip>:30114

## NodePort の確認

```bash
kubectl get svc nominatim overpass valhalla taginfo
```

### 動作確認の注意

- valhalla は `/` が 404 でも正常
- taginfo は `/api/4/keys/all?format=json&rp=1&page=1` などで疎通確認

## containerd にローカルイメージを取り込む（taginfo）

taginfo はローカルでビルドしたイメージを使うため、必要に応じて containerd に取り込む。

```bash
docker save osm-planet-in-da-house-taginfo:latest | ctr -n k8s.io images import -
```

## taginfo: データを入れ替えたら後処理が要る

配布されている `taginfo-db.db` は、上流の `sources/update_all.sh` のうち
**配布用に固めた時点**のもの。そのあとの 2 工程が入っていない。

```
create_extra_indexes   db/add_extra_indexes.sql と db/add_ftsearch.sql
update_master          master/master.sql が keys/tags の
                       in_wiki, in_wiki_en, projects を埋める
```

入れないと次の症状が出る。

```
api/4/search/by_value が常に 0 件
api/4/search/by_key_and_value が常に 0 件
in_wiki が全キー false
projects が常に 0
```

**0 件はエラーに見えない。** `web/lib/api/v4/search.rb` が ftsearch への
問い合わせを `rescue` で包み、例外を `total = 0` に変えて返すため。
表が無いことが表に出ない。

`scripts/taginfo_prepare_data.sh` は最後に
`scripts/taginfo_post_download.sh` を呼ぶ。手で入れ替えたときは自分で流す。

```bash
./scripts/taginfo_post_download.sh /path/to/data/taginfo
kubectl rollout restart deployment/taginfo -n default
```

SQLite は pod 起動時に ATTACH するので、**差し替えたら再起動が要る。**

### 所要とサイズ (2026-10-05、tags 1.87 億行で実測)

```
索引 4 本        643s
ftsearch        641s
合計            21 分

12.48 GB -> 37.25 GB   (索引 +3.7GB、FTS5 +21GB)
```

作業用に元の 2 倍の空きを見ておく。コピーを作って流し、終わってから差し替える
のが安全 (原本に触らないので taginfo は動き続け、止まるのは再起動の数十秒だけ)。

### data/ は gitignore されている

`.gitignore` に `data` があるため、**`git clean -xdf` を打つと 37GB の DB が消える。**
k8s の hostPath もここを指している。このリポジトリでは `-x` を付けないこと。
