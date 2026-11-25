#!/usr/bin/env bash
# Quick health snapshot of the lab. Use it to VERIFY a fix, not to find the problem.
cd "$(dirname "$0")"
NS=shop
echo "== pods";        kubectl -n $NS get pods -o wide
echo; echo "== hpa";   kubectl -n $NS get hpa
echo; echo "== endpoints orders-api"; kubectl -n $NS get endpoints orders-api
echo; echo "== kafka consumer lag (group orders-worker)"
kubectl -n $NS exec deploy/kafka -- /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --describe --group orders-worker 2>/dev/null | sed '/^$/d' || echo "(kafka not reachable)"
echo; echo "== loadgen: last 20 HTTP statuses"
kubectl -n $NS logs deploy/loadgen --tail=20 2>/dev/null | grep -o '"status":"[0-9]*"' | sort | uniq -c || true
