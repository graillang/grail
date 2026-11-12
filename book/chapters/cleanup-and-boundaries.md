# Cleanup and current boundaries

Owned values are released deterministically on normal control flow. You usually do not write
`drop`; an explicit drop simply requests an earlier end when no live borrow prevents it.

{{example:cleanup}}

Generated cleanup handles scope exits, partial moves, active enum payloads, vector elements,
early returns, propagation and loop transfers. Native programs check for zero live runtime
allocations at normal exit. This is not a guarantee about resident memory: the allocator caches
small slabs for reuse, while large single-object arenas are released immediately.

## Calling C

A foreign function is declared with its C name and signature, and each call sits in an `unsafe`
block:

```grl
handle Instance;

extern "C" record Vec2 { x: f64, y: f64 }

extern "C" fn c_length(vector: byval Vec2) -> f64;
extern "C" fn c_create(slot: &mut Instance) -> i32;

fn main() -> u64 {
    mut length: f64 = 0.0;
    unsafe {
        length = c_length(Vec2 { x: 3.0, y: 4.0 });
    }
    println(length);
    return 0;
}
```

A bare record parameter is the C `R *`; passing the whole record by value is written `v: byval R`,
and `byval` is only accepted on an `extern "C"` record, on x86-64, AArch64 and RISC-V 64:

{{example:byval-record}}

The rest of the surface is implemented and executed, and `docs/ffi.md` is the contract:

- `extern "C"` declarations and exports: scalar, float and narrow-integer parameters and results,
  byte views and `CStr`, opaque handles, C-layout records by pointer and by value as results, the
  address of a record as a value (`cptr`/`cptr_mut`), callbacks and `cfn` function pointers, and
  variadic C functions.
- A handle can appear in another module's signature (`use sys_grail::File;`), and two handles of the
  same type compare with `==`/`!=` by identity; a handle has no arithmetic, ordering or size, and
  only a foreign call produces one.
- Out-parameters: a handle, bare pointer or `extern "C"` record binding passed as `&mut` is the C
  `H *`/`void **`/`R *`, so a create function can write a handle into a slot the caller owns or fill
  a struct in place. A record declared without an initializer is zeroed storage with no value, which
  is how an array of handles exists before C fills it.
- Calls of seven to nine word arguments use the target's own register file and then the outgoing
  stack (six registers on x86-64, eight on AArch64 and RISC-V 64).
- Dynamic loading through `dlopen`/`dlsym`/`dlclose` on the three Linux targets, where foreign
  calls stay on the main thread; on Windows x86-64 the loader is reached through ordinary
  `LoadLibraryA`/`GetProcAddress` imports. macOS dynamic loading is not implemented.

`byval` follows each ABI's struct rules, Windows included. Still refused, with a
diagnostic: a `byval` callback parameter, a handle or pointer out-parameter on a callback or `cfn`
type, the address of a *temporary* record (`cptr
needs a named record`) or of a record that has no C layout, foreign calls from a thread other than
the main one on Linux, and dynamic loading on macOS. Tests that execute the C ABI against real
libraries live in `tests/ffi/`; the book's own C examples link a freestanding shim beside them
(`book/ffi/`), which is enough to run the same C from both languages and not enough to need a
system library.

## What this book does not promise

- The execution matrix is: Linux x86-64 (native, full compiler and runtime evidence); Linux AArch64
  and RISC-V 64 (cross-built; qemu execution only when a runner is installed); Windows x86-64 (PE32+
  images and test programs under Wine, not native Windows); Windows AArch64 and macOS
  x86-64/AArch64 (static-only objects and images, not executable here). A cross-built object is not
  platform support; only the evidence in that matrix counts, and `docs/platform-status.md` records
  it row by row.
- Not executable yet: Windows AArch64 and both macOS targets. Not implemented: the Metal backend and
  debugger attach. Vulkan has a verified swapchain/present/draw path including depth and MSAA, and
  the D3D12 backend runs under Wine with vkd3d-proton; COM adds, releases and queries an `IUnknown`
  through the Win32 ABI in an executed case.
- Linux x86-64 emits DWARF `.debug_line` tables and typed locals (`.debug_info`, read back with
  `grail debug lines` and `grail debug info`) with `grail build --debug`; breakpoints, attach and
  DAP are not implemented. `grail profile` samples a Linux x86-64 program's own runtime with
  `ITIMER_PROF` and attributes samples to functions without `perf` or a debug section, and the
  language server `tools/lsp/main.grl` gives editors compiler-sourced diagnostics and same-file
  definitions. The `sys_grail` wrappers over the Linux ABI (files, clocks, environment, loopback
  TCP) are on `main`.
- The optimizer is a per-function pass (slot forwarding, dead-code removal, callee-saved register
  promotion, branch fusion); there is no general inlining or loop optimization yet. Every build
  reads all input files and emits one assembly file. `grail build --split` cuts the finished stream
  at module boundaries and links one object per module (Linux x86-64, without `--debug` or the LLVM
  backend) without changing the code; separate compilation with checked module interfaces is
  designed, not implemented. Implicit module loading, general async/await syntax and a general trait
  system are not covered here; structured tasks, cancellation and suspending green-task I/O are
  described in the concurrency chapter.
- Abort paths, including failed assertions and `!` on an error, do not unwind or run normal cleanup.
- Borrow checking intentionally rejects some valid programs. Whole-frame guards, weak updates
  and opaque external invariant boundaries are conservative.
- The Grail-written unsafe runtime and compiler intrinsics form a trusted boundary. The rejection
  tests and self-compilation checks are not a proof of language or machine-code soundness.
- The Grail-written compiler is authoritative. Only generated assembly bootstraps are retained;
  the duplicate Rust seed and unchecked C compiler have been removed.

## Not implemented yet

- Closing over a struct or enum that merely holds a borrow; capture the reference itself instead.

Indexed map assignment currently updates a named map or a field path only; a temporary receiver or a
nested target such as `nested["a"]["b"] = 1` is rejected. Map iteration only borrows the map, so
`for key, value in map` over an owned map is refused: write `&map`.

Tail-expression returns are deliberately absent, not pending.

## Where to go next

Read `compiler/NATIVE.md` for native bootstrap reproduction and implementation boundaries,
`compiler/tests/` for larger executable regressions, and `docs/design/` for research and proposals.
Design sketches may describe things the current compiler does not implement.

**Try it:** add an owned temporary before each early exit in a small program. Run the book checks
and the native conformance test to keep cleanup and ownership behavior observable.

Temporary owned arguments to a method expression statement end with that statement. Named owners
still follow lexical cleanup, including early returns and loop exits.
