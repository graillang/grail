#!/usr/bin/env bash
# The full multi-platform gate, in its fastest safe shape. Usage:
#   tools/gate.sh [--reseed] [LOGDIR]
# --reseed first republishes the bootstrap (`bootstrap.mjs update all`, which already proves
# self-hosting and assembly identity on every target, so no separate `verify` follows) and commits
# it. Logs go to LOGDIR (default .work/gate), one per leg; LOGDIR/DONE is written last.
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
leg() { local log=$1; shift; slot; ( "$@" > "$G/$log.log" 2>&1; echo "exit=$?" >> "$G/$log.log" ) & }

if [ $reseed = 1 ]; then
  bun tools/bootstrap.mjs update all > "$G/reseed.log" 2>&1
  echo "exit=$?" >> "$G/reseed.log"
  git add compiler/bootstrap && git commit -q -m "Reseed the bootstrap" >> "$G/reseed.log" 2>&1
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

# One line per leg, failures first.
for f in "$G"/*.log; do
  if rg -q 'exit=[1-9]' "$f"; then echo "FAIL $(basename "$f" .log): $(rg 'AssertionError|error' "$f" | head -1 | cut -c1-120)"; fi
done > "$G/summary.txt"
for f in "$G"/*.log; do
  if rg -q 'exit=0' "$f"; then echo "ok   $(basename "$f" .log): $(rg 'passed|identical|verified|agree|checks|ffi:|facts:|program' "$f" | tail -1 | cut -c1-100)"; fi
done >> "$G/summary.txt"
echo done > "$G/DONE"
