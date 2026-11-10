# v3 C ABI / FFI boundary

Grail calls foreign C code directly: `extern "C"` declarations name a symbol the host
linker resolves, and calls are emitted with the C calling convention of the selected
target. There is no C source generation, JIT, wrapper layer or libc requirement: a
program may link a freestanding C object and still be a static Grail executable.

This page is the contract. It is deliberately narrow, and every unsupported case is a
compile error rather than a silent coercion or truncation.

## Declaration syntax

```grl
extern "C" lib "shim.o" fn c_add(a: i64, b: i64) -> i64;
extern "C" lib "shim.o" as "c_mul" fn scale(a: i64, b: i64) -> i64;
extern "C" fn c_identity(v: u64) -> u64;
```

- The ABI name is required and must be exactly `"C"`. Any other name is rejected; there
  is no fallback convention.
- `lib "INPUT"` names one link input for this declaration. The compiler deduplicates the
  inputs in declaration order and emits them as leading `// grail-link: INPUT` lines in
  the generated assembly. Build tooling (`tools/native.mjs`, `grail build`) obeys those
  lines: a relative `*.o`/`*.a`/`*.so` input resolves against the declaring source file,
  a bare name becomes `-lNAME`, and anything starting with `-` or `/` passes through.
  Linker inputs are the compiler's statement of what it needs; no other component guesses
  them.
- `as "SYMBOL"` renames the linker symbol without renaming the Grail function. Without it
  the C symbol is the Grail declaration name, unmangled (`call c_add`, not
  `f_module_c_add`).
- A declaration has no body and is not a definition. It is callable from any file in the
  same module.

## Supported types

| Grail type | C type | Argument words |
| --- | --- | --- |
| `i64` | `int64_t` / `long long` / `ssize_t` | one 64-bit integer register |
| `u64` | `uint64_t` / `size_t` / `unsigned long long` | one 64-bit integer register |
| `i8`..`i32`, `u8`..`u32` | the C integer of that width | one integer register (narrowed/extended per ABI) |
| `f64` / `f32` | `double` / `float` | one float register (see the calling conventions) |
| `&[u8]` (parameter) | `const uint8_t *, size_t` | two: pointer then length |
| `&mut [u8]` (parameter) | `uint8_t *, size_t` | two: pointer then length |
| `CStr` | `const char *` (NUL-terminated) | one 64-bit pointer |
| `CPtr` / `CMutPtr` | `const void *` / `void *` | one 64-bit pointer |
| `handle H` | an opaque C token (`uint64_t` by convention) | one 64-bit word |
| `cfn(P...) -> R` | `R (*)(P...)` | one 64-bit code address |
| `&mut H` (parameter, `H` a `handle`, `CPtr` or `CMutPtr`) | `H *` / `void **`: a slot the callee writes | one 64-bit pointer |
| `extern "C" record R` (parameter) | `R *`, the address of the struct's fields | one 64-bit pointer |
| `extern "C" record R` (result) | `R`, returned by value per the target ABI | registers or a hidden result pointer |
| `unit` (result only) | `void` | result register ignored |

Results may be any of the scalar types above, `CStr`, `CPtr`/`CMutPtr`, a `handle`, a `cfn`, or an
extern record by value. A view is never a result, because C cannot produce a Grail view record; a
C function that fills a buffer returns a length or status instead, and the Grail side re-slices.

Anything else — `string`, any other reference shape, plain (non-`extern "C"`) records, closures —
is rejected with a diagnostic. The remaining gaps are listed under Limits.

### Bare data pointers

Many C APIs take a buffer as a lone pointer, with its size implied or passed elsewhere (keys,
nonces and output buffers in libsodium, `pData` in Vulkan create-info structs). `CPtr` is a
`const void *` and `CMutPtr` a `void *`; both are one word and may be parameters, results and
extern-record fields:

```grail
extern "C" lib "sodium" fn crypto_hash_sha256(out: CMutPtr, input: &[u8]) -> i32;

fn digest<a>(input: &a [u8]) -> u8[] {
    mut out = u8[];
    for i in 32 {
        out.push(0);
    }
    unsafe {
        crypto_hash_sha256(cptr_mut(&mut out), input);
    }
    return out;
}
```

- `unsafe cptr(bytes)` takes the data pointer of a byte sequence or view; `unsafe cptr_mut(&mut
  bytes)` requires write access (a mutable sequence or `&mut [u8]`), and C's writes are visible
  in the Grail bytes afterwards. `cnull()` is the null pointer, for optional parameters.
- Both are `unsafe` for the same reason as `cstr`: the pointer carries no length or lifetime,
  so C may read or write past the bytes, or keep the pointer after Grail frees them. The Grail
  side stays responsible for passing a buffer of the size C expects.
- The bytes stay owned by Grail and alive until the end of the statement that made the pointer.

### Byte views

A `&[u8]` parameter crosses as the C pair `(const uint8_t *, size_t)`, and `&mut [u8]`
as `(uint8_t *, size_t)`. The pointer and the length come from the view's own record, so
no copy and no temporary buffer are created, and an owned `u8[]`/`string` argument
auto-borrows to the view exactly as it does for a Grail call. A view argument is a borrow
for the duration of the call: C must not retain the pointer, and the same value cannot be
mutably borrowed elsewhere in the same expression.

### C strings

`CStr` is a one-word `const char *`. It is produced by `unsafe cstr(value)` where `value`
is a byte sequence or view whose last byte is NUL: the cast is zero-copy and checks the
terminator at runtime (a non-terminated sequence aborts). It is `unsafe` because the
pointer has no lifetime tracking across the call: C may keep it, and the bytes stay owned
by Grail.

### Callbacks and function pointers

A Grail function can be handed to C and called back:

```grl
extern "C" fn c_double(v: i64) -> i64 {
    return v * 2;
}
extern "C" as "c_triple" fn triple(v: i64) -> i64 {
    return v * 3;
}
extern "C" fn c_apply(callback: cfn(i64) -> i64, value: i64) -> i64;
```

- `extern "C" fn name(params) -> result { ... }` is a *definition*, not a declaration:
  the body is ordinary Grail, but the function is emitted with the stated C symbol
  (`as "name"` renames it, otherwise the Grail name is the symbol) and every parameter
  and the result must sit inside the C ABI slice. That is what makes it C-callable.
- `cfn(P...) -> R` is the type of a C function pointer: one word, no environment, called
  with the C ABI. Only `extern "C"` definitions have such a value, so a closure or an
  ordinary Grail function is a type mismatch where a `cfn` is expected — there is no way
  to hand C an address it cannot call.
- Taking the address of an `extern "C"` *declaration* (no body) is still rejected: that
  is a symbol C owns, not a Grail value.
- Generated code preserves the callee-saved registers it allocates and keeps the frame
  16-byte aligned at every call, which is what lets C call back into it.
  `tests/ffi/callbacks.grl` calls two callbacks through C, and the shim clobbers
  `rbx`/`r12`-`r15` around one of them to prove the C ABI contract holds.
- The callback's parameter types are a promise the compiler cannot verify against the
  actual C function-pointer type (a function pointer carries no signature at run time),
  so the declaration and the C prototype must agree; a mismatch is an ABI bug the
  compiler cannot catch.

### C-layout records

```grl
extern "C" record Mixed { a: i32, b: i16, c: i8, d: i64 }

extern "C" fn c_mixed_fill(m: Mixed, d: i64) -> i64;
```

`extern "C" record` matches a C `struct` exactly:

- fields are laid out with C rules — natural alignment, padding between fields, and tail
  padding up to the record alignment — so `offsetof` agrees with the C compiler
  (`a: i32, b: i16, c: i8, d: i64` is `0, 4, 6, 8`, size 16, alignment 8);
- a field may be an 8/16/32/64-bit integer, an `f32`/`f64`, a `handle`, a `CStr` or another
  `extern "C" record`, which is embedded by value: its bytes sit at the field's C offset with
  its own alignment and size, exactly like a C struct member. Anything else (an ordinary Grail
  record, a `string`, a view) is rejected, because those values are pointers and embedding one
  would store the pointer, not the bytes;
- an embedded record is plain data inside its container: `o.inner.x` reads and `o.inner.x = v`
  writes in place, `o.inner = r` copies `r`'s bytes over the embedded ones (and releases `r`),
  and `v := o.inner` copies the bytes out into an independent record. Drop glue frees only the
  outer buffer (`tests/ffi/nested_records.grl`);
- field reads and writes use the field's own width, so `i8`/`i16`/`i32` values are
  truncated on store and sign- or zero-extended on load. Sub-word access is implemented
  with portable byte-wise runtime helpers, so all three targets share one implementation
  (`rt_load_sized`/`rt_store_sized`);
- a record *parameter* is passed as the address of the struct's fields, i.e. the C
  `R *`. The call borrows the record for its duration: Grail keeps ownership of the
  allocation and frees it at the end of the Grail scope, so C must not free or retain it;
- record construction allocates the C size rounded up to whole eight-byte words, and the
  drop path frees exactly that allocation.

Verified by `tests/ffi/extern_records.grl`: the C shim reads fields Grail wrote, writes
fields Grail reads back, and checks its own `offsetof`/`sizeof` values.

### Opaque handles

`handle File;` declares a one-word opaque type for a C-owned resource. A handle can be
bound, passed to declarations, returned from them and compared by identity; it cannot be
constructed (`File {}` is an error), inspected, sized, borrowed as bytes or dropped. Zero
validity is the C library's convention, not the compiler's: ask the library for a validity
or status accessor rather than assuming a sentinel. Handles are not linear in this
increment: the compiler never frees one, so a program that opens a handle must call the
matching close/free declaration itself, and leaking one is an explicit leak rather than an
implicit close.

### Out-parameters

A C function sometimes cannot return the object it creates: `vkCreateInstance(..., VkInstance
*pInstance)` writes the new instance through a slot the caller passes, and so do the D3D12 and Metal
create functions. A declaration spells that slot as a mutable borrow of a handle or bare pointer
binding, and the call passes `&mut` of it:

```grail
handle Instance;

extern "C" lib "shim.o" fn c_create(info: CMutPtr, slot: &mut Instance) -> i32;

fn main() -> u64 {
    mut instance: Instance;
    unsafe {
        c_create(cnull(), &mut instance);
    }
    return 0;
}
```

- The parameter is the C `H *` / `void **`: one word, the address of the binding's own slot. The
  callee writes the word; Grail reads the binding afterwards, and no cast or accessor is needed.
- `&mut` is required. `&H` would be the C `const H *`, which C cannot store through, and is refused
  with `an extern C out-parameter needs &mut; a shared &H is the C const pointer`.
- Only `handle`, `CPtr` and `CMutPtr` bindings are out-parameter slots. Every other reference shape
  — `&mut i64`, `&mut SomeRecord`, `&mut string` — is refused with
  `an extern C out-parameter must be &mut a handle, CPtr or CMutPtr`.
- **The initial value is defined.** A handle or bare pointer binding declared without an
  initializer is null, not uninitialized (`mut instance: Instance;`), so the callee always reads a
  defined word even if it only writes. A binding that already holds a value keeps it, so a second
  call sees what the first one wrote; that is also how a slot is seeded. No other type is
  null-initialized this way: a record or integer binding without an initializer is still
  uninitialized and still rejected where it is used.
- The slot is an ordinary mutable borrow. The same binding cannot be handed to one call twice
  (`borrow conflicts with active access`), and nothing may read or write it while the call runs.
- The borrow is call-scoped, like a view: the write is visible after the call, and the callee must
  not keep the pointer. The call still sits inside an `unsafe` block.
- Only a declaration Grail calls can take one. An `extern "C" fn` *definition* (a C callback) and a
  `cfn` type declaring `&mut H` are refused by name, because Grail has no deref-assignment: a
  callback could not store through the pointer C handed it.
- A handle cannot be constructed at all, not even as null from Grail (`cnull()` is a `CPtr`, and
  `Slot { instance: cnull() }` is a type mismatch), so a declaration's out-parameter is the way to
  obtain one. `tests/ffi/out_params.grl` executes it on x86-64, AArch64 and RISC-V 64: every C twin
  returns a checksum that reads the slot before writing it, so a slot passed by value, an
  uninitialized slot, or a write Grail does not see all change the printed values.

Argument and result registers are the C ABI's own, per target:

| Target | Integer arguments | Result | Call |
| --- | --- | --- | --- |
| x86-64 (SysV) | `rdi, rsi, rdx, rcx, r8, r9`, then the outgoing stack | `rax` | `call SYMBOL` |
| AArch64 (AAPCS64) | `x0`-`x7`, then the outgoing stack | `x0` | `bl SYMBOL` |
| RISC-V 64 (LP64) | `a0`-`a7`, then the outgoing stack | `a0` | `call SYMBOL` |

So a call takes six word arguments in registers on x86-64 and eight on AArch64 and RISC-V 64; every
further word is an eight-byte outgoing stack slot (Win64: four registers, a 32-byte home area, then
slots). Six is not a compiler limit and no compiler limit has replaced it: a declaration may carry up
to 64 argument words and the outgoing stack area is limited to 2 KiB. `tests/ffi/call_words.grl`
executes calls of seven, eight and nine words, with both literal and computed arguments, on all three
targets.

The result register is `rax`/`x0`/`a0` on all three. A foreign call is a direct symbol call with the
same argument/result plumbing as a Grail call. Frames stay 16-byte aligned at call sites, and
generated Grail functions preserve the callee-saved registers they allocate (the internal prologue
saves and restores them), which is what lets C call back into an `extern "C"` definition.

The reverse direction — C calling a Grail callback — reads parameters from the register file only,
because there is no caller frame to read stack arguments from (on Win64 a thunk under the C symbol
moves the four registers and the fifth and sixth stack words into Grail's registers, and no further).
An exported callback may therefore use up to six integer argument words on x86-64 and Windows, and up
to eight on AArch64 and RISC-V 64, plus up to eight floating-point arguments. A longer parameter list
is refused by name rather than read from a register that holds something else:
`a C callback cannot read that many integer argument words`.

## The unsafe boundary

Every foreign call must sit inside an `unsafe { ... }` block:

```grl
fn main() -> u64 {
    mut sum: i64 = 0;
    unsafe {
        sum = c_add(19, 23);
    }
    println(sum);
    return 0;
}
```

A call outside such a block is a compile error: `extern C call requires an unsafe
block`. `unsafe` is lexical and checked — it is the explicit marker that this call has
obligations the compiler cannot verify (the C function may do anything with its
arguments). It does not disable move, drop, borrow or lifetime checking inside the
block. Declarations themselves may be written at module scope without an `unsafe`
marker; it is the call that crosses the boundary.

## Ownership across the boundary

- Values crossing into C by value are passed as scalars or pointer/length pairs; no
  Grail storage is moved or cleaned up by the call, and no hidden allocation or copy is
  performed. Byte views are call-scoped borrows; `CStr` and `handle` are opaque one-word
  tokens that the compiler never frees.
- A foreign call never implicitly frees, copies or retains a Grail argument, and Grail
  never implicitly frees a value produced by C. Views are call-scoped borrows and handles are
  C-owned tokens; no ownership changes hands implicitly.
- Allocator rule: memory allocated on the C side is released on the C side; memory
  allocated by the Grail runtime is released by the Grail runtime. A program that hands
  a Grail-owned pointer to C must never free it in C, and vice versa.
- Calls return exactly the C-visible integer. Nothing synthesises, reads or clears
  `errno`; a runtime that wants error detail exposes its own accessor as a declaration
  (for example an error-code out-parameter), and that accessor's semantics are the
  runtime's, not the compiler's.

## Abort and unwinding across the boundary

**Abort never unwinds, and nothing may unwind across the C boundary.** A checked-arithmetic
failure, an index bound, a failed `!`, a failed `assert` or an explicit abort ends the process on
the spot. That is also true when the abort happens inside a Grail callback that C called: control
never returns into the foreign frame, no C++ destructor, `atexit` handler or DLL detach runs, and
the parent sees a SIGABRT (exit status 134 when a signal handler is installed or on Windows). The
one-line rationale: Grail has no unwinding machinery, so a half-unwound stack would leave every
live owner in an unknown state.

- `rt_abort` sends SIGABRT on POSIX, then calls the platform's cleanup-free exit: `exit_group` on
  Linux, `TerminateProcess` on Windows, `_exit` on macOS. `exit(2)` and `ExitProcess` are never on
  this path, because they run foreign cleanup; `exit(2)` would also end only the calling thread.
- Foreign code that installs a SIGABRT handler cannot change this: the handler runs, returns, and
  the abort still exits the process. There is no supported way to catch a Grail abort in C.
- A `defer`/scope cleanup inside the aborting Grail frame does not run either. Cleanup is for
  ordinary return, error propagation and structured scope exit, not for abort.

## Blocking foreign calls

**A foreign call blocks the executing task thread.** On Linux that thread is a worker of the green
task pool, so while the call blocks, that worker runs no other task; with more blocking tasks than
workers, the extra tasks wait. Only the runtime's own blocking operations hand off to a dedicated
thread: `host::read_file`, `host::write_file` and `host::command`, and only when they are called
from a green task. `host::pipe` reads and writes wait on the readiness reactor, and
`host::sleep_ms` uses a timer, so those suspend instead of blocking.

- An `extern "C"` call, or a call through a `cfn` value, is not wrapped by the compiler: it runs on
  the calling task's thread and blocks it for as long as the C function runs. Nothing in the
  scheduler preempts it or moves the task to another thread.
- A wrapper that knows its call blocks declares it with the runtime hook
  `rt_blocking_enter()` (in `unsafe module runtime`), immediately before the call. The runtime then
  emits one warning per process on stderr naming this contract, the documentation and the way out,
  so a program cannot quietly lose a worker. Nothing warns for an undeclared call, because the
  compiler does not wrap call sites.
- The way out is the documented handoff: `rt_blocking_call(f, a, b)` runs `f(a, b)` on a dedicated
  OS thread and suspends the task, so the worker stays available. That is exactly what
  `host::read_file`, `host::write_file` and `host::command` do.
- On Windows a task is an OS thread (see `concurrency-v1.md`), so a blocking foreign call blocks
  only the task that made it and no handoff is needed.

## Direct calls: calling conventions

A direct call to an `extern "C"` declaration is lowered per platform convention:

| Target | Integer registers | Float registers | Stack |
| --- | --- | --- | --- |
| Linux/macOS x86-64 (SysV) | `rdi rsi rdx rcx r8 r9` | `xmm0`-`xmm7` | 8-byte slots after the registers |
| Windows x86-64 (Win64) | `rcx rdx r8 r9`, by position | `xmm0`-`xmm3`, by position | 32-byte register home area, then slots from the fifth argument |
| AArch64 (Linux, macOS, Windows) | `x0`-`x7` | `d0`-`d7` / `s0`-`s7` | 8-byte slots |
| RISC-V 64 (LP64D) | `a0`-`a7` | `fa0`-`fa7`, then integer registers | 8-byte slots |

Parameters and results of direct calls may be `f64` and `f32` (an `f32` crosses as a real
binary32: narrowed on the way in, widened on the way out), and `i8`..`i32`/`u8`..`u32` (Grail keeps
them sign- or zero-extended in a word, so they pass as is; results are re-extended after the
call because C leaves the upper bits unspecified; RV64 receives `u32` sign-extended as its ABI
requires). Up to 64 argument words are accepted and the outgoing stack area is limited to 2 KiB.
On macOS arm64, which packs stack arguments by size, a narrow or `f32` argument that would land
on the stack is refused. RISC-V objects use the hard-float `lp64d` ABI, which Linux C libraries
use. `tests/ffi/call_abi.grl` executes on x86-64, AArch64 and RISC-V Linux and, through
`tests/windows-cases.json`, on Windows x86-64 under Wine; Windows ARM64 is checked statically.

## Limits

Not implemented yet, and each rejected rather than approximated:

- C-callable callbacks that need more integer argument words than the target passes in registers (six
  on x86-64, eight on AArch64 and RISC-V 64): the callback prologue has no caller frame to read stack
  arguments from, so a longer parameter list is refused by name; macOS callbacks use the same
  SysV/AAPCS64 lowering but are compiled and linked only (no macOS runner);
- an out-parameter on a C callback or a `cfn` type: only a declaration Grail calls can write a slot
  (see Out-parameters above);
- records *passed* by value as arguments (an extern record parameter is the C `R *`; the spelling
  `v: byval R` is decided - see [B7](design/decisions-b2-b6.md#b7-byval-record-parameters-accepted) -
  and implementation follows the separate-compilation work); record
  results are returned by value on every ABI, float fields included
  (`tests/ffi/call_records.grl`, `float_record_results.grl`), and nested records included,
  except a result whose embedded records contain floats (its register classification needs the
  flattened field list; refused with a diagnostic);
- variadic callbacks, callback results that are themselves function pointers, and
  taking the address of a foreign *declaration* (`f := c_add;` is rejected: a C
  declaration is not a Grail function value);
- dynamic loading on macOS (Linux uses the TLS bridge below on all three architectures;
  Windows x86-64 needs none, since `LoadLibraryA`/`GetProcAddress` are ordinary imports and the
  runtime does not own the TEB), and foreign calls or callbacks on threads other than the main
  thread on Linux;

## Dynamic loading and the host TLS bridge

The platform loader is reached through ordinary C declarations; no builtin is involved.
A loader handle is an opaque `handle`, and `dlsym` is declared once per signature with
`as "dlsym"` so the returned address is typed as the `cfn` it will be called through:

```grail
handle Library;
extern "C" lib "c" fn dlopen(path: CStr, mode: i64) -> Library;
extern "C" lib "c" as "dlsym" fn dlsym2(library: Library, symbol: CStr) -> cfn(i64, i64) -> i64;
extern "C" lib "c" fn dlclose(library: Library) -> i64;
```

A `cfn` result is accepted from an extern declaration, and a `cfn` local or capture is
callable with the C ABI. Linking any `lib` input now produces a dynamically linked
executable with the host loader.

The Grail runtime installs its worker record as the thread pointer (x86-64 FS base through
`arch_prctl(ARCH_SET_FS)`, AArch64 `tpidr_el0`, RISC-V `tp`), which is also where glibc keeps
its TCB (errno, malloc tcache, stack guard). On Linux the compiler therefore bridges the two
(x86-64 switches with `arch_prctl`; AArch64 and RISC-V write the register directly):

- `_start` records the loader's FS base in `rt_host_tls` before `rt_thread_init` installs
  Grail's record, which is also recorded in `rt_grail_tls`;
- every `extern "C"` call saves the current FS base, switches to `rt_host_tls`, makes the
  call and restores the saved base;
- every exported `extern "C" fn` (a callback entry) saves the caller's FS base, switches to
  `rt_grail_tls`, and restores the caller's base on every return path.

Both bases are process-wide, so foreign calls and callbacks are only valid on the main thread
(a worker or green-task call that touches libc state shares the main thread's TCB; see
[B3](design/decisions-b2-b6.md#b3-foreign-calls-block-the-executing-thread)): threads created by the
Grail runtime have no libc TCB, and a callback arriving on a foreign thread would share the main
thread's worker record. On x86-64 each switch is an
`arch_prctl` system call; on AArch64 and RISC-V it is a register write. `tests/ffi/dlopen.grl` loads `libdlshim.so`, calls two resolved
functions, passes a Grail callback that itself calls `strlen`, and closes the library
(42, 42, 42, 0) with the runtime initialized. On AArch64 and RISC-V 64 it runs under qemu when
a glibc sysroot is supplied: `GRAIL_SYSROOT_AARCH64` / `GRAIL_SYSROOT_RISCV64` point at a tree
with the target's `ld-linux-*.so.1`, `libc.so` and `libdl` (a Fedora-style `lib64` tree or a
Debian multiarch tree, e.g. the extracted `libc6` and `libc6-dev` packages); the cross link
then uses `--sysroot` and the target loader, and qemu runs with `-L sysroot`. Without one the
fixture is cross-compiled only. The loader functions are declared from `lib "dl"`: glibc before
2.34 keeps them in libdl, later versions in libc with libdl a stub.

## Tests

`bun tools/test-ffi.mjs` (or `just test-ffi`) compiles `tests/ffi/shim.c` for each target,
compiles `tests/ffi/call_scalars.grl` with the FFI build, links the two through the
`// grail-link:` request, and checks:

- exactly one deduplicated link note for six declarations using the same input;
- unmangled calls to `c_add`, `c_mul` (renamed with `as`), `c_identity`, `c_sum4` and
  `c_choose` in the generated assembly;
- the object references the C symbol but does not define it;
- the linked executables run and return the expected values. `call_scalars` checks the six-argument
  call, the `as` rename and `u64` results (`83`, `7`), `views_handles` a NUL-terminated `CStr`, a
  read-only view, a mutable view written by C and a handle round trip (`259`, `1`), `callbacks` C
  calling back into Grail including callee-saved register preservation (`42`, `42`, `10`),
  `extern_records` C layout in both directions (`1606`, `23`, `16`, `-2`, `7`), `out_params` the
  out-parameter slots including a seventh-argument slot and two slots in one call, and `call_words`
  seven, eight and nine word arguments with literal and computed values.
- the suite executes every fixture on x86-64 and, through `qemu-<target>-static`, on AArch64 and
  RISC-V 64: 51 executed fixture instances and no link-only cases, plus two cross-compiled-only ones
  (`dlopen`, which needs a target glibc sysroot). `callback_words` executes the eight-register
  callback on AArch64 and RISC-V 64 and asserts that x86-64 and Windows refuse it by name. Without a
  qemu runner the cross targets are linked and the ABI-level check is reported as link-only.

Rejections are part of the normal native corpus (`tests/native-cases.json`):
`ffi-reject-safe-call`, `ffi-reject-abi`, `ffi-reject-parameter-type`, `ffi-reject-result-type`,
`ffi-reject-arity`, `ffi-reject-duplicate`, `ffi-reject-handle-out-slot`,
`ffi-reject-handle-null-seed`, `ffi-reject-out-shared-borrow`, `ffi-reject-out-scalar`,
`ffi-reject-out-callback`, `ffi-reject-out-cfn` and `ffi-reject-out-double-borrow`, so every target
checks the diagnostics on every run of `bun tools/test-native.mjs`.
