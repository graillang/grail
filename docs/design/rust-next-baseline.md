# Rust's next-generation checking is part of the baseline

2026-10-30. The human explicitly requested that comparisons include new Rust checking, not only
stable-default behavior. [Runner](../../research/experiments/rust_next20/README.md),
[raw evidence](../../research/evidence/rust-next20-20261030/checks.json).

## Sources and versions

Official announcements:

- [Polonius Alpha enabled on nightly, 2026-08-04](https://blog.rust-lang.org/2026/08/04/enabling-polonius-alpha-on-nightly/)
- [Next-generation trait solver enabled on nightly, 2026-08-21](https://blog.rust-lang.org/2026/08/21/enabling-next-solver-on-nightly/)
- [Polonius project goal](https://goals.rust-lang.org/2026/polonius.html)
- [Trait-solver project goal](https://goals.rust-lang.org/2026/next-solver.html)

The project goals/announcements describe ongoing stabilization, capability improvements, modeling,
performance work and correctness fixes. They are not a whole-compiler soundness theorem. The trait
solver reworks trait goals, associated-type normalization and opaque types; its purpose is not merely
more permissive borrow checking. Polonius Alpha improves location-sensitive loan/outlives analysis,
without requiring G1-style exported mutable-content summaries.

The installed unqualified `nightly` was **March 2026**, so it was not used as the modern baseline.
We installed a separately pinned **nightly-2026-10-29**, rustc **1.101.0-nightly**, compiler commit
`92ffebeceaa0a071066f233873c2438e73d70fe7` (2026-10-28), LLVM 23.1.4, in experiment-owned
RUSTUP_HOME. The host default remains stable **1.98.0**, commit
`88d9e12ae178fab0fb5cc050a94da85685d449ea`. No global default was changed.

## Executed controls

Seven source cases across seven configurations (49 compilations). Flag availability is checked
with a separate trivial program, so a missing switch cannot masquerade as a borrow rejection.
Stable experimental flags use a command-local `RUSTC_BOOTSTRAP=1`; this is not a stable feature claim.
Each known-safe accepted positive is executed under the same isolated runner. Rejected programs,
including the genuinely unsafe temporary escape, are never executed.

| Case | Stable default | Stable explicit next | Modern default | Modern legacy | Modern Polonius only | Modern solver only |
| --- | --- | --- | --- | --- | --- | --- |
| Conditional returned reborrow | Reject E0499 | Accept/run | Accept/run | Reject E0499 | Accept/run | Reject E0499 |
| get-or-insert, NLL case 3 | Reject E0499 | Accept/run | Accept/run | Reject E0499 | Accept/run | Reject E0499 |
| Simple tail-cursor append | Accept/run | Accept/run | Accept/run | Accept/run | Accept/run | Accept/run |
| Stored helper replacement, release old source | Reject E0505 | Reject E0505 | Reject E0505 | Reject E0505 | Reject E0505 | Reject E0505 |
| Temporary insertion then restoration | Reject E0597 | Reject E0597 | Reject E0597 | Reject E0597 | Reject E0597 | Reject E0597 |
| Temporary left installed (unsafe escape) | Reject E0597 | Reject E0597 | Reject E0597 | Reject E0597 | Reject E0597 | Reject E0597 |
| Direct reset | Accept/run | Accept/run | Accept/run | Accept/run | Accept/run | Accept/run |

Modern explicit-next agrees with modern default on all seven cases. Same-nightly flag isolation
attributes the first two acceptance changes to **Polonius**, not the trait solver. No trait-solver-
specific soundness/feature corpus was run here; these cases cannot establish its comparative
correctness or performance. The official design/status work remains required reading before
implementing Grail's generic bounds, normalization and any more advanced trait mechanisms.

## Corrections to our architectural baseline

- "Rust rejects get-or-insert without Entry" is not a valid unqualified statement about current
  next-generation Rust. Entry remains a useful API, not a necessary concession in that formulation.
- A simple tail cursor was already accepted by stable; do not count it as a Grail novelty.
- More capable **local** checking can preserve written, body-independent interfaces. Do not equate
  every precision improvement with interprocedural inference or inevitable slow builds.
- The referent-content replacement/restoration limitations from the earlier study remain visible
  in these tested formulations. Polonius does not make every invariant referent lifetime changeable.
  That does not prove that stronger precision is impossible or worth its implementation cost.
- Grail's closed-state loop/branch checker is an early implementation restriction, not Rust's
  capability ceiling and not a permanent requirement of the explicit-interface architecture.
- Our reasons for a smaller trait system are its intended scope and implementation budget, not an
  assumption that Rust has no plan for capability/correctness improvements. Existing Rust proof
  projects and next-generation algorithms are inputs, not proofs automatically inherited by Grail.

## Scope and next gate

This is a targeted capability audit, **not a benchmark**, a compiler correctness comparison, a full
Polonius algorithm review, or a claim that all next-solver soundness issues are resolved. The earlier
compile timings are historical measurements of their exact versions; they are not retested or
rewritten here. Source/toolchain hashes, flags, diagnostics and executed controls are retained.

At each relevant v0 extension, compare the same expressibility/safety case against stable and this
pinned modern baseline. For generic/reference-containing containers, use real APIs and inspect the
next solver/Polonius rules rather than guessing from a stable error. Maintain v0's explicit scope;
seek human approval for product concessions instead of declaring a missing Grail feature unavoidable.
