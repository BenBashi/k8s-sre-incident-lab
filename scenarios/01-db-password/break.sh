#!/usr/bin/env bash
set -e
kubectl -n shop patch secret api-secrets -p '{"stringData":{"DB_PASSWORD":"Winter2026!"}}'
kubectl -n shop delete pods -l app=orders-api
