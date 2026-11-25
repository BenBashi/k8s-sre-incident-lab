#!/usr/bin/env bash
set -e
kubectl -n shop scale deploy/orders-worker --replicas=0
