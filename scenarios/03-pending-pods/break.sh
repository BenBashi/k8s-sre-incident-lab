#!/usr/bin/env bash
set -e
kubectl -n shop set resources deploy/orders-api -c app --requests=cpu=24 --limits=cpu=24
