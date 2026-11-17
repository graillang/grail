#!/usr/bin/env bash
# One command for the quiet window (docs/design/runtime-parity.md, "Against other languages"): the
# measurements whose figure is wall time, taken while the director has paused every other heavy
# agent. It does not pause anything itself - only the director may - it checks the load first and
# records it before and after each stage. Each stage is pinned to a fixed set of CPUs with taskset,
# so the runtimes compared get the same cores, and every runtime is given that many threads.
#   bash tools/quiet-window.sh [--cpus 0-7] [--max-load 6] [--stages sched,parallel,bench,engine]
#   GRAIL_COMPILER   the native compiler (else this tree's), GRAIL_RELEASE_COMPILER for compile-rivals
# Results go to bench/results/*.json as `just bench-results` writes them; the log to
# .work/quiet-window/log.txt. Stages, in order of how much they need the quiet:
#   sched     sched-rivals, 9 rounds: join, spawn, fib(32), the frame loop's tail latency
#   parallel  the parallel ECS benchmark (pool::zip3 against rayon, OpenMP, goroutines, std.Thread) at
#             1, 4 and 8 workers, wall time charted
#   bench     bench-rivals' kernels, CPU time charted (the instruction table is beside it)
#   engine    the engine-shaped programs, CPU time charted
set -euo pipefail
cd "$(dirname "$0")/.."
cpus=0-7; max_load=6; stages=sched,parallel,bench,engine
while [ $# -gt 0 ]; do
  case "$1" in
    --cpus) cpus=$2; shift 2 ;;
    --max-load) max_load=$2; shift 2 ;;
    --stages) stages=$2; shift 2 ;;
    *) echo "quiet-window: unknown option $1" >&2; exit 2 ;;
  esac
done
count=$(taskset -c "$cpus" nproc)
mkdir -p .work/quiet-window
log=.work/quiet-window/log.txt
note() { echo "$(date -u +%FT%TZ) $* (load $(cut -d' ' -f1-3 /proc/loadavg))" | tee -a "$log"; }
load=$(cut -d' ' -f1 /proc/loadavg)
if awk -v l="$load" -v m="$max_load" 'BEGIN { exit !(l > m) }'; then
  note "the machine is not quiet: load $load is above $max_load; pause the other agents first (or pass --max-load)"
  exit 1
fi
note "quiet window: stages $stages on CPUs $cpus ($count threads)"
pin() { RIVALS_THREADS=$count GRAIL_WORKERS=$count RAYON_NUM_THREADS=$count OMP_NUM_THREADS=$count taskset -c "$cpus" "$@"; }
for stage in ${stages//,/ }; do
  note "start $stage"
  case "$stage" in
    sched) pin bun tools/sched-rivals.mjs --rounds 9 --json bench/results/sched-rivals.json ;;
    parallel)
      if [ -f bench/ecs_par.grl ]; then
        pin bun tools/bench-rivals.mjs --runs 5 --metric wall --workers 1,4,8 --json bench/results/parallel.json ecs_par
      else
        note "skip parallel: bench/ecs_par.grl is not in this tree yet"
      fi ;;
    bench) pin bun tools/bench-rivals.mjs --runs 5 --json bench/results/bench-rivals.json dot_f32 dot_f64 ffi_call fnv matmul nbody sieve sort xform_f32 xform_f64 ;;
    engine) pin bun tools/bench-rivals.mjs --runs 5 --json bench/results/engine.json hashmap bintrees strings json dyncall iterchain ecs ;;
    *) note "unknown stage $stage"; exit 2 ;;
  esac
  note "done $stage"
done
note "quiet window finished; commit bench/results/ and rebuild the book"
