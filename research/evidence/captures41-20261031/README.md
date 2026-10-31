# Readonly captured-reference gate — 2026-10-31

Run `python research/experiments/captures41/check.py`. `checks.json` retains full commands/output,
tool versions, three-sample timings and hashes of the measured source/fixtures. This is the
implemented shared-cursor boundary, **not** mutable capture invariance/writeback or full v0.

## Contracts and executed controls

- **117 tests** pass on stable Rust 1.98 and pinned nightly 1.101 (including 23 native tests).
  Formatting and denied-warning all-target Clippy pass. New native tests run clang development,
  actual clang `-O2` release, TinyCC and both mixed-profile directions, without provider source.
- A copied shared source outlives the short cursor frame; the cursor/name can be dropped while the
  source descriptor remains usable. The source owner cannot grow/drop until that view ends.
  A stored unique-field reborrow retains its outer frame/authority and cannot claim the long stored
  lifetime, even when an unrelated long signature anchor is present. Nested captures cannot be
  widened by returning the same outer pointer. Unused slots/output types do not invent input facts.
- Input-source contracts include explicit dereference paths and physical stored-reference outlives
  bounds. The caller retains eligible data/frame sources by written types, not private-body G1
  effects. Live frame loans prevent premature automatic capture expiry. Opaque readonly borrowing
  checks universally, without the former mutable/plain restriction on shared `ref<T>` formation.
- Explicit readonly descriptor and nested pointer loads execute in C and comparison LLVM at
  `-O0` and `-O2`, with `-Werror` const-pointer ABI checks. Unique/owner loads still reject. A typed
  numeric field pointer cannot masquerade as byte storage and fail later C lowering.
- Native result **36 / complete release order `[2,3,1]`** agrees with independently executed
  stable/nightly Rust. Native allocator wrapping balances; optimized ASan/UBSan probes pass.
  Instrumented probes preserve allocator builtins only for observation; production flags unchanged.
- Both Rust versions independently reject the long unique-field return and nested-cursor widening.
  Those are real supported-reference negatives, not unsupported syntax counted as a safety proof.

## Frozen replay and costs

A separately rebuilt `b755920` receives the identical compile/lower-only 1200 raw + 400 source
corpus. Acceptance remains **271 raw + 108 source accepts**, with all **487 C/API outputs** exactly
byte-identical and all 16 legacy plain-loop cost artifacts identical. No API normalization or
compiler compatibility path. Invalid/nonterminating generated IR is never executed.

Three-sample medians at 1000 sites:

| checking workload | before | after |
| --- | ---: | ---: |
| counted | 6.47 ms | 5.75 ms |
| while | 19.59 ms | 19.49 ms |
| refs | 19.04 ms | 18.18 ms |

At 256 new getter calls, distinct captures cost:

| captured sources | checking | emission |
| --- | ---: | ---: |
| 1 | 4.63 ms | 0.84 ms |
| 8 | 8.59 ms | 0.84 ms |
| 32 | 23.09 ms | 1.01 ms |
| 64 | 44.27 ms | 1.18 ms |

All 16/64-call samples are retained. Capture-set work has visible cost; this does not prove global
linear scaling or arbitrary large graph efficiency. Actual source paths avoid cloning whole
pointee trees for every leaf. Type/provenance expansion caps at depth 64 / 4096 nodes, possible
places/dereference result sets at 4096. Regular recursive reference graphs exceeding that budget
fail before parameter materialization; no claim that their general treatment is complete.

## Real token-library composition

The native comparison scans **950272 bytes / 131072 tokens**, agreeing with independent Rust and
all profiles on **11380358366811062272**. Before is the frozen compiler with a by-value byte-view
lexer; after uses a separately compiled shared-cursor lexer carrying the full source and owned
cursor name. Both return borrowed token spans/owned spellings through real generic Result/Option,
use `?`, loop exits and per-token cleanup. Provider source is removed. Three module compiles/links
require identical artifact IDs/executable bytes within each variant.

| compiler/program | profile | sum of module compile medians | run median | lexer + scanner objects |
| --- | --- | ---: | ---: | ---: |
| before | clang | 86.22 ms | 25.50 ms | 11520 bytes |
| before | clang-release | 106.93 ms | 2.98 ms | 3768 bytes |
| before | tcc | 13.12 ms | 34.06 ms | 14016 bytes |
| after | clang | 88.33 ms | 25.28 ms | 12664 bytes |
| after | clang-release | 103.72 ms | 3.06 ms | 4088 bytes |
| after | tcc | 13.68 ms | 32.98 ms | 14896 bytes |

The new program adds one cursor/name and changes the provider ABI; this is representative composition,
not an isolated borrow instruction comparison or a whole compiler benchmark. Fixed clang-shim link
and raw samples are retained. Runtime includes process/input generation overhead. No LTO, CPU
pinning or confidence intervals. TinyCC rows here use the fixed clang shim link intentionally; the
native integration separately exercises real selected-profile driver build/link routes.

## Diagnostics, TCB and incomplete criteria

Rust linked source/tests and focused Python LSP/CLI checks are clean. Historical unlinked scratch
notes and the old running harness's partial Python workspace request are retained if returned,
not silently promoted to a complete workspace pass (Agent fix d4566bd5 already pushed, no restart).

Compiler/checker, source-contract/IR/substitution machinery, native producers/toolchains/runtime
and host remain trusted. Hashes bind bytes, not honesty or a soundness theorem. No provider/model
settings were changed; no delegation was used.

Mutable capture-bearing pointees still fail closed. Invariant local lifetime witnesses and
capture-retaining opaque writeback are **not implemented or counted as passing tests**. Unique
take/pop with residual may-sources, arbitrary-element containers, mutating captured cursors,
remaining ownership joins/precision, full linked inventories, the real seed port, stage-2/stage-3
and retained self-hosted bootstrap artifact remain mandatory unfinished criteria. No permanent
concession to the agreed v0 was made.
