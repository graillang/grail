# Argument evaluation and delayed call activation

A finite hypothetical admission-policy comparison, not an implemented Grail call frontend or a bug
in transforms05. That IR has no nested effectful call expressions or container-storage views.

```sh
python -m research.experiments.calls09.check
ruff check research/experiments/calls09
pyright --project research/experiments/calls09
```

Requires Python, installed Rust and Linux bubblewrap for five Rust reference probes. The call model
checks four policies over 259 effect sequences (length 0..3) and three call forms: a pending stable
named place, a materialized storage view, or both. The six effects are no-op, append b/c, clear,
replace with c, and drop. Nontrivial mutations explicitly invalidate storage epochs; this is not a
claim that every real vector push reallocates. There is one slot and three external sources.

An entry-relative preserve contract is inferred by experiment 05 and instantiated with an early or
late snapshot. The separate concrete path manipulates list contents and storage epochs rather than
applying that contract. Missing-source witnesses also check an owner-generation invalidation suffix.
Materialized values lend storage during evaluation; mutable activation also checks their aliasing.
Dropped/uninitialized targets are rejected at activation even if a place was named earlier.

Failure guards are warranted by source loss/false retention, stale materialized pointers and copied
view aliasing. They cannot be established by Python lint/type checking. The five Rust probes pin
reference behavior, **not** the hypothetical policy's source syntax: Rust accepts push(len), but
rejects nested mutable receiver calls, materialized-view invalidation, overlapping entry arguments
and moving a borrowed target.

No expression parser, computed selector, first-class exclusive view, arbitrary heap alias, callee
closure evaluation, failure path or suspension is modeled. There is no runtime code generation,
compile-time/speed claim or general soundness theorem. See
[design note](../../../docs/design/call-activation-boundary.md) and raw evidence in
`research/evidence/calls09-20261030`.
