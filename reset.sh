#!/usr/bin/env bash
# Return the lab to a healthy baseline after any scenario.
set -uo pipefail
cd "$(dirname "$0")"
NS=shop

echo ">> removing scenario leftovers"
kubectl -n $NS delete job nightly-maintenance --ignore-not-found
kubectl -n $NS delete deploy report-generator --ignore-not-found
for n in $(kubectl get nodes -o name); do kubectl uncordon "$n" >/dev/null; done
kubectl -n $NS scale deploy/mysql deploy/mongo deploy/kafka --replicas=1
kubectl -n $NS rollout status deploy/mysql --timeout=180s
kubectl -n $NS rollout status deploy/mongo --timeout=120s
echo ">> restoring MongoDB worker permissions"
kubectl -n $NS exec deploy/mongo -- mongosh -u root -p mongo-pass --authenticationDatabase admin --quiet shop --eval '
  db.grantRolesToUser("worker", [{role: "readWrite", db: "shop"}]);
  db.revokeRolesFromUser("worker", [{role: "read", db: "shop"}]);
  db.changeUserPassword("worker", "worker-pass");' >/dev/null 2>&1 || true

echo ">> restoring settings stored in the databases"
kubectl -n $NS delete deploy partner-sync --ignore-not-found
kubectl -n $NS exec deploy/mysql -- sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" shop -e \
  "UPDATE app_settings SET v=\"10\", updated_by=\"reset\" WHERE k=\"max_qty_per_order\";"' >/dev/null 2>&1 || true
kubectl -n $NS exec deploy/mongo -- mongosh -u root -p mongo-pass --authenticationDatabase admin --quiet shop --eval '
  db.settings.updateOne({_id: "routing"}, {$set: {events_collection: "order_events"}});' >/dev/null 2>&1 || true

echo ">> recreating the app layer from k8s/20-app.yaml"
kubectl delete -f k8s/20-app.yaml --ignore-not-found --wait=true

echo ">> moving consumer group to latest (skips any poison message)"
for i in $(seq 1 20); do
  kubectl -n $NS exec deploy/kafka -- /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
    --group orders-worker --reset-offsets --to-latest --all-topics --execute >/dev/null 2>&1 && break
  sleep 4
done

kubectl apply -f k8s/20-app.yaml
kubectl -n $NS rollout status deploy/orders-api --timeout=180s
kubectl -n $NS rollout status deploy/orders-worker --timeout=180s
rm -f .current-scenario
echo
./status.sh
