#!/usr/bin/env bash
set -e
kubectl -n shop exec deploy/mongo -- mongosh -u root -p mongo-pass --authenticationDatabase admin --quiet shop --eval '
db.settings.updateOne({_id: "routing"}, {$set: {events_collection: "order_event", updated_by: "data-team-script"}});'
