# Borrow-checker and frontend reference review

2026-10-30. Bounded source review requested during bootstrap work. Neither project becomes a
Grail dependency. Grail's full v0 goal remains active; the aggregate controls below are Rust source,
**not implemented Grail aggregate functionality**.

## Pins and independently checked observations

- [Blu](https://github.com/blulang/blu), local source commit
  `7264d9dc177c1c26e9e79d9cbc57b398445a4593`.
  `crates/blu-compiler/src/owned.rs`: local declarations evaluate initializers before introducing new
  bindings; `snapshot_register`/`snapshot_if_bound` distinguish operand values from mutable binding
  locations; `Statement::Do` performs cleanup and scope closing without a runtime branch. Its
  `docs/language-contract.md` records matching bounded frontend/bytecode contracts. We inspected
  these paths, not its complete conformance suite. Lua/GC/upvalue semantics do not prove ownership
  safety for Grail.
- [Lust](https://github.com/t3dotgg/lust-lang), clone pinned to
  `240e08d91d4aed0299639f6f11fd522912b248f9` (`next`, 2026-10-22). Built locally with stable
  Rust 1.98 and its own pinned TinyCC `43c7708`; initial offline dependency and missing-libtcc build
  attempts failed, then its documented dependency/TinyCC setup succeeded. No source modifications.
  Tests use `lust-core`, not a warm daemon. Its README warns that `docs/ARCH.md` includes plans older
  than implementation; observations below come from code and execution, not those plans alone.

`research/experiments/lust26/check.py` retains 15 acceptance pairs against pinned Rust
`nightly-2026-10-29` (1.101, default checking). This is the modern compiler already audited in
[rust-next-baseline.md](rust-next-baseline.md), not an old NLL ceiling. Seven accepted programs
build and run under both compilers with identical exit status, stdout and stderr. Six static negative
controls are rejected by both and never executed. Two known-safe modern-Rust positives are rejected
by Lust (conditional reborrow and get-or-insert). The helper-replace/temporary-restore rejections are
precision controls, not claims that those programs necessarily execute undefined behavior.

The eight new controls exercise:

| Control | Rust / Lust |
| --- | --- |
| `Vec<Token<'a>>`, owned names, generic moves, partial field move, returned span outliving carrier | accept, equal output |
| Move different owned fields on different returns, recursive cleanup of remaining fields | accept, same `2,1,1,2` destruction trace |
| Two mutable owned fields passed under one lifetime label; reborrow one while using the other | accept, equal output |
| Mutable setter stores a new borrowed source with explicit interface lifetimes | accept, equal output |
| Automatic recursive drop after captured source lifetime ends, without reading its span | accept, equal output |
| Free newly installed setter source before stored view use | reject |
| Return a reference to a carrier's reference slot as if it had the captured data's lifetime | reject |
| Store a short-lived string into `&mut Vec<&'a str>` | reject |

These are small programs, not a Lust soundness proof or its advertised ts-rust/performance census.
The reported execution times include cold/debug-built reference tooling and are **not** a fair
compiler-speed comparison. Rust and Lust also have different std implementations/TCBs. No claim
of body-hidden separate-compilation validation follows from these single-file controls.

## Concrete lessons for the next Grail representation

1. **Use places and moves separately from operand values.** Lust's `src/ir.rs` and
   `src/borrowck/mod.rs` represent local-plus-projection places, field-sensitive initialization and
   moves. Distinct fields can be disjoint while their reference types share one lifetime label.
   Blu's snapshots exposed a current Grail frontend weakness: we reproduced acceptance of
   `take(b,b.len())`, then fixed user-call arguments to materialize immediately. This primitive
   regression is retained in `call-values25`; general mutable-reference/field effects still need tests.
2. **Give lifetime roles their own slots.** `src/borrowck/regions.rs` enumerates a reference's own
   region before pointee regions, plus ADT lifetime parameters and type-argument slots. Relating
   these slots uses variance. Carrier storage and captured source data are not one root set.
   A token accessor returning its stored readonly span can outlive the token; returning a reference
   to the token's span **slot** cannot. The paired positive/negative controls enforce this distinction.
3. **Treat mutable stores invariantly where required.** `regions/store.rs` handles stored parts and
   variance instead of assuming every flow is covariant. A generic mutable-container call cannot
   preserve only pre-call captured origins. Grail must instantiate declared region/type constraints
   and retain every admitted source without requiring G1 post-state inference. Do not copy Lust's
   opaque/builtin fallback rules without independently validating the corresponding Grail contract.
4. **Separate use-live from drop-live.** Lust has field paths for partial moves and distinct
   liveness for regions touched by recursive/custom drop (`DropMode`); C lowering elaborates
   remaining-field cleanup and drop/move flags. Merely retaining every captured source until every
   owning container drops is unnecessarily restrictive. Merely forgetting all captures at the
   container's last ordinary use can be unsafe when a destructor reads them. The drop-only control
   is specifically a no-custom-destructor case; it does not license arbitrary dangling destructors.
5. **Separate lifetime dependence from exclusive target identity.** Existing valid unique accesses
   can have the same lifetime bound but disjoint targets. Loan conflict checking must use places,
   reborrow authority and validity, not deduplicate targets by lifetime label. Trusted split APIs
   still need their own concrete range/disjointness validation.
6. **Keep generic checking separate from instance discovery.** `src/mono/mod.rs` keys instances by
   template plus concrete type/const arguments with regions erased, caches callee edges and bounds
   discovery (depth 128 and a configurable instance cap in Lust). This is a useful monomorphization
   reference, not a chosen Grail backend. Before selecting mono versus erased layouts, measure
   representative compiler/container instances, generated code volume, build cost and runtime.
   Independent caller checking still needs public type/region/layout/drop metadata; code generation
   may additionally need generic bodies, whose changes must invalidate specialized artifacts.

Lust's two borrow-checker entry files plus their region modules currently total about 16k lines,
covering much more Rust (traits, dyn, higher-ranked/function-pointer regions) than v0 needs. Copying
that system wholesale would defeat the small-bootstrap objective. Conversely, calling all difficult
cases permanent subset limits would evade v0. Use the executable gates to build the necessary field,
region, initialization and cleanup core, and invalidate wrong representations early.

## Deliberately not adopted

No warm-daemon architecture, Rust-subset restriction, crates.io adapter surface, runtime reference
counting/GC, full trait solver, higher-ranked types or elaborate opaque-return system is imported.
Lust's location-insensitive NLL rejects are implementation choices, not modern Rust limits or
approved Grail concessions. Its performance claims have not been reproduced here. Continue with
[aggregate ownership gates](aggregate-ownership-gates.md) and actual Grail source integration.
