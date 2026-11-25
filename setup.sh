#!/usr/bin/env bash
# Creates the lab: kind cluster + metrics-server + MySQL/Mongo/Kafka + shop app.
# Needs: Docker (Docker Desktop / OrbStack / colima), kind, kubectl.  brew install kind kubectl jq
set -euo pipefail
cd "$(dirname "$0")"
CLUSTER=bootcamp
IMAGE=bootcamp/shop-app:1.0

for bin in docker kind kubectl; do
  command -v "$bin" >/dev/null || { echo "missing: $bin  (brew install $bin)"; exit 1; }
done

if ! kind get clusters | grep -qx "$CLUSTER"; then
  echo ">> creating kind cluster '$CLUSTER'"
  kind create cluster --config k8s/kind-cluster.yaml
fi
kubectl config use-context "kind-$CLUSTER"

echo ">> installing metrics-server (needed for HPA / kubectl top)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' || true

echo ">> building app image and loading it into kind"
docker build -t "$IMAGE" app
kind load docker-image "$IMAGE" --name "$CLUSTER"

echo ">> datastores"
kubectl apply -f k8s/00-namespace.yaml -f k8s/10-datastores.yaml
kubectl -n shop rollout status deploy/mysql --timeout=240s
kubectl -n shop rollout status deploy/mongo --timeout=180s
kubectl -n shop rollout status deploy/kafka --timeout=240s

echo ">> creating Kafka topic 'orders' (3 partitions)"
for i in $(seq 1 20); do
  kubectl -n shop exec deploy/kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic orders --partitions 3 --replication-factor 1 && break
  sleep 3
done

echo ">> app"
kubectl apply -f k8s/20-app.yaml
kubectl -n shop rollout status deploy/orders-api --timeout=180s
kubectl -n shop rollout status deploy/orders-worker --timeout=180s

echo
./status.sh
echo
echo "Lab is up. Next:  ./break.sh   (random scenario)   or   ./break.sh list"
