#!/usr/bin/env bash
# The full multi-platform gate, in its fastest safe shape. Usage:
#   tools/gate.sh [--reseed] [LOGDIR]
# GATE_RESEED_COMPILER names the compiler the reseed starts from when the checked-in seed cannot
# read the tree (a two-step bootstrap: docs/testing.md). It is used for the reseed only; every leg
# after it builds from the seed that was just published, which is what proves the seed.
# --reseed first republishes the bootstrap (`bootstrap.mjs update all`, which already proves
# self-hosting and assembly identity on every target, so no separate `verify` follows) and commits
# it. Logs go to LOGDIR (default .work/gate), one per leg; LOGDIR/DONE is written last. Run it again
# on the same LOGDIR after an interruption and it skips what already passed.
#
# Load is capped at three heavy jobs at a time: this machine has hard-crashed under more. Within
# that cap the independent legs overlap - the LLVM corpus runs while the emulated AArch64/RISC-V
# legs wait on qemu, and the tool suites run three at a time instead of one after another.
set -u
cd "$(dirname "$0")/.."
reseed=0
if [ "${1:-}" = "--reseed" ]; then reseed=1; shift; fi
G=${1:-.work/gate}
mkdir -p "$G"
rm -f "$G/DONE"

# At most three jobs: wait for a slot before starting one.
# GATE_JOBS lowers the cap further (a host that overheats): GATE_JOBS=1 runs the legs one by one.
slot() { while [ "$(jobs -rp | wc -l)" -ge "${GATE_JOBS:-3}" ]; do wait -n; done; }
# A leg whose log already ends in exit=0 is skipped, so a gate cut short (a host reset) resumes
# where it stopped when run again on the same LOGDIR.
done_ok() { [ -f "$1" ] && tail -1 "$1" | grep -qx 'exit=0'; }
leg() { local log=$1; shift; done_ok "$G/$log.log" && return 0; slot; ( "$@" > "$G/$log.log.tmp" 2>&1; echo "exit=$?" >> "$G/$log.log.tmp"; mv "$G/$log.log.tmp" "$G/$log.log" ) & }

if [ $reseed = 1 ]; then
  # One resumable step per target (each up to an hour under qemu), then one publish.
  for t in x86_64 aarch64 riscv64; do
    if ! done_ok "$G/reseed_$t.log"; then
      GRAIL_COMPILER=${GATE_RESEED_COMPILER:-${GRAIL_COMPILER:-}} bun tools/bootstrap.mjs stage $t > "$G/reseed_$t.log.tmp" 2>&1
      echo "exit=$?" >> "$G/reseed_$t.log.tmp"
      mv "$G/reseed_$t.log.tmp" "$G/reseed_$t.log"
      done_ok "$G/reseed_$t.log" || { echo "reseed $t failed" > "$G/summary.txt"; touch "$G/DONE"; exit 1; }
    fi
  done
  if ! done_ok "$G/reseed.log"; then
    GRAIL_COMPILER=${GATE_RESEED_COMPILER:-${GRAIL_COMPILER:-}} bun tools/bootstrap.mjs publish > "$G/reseed.log.tmp" 2>&1
    status=$?
    if [ $status = 0 ]; then
      git add compiler/bootstrap && git commit -q -m "Reseed the bootstrap" >> "$G/reseed.log.tmp" 2>&1
    fi
    echo "exit=$status" >> "$G/reseed.log.tmp"
    mv "$G/reseed.log.tmp" "$G/reseed.log"
  fi
fi
bun tools/ci.mjs preflight > "$G/preflight.log" 2>&1
C=$(bun tools/native.mjs build 2>&1 | tail -1)
case "$C" in /*) ;; *) C=$PWD/$C;; esac
export GRAIL_COMPILER=$C GRAIL_FFI_COMPILER=$C
export GRAIL_SYSROOT_AARCH64=/usr/aarch64-linux-gnu GRAIL_SYSROOT_RISCV64=/usr/riscv64-linux-gnu
echo "$C" > "$G/compiler.txt"

# Corpus legs: native x86-64 first, then the emulated targets interleaved with the LLVM passes.
for i in 1 2 3; do leg x86_64_$i env GRAIL_TEST_SHARD=$i/3 bun tools/test-native.mjs x86_64; done
for arch in aarch64 riscv64; do
  for i in 1 2 3; do leg ${arch}_$i env GRAIL_TEST_SHARD=$i/3 bun tools/test-native.mjs $arch; done
done
# The LLVM backend on the emulated targets: the `vec` cases every gate (a minute each; generics,
# hashmaps and threads go through the weak-symbol and atomics paths that broke there before), and one
# third of the corpus. The third is derived from the tree being gated, not the date, so the same tree
# always runs the same cases; the leg's name carries it, so a failure reproduces with
# `GRAIL_BACKEND=llvm GRAIL_TEST_SHARD=<i>/3 bun tools/test-native.mjs <arch>`.
xshard=$(( 16#$(git rev-parse 'HEAD^{tree}' | cut -c1) % 3 + 1 ))
for arch in aarch64 riscv64; do
  leg llvm_${arch}_vec env GRAIL_BACKEND=llvm bun tools/test-native.mjs $arch --filter vec
  leg llvm_${arch}_shard${xshard}of3 env GRAIL_BACKEND=llvm GRAIL_TEST_SHARD=$xshard/3 bun tools/test-native.mjs $arch
done
for i in 1 2 3; do leg llvm_$i env GRAIL_BACKEND=llvm GRAIL_TEST_SHARD=$i/3 bun tools/test-native.mjs x86_64; done
for i in 1 2 3; do
  leg vf_$i env GRAIL_BACKEND=llvm GRAIL_RANGE_FACTS=1 GRAIL_VERIFY_FACTS=1 GRAIL_TEST_SHARD=$i/3 bun tools/test-native.mjs x86_64
done

# Tool suites: independent of each other (each has its own .work directory).
for t in test-selfhost test-ffi test-cli interface-test cache-test split-test test-facts test-debug-lines abundance-test borg-test grammar-test; do
  leg $t bun tools/$t.mjs
done
leg windows bun tools/windows.mjs check
leg book bun tools/book.mjs check
leg lint bun tools/ci.mjs lint
wait
# Compile speed, after every other leg has finished so nothing else is running beside it: a report
# of the numbers in docs/design/compile-speed.md, which fails only when a compile itself does.
leg compile-bench bun tools/compile-bench.mjs
wait
# Run time against C, one backend at a time on a quiet machine: the numbers the runtime-parity pillar
# is judged by (docs/design/runtime-parity.md). They fail only when a program's output differs from
# the C program's.
leg runtime-bench-native bun tools/bench.mjs --rounds 3
wait
GRAIL_BACKEND=llvm leg runtime-bench-llvm bun tools/bench.mjs --rounds 3
wait

# One line per leg, failures first.
for f in "$G"/*.log; do
  if rg -q 'exit=[1-9]' "$f"; then echo "FAIL $(basename "$f" .log): $(rg 'AssertionError|error' "$f" | head -1 | cut -c1-120)"; fi
done > "$G/summary.txt"
for f in "$G"/*.log; do
  if rg -q 'exit=0' "$f"; then echo "ok   $(basename "$f" .log): $(rg 'passed|identical|verified|agree|checks|ffi:|facts:|program|compile-bench:|runtime-bench' "$f" | tail -1 | cut -c1-100)"; fi
done >> "$G/summary.txt"
echo done > "$G/DONE"
