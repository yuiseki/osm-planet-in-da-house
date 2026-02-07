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
