# Retained capture joins / loop fixed points — 2026-10-31

Run `python research/experiments/captures41/check.py --joins`. Frozen control: `b7cf6f9`.
`checks.json` retains commands, current input hashes, three-run costs and native identities.
`differential.json` retains all replay output hashes. Stable/pinned-nightly suites pass **137 tests
each** (including native tests); fmt, Clippy, complete Grail Rust LSP and targeted Python LSP pass.

## Meaningful contracts

- Branch joins retain local and external storage while unioning possible sources/targets/parents.
  Both selected owners stay protected; a source overwritten on both paths can be reused.
- Loop backedges are widened/rechecked independently of breaks. Zero-count, mixed continue/break,
  while-condition zero-body effects, later-iteration borrowing, unique Option pop, local carrier
  destruction and nested lifetime invariance are exercised. The prior stale external-cell return
  proof still rejects. The temporary exact-state barrier is removed, not weakened without analysis.
- Only ancestry to no-longer-present parent capabilities is normalized. Live local **and ghost**
  parents stay frozen, data roots remain, and reference slot identities/bounds cannot change.
- Hidden core/provider/client modules execute **52** with tagged Rust-owned destruction order
  **[4,6,5,3,2,1]**, matching the exact allocator-instrumented C probe. Production objects separately
  check result/leak freedom, allowing legitimate optimizer allocation elision. -O2 ASan/UBSan disables
  allocator builtins only for the probe. Descriptor branches, backedges and false-condition writes
  execute in C and LLVM at -O0/-O2. Mixed development/release/TinyCC directions pass.
- Frozen replay remains **271/1200 raw**, **108/400 source**, and **487 identical C/API hashes**.
  Invalid/nonterminating generated cases are not executed.

`failed-rust-operator-control.json` retains an initial bad control: plain assignment compiled, while
Grail's case uses initialized-value `exchange`. The matched `mem::replace` control rejects (E0502).
The safe assignment remains a positive Rust control. No accepted program is relabeled as rejected;
these are distinct operations. The harness recognizes this borrow error as well as lifetime errors.

## Checking costs

Times are shared-host three-run medians, not service guarantees. Identical-program comparisons:

| program | b7cf6f9 check ms | new check ms |
|---|---:|---:|
| 1000 counted loops | 6.246 | 8.758 |
| 1000 while loops | 18.654 | 22.419 |
| 1000 numeric-reference loops | 24.660 | 27.166 |
| 64 readonly captures / 256 calls | 97.719 | 95.555 |
| 64 mutable captures / 256 calls | 316.249 | 314.735 |

The additional stress program writes 256 distinct loop bodies, each containing opaque updates. This
requires new fixed-point analysis and was not admitted by the frozen checker. Unchanged-state index
rebuilding and metadata-ID noise were removed; `pre-stable-index-cache.json` preserves the initial
passing run. The improvement is modest, not an algorithmic scalability claim:

| fields / 256 loop bodies | initial ms | revised ms |
|---|---:|---:|
| 1 | 17.813 | 15.764 |
| 8 | 54.597 | 50.478 |
| 32 | 338.363 | 321.604 |
| 64 | 1119.778 | 1031.610 |

Explicit origin matrices remain quadratic; loop analysis caps at 4096 rounds and existing source /
target / structural budgets apply. Small compiler-shaped cursors do not establish scalability for
arbitrarily wide contracts or the full compiler. Plain-loop overhead above is real.

## Compiler-shaped token workload

Both arms process **950272 bytes / 131072 tokens** and checksum **11380358366811062272**, with actual
generic core, owned spellings, borrowed spans, Result errors and hidden-source separate compilation.
The prior control advances once per token; the new provider advances inside validation, requiring a
real external-cell loop join. Its added calls/work explain some runtime change. This is not an
isolated instruction comparison, a contrived slow control, or the real compiler port. Three repeated
builds/links/runs per profile retain stable immutable generations and executable hashes.

| profile | old total module build ms | new build ms | old runtime ms | new runtime ms |
|---|---:|---:|---:|---:|
| clang | 82.450 | 82.271 | 25.952 | 30.412 |
| clang-release | 101.352 | 102.690 | 2.818 | 3.414 |
| tcc | 13.683 | 14.013 | 35.020 | 42.566 |

## Scope / decision

Continue with retained-slot mutation and compiler/library composition. This is **not** general
conditional ownership: resource sets, initialization shape, reference capability positions and
stored bounds must agree. Conditional moves, differing partial initialization, addressed-scalar
resource joins, finer field/parent loan ending and regular recursive reference graphs remain open.
Real arbitrary-element heap containers, the real seed port, stage-2/stage-3 and a documented
reproducible bootstrap artifact remain mandatory. No permanent v0 concessions are approved here.

No schema bump or compatibility path is added; checked IR/template bundles remain version 2. The
checker/normalization/codecs, native producers/toolchains/runtime and host remain in the TCB. These
finite controls are not a soundness theorem or a self-hosting demonstration.
