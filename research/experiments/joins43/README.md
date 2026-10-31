# Retained capture joins / loop fixed-point gate

Run the maintained shared harness: `python research/experiments/captures41/check.py --joins`.
The frozen control is `b7cf6f9`. Unchanged plain, numeric-reference, readonly and opaque-mutation
programs measure checker overhead; the new workload adds independently written loops with opaque
capture writeback (1/8/32/64 fields, 16/64/256 bodies). Generated inputs are never executed unless
they are the explicit terminating library/native workloads.

The real lexer now advances the stored cursor from inside its validation loop. Its previous mutable
control advances once after validation. Same valid input/checksum and hidden interfaces, but different
work granularity: the runtime comparison is not an isolated compiler-optimization result.

The independent Rust control executes zero counts, mixed exits and Option pop with tagged owned
names, giving 52 and destruction order [4,6,5,3,2,1]. `invalid_long.rs` must reject a stale long-return
proof; `invalid_widen.rs` uses initialized-value replacement matching Grail exchange. Plain assignment
can end a reference earlier, and remains a positive control in reference.rs. An initial control used
assignment by mistake; its acceptance is retained as a failed gate, not reclassified as rejection.

Native tests hide provider/core sources, mix development/release/TinyCC, validate zero live allocations
in production objects and exact destruction with allocator builtins disabled only in the optimizing
ASan/UBSan probe. Descriptor branch/backedge/zero-body-condition behavior executes in both C and LLVM.

This is a retained-slot join, not conditional ownership/maybe-initialization or a complete bootstrap.
See docs/design/capture-joins.md and the retained evidence for costs, TCB and remaining requirements.
