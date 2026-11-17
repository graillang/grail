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

`extern "C" lib "name";` with no declaration after it asks the linker for `name` and nothing else:
a module that binds a C++ shim states the C runtime the shim expects this way
(`abundance/src/imgui.grl`). On Windows, where an import names a symbol, it requests nothing.

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
| `&r` / `&mut r` with `cptr`/`cptr_mut` (`r` an extern record) | `const R *` / `R *` | one 64-bit pointer |
| `handle H` | an opaque C token (`uint64_t` by convention) | one 64-bit word |
| `cfn(P...) -> R` | `R (*)(P...)` | one 64-bit code address |
| `&mut H` (parameter, `H` a `handle`, `CPtr`, `CMutPtr` or an extern record) | `H *` / `void **` / `R *`: storage the callee writes | one 64-bit pointer |
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
- Both are `unsafe` for the same reason as `cstr`: the pointer carries no length, so C may read or
  write past the bytes, and nothing stops C from keeping it after the call. The Grail side stays
  responsible for passing a buffer of the size C expects.
- The bytes stay owned by Grail, and the pointer is a borrow of them for as long as it is live. That
  is the same rule as for a record address (see "Pointer lifetimes" below), so `cptr(&b)` kept in a
  binding forbids `b.push(...)` until the pointer's last use.

### Records by pointer

A C struct that *points at* another struct — `VkInstanceCreateInfo::pApplicationInfo`,
`VkRenderPassCreateInfo::pAttachments`, `VkPresentInfoKHR::pSwapchains` — needs the address of an
`extern "C"` record Grail owns. `cptr(&r)` is that address as a `CPtr`, and `cptr_mut(&mut r)` the
same address as a `CMutPtr`:

```grail
extern "C" record AppInfo { api_version: u32, flags: u32 }
extern "C" record CreateInfo { s_type: u32, pad: u32, p_app: CPtr, p_names: CPtr, count: u32 }
extern "C" lib "shim.o" fn c_create_info(info: CreateInfo) -> i64;

fn main() -> u64 {
    mut app = AppInfo { api_version: 5, flags: 0 };
    mut info = CreateInfo { s_type: 1, pad: 0, p_app: cnull(), p_names: cnull(), count: 7 };
    unsafe {
        info.p_app = cptr(&app);
    }
    mut created: i64 = 0;
    unsafe {
        created = c_create_info(info);
    }
    println(created); // 5 + 7 + 1
    return 0;
}
```

- The pointer is the address of the record's *own fields* — the pointer a record *parameter* already
  is — so `cptr(&r)` and passing `r` itself reach the same bytes. One pointer type does not replace
  the other: a record parameter stays the way to pass a struct to a call, and `cptr` is the way to
  *name* its address when it has to be stored in a field, kept in a binding or compared.
- Only an `extern "C"` record has a C layout to point at. `cptr(&plain_record)` is refused with
  `cptr takes the address of an extern "C" record; a Grail record has no C layout`.
- The record must be a name: `cptr(&AppInfo { ... })` is refused with `cptr needs a named record:
  the address of a temporary would not outlive the pointer`, because a temporary's storage is a
  binding nobody can see and its lifetime would be a guess the caller cannot check.
- The pointer is a borrow of the record, held for as long as the pointer is live (see "Pointer
  lifetimes" below). Within one call, `c_two(cptr(&r), cptr_mut(&mut r))` fails with `the value
  handed to C as a writable pointer is already borrowed in this expression`, and the
  read-only-then-writable order with `the value handed to C as a read-only pointer is already
  mutably borrowed in this expression`. `cptr_mut` also requires a mutable place, as `cptr_mut` of a
  byte sequence does.
- It is `unsafe` for the same reason as `cptr` of bytes: the pointer carries no length, and what C
  does with it is unchecked. Grail keeps ownership of the record and frees it at the end of the
  Grail scope, so C must not free it or keep it past the call.
- A field of an embedded record is interior storage, and its address is the `R *` a nested struct
  member has in C: `cptr(&pairs.first)` where `pairs` is a record of `RefPair` fields points into
  `pairs` at that element's offset. An array of structs is therefore a record of embedded records
  and needs no separate array type — the record's address *is* the array.

### Pointer lifetimes

A `CPtr`/`CMutPtr` made by `cptr`/`cptr_mut` from Grail storage (a named `extern "C"` record, a
field of one, a byte sequence or a view) holds the same loan a reference to that storage would. It
is checked with the ordinary ownership machinery and not with a separate one: the pointer value is a
holder of the loan, and the loan follows the pointer wherever the pointer goes.

- **Where the pointer lives.** It may live in a binding (`p := cptr(&r)`), in a copy of one
  (`q := p`), in a record field (`info.p_app = cptr(&app)`, or a field of a record literal), in a
  value read back out of that field, in a record the field's record was moved into, and in a
  closure that captured it. The borrow lasts until the last use of whichever of these is used last.
  Last use is what a reference has too: a pointer nobody reads again does not hold anything.
- **What it forbids while live.** The borrowed storage cannot be assigned, modified, moved or
  dropped. A `cptr_mut` pointer is the exclusive borrow, so the storage cannot be read through
  another path either. Each refusal names the storage, the binding holding the pointer and the
  `cptr` that made it:

  ```text
  cannot assign to `sub` while a C pointer to it is live in `p` (made by cptr at line 5)
  cannot modify `sub` while a C pointer to it is live in `p` (made by cptr at line 5)
  cannot move `sub` while a C pointer to it is live in `p` (made by cptr at line 5)
  cannot drop `b` while a C pointer to it is live in `p` (made by cptr at line 5)
  cannot use `sub` while a C pointer to it is live in `p` (made by cptr_mut at line 5)
  cannot borrow `sub` while a C pointer to it is live in `p` (made by cptr at line 5)
  ```

- **It cannot outlive the storage.** A pointer kept in something that outlives the storage fails
  where the storage ends, and a returned pointer, including one inside a returned record or a
  returned closure, fails at the `return`:

  ```text
  `app` goes out of scope while a C pointer to it is live in `info` (made by cptr at line 9)
  `app` goes out of scope while a C pointer to it is live in `*out` (made by cptr at line 2)
  cannot return a C pointer to `app`: the pointer would outlive it (made by cptr at line 3)
  ```

  A pointer into a borrowed parameter (`cptr(app)` for `app: &AppInfo`, `cptr(bytes)` for a view)
  carries the parameter's lifetime. It may live in locals for the whole call but may not be
  returned, because `CPtr` has no lifetime parameter to carry it out.
- **Grail calls are assumed to pass pointers on.** A Grail function's `CPtr` parameter is a plain
  word inside the callee, so the caller does the conservative thing: when an argument carries a C
  pointer, the call's result (if its type can hold one: a `CPtr`, a record or container with one
  inside, a closure) and the referent of every `&mut` argument whose type can hold one are taken
  to keep that pointer too. `fn keep(p: CPtr) -> CPtr { return p; }` therefore cannot launder a
  borrow, and neither can `fn put(out: &mut CreateInfo, p: CPtr)`.
- **C calls borrow, and C must not keep the pointer.** An `extern "C"` call that takes a `CPtr`, or
  a record whose fields hold one, borrows it for the duration of the call, the same as a record or
  view parameter. The declaration cannot say that C retains the pointer. A program whose C library
  does keep one (a callback's user data, a descriptor C reads later) must keep the storage alive
  itself, in a record whose scope encloses every call C makes with that pointer, and that is
  unchecked. A `CPtr` that C *returns* is C's pointer and carries no Grail borrow.

`tests/native-cases.json` (`ffi-reject-cptr-*`, `ffi-cptr-*`) has each refusal and each accepted
shape. `cptr` of a temporary is still refused outright (`cptr needs a named record`), because
nothing names its storage.

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

`unsafe cstr_bytes(s)` goes the other way: it copies the bytes of a C string - one C returned
(`SDL_GetError()`), or one Grail made - into a fresh `u8[]`, up to the NUL. A null `CStr` reads as
empty. It is `unsafe` because only C knows the string is terminated and alive for the copy; the
result is ordinary Grail bytes with no tie to C memory.

### C arrays

A C array is reached in one of two ways, and neither is pointer arithmetic: Grail code only ever
holds a vector with its own length and bounds checks.

**Inline in a record**: a field `f: [T; N]` is N elements of `T` laid out in place, exactly as the C
member `T f[N]` (size N * size of T, alignment of T). Grail code reads the field whole, as a fresh
vector of N elements (`T[]`; `[u8; N]` reads as the byte sequence `u8[]`), and assigns it whole
from a vector of exactly N elements - any other length aborts, since C reads all N:

```grl
extern "C" record PhysicalDeviceProperties { api_version: u32, device_type: u32, device_name: [u8; 256] }

name := props.device_name;        // 256 bytes, copied out
props.device_name = renamed;      // renamed.len() must be 256
println(props.device_name[0]);    // a chained read indexes the copy
```

An element may be an integer, `f32`/`f64`, a `handle`, `CStr`, `CPtr` or an `extern "C"` record. There
is no reference into the inline array (`&r.f` is rejected): a reference would let code reach past
its N elements, which is exactly what C arrays get wrong.

**Handed out by pointer and length**: `unsafe cslice(T, p, n)` copies the `n` elements of `T` at the
`CPtr` `p` - an array C returned along with its count - into a `T[]`:

```grl
names := cslice(CStr, SDL_Vulkan_GetInstanceExtensions(count), u64(count.value));
for i in names.len() {
    println(cstr_bytes(names[i]).text());
}
```

It is `unsafe` because only C knows that `p` points at `n` live elements. After the copy the
vector is Grail's.

Verified by `tests/ffi/c_arrays.grl` on every target: C fills a record of byte, `u32`, `f32`,
`i8` and record arrays, Grail reads each back and assigns one, and C sums what it then sees; and
the string, integer and record arrays C hands out are copied with `cslice`.

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
- A record parameter of an `extern "C" fn` definition is the `const R *` the C caller passes: it is
  *borrowed*, never freed. Its fields are readable and the storage belongs to C, so a callback that
  receives an 800-byte `VkPhysicalDeviceProperties`-shaped struct neither copies nor releases it.
- A callback may take more arguments than the register files hold: the prologue reads the rest
  from the caller's frame (SysV x86-64 after six integer and eight vector registers, AAPCS64 and
  RV64 after eight of each, Win64 after four of each, which its thunk moves as well). `cbstk-callback-stack-arguments`
  in `tests/native-cases.json` calls a 24-parameter callback from a C-ABI Grail caller with no C
  toolchain needed, and `tests/ffi/callback_stack.grl` does the same through a C shim.
- A record **by value** into a callback is still refused (`a C callback cannot take a record by
  value yet`), because the copy the callee is owed would have to be materialised in the callback's
  own frame from register halves and stack words. That is the one remaining callback shape with no
  implementation; `byval` on a declaration Grail *calls* works on every ABI.
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
- a field may be an 8/16/32/64-bit integer, an `f32`/`f64`, a `handle`, a `CStr`, an inline C
  array `[T; N]` (see C arrays above) or another `extern "C" record`, which is embedded by value: its bytes sit at the field's C offset with
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

### Records by value as arguments

An `extern "C" record` parameter is the C `R *`, which is what Win32, Vulkan and D3D12 declare. A C
function that instead takes the whole record by value (`ImVec2`, some SDL calls) is declared with the
`byval` marker:

```grail
extern "C" record Vec2 { x: f32, y: f32 }

extern "C" fn c_length(v: byval Vec2) -> f32;

vec := Vec2 { x: 3.0, y: 4.0 };
length := unsafe { c_length(vec) };
```

- The marker is part of the parameter's type, so one declaration can use both spellings
  (`near: byval Vec2, far: Vec2`) and each call site is checked against the one it names.
- Classification reuses the record's C layout, flattened through embedded records, and follows the
  target ABI: SysV x86-64 per-eightbyte INTEGER/SSE classes with a mixed eightbyte counting as
  INTEGER, MEMORY over 16 bytes or when a register class is exhausted; AAPCS64 homogeneous float
  aggregates in `v0`-`v7`, other composites up to 16 bytes in consecutive `x` registers, larger
  records by reference to a caller copy; RV64 by reference over 2*XLEN and otherwise one register per
  field for one or two fields with a float, else one integer register per eightbyte. The argument
  counters of the call are advanced by the plan, so a `byval` record keeps its place among the
  arguments around it, and a call through a `cfn` that declares the marker uses the same lowering.
- The record is borrowed, not moved: it is still usable after the call, like a C-layout record passed
  by pointer.
- Win64 passes a record of 1, 2, 4 or 8 bytes as one integer word in its positional slot
  (`rcx`/`rdx`/`r8`/`r9`, then the stack above the 32-byte home area) - floats included, since Win64
  never passes a struct in `xmm` - and any other size by reference to a 16-byte-aligned copy the
  caller makes. Windows ARM64 follows AAPCS64 for fixed parameters (homogeneous float aggregates in
  `v` registers, up to 16 bytes in `x` registers, larger by reference), which is the lowering it uses.
  The Win64 shapes execute under Wine (`ffi-byval-records` in `tests/windows-cases.json`): every
  record size from 4 to 40 bytes, both directions and the callee-writes-its-copy case, with the
  same 25 checksum values the ELF targets print. Windows ARM64 is built as a COFF-ARM64 image and
  its AAPCS64 lowering is the one Linux AArch64 executes, but it is not run (no ARM64 Windows
  runner here).
- Refused with a diagnostic rather than approximated: anything that is not an `extern "C"` record
  (`byval must name an extern "C" record type; a bare record parameter is a pointer`), and an
  `extern "C" fn` definition, because a C callback cannot take a record by value yet.
- `tests/ffi/byval_records.grl` executes 4-, 8-, 12-, 16-, 24- and 40-byte records, mixed int/float
  fields, an ImVec2-shaped float pair, a three-float aggregate, an embedded array, a `byval`
  parameter after six integer arguments and a record sharing the stack area with a following scalar,
  with `tests/ffi/byval_shim.c` returning a checksum over every field each twin received, on x86-64,
  AArch64 and RISC-V 64.
  The 12-byte shape is the interesting one: it is neither a power of two nor a whole number of
  eightbyte words, so SysV spends two INTEGER eightbytes (the second 4 bytes wide), AAPCS64 two `x`
  registers, and Win64 and RV64 pass it by reference. The 40-byte shape exhausts both integer
  register files before the callee sees it, so SysV uses MEMORY and AAPCS64, RV64 and Win64 pass a
  pointer to a caller copy.
- The same fixture covers the other direction and the copy semantics: records of 4, 12, 16, 24 and
  40 bytes **returned by value** (Win64 returns only a 1/2/4/8-byte record in `rax` and any other
  size through a hidden result pointer in `rcx`; SysV uses `rax:rdx` up to 16 bytes and MEMORY above
  it), a callee that writes its own copy (the caller's fields must not change), and one call that
  takes a record by value and returns a record by value, so the argument copy's address and the
  hidden result pointer are live at the same time. That last shape is the one a Win32 API such as
  `MulDiv`-style record-returning calls need, and it is where an off-by-one in the argument counter
  would put the result pointer in a register the callee already used.

### Opaque handles

`handle File;` declares a one-word opaque type for a C-owned resource. A handle can be
bound, passed to declarations, returned from them and compared by identity; it cannot be
constructed (`File {}` is an error), inspected, sized, borrowed as bytes or dropped. A handle
declared in one module is nameable in any module that imports it - `use sys_grail;` then
`sys_grail::File`, or `use sys_grail::File;` then `File` - so another module's parameters,
results and record fields can name it, and it stays opaque there: binding, passing, storing and
`==`/`!=` against a handle of the same type are the whole surface, and arithmetic, ordering, a
conversion or a construction is a compile error that says so. Zero
validity is the C library's convention, not the compiler's: ask the library for a validity
or status accessor rather than assuming a sentinel. Handles are not linear in this
increment: the compiler never frees one, so a program that opens a handle must call the
matching close/free declaration itself, and leaking one is an explicit leak rather than an
implicit close.

#### Classifying a handle for the thread boundary

A handle declaration also carries the audited foreign-resource contract that the parallel surface
reads (`docs/design/parallelism.md`):

```grail
handle File: transferable;                    // may move to a worker, not be used concurrently
handle PhysicalDevice: transferable, shareable;
handle Window;                                // thread-affine: neither, and this is the default
```

Two properties come out of it. **transferable(T)**: a value may cross to another thread, including
being destroyed there. **shareable(T)**: concurrent shared access is permitted. For Grail-defined
types both are derived structurally - a record is transferable when every field is, shareable when
every field is, a slice when its element is. For a handle they are read from its declaration.

**Nothing declared means neither.** A handle no one has audited is thread-affine, so it cannot reach
a worker by accident, and adding a foreign type to the compiler never widens what a worker may
reach. `shareable` implies `transferable` - a value usable on another thread may also be moved to
it - and writing `shareable` alone is an error.

The audit is a claim about the C library, not about Grail's wrapper, and the module that declares
the handle is where it is made. `sys_grail` declares `File`, `Socket` and `Process` transferable
only: each is an owned OS resource with no wrapper-side state, so it can be handed to a worker and
closed there, but nothing in the module serializes two users of one, so `close` under another
worker's read is a race the type cannot see. `Thread` is neither: its one correct disposal - join or
detach, exactly once - is bookkeeping the creating thread owns, and this shim hands every handle out
through a `_Thread_local` slot, so the acquisition path itself is thread-local. `rhi_vulkan`
declares `Instance` neither - it is created and destroyed on the thread that owns the display
connection, with every child object dead before it - and `PhysicalDevice` both, because it owns
nothing, has no destructor and every operation on it is a query.

A safe wrapper cannot erase a restriction. `struct Holder { file: File }` is transferable only when
`File` is, `&Holder` is shareable only when `Holder` is, and a closure that captures either
inherits the restriction, because its environment is part of its type.

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
- A `handle`, a `CPtr`/`CMutPtr`, or an `extern "C"` record is an out-parameter slot. Every other
  reference shape — `&mut i64`, `&mut some_grail_record`, `&mut string` — is refused with
  `an extern C out-parameter must be &mut a handle, CPtr, CMutPtr or extern "C" record`.
- `p: &mut R` for an extern record is the C `R *`: the address of the record's own fields, so the
  callee fills the struct in place and Grail reads the typed fields afterwards
  (`vkGetPhysicalDeviceSurfaceCapabilitiesKHR`, `vkGetSurfaceFormats`). It needs a binding to write
  into: `c_fill(&mut Slots { ... })` is refused with `an extern C out-parameter needs a binding to
  write into; a temporary record would be discarded`, because the values C wrote would be dropped
  with the statement.
- **A record slot starts zeroed, not initialised.** An `extern "C"` record binding declared without
  an initializer (`mut caps: Caps;`) is an allocation of `sizeof(struct)` zero bytes: the storage
  exists so `&mut caps` is a valid pointer and a callee that reads a field before writing it reads 0
  (a handle slot C fills starts as `VK_NULL_HANDLE`). The *value* does not exist yet — reading a
  field of the binding, or moving it, before a foreign call or an assignment wrote it is refused with
  `use of moved, borrowed or partially initialized value`, so a zeroed handle can never be read as if
  it were one. That is how
  an array of handles is created without constructing a handle: `mut buffers: CommandBuffers;` then
  `c_alloc_command_buffers(&mut buffers)`. A handle-typed field may also be seeded from a handle the
  program already holds (`Slots { h0: swapchain }`), which is how `pSwapchains`/`pCommandBuffers`
  are built for `vkQueuePresentKHR` and `vkQueueSubmit`. A *non*-extern record or an integer
  declared without an initializer is still uninitialized and still rejected where it is used, and a
  handle itself still cannot be constructed (`File {}` is an error).
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
- Only a declaration Grail calls can take a handle or pointer out-parameter. An `extern "C" fn`
  *definition* (a C callback) and a `cfn` type declaring `&mut H` are refused by name, because
  Grail has no deref-assignment: a callback could not store a word through the pointer C handed it.
- A record out-parameter is the exception: a callback may take `p: &mut R` for the `R *` C passes,
  and a `cfn` type may declare it. The callback's body works on a Grail-owned copy of C's struct,
  and every exit - falling off the end or any `return` - copies the bytes back into C's storage
  before the copy is freed, so `p.field = v`, passing `p` on, and even `exchange(p, other)` are all
  sound (one record-sized copy each way). A call *through* such a `cfn` passes the record's own
  address, as a direct extern call does (`tests/ffi/callback_record_write.grl`,
  `ffi-cfn-record-mut-param`).
- A handle cannot be constructed at all, not even as null from Grail (`cnull()` is a `CPtr`, and
  `Slot { instance: cnull() }` is refused with `generic argument shape mismatch`), so a
  declaration's out-parameter is the way to
  obtain one — or a record field a call filled, whose untouched slots are the null handle.
  `tests/ffi/out_params.grl` executes it on x86-64, AArch64 and RISC-V 64, and on Windows
  x86-64 under Wine through `tests/windows-cases.json`: every C twin returns a checksum that reads
  the slot before writing it, so a slot passed by value, an uninitialized slot, or a write Grail does
  not see all change the printed values.

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
executes calls of seven, eight and nine words, with both literal and computed arguments, on x86-64,
AArch64 and RISC-V 64, and on Windows x86-64 under Wine.

The result register is `rax`/`x0`/`a0` on all three. A foreign call is a direct symbol call with the
same argument/result plumbing as a Grail call. Frames stay 16-byte aligned at call sites, and
generated Grail functions preserve the callee-saved registers they allocate (the internal prologue
saves and restores them), which is what lets C call back into an `extern "C"` definition.

The reverse direction — C calling a Grail callback — reads each parameter from where the target's
C ABI put it: the argument registers first, then the caller's stack. It reads **one argument word
per parameter**, which is why a byte view parameter is refused on a definition: C passes a view as
two words (pointer, then length), there is no second word for the entry to read, and where such a
pair would land differs by target (Win64 splits registers from the fifth argument). Declare the pair
instead — `p: CPtr, n: u64` — and copy the bytes with `cslice(u8, p, n)` inside an `unsafe` block;
`ffin-c-definition-pointer-length` executes that shape on all three targets, with the pair in the
middle of the argument list. The refusal names the parameter and that fix:

```
error: parameter `v` is a byte view, which C passes in two argument words (pointer then length); a
C callback entry reads one argument word per parameter - take `v: CPtr` and a `u64` length, and copy
the bytes with `cslice(u8, p, n)` inside an unsafe block
```

A `cfn` *type* may still declare a byte view: a `cfn` describes a callee Grail calls, and a call
emits the pair, so only a definition (a callee C calls) cannot take one. The result position has no
buffer shape either — a callback result is an integer, `f32`/`f64`, a `CStr` or a handle, and a
buffer answer is a length or a status. Past the registers, arguments sit
one 8-byte slot each above the callback's frame record, at `16(%rbp)` onward on SysV x86-64, AAPCS64 and
RV64 (the frame pointer is `x29`/`s0` there). On Win64 a thunk under the C symbol moves the four
registers and the fifth and sixth stack words into Grail's registers, and the body reads argument
`i >= 6` at `208+8i(%rbp)`, past the thunk's saved state and the 32-byte home area. RV64 passes a
floating-point argument that finds no free FP register in the next free integer register before
using the stack. Narrow integers are sign- or zero-extended and `f32` widened wherever they arrive
(`tests/ffi/callback_stack.grl`: 24 parameters, and ten doubles before an integer).

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

## Raw address offsets in unsafe modules

Integer arithmetic in an `unsafe module` follows the build's overflow mode like all other code:
a size or count computed as `n * 8` aborts on overflow in a checked build. The one exception is
address formation. The address operand of `raw_load`, `raw_store`, `raw_byte`, `raw_putbyte`,
`raw_load32` and `raw_store32` written as `p + k` or `p - k`, with `k` a literal, is not integer
arithmetic: it has no overflow check in any build, and the native backend folds it into the
instruction's addressing (`raw_load(p + 16)` is `movq 16(%rax),%rax`). This is Rust's `ptr.add`
rule: keeping such an address inside its object is the unsafe author's contract. Only the whole
operand counts - `raw_load((p + 8) * 2)` checks its arithmetic as usual - and a computed offset
(`p + i * 8`) is arithmetic too. The corpus pins both halves (`raw-address-offset-*`).

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

A task is a green task: a stack that a scheduler worker runs. What a foreign call does to that
worker depends on how the function is declared (x86-64 Linux today; elsewhere every form is a plain
call that occupies its worker for the call):

| declaration | what a call from a task does | cost per call |
| --- | --- | --- |
| `extern "C" blocking fn` | gives the worker to another thread for the call, at once: other tasks and jobs keep running; the caller keeps its task (C's frames and thread-locals stay put) and afterwards becomes a spare thread | a runtime call before and after |
| `extern "C" fn` (default) | counts itself in and out on its worker; if the call is still running after 10 ms while work is queued, the scheduler's monitor gives the worker away as for `blocking`, and says once on stderr which function it was | about 1.2 ns (10M calls of `labs`) |
| `extern "C" nonblocking fn` | a bare call, as from C: the promise is that it never blocks (math, an engine API that only records commands). If it blocks anyway, its worker is held for the call - latency, never a safety problem | none: the call is `call sym@plt` |

The attributes travel in interface files, so a call from another module behaves as declared.
Off a worker - `main`, a `thread::spawn` thread, a callback from C - every form is a plain call: the
thread is its own. Threads for blocked calls are made on demand and reused; an idle one retires
after a second once more than the worker count are waiting. At most 10,000 threads may be blocked
in foreign calls; the next one ends the program with a message instead of exhausting the machine.

The runtime's own blocking operations (`host::read_file`, `host::write_file`, `host::command`) give
their worker away the same way; `host::read_fd`/`write_fd` park on the readiness reactor and
`host::sleep_ms` on a timer.

A callback from C into Grail keeps its task on its thread: if it waits (sleeps, locks, joins), the
thread blocks instead of the task moving to another worker, because C's frames are under it.

### Task scheduling is the same on both platforms

A `spawn`ned task is a green task everywhere: it runs on a scheduler thread until it yields or
blocks, and suspension parks the task rather than the thread. A program may rely on exactly that
observable contract on every target:

- `sleep_ms`, `read_fd`, `write_fd` and the blocking host operations park the calling task, so
  other tasks keep running;
- `join`, task-scope exit and cancellation behave identically;
- the interleaving *order* of two tasks is not a guarantee, and portable code must not rely on it.
  Linux works the run queue with one scheduler thread per CPU (clamped to 4-64), so two ready tasks
  can run at the same time; Windows has one scheduler thread, so its queue is FIFO and the
  interleaving is deterministic. A program that leans on Windows' FIFO order is as unportable as
  one that leans on Linux' parallelism.

What differs is only the mechanism, and it lives in the platform module:

| | Linux (`os-linux.grl`) | Windows (`os-windows.grl`) |
| --- | --- | --- |
| Task stack | 256 KiB mapping with a guard page, `raw_switch` swaps stacks | Win32 fiber (`CreateFiberEx`), `SwitchToFiber` swaps contexts |
| Scheduler threads | one per CPU, clamped to 4-64 | one |
| Readiness | epoll + eventfd/timerfd reactor | none: the blocking host operation runs on a helper thread and the task parks (`rt_offload`) |
| `host::sleep_ms` | timerfd arm + park | `Sleep` on a helper thread + park |
| `rt_wait_fd` | parks on the epoll registration | reports ready; the parked task is inside the offloaded operation instead |

`GRAIL_TASKS=thread` selects the opt-in **thread-per-task** scheduler instead, on any platform. It
is a different semantic, not a faster one: each task is its own OS thread, a task that never yields
still makes progress beside another, suspension blocks that task's thread, `rt_wait_fd` returns
immediately because the ready task performs the blocking call on its own thread, and
`rt_reactor_fence` is a no-op. It is the right choice for CPU-bound fan-out once there is a
`Send`/`Sync` check to keep shared memory out of it; there is none yet, so two tasks can mutate the
same memory at once and the compiler says nothing. Under the default green scheduler that race is
much narrower (one task at a time on the Windows scheduler thread) but not absent on Linux, so this
mode does not introduce a new kind of unsoundness - it makes an existing hazard easy to hit.
  `host::read_file`, `host::write_file`, `host::command` and `host::command_with` do.
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
binary32: narrowed on the way in, widened on the way out) and `i8`..`i32`/`u8`..`u32` (see narrow
integers below). Up to 64 argument words are accepted and the outgoing stack area is limited to 2 KiB.
On macOS arm64, which packs stack arguments by size, a narrow or `f32` argument that would land
on the stack is refused. RISC-V objects use the hard-float `lp64d` ABI, which Linux C libraries
use. `tests/ffi/call_abi.grl` executes on x86-64, AArch64 and RISC-V Linux and, through
`tests/windows-cases.json`, on Windows x86-64 under Wine; Windows ARM64 is checked statically.

### Narrow integers: what the caller puts in the register

A narrow integer occupies one integer register, and each of these ABIs is explicit about the bits
above the value: they are the *caller's* business on the way in and the *callee's* on the way out,
and neither side may assume the other left them alone.

| Target | The caller's obligation | What Grail passes | A narrow result |
| --- | --- | --- | --- |
| Linux/macOS x86-64 (SysV) | extend the value to 32 bits - zero for an unsigned type, sign for a signed one; bits 63:32 are unspecified | the type's canonical word, so the upper half is zero for an unsigned type and all sign for a signed one | re-extended from the declared width: C leaves the upper bits of `%rax` unspecified, and a `u32` result must not be read as a 64-bit word |
| Windows x86-64 (Win64) | the register holds an eight-byte slot; the upper half may be anything | the canonical word | re-extended from the declared width |
| AArch64 (AAPCS64) | the same 32-bit extension; bits 63:32 are unspecified | the canonical word | re-extended from the declared width |
| RISC-V 64 (LP64D) | zero- or sign-extend the value to 32 bits by its type, then **sign-extend it to XLEN** | the canonical word, converted where the two differ | re-extended from the declared width |

Grail holds a sized integer as a canonical word - unsigned zero-extended, signed sign-extended - so
passing it as it stands satisfies the first three rows, and RISC-V 64 is the one target where the
canonical word is not yet what the ABI wants: a `u32` is sign-extended at the boundary (`cext s32`).
Concretely, a `u32` of `0xffffffff` arrives as `0x00000000ffffffff` on x86-64 and AArch64 and as
`0xffffffffffffffff` on RISC-V 64; a `u32` with bit 31 clear, and every `u8`/`u16`/`i8`/`i16`/`i32`,
arrive identical on all three. A C callee of that width reads only the low 32 bits, so both are
correct for it. A callee that inspects the whole register sees exactly the word above - and an
`extern "C" fn` *defined in Grail* is one of those: its prologue extends the parameter from the
declared width itself and ignores the upper half, so a Grail callback and a Grail direct call cannot
disagree about a narrow value no matter which ABI carried it.

`tests/ffi/narrow_upper.grl` pins all of it with C twins declared `unsigned long long`, including
one `connect`-shaped symbol declared twice (narrow and wide), the six widths in result position, and
the narrow fields of a record passed by value; the corpus cases `ffin-narrow-arguments`,
`ffin-narrow-arguments-riscv64` (the RISC-V sign extension), `ffin-narrow-results` and
`ffin-narrow-record-fields` execute on x86-64, AArch64 and RISC-V 64 with no C toolchain, using a
Grail-defined C-ABI callee that returns the whole 64-bit word.

## Importing a C header: `grail bindgen`

`grail bindgen HEADER.h -o OUT.grl` writes the declarations a Grail program needs to call a C
library: `extern "C"` functions, C-layout records, enum constants, `pub const` macros that are
integer constants, and a `SIZE`/`ALIGN`/`OFFSET_<field>` constant per record so `sizeof` and
`offsetof` are available without C.

```console
$ grail bindgen /usr/include/zlib.h -o src/zlib.grl
```

| Option | Effect |
| --- | --- |
| `-o OUT.grl` | output file; `--print` writes to stdout instead |
| `-I DIR`, `-isystem DIR` | `#include` search path, in that order before the defaults |
| `-D NAME[=VALUE]` | define a macro before reading the header |
| `-l LIB` | emit `pub extern "C" lib "LIB";` for every declaration |
| `-M lp64\|llp64` | `long` is 64 bits (Unix, the default) or 32 (Win64) |
| `--module NAME` | the `module NAME;` the output declares (default: the `-o` file's stem) |
| `--strict` | refuse file-scope variables and function-like macros instead of noting them |
| `--dump-tokens` | print the preprocessed token stream and stop |

The importer is a preprocessor and declaration parser, not a C compiler: it resolves `#include`
(quote and angle forms, with include guards de-duplicated by path), expands object-like and
function-like macros — `##` pasting included — so a header's own `#define`s work, honours
`#if`/`#ifdef`/`#ifndef`/`#elif`/`#else`/`#endif` with a C constant-expression evaluator
(`defined`, arithmetic, shifts, casts, `sizeof`/`_Alignof` of a type, `?:`), and parses typedefs,
struct/union/enum declarations, function declarations, function definitions (`static inline`
helpers, which are not linkable symbols and are reported rather than emitted) and the attributes
that do not change layout. It does **not** use libclang: linking a C parser into the compiler would
make it a build dependency of every Grail install and of the bootstrap seed, and this importer has
to refuse by name rather than silently mistype.

The mapping is the one in "Supported types":

| C | Grail | Note |
| --- | --- | --- |
| `char` | `u8` | a plain `char` is the byte type; `signed char` is `i8`, `unsigned char` is `u8` |
| `short`, `int`, `long long` | `i16`, `i32`, `i64` | `long` is 64 bits on a 64-bit LP64 host, 32 under `-M llp64` |
| `size_t`, `ssize_t`, `int64_t`, `uint32_t`, … | `u64`, `i64`, `i64`, `u32`, … | the C library's typedefs are preloaded, so a header that uses `size_t` without `<stddef.h>` parses |
| `float`, `double` | `f32`, `f64` | |
| `T *` (not `char`) | `CPtr` / `CMutPtr` | const pointee → `CPtr`; the type is a one-word C pointer |
| `const char *` | `CStr` | `char *` (non-const) is `CMutPtr`: it may be an output buffer |
| `R *`, `struct R *` | `CPtr` | `cptr(&r)` supplies a record's address, `cnull()` a null |
| `R f(...)` | `-> R` | a record result by value, classified per ABI |
| `R (*)(...)` | `cfn(...) -> ...` | in a parameter or result; a record *field* of that type is `CMutPtr` (a field cannot hold a `cfn`) |
| `struct { ... }` | `extern "C" record` | C size, alignment, offsets and padding |
| a union | `extern "C" record { bytes: [E; n] }` | overlapping members have no Grail spelling, so only the exact size and alignment are exported |
| an incomplete `struct` | `pub handle` | the type can be named and passed by pointer |
| `enum` | `i32` (or `i64` when a value needs it) plus `pub const` per enumerator | |
| `#define FOO (1u << 3)` | `pub const FOO: i64 = 8;` | any object-like macro whose expansion is a pure number expression |

Refusals, each naming the construct and its `file:line`, and leaving no output file behind: a
bit-field, `__attribute__((packed))`/`aligned`, `#pragma pack`, `long double`, `_Complex`,
`__int128`, `_Atomic`, `typeof`, an anonymous struct/union member (which would have to be
flattened), a multi-dimensional array member, `#error`, an `#if` condition the evaluator cannot
fold, and a type the importer does not model (`__builtin_va_list` is the exception: it is modelled
as an opaque pointer, which is how x86-64 passes a `va_list` parameter).

Reported as `note:` lines and left out of the binding — not mistyped, simply not expressible:
a **file-scope variable** (Grail has no extern globals; read it through an accessor function) and a
**function-like macro** (Grail has no macros). `--strict` turns both into refusals, so a caller can
choose.

Limits: the importer describes the host target's ABI (`__x86_64__`, `__LP64__`, `__linux__` and the
other predefines are supplied; `-M llp64` changes the integer model only), it does not model
`va_list` passed by value (AArch64), it expands macros a header redefines in the usual way but
refuses `#` stringize, a declaration split by a macro invocation across a newline, and any header
that needs a GCC/Clang-specific type or attribute to declare its API. A generated binding is C's
statement of the API; the header's own `#if` branches decide what that statement is, so
`-D`/`-I` arguments matter as much as they do for `cc`.

`tools/bindgen-test.mjs` (or `just bindgen-test`) covers it: the binding for
`tests/bindgen/fixture.h` is committed (`tests/bindgen/fixture_binding.grl`) and regenerated byte
for byte; that binding is compiled and executed against `tests/bindgen/fixture_shim.c`, and every
`SIZE`/`OFFSET` constant is compared with the C compiler's own `sizeof`/`offsetof`; the system's
real `<zlib.h>` is imported and used to call a C `crc32`, whose value (`0xCBF43926` for
`"123456789"`) proves the generated pointer and length types; and each refusal above is asserted to
name its construct and file:line. The corpus case `cimp-fixture-layout` runs the generated binding
on every target.

## Limits

Not implemented yet, and each rejected rather than approximated:

- macOS callbacks use the same SysV/AAPCS64 lowering, stack arguments included, but are compiled and
  linked only (no macOS runner);
- an out-parameter on a C callback or a `cfn` type: only a declaration Grail calls can write a slot
  (see Out-parameters above);
- a byte view parameter on a C callback (refused by name, with the `CPtr` + `u64` spelling and
  `cslice`), because a definition's entry reads one argument word per parameter and C passes a view
  in two; and any buffer-shaped callback result, for the same reason. A `cfn` type may declare a
  view, because only Grail calls through one;
- a `byval` record parameter on a C callback. Record results are
  returned by value on every ABI, float fields included, embedded records included: the register
  classification runs over the flattened field list, so a float inside an embedded record is
  classified like one at the top level (`tests/ffi/call_records.grl`, `float_record_results.grl`,
  `nested_float_results.grl`);
- pointer arithmetic, an index of a `CPtr`, a view built from an address, and a reference into an
  inline C array: C arrays are copied into vectors (`[T; N]` fields, `cslice`), see C arrays above;
- a pointer that C keeps after the call returns. A `CPtr` made by `cptr`/`cptr_mut` is a checked borrow
  inside Grail (see "Pointer lifetimes"), but an `extern "C"` declaration cannot state that C retains
  it. A library that does (callback user data) needs storage whose lifetime the program controls,
  and that is the programmer's responsibility. Inside Grail a `CStr` is checked like a `CPtr`: one
  of a literal points at static storage and may be kept, and one of bytes borrows them, so they
  cannot change or be dropped while it is live;
- variadic callbacks, callback results that are themselves function pointers, and
  taking the address of a foreign *declaration* (`f := c_add;` is rejected: a C
  declaration is not a Grail function value);
- dynamic loading on macOS (Linux uses the TLS bridge below on all three architectures;
  Windows x86-64 needs none, since `LoadLibraryA`/`GetProcAddress` are ordinary imports and the
  runtime does not own the TEB). Foreign calls and callbacks work on any thread on Linux, including
  threads C itself created (`tests/ffi/threads.grl`, `foreign_thread.grl`);

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

The Grail runtime installs each OS thread's worker record as the thread pointer (x86-64 FS base
through `arch_prctl(ARCH_SET_FS)`, AArch64 `tpidr_el0`, RISC-V `tp`), which is also where glibc keeps
its TCB (errno, malloc tcache, stack guard, DTV). On Linux the compiler bridges the two per thread
(x86-64 switches with `arch_prctl`; AArch64 and RISC-V write the register directly):

- every thread's record carries its own host TLS base in record word 56: the thread's glibc TCB, or 0
  in a static program that never loaded libc. `_start` stores the loader's base for the main thread
  before `rt_thread_init` installs the main record;
- in a process that loaded libc, every thread the runtime creates (scheduler workers, which run green
  tasks and jobs, the reactor, offload threads, `GRAIL_TASKS=thread` task threads) is created by glibc's
  `pthread_create`, so it has a real TCB that glibc built and will tear down itself; a static program
  keeps cloning its own threads, which have no TCB and need none;
- every `extern "C"` call switches to the calling thread's own TCB and back, and does not switch at
  all on a thread without one;
- every exported `extern "C" fn` (a callback entry) finds the record of the thread it runs on through
  `rt_tls_record`, an initial-exec ELF TLS word of the executable that glibc allocates in every thread
  it creates, switches to it, and restores the caller's TCB on every return path.

So foreign calls are valid on any runtime thread, including from jobs and green tasks, and libc
state is the calling thread's: errno set on a worker is not the main thread's errno. A callback runs
on the thread that called into C, with that thread's record (on a green task's scheduler thread, the
task that made the foreign call). **A callback that arrives on a thread C created itself** finds no Grail record and adopts one:
the outermost callback on that thread maps a fresh record (its own TCB in word 56, no task or
scheduler state), publishes it for the duration of the callback, and unmaps it when the callback
returns to C. Inside, the callback may allocate, make foreign calls (on that thread's TCB, with its
own errno) and be re-entered through C; a nested callback finds the published record and adopts
nothing. The cost is one `mmap` and one `munmap` per outermost callback on such a thread
(`tests/ffi/foreign_thread.grl`; see [B3](design/decisions-b2-b6.md#b3-foreign-calls-block-the-executing-thread)). A dynamically linked
program is always linked against libc (`-lc` is added with the loader), because the runtime binds
`pthread_create` weakly; a libc-loading program without it aborts by name at its first thread. On
x86-64 a foreign call costs two `arch_prctl` system calls and a callback two, plus one TLS load; on
AArch64 and RISC-V each switch is a register write. `tests/ffi/threads.grl` calls `getpid`, `strlen`,
`malloc`/`free`, `close(-1)` with errno and `pthread_self` from a pool worker and from a green task,
and holds two different errno values on the main thread and a worker at the same time.

Two limits remain. A callback must not suspend the green task that made the foreign call: the task
could resume on another scheduler thread and return into C there, on the first thread's TCB. And
glibc's internal signals (`SIGSETXID`, which `setuid`/`setgid` broadcast to every thread, and
`pthread_cancel`) assume the thread pointer is the TCB, which is false while a thread runs Grail
code, so neither is supported in a Grail process.

`tests/ffi/dlopen.grl` loads `libdlshim.so`, calls two resolved
functions, passes a Grail callback that itself calls `strlen`, and closes the library
(42, 42, 42, 0) with the runtime initialized. On AArch64 and RISC-V 64 it and `threads` run under
qemu when a glibc sysroot is supplied: `GRAIL_SYSROOT_AARCH64` / `GRAIL_SYSROOT_RISCV64` point at a tree
with the target's `ld-linux-*.so.1`, `libc.so` and `libdl` (a Fedora-style `lib64` tree or a
Debian multiarch tree, e.g. the extracted `libc6` and `libc6-dev` packages); the cross link
then uses `--sysroot` and the target loader, and qemu runs with `-L sysroot`. Without one the
two fixtures are cross-compiled only. The loader functions are declared from `lib "dl"`: glibc before
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
  out-parameter slots including a seventh-argument slot and two slots in one call, `record_pointers`
  the record-by-pointer and record-out-parameter shapes (`13`, `5`, `0`, `4194304`, `0`, `0`, `110`,
  `77`, `1`, `433`, `8` — a create-info reading a struct through `cptr(&app)`, `flags` as the zero
  the storage started as, an array of handles C fills and Grail passes back with the handle Grail
  reads equal to the one C hands back, an array of structs addressed at two interior elements, and
  one count record across two declarations of one symbol), `record_field_refs` `&mut` of an extern
  record held in a plain record's field, written by a Grail callee and by C, with the neighbouring
  fields unchanged (`7`, `102`, `307`, `40`, `41`, `60`, `61`, `5`), `call_words` seven, eight and nine word
  arguments with literal and computed values, `byval_records` the by-value record shapes with a
  checksum over every field each C twin received, and `narrow_upper` the narrow integer rules of the
  section above through C twins declared `unsigned long long` (the six widths in argument and result
  position, one `connect`-shaped symbol declared twice, and the narrow fields of a by-value record).
- every fixture executes on x86-64 and, through `qemu-<target>-static`, on AArch64 and RISC-V 64 as
  well, so a host with both runners executes each one three times; without a runner the cross
  targets link and are reported as link-only. Two fixtures, `dlopen` and `threads`, need the
  target's glibc: they execute on the host and, with a sysroot (below), under qemu on AArch64 and
  RISC-V 64; without one they are cross-compiled only. `callback_words` executes the eight-register
  callback on AArch64 and RISC-V 64 and asserts that x86-64 and Windows refuse it by name. Without a
  qemu runner the cross targets are linked and the ABI-level check is reported as link-only. The same
  `out_params` and `call_words` sources are `ffi-out-params` and `ffi-call-words` cases in
  `tests/windows-cases.json`, which `bun tools/windows.mjs check` builds as a PE image and executes
  under Wine on Windows x86-64; Windows ARM64 is checked statically, because there is no ARM64
  Windows runner.

Rejections are part of the normal native corpus (`tests/native-cases.json`):
`ffi-reject-safe-call`, `ffi-reject-abi`, `ffi-reject-parameter-type`, `ffi-reject-result-type`,
`ffi-reject-arity`, `ffi-reject-duplicate`, `ffi-reject-handle-out-slot`,
`ffi-reject-handle-null-seed`, `ffi-reject-out-shared-borrow`, `ffi-reject-out-scalar`,
`ffi-reject-out-callback`, `ffi-reject-out-cfn`, `ffi-reject-out-double-borrow`,
`ffi-reject-byval-plain-record`, `ffi-reject-byval-scalar`, `ffi-reject-byval-callback`,
`ffin-reject-c-definition-slice`, `ffin-reject-c-definition-slice-mut`,
`ffin-reject-c-definition-slice-result`, `handle-reject-arithmetic`,
`ffi-reject-handle-construction`,
`ffi-reject-record-address-temporary`, `ffi-reject-record-address-plain`,
`ffi-reject-record-pointer-alias-writable`, `ffi-reject-record-pointer-alias-shared`,
`ffi-reject-record-out-plain`, `ffi-reject-record-out-shared`, `ffi-reject-record-out-temporary`,
`ffi-reject-record-unfilled-read` and `ffi-reject-record-unfilled-move`, so every target checks the
diagnostics on every run of `bun tools/test-native.mjs`. `tests/handles/stream_def.grl` declares a
handle and its libc declarations, `stream_user.grl` uses it as a parameter, a result and a record
field and compares two handles: the executed `cross-module-handle-signatures` case.

The same corpus executes the record shapes without a C toolchain, by declaring the symbol and
defining it as an `extern "C" fn` (a C-ABI Grail function), which is the same one-word pointer on
both sides: `ffi-record-address` (`42`), `ffi-record-address-field` (`433`, two interior element
addresses), `ffi-record-out-param` (`0`, then `0` — a zeroed binding the callee reads, and the same
field read by Grail after the call: the accepted half of the `ffi-reject-handle-out-slot` pair), the
recorded regression `ffi-record-two-declarations` (`8`, one count record across two declarations of
one symbol, which must reach its exit status without aborting),
`ffi-record-callback-parameter` (`20`, a callback's record parameter borrowed rather than freed) and
`ffi-record-array-pointer` (`34`, an array of slots read through the record's own address). The
handle-typed twin of the array shapes needs a real C library to produce the handles, so
`tests/ffi/record_pointers.grl` covers it, including the comparison that the handle Grail reads out
of the array equals the one C hands back.
