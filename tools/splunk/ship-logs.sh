#!/usr/bin/env bash
# Ships logs from namespace "shop" + K8s events to Splunk HEC every 10s. Ctrl+C to stop.
# Lab-grade: a line can occasionally be duplicated or missed at the 10s boundaries.
set -uo pipefail
HEC_URL=${HEC_URL:-https://localhost:8088/services/collector/event}
HEC_TOKEN=${HEC_TOKEN:-00000000-0000-0000-0000-000000000001}
NS=shop
command -v jq >/dev/null || { echo "missing jq (brew install jq)"; exit 1; }

send() {  # stdin: newline-separated HEC events, sent in chunks of 500 lines
  local tmp; tmp=$(mktemp)
  cat > "$tmp"
  if [[ -s "$tmp" ]]; then
    split -l 500 "$tmp" "$tmp.part."
    for part in "$tmp".part.*; do
      curl -sk "$HEC_URL" -H "Authorization: Splunk $HEC_TOKEN" --data-binary @"$part" >/dev/null \
        || echo "send failed (is Splunk up on :8088?)"
    done
  fi
  rm -f "$tmp" "$tmp".part.*
}

echo "shipping logs from namespace $NS to $HEC_URL ..."
while true; do
  for pod in $(kubectl -n $NS get pods -o jsonpath='{.items[*].metadata.name}'); do
    kubectl -n $NS logs "$pod" --all-containers --since=10s 2>/dev/null \
      | jq -R -c --arg pod "$pod" \
        '{event: (try fromjson catch {msg: .}), sourcetype: "_json", source: $pod, host: $pod, index: "main"}' \
      | send
  done
  kubectl -n $NS get events -o json \
    | jq -c --argjson since "$(( $(date +%s) - 10 ))" '.items[]
        | select(((.lastTimestamp // .eventTime // "1970-01-01T00:00:00Z") | sub("\\.[0-9]+";"") | fromdateiso8601) >= $since)
        | {event: {reason, type, message, object: (.involvedObject.kind + "/" + .involvedObject.name), count},
           sourcetype: "_json", source: "k8s-events", index: "main"}' \
    | send
  sleep 10
done
