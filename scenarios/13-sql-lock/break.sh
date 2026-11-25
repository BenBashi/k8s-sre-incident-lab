#!/usr/bin/env bash
set -e
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata: {name: nightly-maintenance, namespace: shop}
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: maintenance
          image: mysql:8.4
          command: ["mysql", "-h", "mysql", "-ushop", "-pshop-pass", "shop",
                    "-e", "LOCK TABLES orders WRITE; SELECT SLEEP(86400);"]
EOF
