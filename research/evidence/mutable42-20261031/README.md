# Mutable lifetime witnesses / opaque writeback — 2026-10-31

Reproduce `python research/experiments/captures41/check.py --mutable`. The shared harness's readonly
mode was also executed successfully, with its output redirected to ignored scratch to preserve the
original readonly milestone evidence. `checks.json` records commands, source hashes, medians and
native identities; `differential.json` records frozen replay/C-output hashes. Both full stable and
pinned-nightly suites pass **126 tests each**, including native tests. Clippy, formatting, focused
Python/Rust diagnostics and a complete Grail Rust workspace diagnostic pass are clean.

## Safety, composition and revision

- Good stored-bound writes and short-frame/long-data unique transfers compile and execute. Bad
  generic bodies, short new sources, invariant nested/phantom narrowing, wrong reborrows and early
  old/new-owner growth reject. Generic type-argument and callee lifetime namespaces stay independent.
- Source-hidden core/cells/client modules run cursor updates, generic replacement, Option pop,
  owned-name destruction and Result failure cleanup. Independent stable/nightly Rust agrees:
  **46**, instrumented free order **[3,4,5,6,2,1]**. C/LLVM span and nested-pointer exchange execute
  at -O0/-O2. Development/release/TinyCC and mixed directions retain reproducible artifacts.
- A reproduced producer loop was accepted while continuation checking reused stale external
  captures. Backedges/exits/while conditions now close external state too. This is an interim
  conservative barrier, not a general join or an approved v0 exclusion of safe changing states.
- `failed-native-audit.json` retains an initial instrumentation mistake: optimized production
  objects elided two unused temporaries, correctly returning 46 with frees [3,4,2,1]. Production
  objects now check result and zero live allocations; only the optimizing sanitizer probe disables
  allocator builtins and asserts the full six-allocation trace. Production optimization is unchanged.
- Frozen `3d5eaa18` replay: **271/1200 raw** and **108/400 source** cases accepted, with all **487**
  retained C/API output hashes identical. Invalid/nonterminating generated code is never executed.

## Checking costs

Times below are three-run medians on this shared host, not a service-level guarantee. The old/new
plain and readonly programs are identical; the new mutable workload performs additional operations.

| identical workload | old check ms | new check ms |
|---|---:|---:|
| 1000 counted loops | 5.876 | 6.669 |
| 1000 while loops | 18.087 | 19.069 |
| 1000 numeric-reference loops | 17.078 | 23.713 |
| 1 readonly capture / 256 calls | 4.349 | 8.170 |
| 64 readonly captures / 256 calls | 41.287 | 98.361 |

The first writeback implementation recomputed an equal-type source union for every field, causing
cubic growth. `pre-projection-cache.json` preserves that passing-but-costly run. The implementation
was revised to cache each full written reference type's projection over one immutable call snapshot.
It retains every eligible source; this is not private-body effect inference.

| mutable fields / 256 updates | initial check ms | cached check ms |
|---|---:|---:|
| 1 | 8.390 | 8.640 |
| 8 | 26.274 | 21.153 |
| 32 | 375.851 | 107.152 |
| 64 | 2524.646 | 317.744 |

Explicit origin may-sets still impose quadratic worst-case storage/index work. The readonly and
plain-check overhead above is real and remains an optimization target; small finite costs do not
establish whole-compiler scalability. No blanket G0 efficiency claim is made.

## Real mutable-cursor token workload

The provider advances a captured remaining span, returns borrowed spans with owned spellings, and
uses the actual generic Result/Option library across hidden modules. Both programs process **950272
bytes / 131072 tokens**, yielding **11380358366811062272**. Three builds/links/runs per profile retain
stable generation IDs and executable hashes. Provider source is removed. Runtime includes process /
host-shim overhead. The prior readonly cursor is the control; the program/ABI differ, so these are
composition/build/runtime costs, not isolated instructions or a complete compiler benchmark.

| profile | old compile modules ms | new compile modules ms | old runtime ms | new runtime ms |
|---|---:|---:|---:|---:|
| clang | 80.163 | 77.982 | 24.165 | 26.160 |
| clang-release | 98.803 | 100.731 | 3.253 | 2.828 |
| tcc | 13.448 | 13.664 | 30.947 | 35.968 |

## Decision / remaining requirements

This supports continuing with mutable cells and bounded cursor composition after correcting the
stale-proof and repeated-union failures. It does **not** validate arbitrary-element heap collections
or general changing-state joins. Those cases, regular recursive references, practical diagnostics,
the real Rust-seed port, stage-2/stage-3 and a reproducible bootstrap artifact remain required.

Canonical IR/template bundle schema 2 requires rebuilding old templates, with no compatibility
reader or retired plain-kind route. Native keys still erase lifetimes, not layouts/modes. The
checker/provenance/codec, native producers/toolchains/runtime and host remain in the TCB; hashes bind
bytes, not producer honesty or a soundness theorem. This milestone is not completion of bootstrap v0.

During collection, Agent journal contention and ignored-tree diagnostic discovery defects were
fixed and pushed separately as `9600fa47` and `4e918d6c`. The running host was not restarted. Its older
broad diagnostic scanner produced explicitly partial reports; after releasing this session's idle
LSP resources, the Grail-only workspace pass completed with no diagnostics.
