# Cleanup and current boundaries

Owned values are released deterministically on normal control flow. You usually do not write
`drop`; an explicit drop simply requests an earlier end when no live borrow prevents it.

{{example:cleanup}}

Generated cleanup handles scope exits, partial moves, active enum payloads, vector elements,
early returns, propagation and loop transfers. Native programs check for zero live runtime
allocations at normal exit. This is not a guarantee about resident memory: the allocator caches
small slabs for reuse, while large single-object arenas are released immediately.

## What this book does not promise

- The execution matrix is: Linux x86-64 (native, full compiler and runtime evidence); Linux AArch64
  and RISC-V 64 (cross-built; qemu execution only when a runner is installed); Windows x86-64 (PE32+
  images, ten test programs under Wine, not native Windows); Windows AArch64 and macOS
  x86-64/AArch64 (static-only objects and images, not executable here). A cross-built object is not platform support; only the evidence in that matrix
  counts.
- Not executable yet: Windows AArch64 and both macOS targets. Not implemented: D3D12 and Metal
  backends, debugger attach, and a profiler; COM remains open on `main` (a branch implementation
  with 22 checks and 11 Wine executions is pending integration). The Vulkan backend has a verified
  swapchain/present/draw path, including depth and MSAA; D3D12 and Metal return `UNSUPPORTED`.
  `docs/platform-status.md` records the evidence for each row.
- Linux x86-64 emits DWARF `.debug_line` tables with `grail build --debug` (inspect them with
  `grail debug lines`); `.debug_info` variable data and debugger attach are not implemented. The
  v3 C FFI slice — `extern "C"` scalars, byte views/`CStr`, opaque handles, C-layout records and
  callbacks — links and executes 12 fixtures across x86-64, AArch64 and RISC-V, and the `sys_grail`
  wrappers over the Linux ABI (files, clocks, environment, loopback TCP) are on `main`; dynamic
  library loading, variadic C functions and record results remain open.
- The optimizer is a per-function pass (slot forwarding, dead-code removal, callee-saved register
  promotion, branch fusion); there is no general inlining or loop optimization yet. Implicit module
  loading, general async/await syntax and a general trait system are not covered here; structured tasks, cancellation and suspending green-task I/O are described in the concurrency chapter.
- Abort paths, including failed assertions and `!` on an error, do not unwind or run normal cleanup.
- Borrow checking intentionally rejects some valid programs. Whole-frame guards, weak updates
  and opaque external invariant boundaries are conservative.
- The Grail-written unsafe runtime and compiler intrinsics form a trusted boundary. The rejection
  tests and self-compilation checks are not a proof of language or machine-code soundness.
- The Grail-written compiler is authoritative. Only generated assembly bootstraps are retained;
  the duplicate Rust seed and unchecked C compiler have been removed.

## Not implemented yet

- Map iteration with `for key, value in map`; use indexing, `get` and `entry` instead.
- Record patterns in `match`; read the fields instead.
- Closures that capture a borrowed value; capture an owned copy instead.
- Consuming loops over owned elements (`for item in items` where items own data); use `&items`.

Indexed map assignment currently updates a named map or a field path only; a temporary receiver or a
nested target such as `nested["a"]["b"] = 1` is rejected.

Tail-expression returns and tuples are deliberately absent, not pending.

## Where to go next

Read `compiler/NATIVE.md` for native bootstrap reproduction and implementation boundaries,
`compiler/tests/` for larger executable regressions, and `docs/design/` for research and proposals.
Design sketches may describe things the current compiler does not implement.

**Try it:** add an owned temporary before each early exit in a small program. Run the book checks
and the native conformance test to keep cleanup and ownership behavior observable.

Temporary owned arguments to a method expression statement end with that statement. Named owners
still follow lexical cleanup, including early returns and loop exits.
