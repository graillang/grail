#!/usr/bin/env bash
# Land a branch on main through the landing service (tools/landsvc/landd.py; see docs/testing.md,
# "Landing on main"):
#   bash tools/land.sh BRANCH [--wait]     queue BRANCH (--wait blocks until its verdict)
#   bash tools/land.sh --status            the queue, the landing in progress, the last results
# The service merges the branch onto current main itself, gates it (possibly together with other
# queued branches), and fast-forwards main and the branch on green. GRAIL_LAND_SVC names the
# service's directory on this host.
svc=${GRAIL_LAND_SVC:-$HOME/grail-landsvc}
[ -x "$svc/land.sh" ] || { echo "land: no landing service at $svc (start tools/landsvc/landd.py there; docs/testing.md)"; exit 2; }
exec bash "$svc/land.sh" "$@"
