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
```

## 状態確認

```bash
kubectl get pods -o wide
kubectl get deployments
kubectl get services
```

## 旧 Pod が残って hostPort 競合する場合の対処

```bash
kubectl delete pod -l app=nominatim
kubectl delete pod -l app=overpass
kubectl delete pod -l app=valhalla
```

## ログ確認

```bash
kubectl logs -f deployment/nominatim
kubectl logs -f deployment/overpass
kubectl logs -f deployment/valhalla
```

## 直接アクセス（hostPort）

- nominatim: http://<node-ip>:8001
- overpass: http://<node-ip>:8002
- valhalla: http://<node-ip>:8003

### 動作確認の注意

- valhalla は `/` が 404 でも正常
