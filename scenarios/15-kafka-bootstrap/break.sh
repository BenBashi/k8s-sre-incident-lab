#!/usr/bin/env bash
set -e
kubectl -n shop patch configmap app-config -p '{"data":{"KAFKA_BOOTSTRAP":"kafka:9093"}}'
kubectl -n shop delete pods -l app=orders-api
kubectl -n shop delete pods -l app=orders-worker
