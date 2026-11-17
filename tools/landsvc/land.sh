#!/usr/bin/env bash
# Queue a branch for landing on main:   bash /home/shulgin/grail-landsvc/land.sh BRANCH [--wait]
#   --status          the queue, the landing in progress and the last results
#   --remote-status   the emulated legs and fuzzer of the newest landing on the build host
# The landing service (landd.py) merges your branch onto current main itself (a clean merge, or
# conflicts only in tests/*.json and *.md), gates it, possibly together with other queued branches,
# and fast-forwards main and your branch on green. You never need to re-merge just because main
# moved while you waited; only a real conflict comes back to you. Nothing you kill can stop a landing.
svc=$(cd "$(dirname "$0")" && pwd)
if [ "${1:-}" = "--status" ]; then
  echo "queue:"; for f in $(ls "$svc/requests" 2>/dev/null); do echo "  $(head -1 "$svc/requests/$f") ($f)"; done
  echo "in progress: $(cat /home/shulgin/grail-landq.lock.who 2>/dev/null)"
  echo "recent:"; tail -n 12 /home/shulgin/grail-land-logs/landings.txt
  exit 0
fi
if [ "${1:-}" = "--remote-status" ]; then
  # The emulated legs and the fuzzer the newest landing started on the build host
  # (tools/land-remote.sh): exit 0 all passed, 1 one failed, 3 still running. A final verdict is
  # recorded once in post.txt, beside the post-landing gate's lines.
  remote=${GRAIL_LAND_REMOTE:-root@borg.ml}
  report=$(ssh -o BatchMode=yes "$remote" "bash /srv/grail/w/tools/land-remote.sh --status"); rc=$?
  echo "$report"
  stamp=$(echo "$report" | sed -n 's/^landing //p' | head -1)
  post=/home/shulgin/grail-land-logs/post.txt
  if [ -n "$stamp" ] && { [ $rc = 0 ] || [ $rc = 1 ]; } && ! grep -q " remote $stamp " "$post" 2>/dev/null; then
    verdict=GREEN; [ $rc = 1 ] && verdict=RED
    fails=$(echo "$report" | grep -E ': FAIL' | sed 's/^ *//' | tr '\n' ';' | cut -c1-400)
    echo "$(date -u +%FT%TZ) remote $stamp $verdict ${fails}($remote:/srv/grail/logs/$stamp)" >> "$post"
  fi
  exit $rc
fi
br=${1:?usage: land.sh BRANCH [--wait] | --status | --remote-status}
git ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1 || git -C /home/shulgin/grail-landq ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1 || { echo "land: no branch $br on origin; push it first"; exit 2; }
for f in "$svc"/requests/*; do [ -f "$f" ] && [ "$(head -1 "$f")" = "$br" ] && { echo "land: $br is already queued ($(basename "$f"))"; existing=1; }; done
if [ -z "${existing:-}" ]; then
  req="$svc/requests/$(date -u +%s%N)-${br//\//_}"
  printf '%s\n%s\n' "$br" "$(whoami)@$(pwd)" > "$req"; echo "land: queued $br"
fi
res="$svc/results/${br//\//_}.txt"; before=$(wc -l 2>/dev/null < "$res" || echo 0)
[ "${2:-}" = "--wait" ] || { echo "land: results in $res and /home/shulgin/grail-land-logs/landings.txt"; exit 0; }
while :; do
  n=$(wc -l 2>/dev/null < "$res" || echo 0)
  if [ "$n" -gt "$before" ]; then last=$(tail -1 "$res"); case "$last" in *" train-red "*|*" retry "*) before=$n; continue;; esac; echo "land: $last"; case "$last" in *" LANDED "*|*" already-on-main"*) exit 0;; *) exit 1;; esac; fi
  sleep 20
done
