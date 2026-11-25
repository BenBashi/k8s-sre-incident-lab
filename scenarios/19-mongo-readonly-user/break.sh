#!/usr/bin/env bash
set -e
kubectl -n shop exec deploy/mongo -- mongosh -u root -p mongo-pass --authenticationDatabase admin --quiet shop --eval '
db.revokeRolesFromUser("worker", [{role: "readWrite", db: "shop"}]);
db.grantRolesToUser("worker", [{role: "read", db: "shop"}]);'
