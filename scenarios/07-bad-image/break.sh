#!/usr/bin/env bash
set -e
kubectl -n shop patch deploy orders-worker -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null},"template":{"spec":{"containers":[{"name":"app","image":"bootcamp/shop-app:1.1"}]}}}}'
