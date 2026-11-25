#!/usr/bin/env bash
set -e
kubectl -n shop set env deploy/orders-worker KAFKA_TOPIC=order-events
