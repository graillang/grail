
## Unsafe code: raw pointers

`unsafe { ... }` is the hatch for work the checker cannot follow. It already gated foreign calls
and the C pointer builtins; it now also gates raw pointers, `*T` and `*mut T`.

A raw pointer is one word, `Copy`, and drops nothing. It is written `*T` or `*mut T`, and `**T` is a
pointer to a pointer. The type can be spelled anywhere - a parameter, a field, a return - but every
operation on it needs an `unsafe` block, and each one is refused by name outside one:

```grl
fn main() {
    mut x: u64 = 41;
    unsafe {
        p := ptr_of(&mut x);     // *mut u64: the address a reference already carries
        p.write(p.read() + 1);
        q := alloc(u64, 4);      // *mut u64 over four zeroed elements
        q.add(1).write(9);       // steps by the element width
        println(q.add(1).read());
        free(q);
    }
    println(x);                  // 42
}
```

| operation | what it is |
| --- | --- |
| `ptr_of(&x)` / `ptr_of(&mut x)` | `*T` / `*mut T`: the address of the slot holding the value |
| `alloc(T, n)` | `*mut T` over `n` zeroed elements; `free(p)` releases it |
| `p.addr()` / `ptr_from_addr(T, a)` | the address as a `u64`, and a `*mut T` at one |
| `p.add(n)` / `p.sub(n)` | step by the element width: the natural width of a sized integer, f32 and f64, one word for everything else |
| `p.read()` / `p.write(v)` | load and store at that width; `write` needs `*mut T` |
| `p.is_null()` / `p.cast(U)` | the null pointer, and the same address as `*U` |

`p.read()` on an owned value duplicates ownership and `p.write(v)` moves `v` in without dropping
what was there - the same contract as Rust's `ptr::read` and `ptr::write`. A pointer also pins what
it names: a pointer made from a reference keeps that reference's loan for the rest of the function,
so the storage cannot be moved or freed underneath it. A record holding a raw pointer is
thread-affine, so it cannot cross to another thread.

### Handing a borrow back out

`p.as_ref()` and `p.as_mut()` turn a pointer into a reference again. They may only be the *returned*
value of a function whose result is a reference of the same type, because that result is what names
the lifetime the borrow gets:

```grl
unsafe fn value_of<a>(p: *mut u64, anchor: &a u64) -> &a u64 {
    return p.as_ref();
}
```

The pointer is the assertion that the storage there holds the pointee; the region comes from the
declared result, so the caller's borrow checking still applies (here the reference lives no longer
than `anchor`). `as_mut` gives `&mut T`, needs a `*mut T`, and the result must be `&mut T`. Used
anywhere else - a binding, an argument, a longer chain - both are refused by name.

### `unsafe fn`

A function whose contract the checker cannot see is declared `unsafe fn`. Its body sits one level
down, so it needs no inner `unsafe` block, and every call from safe code must be inside one:

```grl
unsafe fn bump(p: *mut u64) -> u64 {
    q := p.read() + 1;      // no inner `unsafe` needed
    p.write(q);
    return q;
}

fn main() {
    mut x: u64 = 41;
    unsafe { println(bump(ptr_of(&mut x))); }   // 42
}
```

### Audited records

A record that holds a raw pointer (or other foreign state) is thread-affine, which is the right
default but wrong for a type that is *designed* to be shared. `unsafe struct` states the audited
contract where the type is declared:

```grl
unsafe struct Arcish<T>: transferable, shareable {
    p: *mut T,
    n: u64
}
```

The classification takes `unsafe` on purpose - a plain `struct` cannot claim one - and only a struct
can take it (`shareable` implies `transferable`). The type arguments must still classify, as Rust
requires of `unsafe impl<T: Send + Sync>`: `Arcish<Handle>` is accepted only for handles that are
safe to move and to share. What the declaration buys is the walk of the fields skipped; what it does
not buy is anything the foreign code itself does behind that pointer.



Owned values are released deterministically on normal control flow. You usually do not write
`drop`; an explicit drop simply requests an earlier end when no live borrow prevents it.

{{example:cleanup}}

Generated cleanup handles scope exits, partial moves, active enum payloads, vector elements,
early returns, propagation and loop transfers. Native programs check for zero live runtime
allocations at normal exit. This is not a guarantee about resident memory: the allocator caches
small slabs for reuse, while large single-object arenas are released immediately.

## Cleanup you can write: `impl Drop`

A type's fields say what it holds. A type that owns something its fields do not describe - a count in
someone else's memory, a resource a foreign library handed out - says so itself, with Rust's `Drop`:

```grl
struct Session {
    id: u64,
    tags: string
}
impl Drop for Session {
    fn drop(self: &mut Session) {
        println("closing session {} ({})", self.id, self.tags);
    }
}
```

`Drop` is a built-in interface, like `Send` and `Share`: the name is reserved, nothing imports it, and
`fn drop(self: &mut Self)` is its only method. An implementation that does not have that shape is
refused at the `impl`, and so is one for a type declared in another module.

The method runs at the head of the cleanup the compiler generates anyway, before the fields are
released, and the fields are released afterwards exactly as they would be without it. The order is
fixed:

```grl
fn main() {
    s := Session { id: 7, tags: "beta" };
    println("work");
    drop(s);                 // ends the storage now, not at the end of the scope
    println("done");
}
```

- a value's own `drop` first, then its fields in declaration order;
- a scope's locals in reverse declaration order;
- vector elements front to back; an interface object's `drop` goes through its vtable to the same
  helper, so a `dyn` carrying the value runs it too.

`drop` is the compiler's to call, so `x.drop()` is refused by name: the call belongs to the glue, and
`drop(x)` is how a program ends a value's storage early. A value that implements `Drop` is also
opaque to partial moves, as in Rust: a field cannot be taken out of an owned value of that type, and
`match p { Session { .. } => ... }` cannot take it apart, because the fields the glue would walk
afterwards are no longer there. `match &p { Session { .. } => ... }` binds them as references and is
fine.

Generic code inherits the hook: `impl<T> Drop for Holder<T>` runs for every `Holder<U>` that is
dropped, because each instantiation's glue calls that instantiation's `drop`.

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
