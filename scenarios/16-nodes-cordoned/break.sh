#!/usr/bin/env bash
set -e
for n in $(kubectl get nodes -o name | grep worker); do kubectl cordon "$n"; done
kubectl -n shop delete pods -l app=orders-api
