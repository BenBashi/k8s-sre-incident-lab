#!/usr/bin/env bash
set -e
kubectl -n shop patch svc orders-api -p '{"spec":{"selector":{"app":"order-api"}}}'
