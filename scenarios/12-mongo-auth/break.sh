#!/usr/bin/env bash
set -e
kubectl -n shop patch secret worker-secrets -p '{"stringData":{"MONGO_PASSWORD":"worker-pass-2026"}}'
kubectl -n shop delete pods -l app=orders-worker
