# Typed storage foundation — 2026-10-31

Run `python research/experiments/references40/check.py`. Retained commands, versions, source hashes,
raw samples and medians are in `checks.json`. This is an implemented **lifetime-free referent**
checkpoint, not proof/completion of the general captured-reference invariance/writeback gate.

## Checked and executed

- **105 tests** pass on stable Rust 1.98 and pinned nightly 1.101, including 20 native tests.
  All-target denied-warning Clippy and formatting pass. New reference tests additionally run all
  three native profiles, both mixed-profile directions and allocator probes with clang/TinyCC.
- Real source-hidden provider/client programs exchange owned strings and numeric fields, grow byte
  descriptors through typed mutable references, transfer generic owners, and return pointers to
  caller scalar storage. Repeated builds retain identical artifact IDs and executable bytes.
- Numeric pointer returns and real indirect loads/stores run through C and comparison LLVM at
  `-O0` / `-O2`; branch choices give **19 / 92**. Heap/nominal LLVM restrictions remain explicit.
- Generic source/IR bodies universally check. A hidden `ref<T>` kind requirement rejects at body or
  call checking, not after caller-specific native instantiation. Signature-exposed requirements,
  nested nominal substitutions, stored-field roots and source-hidden generic replacement execute.
- Negative checks reject overwritten/ended/exclusively read scalar slots, shared mutation, parent
  use during child reborrows, local pointer escapes, affine loads, and overlap between typed field
  storage loans and exclusive byte-data access. Moved owned fields relocate storage identity while
  preserving external capture roots; dropping the old partial container does not drop that field.
- Owner replacement returns the previous owner rather than destroying the new one. Native result
  **45** and complete release order **`[4,5,2,3,1]`** match independently executed stable/nightly Rust
  controls. Allocator wrapping balances and optimizing ASan/UBSan probes pass. Instrumented probes
  disable allocator builtins only to preserve observation; production optimization flags are unchanged.

## Frozen conformance / checking costs

The gate rebuilds `85ec12d` independently from Git archive. The same compile/lower-only 1200 raw +
400 source corpus retains **271 raw + 108 source accepts**, with all **487 C/API outputs** exactly
byte-identical. No normalization or compatibility compiler mode is used. Invalid/nonterminating
IR is not executed. The 16 unchanged plain sequential-loop cost artifacts also match exactly.

Three-sample medians at 1000 sites:

| workload | old checking | new checking | old emission | new emission |
| --- | ---: | ---: | ---: | ---: |
| plain counted loops | 5.71 ms | 6.50 ms | 0.82 ms | 0.76 ms |
| plain while loops | 18.21 ms | 19.30 ms | 1.83 ms | 1.82 ms |
| typed scalar updates through calls | — | 17.39 ms | — | 2.44 ms |

There is measurable added bookkeeping, not a claim of zero-cost checking. Addressed scalar storage
uses explicit place liveness while unaddressed values keep the scalar fast path. Prefix queries
use the ordered access index; ending a loan retires only its possible scalar targets, not all
addressed values. 32/128/512-site samples and all command timings are retained. This is not a proof
of global linear complexity or large origin-set scalability; target sets cap at 4096.

## Mutable-state workload

A separately compiled source-hidden `stats::step` updates two fields through a typed mutable record
reference for every byte of a **1048576-byte** source-like input. All profiles and Rust agree on
**17137066083288806337**. It also exposed/fixes a real frontend bug: nested expression-statement
blocks could end a counted-loop input view before the backedge. Source regressions retain borrowed
entry resources through nested counted/while blocks.

| native objects | sum of module compile medians | fixed clang-shim link | run median | two object bytes |
| --- | ---: | ---: | ---: | ---: |
| clang development | 57.60 ms | 52.50 ms | 9.45 ms | 2920 |
| clang-release | 64.35 ms | 51.00 ms | 3.81 ms | 2288 |
| TinyCC development | 7.34 ms | 52.31 ms | 9.40 ms | 2501 |

Three repeats require identical module artifact IDs and shim executable bytes. Module samples include
first publication plus existing-generation verification; no checking cache is claimed. All benchmark
links use a fixed clang host shim intentionally; native integration separately exercises the real
selected-profile build/link routes. Runtime includes process/input generation overhead (including
host-shim byte filling), not just the Grail update kernel. No LTO, CPU pinning or confidence interval.
This is mutable compiler-state/library evidence, not the real seed port or a whole compiler benchmark.

## Honest boundary / TCB

Rust workspace source/tests and focused Python LSP have zero diagnostics. Seven severity-4 notes
belong to old unlinked scratch files. Python CLI Pyright/Ruff are clean; the old running tool host's
Python workspace request is partial/timed out, as retained. Borg Agent fix **d4566bd5** was already
pushed; no active host restart, provider/model switch or delegation was performed.

Lifetime-bearing pointees, including phantom lifetime slots and unused type arguments, deliberately
fail closed. Those failures are **not** a successful invariance/writeback proof. Invariant local
witnesses, long stored-source versus short outer-frame bounds, conservative capture writeback,
unique take/pop with residual may-sources and real reference-containing containers/cursors remain
required. No permanent concession to v0 was made. Field-splitting through one mutable parent remains
conservative; remaining ownership joins/ergonomics are not declared complete.

The compiler/checker/IR codec and C/LLVM/native toolchains/runtime/filesystem remain trusted. Hashes
bind bytes, not producer honesty or a general soundness theorem. Full executable implementation
inventories, the real Grail seed port, stage-2/stage-3 and retained bootstrap artifact remain unfinished.
