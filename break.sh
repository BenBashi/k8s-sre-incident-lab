#!/usr/bin/env bash
# Break the lab.
#   ./break.sh          random scenario (name hidden, like the real interview)
#   ./break.sh list     list scenarios
#   ./break.sh 07       a specific scenario by number
set -euo pipefail
cd "$(dirname "$0")"
STATE=.current-scenario

if [[ "${1:-}" == "list" ]]; then
  ls scenarios; exit 0
fi

if [[ -f $STATE ]]; then
  echo "A scenario is already active. Fix it, then run ./reset.sh before breaking again."; exit 1
fi

if [[ -n "${1:-}" ]]; then
  pick=$(ls scenarios | grep "^$1" | head -1)
  [[ -n "$pick" ]] || { echo "no scenario $1"; exit 1; }
else
  pick=$(ls scenarios | awk 'BEGIN{srand()} {a[NR]=$0} END{print a[int(rand()*NR)+1]}')
fi

echo "breaking the system... (some scenarios take up to 3 minutes)"
bash "scenarios/$pick/break.sh" >/dev/null
echo "$pick" > $STATE
date +%s >> $STATE

echo "=================== INCIDENT TICKET ==================="
cat "scenarios/$pick/ticket.md"
echo "======================================================="
echo "Clock started. Stuck?  ./reveal.sh hint    Done?  ./reveal.sh solution    Then ./reset.sh"
