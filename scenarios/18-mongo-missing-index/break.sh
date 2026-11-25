#!/usr/bin/env bash
set -e
kubectl -n shop exec deploy/mongo -- mongosh -u root -p mongo-pass --authenticationDatabase admin --quiet shop --eval '
db.order_events.dropIndex("order_id_1");
for (let b = 0; b < 150; b++) {
  const docs = [];
  for (let i = 0; i < 10000; i++) docs.push({order_id: UUID().toString(), item: "legacy", qty: 1, imported: true});
  db.order_events.insertMany(docs, {ordered: false});
}'
