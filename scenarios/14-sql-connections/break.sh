#!/usr/bin/env bash
set -e
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: report-generator, namespace: shop, labels: {app: report-generator}}
spec:
  replicas: 1
  selector: {matchLabels: {app: report-generator}}
  template:
    metadata: {labels: {app: report-generator}}
    spec:
      containers:
        - name: app
          image: bootcamp/shop-app:1.0
          imagePullPolicy: IfNotPresent
          env:
            - {name: ROLE, value: hog}
            - {name: SERVICE_NAME, value: report-generator}
            - {name: HOG_CONNECTIONS, value: "40"}
          envFrom:
            - configMapRef: {name: app-config}
            - secretRef: {name: api-secrets}
EOF
