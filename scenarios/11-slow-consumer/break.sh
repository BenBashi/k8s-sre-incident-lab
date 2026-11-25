#!/usr/bin/env bash
set -e
kubectl -n shop set env deploy/orders-worker PROCESSING_DELAY_MS=1500
