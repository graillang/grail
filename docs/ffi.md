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

## Supported types (increment 1)

| Grail type | C type | Argument words |
| --- | --- | --- |
| `i64` | `int64_t` / `long long` / `ssize_t` | one 64-bit integer register |
| `u64` | `uint64_t` / `size_t` / `unsigned long long` | one 64-bit integer register |
| `&[u8]` (parameter) | `const uint8_t *, size_t` | two: pointer then length |
| `&mut [u8]` (parameter) | `uint8_t *, size_t` | two: pointer then length |
| `CStr` | `const char *` (NUL-terminated) | one 64-bit pointer |
| `handle H` | an opaque C token (`uint64_t` by convention) | one 64-bit word |
| `unit` (result only) | `void` | result register ignored |

Results may be `i64`, `u64`, `unit`, `CStr` or a `handle`: one word each. A view is never
a result, because C cannot produce a Grail view record; a C function that fills a buffer
returns a length or status instead, and the Grail side re-slices.

Anything else — narrower integers, floats, `string`, references, records, closures — is
rejected with a diagnostic. Later increments widen this table; until they land, writing
`v: u32` is an error, not a silent 32-bit truncation.

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

### Opaque handles

`handle File;` declares a one-word opaque type for a C-owned resource. A handle can be
bound, passed to declarations, returned from them and compared by identity; it cannot be
constructed (`File {}` is an error), inspected, sized, borrowed as bytes or dropped. Zero
validity is the C library's convention, not the compiler's: ask the library for a validity
or status accessor rather than assuming a sentinel. Handles are not linear in this
increment: the compiler never frees one, so a program that opens a handle must call the
matching close/free declaration itself, and leaking one is an explicit leak rather than an
implicit close.

Argument and result registers are the C ABI's own, per target:

| Target | Integer arguments (up to six) | Result | Call |
| --- | --- | --- | --- |
| x86-64 (SysV) | `rdi, rsi, rdx, rcx, r8, r9` | `rax` | `call SYMBOL` |
| AArch64 (AAPCS64) | `x0, x1, x2, x3, x4, x5` | `x0` | `bl SYMBOL` |
| RISC-V 64 (LP64) | `a0, a1, a2, a3, a4, a5` | `a0` | `call SYMBOL` |

These are the same registers Grail already uses for its own calls, so a foreign call is
a direct symbol call with the same argument/result plumbing. Frames stay 16-byte aligned
at call sites, and generated Grail functions preserve the callee-saved registers they
allocate (the internal prologue saves and restores them), which is what makes callbacks
implementable in a later increment.

More than six arguments is rejected: Grail has no stack-argument passing yet, and the
compiler will not silently drop the seventh argument.

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
  never implicitly frees a value produced by C. Ownership transfers only where an
  increment says so explicitly (handles and views, later increments).
- Allocator rule: memory allocated on the C side is released on the C side; memory
  allocated by the Grail runtime is released by the Grail runtime. A program that hands
  a Grail-owned pointer to C must never free it in C, and vice versa.
- Calls return exactly the C-visible integer. Nothing synthesises, reads or clears
  `errno`; a runtime that wants error detail exposes its own accessor as a declaration
  (for example an error-code out-parameter), and that accessor's semantics are the
  runtime's, not the compiler's.

## Limits (explicit, increment 1)

Not implemented yet, and each rejected rather than approximated:

- narrower integer widths (`i8`/`i16`/`i32`/`u8`/`u16`/`u32`) and sign/zero extension at
  the boundary;
- floating-point arguments and results (`xmm0-7` / `v0-7` / `fa0-7` and the SysV SSE
  classification);
- `extern record` C layout and records crossing by value or reference;
- callbacks, function pointers, and taking the address of a foreign declaration
  (`f := c_add;` is rejected: a C declaration is not a Grail function value);
- by-value struct arguments/results (including SysV eightbyte classification and
  `sret`), and stack-passed arguments beyond six;
- dynamic library loading (`dlopen`/`dlsym` hooks);
- variadic C functions.

## Tests

`bun tools/test-ffi.mjs` (or `just test-ffi`) compiles `tests/ffi/shim.c` for each target,
compiles `tests/ffi/call_scalars.grl` with the FFI build, links the two through the
`// grail-link:` request, and checks:

- exactly one deduplicated link note for six declarations using the same input;
- unmangled calls to `c_add`, `c_mul` (renamed with `as`), `c_identity`, `c_sum4` and
  `c_choose` in the generated assembly;
- the object references the C symbol but does not define it;
- the linked executables run and return the expected values — `call_scalars` checks the
  six-argument call, the `as` rename and `u64` results (`83`, `7`), `views_handles` checks
  a NUL-terminated `CStr`, a read-only view, a mutable view written by C, and a handle
  round trip (`259`, `1`) — executed on the host, and on a cross target when
  `qemu-<target>-static` is installed; otherwise the cross targets are linked and the
  ABI-level check is reported as link-only.

Rejections are part of the normal native corpus (`tests/native-cases.json`):
`ffi-reject-safe-call`, `ffi-reject-abi`, `ffi-reject-parameter-width`,
`ffi-reject-result-type`, `ffi-reject-arity` and `ffi-reject-duplicate`, so every target
checks the diagnostics on every run of `bun tools/test-native.mjs`.
