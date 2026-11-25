#!/usr/bin/env bash
set -e
kubectl -n shop exec deploy/kafka -- sh -c "echo '{order_id: broken' | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic orders"
