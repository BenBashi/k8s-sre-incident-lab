#!/usr/bin/env bash
# ./reveal.sh hint | solution   — for the active scenario
cd "$(dirname "$0")"
[[ -f .current-scenario ]] || { echo "no active scenario"; exit 1; }
pick=$(sed -n 1p .current-scenario)
start=$(sed -n 2p .current-scenario)
echo "elapsed: $(( ($(date +%s) - start) / 60 )) min   scenario: $pick"
echo
case "${1:-hint}" in
  hint) cat "scenarios/$pick/hint.md" ;;
  solution) cat "scenarios/$pick/solution.md" ;;
  *) echo "usage: ./reveal.sh hint|solution" ;;
esac
