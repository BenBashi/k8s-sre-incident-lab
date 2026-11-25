#!/usr/bin/env bash
set -e
kubectl -n shop scale deploy/mongo --replicas=0
