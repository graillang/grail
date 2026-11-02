# Cleanup and current boundaries

Owned values are released deterministically on normal control flow. You usually do not write
`drop`; an explicit drop simply requests an earlier end when no live borrow prevents it.

{{example:cleanup}}

Generated cleanup handles scope exits, partial moves, active enum payloads, vector elements,
early returns, propagation and loop transfers. Native programs check for zero live runtime
allocations at normal exit. This is not a guarantee about resident memory: the allocator caches
small slabs for reuse, while large single-object arenas are released immediately.

## What this book does not promise

- The native target is Linux x86-64, with GNU assembler/linker and at most six parameters per call.
- There is no optimizer, implicit module loading, portable target, closure/async system or general
  trait-based generic programming covered here.
- Abort paths, including failed assertions and `!` on an error, do not unwind or run normal cleanup.
- Borrow checking intentionally rejects some valid programs. Whole-frame guards, weak updates
  and opaque external invariant boundaries are conservative.
- The Grail-written unsafe runtime and compiler intrinsics form a trusted boundary. The rejection
  tests and self-compilation checks are not a proof of language or machine-code soundness.
- The older C bootstrap and Rust seed are independent recovery/checking routes, not dependencies
  of the direct native runtime.

## Where to go next

Read `compiler/NATIVE.md` for native bootstrap reproduction and implementation boundaries,
`compiler/tests/` for larger executable regressions, and `docs/design/` for research and proposals.
Design sketches may describe things the current compiler does not implement.

**Try it:** add an owned temporary before each early exit in a small program. Run the book checks
and the native conformance test to keep cleanup and ownership behavior observable.
