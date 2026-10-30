# Pending-work ownership on error

Finite protocol model, not a device runtime or ownership compiler. The concrete failure modes are:
1. On error, dropping a user operation handle also drops the scope's buffer dependency before work stops.
2. One acknowledgment clears a whole registry although another operation still borrows the buffer.

These are meaningful lifetime/protocol boundaries. Static Python checks cannot detect wrong state
transitions; the earlier one-loan sampled Quint model does not exercise handle/registry separation or
multiple operations. This checker exhausts reachable states rather than adding incidental unit tests.

From the Grail root:

```sh
python -m research.experiments.cleanup06.check
ruff check research/experiments/cleanup06
pyright --project research/experiments/cleanup06
```

## State and transition assumptions

A scope owns one stable, read-only buffer. Up to N single-use operation IDs may borrow it. State has:
- user handles, consumed by explicit finish on normal paths or abandonment on error;
- a separate scope-owned registry, retaining each still-active operation's obligation;
- operation phase: idle, running, cancel_requested or stopped;
- scope phase: body, normal_cleanup, error_cleanup, exited_normal or exited_error;
- buffer_alive, initially true and cleared only by scope exit.

Submit registers work and creates its handle. Acknowledgment means **no further buffer access by that
modeled operation**, not merely that a cancel request was submitted. It stops that operation and
removes its registry entry. Normal finish consumes an already-stopped operation's handle. Error
abandonment consumes handles and requests cancellation without asserting any operation has stopped.
Scope exit requires no user handles and an empty registry. Submission stops when cleanup starts.

The correct policy preserves the registry on error. Two deliberately wrong policies clear it on
handle abandonment or on any single acknowledgment. All policies consume every user handle before
exit: that resource discipline alone is not the buffer-lifetime invariant.

Checked property: active operations imply buffer_alive. Auxiliary invariant for the correct policy:
active IDs are a subset of registered IDs. An explicit stall transition permits infinite pending
cleanup; no fairness, completion deadline or eventual response is assumed.

## Bounds and limitations

The checker enumerates the complete reachable graph for N = 1, 2 and 3, including stalls. IDs are not
reused; operations are submitted at most once. There are no stale completions, multishot results,
write races, address relocation, escaping results, nested scopes, arbitrary callbacks or failures
inside bookkeeping/cleanup itself. Buffer stability and truthful acknowledgment are assumptions.

There is no kernel/device execution, compiler translation proof or machine-checked unbounded theorem.
The short invariant argument in the [design note](../../../docs/design/cleanup-boundary.md) is a proof
sketch. Source hashes and complete shortest counterexample traces are retained under
`research/evidence/cleanup06-20261030`. Downloaded primary man pages are ignored `.work` scratch;
their pinned URLs, byte sizes and hashes are in precedent-sources.json.
