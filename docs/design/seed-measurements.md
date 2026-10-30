# First reusable seed: explicit ownership and backend measurements

2026-10-30. [Implementation](../../seed/README.md),
[raw evidence](../../research/evidence/seed18-20261030/checks.json).
The human approved implementation after the architecture discussion: prefer explicit, modular
ownership over full G1 referent-state inference, prioritize fast feedback and early self-hosting,
and measure backend alternatives rather than treating C-first as settled.

## What was built

A std-only Rust library checks a typed IR and produces a private validated value accepted by the
C and LLVM emitters. A command-line demonstration constructs fixed provider/client workloads.
The seed infers register types locally; written function signatures name region relationships.
Regions are not target identities. The checker separately tracks origin targets, exclusive/read
access, and suspended parent carriers. There is no G1 interprocedural post-state inference.

The provider scans bytes, counts word starts, computes a wrapping rolling hash and updates a byte
bucket table. The client stores a view in a one-field carrier and reborrows it across repeated
calls. Its checker receives only the decoded signature, not the provider body. The library API
makes that dependency boundary explicit, although the demo binary also contains fixture builders.
Interfaces are canonical text with schema, name, parameter types/regions and result type/region.
Decoding is schema validation, not evidence of an honest producer or a stable final ABI.

This is not a `.grl` parser, full Rust-style NLL checker, general compiler driver or self-hosted
compiler. View arguments are affine and explicitly reborrowed. Loops require identical resource
state at back edges; explicit IR `End` operations are not yet inferred from source liveness.
Buffers are local stack allocations, with no owning buffer arguments/returns across interfaces.
General generics, arbitrary records, branches, Result/errors, closures, heap ownership, destructors,
async, capabilities and optional verification remain unimplemented. No whole-language safety claim.

## High-signal correctness checks

Seven Rust tests cover release/movement while borrowed, the read/write conflict matrix, carrier
restriction and reactivation, return-origin validation, imported results retaining their owners and
parents, canonical/mode-sensitive interfaces, closed loop resource states, and ending/moving one
shared carrier while another remains live. These are public checker contracts, not message tests.

Native results are checked against a separate Python algorithm, not against agreement between the
two emitters alone. All five native configurations pass lengths 0, 1, 1,024 and 65,537, plus the
main workload. Both generated backends retain byte bounds checks and remainder-by-zero guards;
u64 arithmetic wraps. Guard-trap execution and arbitrary-program oracle checking are not covered
by this checksum corpus. There is no independent authority interpreter or soundness proof yet.

## Protocol and evidence boundary

Command, from the repository root:

```sh
python seed/measure.py --pairs 10 --length 262144 --repeats 16
```

- Warm filesystem; AMD Ryzen 9 7900X, Linux x86-64, shared/uncontrolled host load recorded.
- Rust 1.98.0; clang/LLVM 23.1.3; installed GCC version recorded, **not benchmarked**.
- Ten measured samples per configuration after one warmup; backend order reversed on alternating
  rounds. Before/after checker executables also alternate within each size/pair. Runtime-only
  rounds interleave all seven native variants, including Rust. No selected best sample.
- One 262,144-byte input, 16 scans (4 MiB processed), deterministic input/table initialization.
- Five seed configurations: TinyCC, C via clang O0/O2, and directly emitted LLVM IR via clang O0/O2.
  LLVM does not come from compiling the generated C. A small C printing shim is common to both.
- Native execution runs through the same bubblewrap envelope. Runtime includes startup/isolation,
  initialization and printing. Do not interpret it as kernel-only timing.
- Raw rows retain commands/flags, input hashes, exit status, stdout/stderr, wall time, Linux wait4
  child CPU/RSS; seed binary/source hashes and the earlier TinyCC provenance are also recorded.
- Build pipelines include check/emission subprocesses, source/object compilation, linking and
  harness provenance bookkeeping. They exclude building the Rust seed itself, native execution
  and oracle computation. Seed/bootstrap build commands are recorded separately.
- The edit driver is a deliberately explicit experiment, not a persistent incremental build engine.
  Within a run it compares exact API bytes. A body edit reuses the client object (hash checked);
  a signature edit adds an argument, regenerates the matching client call, rechecks and recompiles.
  Tool upgrades, transitive dependency graphs and invalidation across runs are not implemented.

## Build and edit latency

Medians in milliseconds, this fixed two-function program:

| Backend | Clean build/link | Body edit/link, client reused | Signature edit/link |
| --- | ---: | ---: | ---: |
| TinyCC | 8.66 | 4.42 | 6.68 |
| C → clang O0 | 89.70 | 47.49 | 70.93 |
| LLVM IR → clang O0 | 79.81 | 42.32 | 58.62 |
| C → clang O2 | 106.35 | 54.55 | 83.18 |
| LLVM IR → clang O2 | 94.32 | 48.98 | 69.93 |

TinyCC is the existing Goose-built standalone driver, configured for embedded use. The harness
supplies host CRT objects, libc search paths and its support archive explicitly; no third-party
source or machine-wide installation was changed. This is an external compiler process, not an
in-process JIT. Platform/FFI/fiber compatibility and large-package behavior remain open.

**Implication:** C output need not force a slow development path. TinyCC is a strong candidate for
this seed's development backend. Direct LLVM IR saves some clang pipeline time here, but not enough
to match TinyCC. Keep C and LLVM paths available for this evaluation; these numbers do not justify
building our own machine-code backend or an optimizer, nor prove TinyCC sufficient for the language.

## Runtime context, not a win over Rust

| Native executable | Median process time, ms |
| --- | ---: |
| TinyCC | 19.67 |
| C → clang O0 | 20.28 |
| LLVM IR → clang O0 | 22.41 |
| C → clang O2 | 6.87 |
| LLVM IR → clang O2 | 6.85 |
| Rust O0, panic abort | 24.79 |
| Rust O2, panic abort | 7.22 |

Rust implements the same input/hash/table algorithm separately, with safe indexing and a stack
input array. These figures are context, **not a general speed claim**: source shapes, checked IR,
backend versions and runtimes differ; startup is included; the workload is small. The close O2
numbers do not establish superiority. TinyCC sacrifices optimization, but its compilation savings
are meaningful for this edit/test workload. Release-code quality needs broader workloads.

## A measured checker mistake and its fix

The delivered baseline is commit `d6ac951`, rebuilt from tracked Rust sources in owned scratch.
It scans all live values on each access. Even numeric registers increased access-checking cost.
The current implementation maintains per-origin read/write counts and per-carrier child counts,
with a loan lookup for excluding legitimate ancestors during reborrow. Moves and call results
transfer the indexes; ending one read view does not release other live views.

| Size | Ordinary register growth, before → after ms | Live-read fan-out, before → after ms |
| ---: | ---: | ---: |
| 16 | 0.0066 → 0.0071 | 0.0049 → 0.0069 |
| 64 | 0.0176 → 0.0173 | 0.0242 → 0.0217 |
| 256 | 0.0862 → 0.0542 | 0.2394 → 0.0898 |
| 1,024 | 0.7837 → 0.2183 | 3.3281 → 0.4354 |
| 4,096 | 10.7015 → 0.9173 | 59.5274 → 2.0595 |

These are internal checker times, excluding fixture construction/process startup. At tiny sizes,
index maintenance can cost more. At 4,096 the fan-out case improves about 29×. These families do
not establish general linear complexity: deep ancestry, large origin unions and loop-state cloning
can still grow substantially. There is no representative source-program throughput figure yet.

## What this permits us to decide

1. Continue the explicit-signature seed rather than full G1. Nothing measured requires restoring
   its extra precision as the foundation; this narrow slice also cannot rule out future demand.
2. Keep TinyCC as a serious development candidate and optimizing C/LLVM as release candidates.
   C-first is now supported by a measured option, not just presumed convenience.
3. Grow a small real bootstrap workload next. It must expose source parsing/liveness, actual library
   APIs, ownership diagnostics and module tooling; none is measured by these fixed typed fixtures.
4. Do not claim Go-like package-scale builds, Rust-class general performance, full safety, complete
   lifetime inference or achieved self-hosting. The first slice supplies a baseline to improve.
