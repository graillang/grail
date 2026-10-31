# Checked loop exits

`checks.json` is the successful 33-command gate, retaining versions, statuses, environments, outputs,
source hashes and medians. Stable and pinned nightly each pass **62 checker/source/hash + 15 native
checks** (77 total). Explicit tests additionally select clang development, actual clang release and
TinyCC for numeric/nested/match control, and clang/TinyCC objects for exact ownership audits.
No model/provider or global host toolchain setting changes; generated invalid/nonterminating IR is
compile/lower-only and never executed.

## Operational evidence

- Source-hidden control provider/client calls cover counted, while, nested-loop exits and reborrow
  release before subsequent unique access. Numeric results agree with independent Rust and C/LLVM
  at `-O0`/`-O2`. Counted continue reaches its increment; a match switch cannot intercept loop exits.
- Allocating-condition partial-record cleanup frees `[2,3,4,5,6,7,1]`. Thus no extra condition runs
  after break. Owned match payloads and earlier locals free `[3,2,5,4,1]`. Selected native objects
  and independent optimized ASan/UBSan C probes agree with real Rust scope/Drop controls.
- The optimized **instrumentation** disables allocator builtins so permitted allocation elision
  cannot defeat exact observations; production profile flags are unchanged.
- Source/raw negatives reject outside/condition jumps, unreachable operations, unclosed locals,
  changed outer ownership/loans and lost scalar definitions, including all-terminating branches.

`reference.txt` retains independent results plus the intentional precision difference: Rust accepts
consuming an outer owner immediately before break if it is not needed afterward. Grail currently
requires the existing loop-entry resource invariant and rejects this. General conditional ownership
joins remain unfinished v0 work; this is not concealed as an invalid Rust program or language proof.

## Frozen differential / costs

The gate rebuilds prechange `a1dd4ee` from `git archive`, not a current-compiler compatibility mode.
`differential.json` compares 1,200 raw and 400 source cases: **271 raw + 108 source accept**, all other
rejections match, and all **487 accepted C/API outputs** are byte-identical. The 16 plain sequential
loop cost artifacts (two kinds × four sizes × C/API) also match before/after exactly.

Three-run medians, 1,000 sequential sites:

| workload | old check | new check | old C emission | new C emission |
| --- | ---: | ---: | ---: | ---: |
| counted loop | 5.21 ms | 5.61 ms | 0.45 ms | 0.57 ms |
| while loop | 16.07 ms | 16.24 ms | 1.25 ms | 1.20 ms |
| break-heavy, scoped owners | — | 12.65 ms | — | 1.14 ms |
| continue-heavy, scoped owners | — | 11.40 ms | — | 0.97 ms |

Raw samples/32/128/512-site data are retained too. Entry snapshots add bounded per-live-state work;
branches share them rather than recursively copying states. These measurements do not prove linear
complexity, large-owner-graph scalability, or any whole-language soundness theorem.

Rust workspace and Python LSP diagnostics are retained clean. No interface schema or foreign ABI
change. Generic functions, typed-reference mutation/invariance, arbitrary-element collections,
conditional owner joins, the actual Grail compiler port and stage-2/stage-3 remain unfinished.
