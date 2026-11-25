#!/usr/bin/env bash
set -e
kubectl -n shop patch deploy orders-api -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","livenessProbe":{"httpGet":{"path":"/ready","port":8080},"initialDelaySeconds":5,"periodSeconds":5,"failureThreshold":1,"timeoutSeconds":1}}]}}}}'
kubectl -n shop rollout status deploy/orders-api --timeout=180s
kubectl -n shop scale deploy/mysql --replicas=0
sleep 45
kubectl -n shop scale deploy/mysql --replicas=1
