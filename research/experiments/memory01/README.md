# Memory/modularity experiment 01

These are research probes and measurement tools, not a Grail compiler or its safety proof.
Run from the Grail repository root. Requires Linux/bubblewrap, Python, Rust, and C/CMake for Goose.
No dependency download or system installation is performed by the Python runners.

## Isolation

`sandbox.py` mounts system tools and the selected Rust toolchain read-only; exposes only this
experiment tree, a writable `.work` directory, and optionally a read-only third-party checkout.
Network, IPC and process namespaces are isolated. HOME is temporary and the environment is cleared.
Rust client probes see only `probes/` and compiled artifacts, not the provider's source.
CPU/file/core limits are applied. No address-space cap is used because Goose reserves sparse stacks.
This is filesystem/network isolation, not a claim of a hardened sandbox against kernel exploits.

## Commands

```sh
python research/experiments/memory01/run_probes.py
python research/experiments/memory01/run_representations.py
python research/experiments/memory01/run_compilation.py
python research/experiments/memory01/run_goose.py
```

Before `run_goose.py`, build the pinned checkout (read the build inputs first):

```sh
mkdir -p research/experiments/memory01/.work/goose-build
python research/experiments/memory01/sandbox.py \
  --source research/repos/goose --work research/experiments/memory01/.work/goose-build -- \
  cmake -S /src -B /work -G Ninja -DCMAKE_MAKE_PROGRAM=/usr/bin/ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DGOOSE_VERSION=0357b1c -DGOOSE_BUILTIN_LIBS=
python research/experiments/memory01/sandbox.py \
  --source research/repos/goose --work research/experiments/memory01/.work/goose-build -- \
  cmake --build /work -j2
```

Representation correctness test:

```sh
python research/experiments/memory01/sandbox.py -- \
  rustc --test /experiment/src/representation.rs --edition=2024 -D warnings \
  -o /work/representation-tests
python research/experiments/memory01/sandbox.py -- /work/representation-tests
```

Results are written to `research/evidence/experiments-20261030/` (rerunning replaces that run's
files). Copy that directory first to preserve comparisons. Generated binaries/caches are ignored.
`manifest.json` records the tested source hashes/toolchains/conditions; refresh provenance when
making a new measured revision rather than attaching old numbers to changed code.

## Interpretation boundaries

- Rust probes demonstrate a reference expressivity envelope, not inferred Grail signatures.
- Goose probes exercise its real whole-program checker/runtime, not separate compilation.
- The page guard is a lifetime-only model; the pending future is a type probe, never executed.
  Neither proves real mmap eviction, kernel I/O cancellation, direct-style async or race freedom.
- The recursive parser accepts atoms/groups. It is not a full JSON/parser library benchmark.
- Representation timing uses one shared scanner and safe bounds-checked reconstruction. It keeps
  the original input for all variants; owned tokens could drop it after parsing in another workload.
- Timings use uninstrumented binaries; a separate binary counts allocations. Requested bytes are
  allocation requests, not peak live heap. Unsafe code is confined to allocator instrumentation.
- Linux `process_vm_hwm_kib` is used for program peak memory; wait4's separate peak can retain a
  fork/exec wrapper's memory floor and is retained only as raw context.
- Generic dispatch compilation is deliberately artificial and callback-heavy; sharing a compiled
  trait-object implementation changes runtime dispatch. No runtime winner is established.
- Metadata-only checks are binary-crate frontend checks; a zero-byte emitted artifact is not a
  compact exported-interface result. Full compile times include code generation and linking.
