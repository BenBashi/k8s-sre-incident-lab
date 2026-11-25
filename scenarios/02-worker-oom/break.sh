#!/usr/bin/env bash
set -e
kubectl -n shop set resources deploy/orders-worker -c app --limits=memory=24Mi --requests=memory=24Mi
