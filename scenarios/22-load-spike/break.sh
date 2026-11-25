#!/usr/bin/env bash
set -e
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: partner-sync, namespace: shop, labels: {app: partner-sync}}
spec:
  replicas: 4
  selector: {matchLabels: {app: partner-sync}}
  template:
    metadata: {labels: {app: partner-sync}}
    spec:
      containers:
        - name: client
          image: curlimages/curl:8.10.1
          command: ["/bin/sh", "-c"]
          args:
            - |
              while true; do
                curl -s -o /dev/null --max-time 10 -X POST -H 'Content-Type: application/json' \
                  -H 'X-Client: partner-sync' -d '{"item":"bulk","qty":1}' http://orders-api/orders
                curl -s -o /dev/null --max-time 10 "http://orders-api/burn?ms=300"
              done
          resources:
            requests: {cpu: 10m, memory: 16Mi}
            limits: {memory: 64Mi}
EOF
