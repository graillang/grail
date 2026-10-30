# Lifetime roots and exclusive-access authority

Fifteen isolated Rust probes plus a small **ghost** interval-permission comparison. This is not a
Grail checker, runtime borrow table, compiler implementation or soundness theorem.

Concrete failure modes justify the checks: parent bypass during reborrow; returning a view beyond
its mutable carrier loan; copying/using consumed authority; conflating lending with disjoint item
transfer; accepting overlapping mutable outputs merely because their source roots are identical.

```sh
python -m research.experiments.authority08.check
ruff check research/experiments/authority08
pyright --project research/experiments/authority08
```

Needs installed Rust and Linux bubblewrap; no third-party crate or installation. Nine cases compile
and run, six reject with intended codes/lifetime diagnostics. Positive results are not source
translations of the hypothetical Grail signatures: notably Rust may implicitly reborrow a mutable
reference passed to a function. A wrapper with a consuming self receiver tests genuine move semantics.

The ghost model compares interval overlap with independently materialized per-cell permissions for
one-level child loans within [0,n], n = 0..8. It checks 45 partitions and 19,668 parent-access queries,
including resumption after the child ends. Empty intervals have no memory cells. Source-root/mode
summaries are intentionally coarse for index paths; a valid split and an invalid overlapping pair
collide under that summary.

This does **not** imply that more public qualifier slots or a runtime loan graph are mandatory.
A view type's well-formedness and safe/trusted constructors may provide the missing guarantee.
The descriptors do not enforce affine binding use; split assumes an unencumbered mutable parent.
The model does not implement inference, branches, loops, nested loans, aliasing heaps, observable
destructors, pointer provenance or generic first-class mutable-reference state.

Aeneas/Hylo source/specification excerpts were inspected read-only and pinned; neither toolchain was
built or benchmarked and no proof was replayed. [Design note](../../../docs/design/authority-boundary.md).
Raw diagnostics, executions, finite comparisons and hashes go to
`research/evidence/authority08-20261030/checks.json`.
