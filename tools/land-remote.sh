#!/usr/bin/env bash
# The build host's half of a landing (tools/land.sh, GRAIL_LAND_REMOTE). It runs there, from the
# checkout of main in /srv/grail/w:
#
#   bash tools/land-remote.sh STAMP     after a landing: make sure this checkout has the patched
#                                       qemu-aarch64 (tools/qemu/build.sh, a no-op once built; the
#                                       first build takes several minutes), then start the emulated
#                                       aarch64/riscv64 legs under /srv/grail/run-leg.sh, and beside
#                                       them the front-end fuzzer at 2000 cases with a seed taken
#                                       from STAMP, so every landing tries new inputs and a front-end
#                                       hang or crash is found within hours. Detached: the landing does
#                                       not wait for any of it.
#   bash tools/land-remote.sh --status  the emulator and each leg's verdict for the newest landing;
#                                       exit 0 all passed, 1 a leg failed, 3 still running.
#
# Logs: /srv/grail/logs/STAMP/{qemu-aarch64,aarch64_N,riscv64_N,fuzz}.log, STAMP being the
# landing's (the same one names its local log directory); the fuzzer's report.json and the shrunk
# input of every bug it found are copied to STAMP/fuzz/, because the next landing's checkout
# reuses .work/fuzz. Reproduce one with `bun tools/fuzz-frontend.mjs --seed SEED --cases 2000`.
# The closure-passing fuzzer runs beside it at 400 cases (fuzz-closures.log; a bug's program is kept
# in STAMP/fuzz-closures/; `bun tools/fuzz-closures.mjs --seed SEED --cases 400 --keep` reproduces).
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
  for f in "$d/fuzz.log" "$d/fuzz-closures.log"; do
  [ -f "$f" ] || continue
  label=$(basename "$f" .log)
  if [ -f "$f" ]; then
    seed=$(grep -m1 '^seed ' "$f" | cut -d' ' -f2)
    summary=$(grep -E '^fuzz(-closures)?: ' "$f" | tail -1)
    if ! grep -q '^exit=' "$f"; then
      echo "  $label (seed $seed): running"
      [ $status = 0 ] && status=3
    elif grep -q '^exit=0$' "$f"; then
      echo "  $label (seed $seed): ok   ${summary#*: }"
    else
      echo "  $label (seed $seed): FAIL ${summary#*: }"
      grep -E '^BUG |^  repro |^slowest:' "$f" | head -6 | sed 's/^/    /'
      echo "    inputs: $d/$label/"
      status=1
    fi
  fi
  done
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
# The fuzzer runs against the compiler this landing built, so it tests exactly what landed. Its
# seed is the stamp's digits: a different 2000 inputs every landing, the same ones on a re-run.
compiler=${GRAIL_LEG_COMPILER:-/srv/grail/grail-main}
seed=$((10#$(echo "$stamp" | tr -dc 0-9 | tail -c 9)))
cases=${GRAIL_FUZZ_CASES:-2000}
(
  echo "seed $seed cases $cases" > "$base/$stamp/fuzz.log"
  cd /srv/grail/w && PATH=/root/.bun/bin:$PATH nice -n 15 bun tools/fuzz-frontend.mjs --cases "$cases" --seed "$seed" \
    --jobs 2 --timeout 60000 --shrink --quiet --compiler "$compiler" >> "$base/$stamp/fuzz.log" 2>&1
  status=$?
  mkdir -p "$base/$stamp/fuzz"
  cp -r .work/fuzz/report.json .work/fuzz/bugs "$base/$stamp/fuzz/" 2>/dev/null
  echo "exit=$status" >> "$base/$stamp/fuzz.log"
) &
# The closure-passing fuzzer (tools/fuzz-closures.mjs, docs/design/dyn-and-callable-bounds.md S6(A)):
# compile-and-run, so a missed erase shows up as the use-after-free it is; 400 cases, the same seed.
ccases=${GRAIL_FUZZ_CLOSURE_CASES:-400}
(
  echo "seed $seed cases $ccases" > "$base/$stamp/fuzz-closures.log"
  cd /srv/grail/w && PATH=/root/.bun/bin:$PATH nice -n 15 bun tools/fuzz-closures.mjs --cases "$ccases" --seed "$seed" \
    --jobs 2 --keep --compiler "$compiler" >> "$base/$stamp/fuzz-closures.log" 2>&1
  status=$?
  mkdir -p "$base/$stamp/fuzz-closures"
  for b in $(sed -n 's/^BUG \([0-9]*\) .*/\1/p' "$base/$stamp/fuzz-closures.log"); do
    cp -r ".work/fuzz-closures/$b" "$base/$stamp/fuzz-closures/" 2>/dev/null
  done
  echo "exit=$status" >> "$base/$stamp/fuzz-closures.log"
) &
for t in aarch64 riscv64; do
  for i in 1 2 3; do
    GRAIL_LEG_COMPILER=${GRAIL_LEG_COMPILER:-/srv/grail/grail-main} /srv/grail/run-leg.sh "$stamp/${t}_$i" env GRAIL_TEST_SHARD=$i/3 bun tools/test-native.mjs $t --jobs 2 &
  done
done
wait
