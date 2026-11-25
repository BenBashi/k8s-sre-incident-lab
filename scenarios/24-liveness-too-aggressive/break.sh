#!/usr/bin/env bash
set -e
kubectl -n shop patch deploy orders-api -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","livenessProbe":{"httpGet":{"path":"/healthz","port":8080},"initialDelaySeconds":0,"periodSeconds":1,"failureThreshold":1,"timeoutSeconds":1}}]}}}}'
