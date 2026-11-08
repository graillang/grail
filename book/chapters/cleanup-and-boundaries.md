# Cleanup and current boundaries

Owned values are released deterministically on normal control flow. You usually do not write
`drop`; an explicit drop simply requests an earlier end when no live borrow prevents it.

{{example:cleanup}}

Generated cleanup handles scope exits, partial moves, active enum payloads, vector elements,
early returns, propagation and loop transfers. Native programs check for zero live runtime
allocations at normal exit. This is not a guarantee about resident memory: the allocator caches
small slabs for reuse, while large single-object arenas are released immediately.

## What this book does not promise

- The native targets are Linux x86-64, ARM64 and RISC-V 64, with at most six word parameters per call.
- The optimizer is a per-function pass (slot forwarding, dead-code removal, callee-saved register
  promotion, branch fusion); there is no general inlining or loop optimization yet. Implicit module
  loading, general async/await syntax and a general trait system are not covered here; structured tasks, cancellation and suspending green-task I/O are described in the concurrency chapter. CPU support does not imply support for macOS or Windows.
- Abort paths, including failed assertions and `!` on an error, do not unwind or run normal cleanup.
- Borrow checking intentionally rejects some valid programs. Whole-frame guards, weak updates
  and opaque external invariant boundaries are conservative.
- The Grail-written unsafe runtime and compiler intrinsics form a trusted boundary. The rejection
  tests and self-compilation checks are not a proof of language or machine-code soundness.
- The Grail-written compiler is authoritative. Only generated assembly bootstraps are retained;
  the duplicate Rust seed and unchecked C compiler have been removed.

## Approved model status in this preview

The book follows the approved syntax-v2 surface. These parts are documented but not yet accepted by
the preview compiler, so they appear only in prose:

- Map literals `["a": 1]` and `[:]`, `[K: V]::with_seed(seed)`, required-key indexing `map[key]`, and
  `entry.or_insert(value)`. Use `hashmap::with_seed`, `get`/`get_mut`/`entry` and `insert`.
- `&` and `&mut` for records, vectors, maps and scalars. Those still use `borrow`/`borrow_mut`;
  byte buffers already use `&[u8]` and `&mut [u8]`.
- Direct temporary iteration (`for part in text.split(' ')`) in the book's `--default-u64` mode;
  keep the explicit `parts` binding and `for part in borrow(parts)`.

Tail-expression returns and tuples are deliberately absent, not pending.

## Where to go next

Read `compiler/NATIVE.md` for native bootstrap reproduction and implementation boundaries,
`compiler/tests/` for larger executable regressions, and `docs/design/` for research and proposals.
Design sketches may describe things the current compiler does not implement.

**Try it:** add an owned temporary before each early exit in a small program. Run the book checks
and the native conformance test to keep cleanup and ownership behavior observable.

Temporary owned arguments to a method expression statement end with that statement. Named owners
still follow lexical cleanup, including early returns and loop exits.
