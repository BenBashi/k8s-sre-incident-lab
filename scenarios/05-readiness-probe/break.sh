#!/usr/bin/env bash
set -e
kubectl -n shop patch deploy orders-api -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null},"template":{"spec":{"containers":[{"name":"app","readinessProbe":{"httpGet":{"path":"/readyz"}}}]}}}}'
