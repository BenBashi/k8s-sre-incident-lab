#!/usr/bin/env bash
set -e
kubectl -n shop patch deploy orders-api --type=json -p '[{"op":"remove","path":"/spec/template/spec/containers/0/resources"}]'
kubectl -n shop set env deploy/loadgen BURN_MS=400
