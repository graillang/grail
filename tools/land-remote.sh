#!/usr/bin/env bash
# The build host's half of a landing (tools/land.sh, GRAIL_LAND_REMOTE). It runs there, from the
# checkout of main in /srv/grail/w:
#
#   bash tools/land-remote.sh STAMP     after a landing: make sure this checkout has the patched
#                                       qemu-aarch64 (tools/qemu/build.sh, a no-op once built; the
#                                       first build takes several minutes), then start the emulated
#                                       aarch64/riscv64 legs under /srv/grail/run-leg.sh. Detached:
#                                       the landing does not wait for any of it.
#   bash tools/land-remote.sh --status  the emulator and each leg's verdict for the newest landing;
#                                       exit 0 all passed, 1 a leg failed, 3 still running.
#
# Logs: /srv/grail/logs/STAMP/{qemu-aarch64,aarch64_N,riscv64_N}.log, STAMP being the landing's
# (the same one names its local log directory).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
base=/srv/grail/logs
if [ "${1:-}" = "--status" ]; then
  d=$(ls -1d "$base"/2*/ 2>/dev/null | tail -1)
  [ -n "$d" ] || { echo "no landing has run here"; exit 2; }
  echo "landing $(basename "$d")"
  q="$d/qemu-aarch64.log"
  if [ -f "$q" ]; then
    version=$(grep -m1 '^qemu-aarch64 version' "$q")
    if grep -q '^exit=0$' "$q"; then echo "  emulator: ${version:-?}"
    elif grep -q '^exit=' "$q"; then echo "  emulator: FAILED to build ($(grep -v '^exit=' "$q" | tail -1))"
    else echo "  emulator: building"; fi
  fi
  status=0
  for f in "$d"/aarch64_*.log "$d"/riscv64_*.log; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .log)
    summary=$(grep -E '^[a-z0-9_]+: passed [0-9]+ failed [0-9]+' "$f" | tail -1)
    if ! grep -q '^exit=' "$f"; then
      echo "  $n: running"
      [ $status = 0 ] && status=3
    elif grep -q '^exit=0$' "$f"; then
      echo "  $n: ok   ${summary:-}"
    else
      fails=$(sed -n 's/^FAIL \([^ ]*\).*/\1/p' "$f" | head -8 | tr '\n' ' ')
      echo "  $n: FAIL ${summary:-$(grep -v '^exit=' "$f" | tail -1)}${fails:+; $fails}"
      status=1
    fi
  done
  [ -n "$(ls "$d"/aarch64_*.log "$d"/riscv64_*.log 2>/dev/null)" ] || { echo "  legs: not started yet"; [ $status = 0 ] && status=3; }
  exit $status
fi
stamp=${1:?usage: tools/land-remote.sh STAMP | --status}
if [ "${2:-}" != "--detached" ]; then
  mkdir -p "$base/$stamp"
  setsid nohup bash "$0" "$stamp" --detached > "$base/$stamp/launch.log" 2>&1 < /dev/null &
  exit 0
fi
nice -n 15 bash tools/qemu/build.sh > "$base/$stamp/qemu-aarch64.log" 2>&1
echo "exit=$?" >> "$base/$stamp/qemu-aarch64.log"
for t in aarch64 riscv64; do
  for i in 1 2 3; do
    GRAIL_LEG_COMPILER=${GRAIL_LEG_COMPILER:-/srv/grail/grail-main} /srv/grail/run-leg.sh "$stamp/${t}_$i" env GRAIL_TEST_SHARD=$i/3 bun tools/test-native.mjs $t --jobs 2 &
  done
done
wait
