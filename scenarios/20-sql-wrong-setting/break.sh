#!/usr/bin/env bash
set -e
kubectl -n shop exec deploy/mysql -- sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" shop -e \
  "UPDATE app_settings SET v=\"1\", updated_by=\"pricing-sync-job\" WHERE k=\"max_qty_per_order\";"'
