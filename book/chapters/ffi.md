# Calling C

Grail calls foreign C code directly. `extern "C"` declares a symbol the linker resolves, a call is
emitted with the target's C calling convention inside an `unsafe` block, and no wrapper layer, code
generator or libc is required. `docs/ffi.md` is the contract; this chapter is the shape of it.

## Scalars, strings and buffers

`extern "C"` parameters are C's own: integers of every width, `f64`/`f32`, `CStr` for a
`const char *`, `&[u8]`/`&mut [u8]` for a `(pointer, length)` pair, `handle Name;` for an opaque
C token, `cfn(...) -> R` for a function pointer, and `CPtr`/`CMutPtr` for a bare `void *`.

```grl
extern "C" lib "shim.o" fn c_add(a: i64, b: i64) -> i64;
extern "C" lib "shim.o" fn c_strlen(s: CStr) -> i64;
```

A call sits in an `unsafe` block because the C function may do anything with its arguments, and
because the compiler cannot check that a `CStr` is NUL-terminated or that a buffer is as large as C
expects. `unsafe` marks that boundary; it does not switch off moves, drops or borrow checking.

## Records by pointer, and records C fills

A C API that describes itself with structs needs two more shapes, and both are the same idea: a
record Grail owns is passed as the *address of its own fields*, which is exactly what C means by
`struct R *`.

- A record **parameter** is that address for the duration of the call:
  `fn book_create(info: CreateInfo)` passes `app`'s bytes, C may read them, and Grail still owns the
  allocation afterwards.
- `unsafe cptr(&r)` is that same address as a *value*: a `CPtr` (or `CMutPtr` from
  `cptr_mut(&mut r)`) for a field, a binding or a parameter typed `const void *`/`void *`. That is
  how a create-info struct points at another struct — `VkInstanceCreateInfo::pApplicationInfo`,
  `VkRenderPassCreateInfo::pAttachments` — without laying the bytes out by hand.
- `p: &mut R` in a declaration is the C `struct R *` the callee **writes**: the caller passes
  `&mut` of a binding and reads the typed fields afterwards. An `extern "C"` record binding declared
  without an initializer gets zeroed storage, so a field the callee leaves alone has a defined value
  and a handle slot it fills starts as the null handle — but the binding has no *value* until the
  call (or an assignment) gives it one, so reading a field before that is refused with
  `use of moved, borrowed or partially initialized value`. Zeroed bytes are not an initialised
  handle.

`cptr` is `unsafe` for the same reason as `cptr` of a byte sequence: the pointer carries no length,
and C must not keep it or free it once the call returns. On the Grail side it is a borrow like any
other. The record it points at must be a name, not a temporary, and it cannot move, be dropped, or be
handed to C a second time in one call. The compiler says so by name:

```grl
info.p_app = cptr(&AppInfo { api_version: 1, flags: 0 });
// cptr needs a named record: the address of a temporary would not outlive the pointer
c_two(cptr(&app), cptr_mut(&mut app));
// the value handed to C as a writable pointer is already borrowed in this expression
c_fill(&mut Slots { h0: h1, h1: h1 });
// an extern C out-parameter needs a binding to write into; a temporary record would be discarded
```

An array of structs needs no array type: a record of embedded records is laid out contiguously, so
the record's address *is* the array, and `cptr(&pairs.first)` is the address of one element. An
array of *handles* is a record of `handle` fields for the same reason, which is how a submit or
present call gets its `pCommandBuffers`/`pSwapchains`: C fills the record through `&mut`, or Grail
seeds it from handles it already holds.

{{example:ffi-record-pointers}}

The example is the whole contract in twelve lines: `cptr(&app)` is the pointer `book_create` follows
to read `api_version`, and `book_fill` writes `api_version` through `&mut filled` while `flags` stays
the zero the binding started with. Both languages run the same C file — Grail's pointer field is
Rust's `*const AppInfo`, Grail's `&mut AppInfo` is Rust's `*mut AppInfo` — so the numbers are the
same numbers.

The pointer borrows `app` for as long as the pointer lives, and not only for the statement that
made it. It lives in `info`, in a binding, in a copy of either or in a closure that captured it, and
`app` stays borrowed until the last use of whichever of those comes last. Replacing `app` before that
is the error below, and so is letting the pointer outlive it: keeping it in a record from an outer
scope, returning it, or returning a closure that holds it.

{{example:ffi-pointer-lifetime}}

A Grail function that takes a `CPtr` and returns one, or that stores one through a `&mut` record
parameter, is assumed to pass on whatever its arguments pointed at, so a helper cannot launder the
borrow. A call to C borrows the pointer for that call only: C must not keep it. When C really does
keep a pointer (a registered callback's user data, a long-lived descriptor), the storage has to be
something the program controls, such as a record that outlives every call C makes with that
pointer. There is no annotation that tells the compiler "C keeps this" yet.

## Arrays of handles

A record of `handle` fields is an array of handles for the same reason a record of records is an
array of structs: the fields are laid out contiguously, so the record's address is the array. This is
the shape `pCommandBuffers` and `pSwapchains` take, and it is where the uninitialised-record rule
matters most, because a handle cannot be constructed at all.

{{example:ffi-handle-array}}

`mut buffers: CommandBuffers;` is storage - `sizeof(struct command_buffers)` zero bytes - and
`c_alloc_buffers(&mut buffers)` is the pointer C writes the four slots through. Only after that call
are the fields *values*: reading one before it is the error below, so a zeroed slot can never be read
as if C had produced a handle. A non-extern record, or an integer, declared without an initializer is
still plain uninitialized and still refused where it is used; a bare `handle` binding is the one
exception, being null rather than uninitialized, because C reads it even when it only writes.

{{example:ffi-uninitialised-record}}

That is the whole rule in one line, and it is the same rule Rust states as E0381: a binding nothing
wrote has no value to read. The difference is what the storage is - Grail zero-fills an `extern "C"`
record so the callee's pointer is always valid, and then refuses to let the zeroes be mistaken for
data.

## What crosses, and what does not

- A record parameter or a `cptr` address is one word: C reads or writes the fields at that address
  and Grail never copies the struct into or out of the call.
- Ownership does not change hands. Grail frees what Grail allocated, C frees what C allocated, and a
  pointer Grail hands over must not be freed by C. A callback's record parameter is C's storage for
  the same reason: it is borrowed, never freed.
- A `handle` is an opaque C token and still cannot be constructed: it comes from a declaration's
  out-parameter or from a record field a foreign call filled.
- A record crosses by pointer unless the declaration spells `v: byval R`, which passes the struct by
  value per the target ABI on the Linux targets and is refused by name on Windows. A callback cannot
  write through a pointer it is given (there is no deref-assignment), and there is no pointer
  arithmetic, so an array of dynamic length is a fixed-capacity record with its count checked
  afterwards.
- A `CPtr` made by `cptr`/`cptr_mut` is a borrow of the record or bytes it points at. The
  borrow lasts as long as the pointer is live (in a binding, a record field or a closure), so the
  storage cannot be replaced, moved or dropped under it, and the pointer cannot be returned or kept
  past the storage's scope. The address of a temporary is refused outright. A `CPtr` that C *returns*
  is C's pointer and carries no borrow.

## What this month added

The FFI grew the two shapes every C API with create-info structs needs, and one fix that was a
soundness bug.

- **A pointer to a record Grail owns.** `unsafe cptr(&r)` is that address as a `CPtr` and
  `cptr_mut(&mut r)` the same as a `CMutPtr`, so a struct that points at another struct -
  `VkInstanceCreateInfo::pApplicationInfo`, `VkRenderPassCreateInfo::pAttachments` - is expressible
  without laying bytes out by hand. The address is the one a record *parameter* already was, so the
  two forms reach the same bytes; `cptr` is how a program *names* it, in a field, a binding or a
  parameter typed `const void *`/`void *`. An embedded record's field is interior storage, so
  `cptr(&pairs.first)` is an element address and an array of structs needs no array type.
- **Records C fills.** `p: &mut R` in a declaration is the C `R *`: the callee writes the struct in
  place and the caller reads the typed fields afterwards. The slots start zeroed, so a field the
  callee leaves alone reads 0 - but the binding has no value until something wrote it, which is what
  keeps a zeroed handle from being read as one.
- **Arrays of handles**, seeded by C through `&mut` or built by the program from handles it already
  holds, which is how a submit or present call gets its handle array.
- **A callback's record parameter is borrowed, not owned.** The parameter prologue used to mark every
  parameter as an owning binding, so the epilogue ran drop glue on the address C handed over and the
  process aborted inside the runtime's free path at exit - after `main` had printed everything and
  returned 0. A callback's record parameter is the `const R *` the caller owns, so it is registered
  as a borrow now and the fields stay readable under the ordinary rules.

## Bindings can be generated

Writing `extern "C"` declarations by hand is the right way to bind a small surface. A whole C
library is a different job: `grail bindgen` reads the header and writes the declarations, the
C-layout records and the constants `sizeof`/`offsetof` would have given you.

```console
$ grail bindgen /usr/include/zlib.h -o src/zlib.grl
$ rg 'fn crc32|record z_stream|Z_STREAM_SIZE' src/zlib.grl
pub extern "C" record z_stream { next_in: CMutPtr, avail_in: u32, ... }
pub const Z_STREAM_SIZE: u64 = 112;
pub extern "C" fn crc32(a0: u64, a1: CPtr, a2: u32) -> u64;
```

The file is a normal module, so a program imports it and calls C with the generated types:

```grail
module bindings_demo;
use zlib;

fn crc_of(data: &[u8]) -> u64 {
    unsafe {
        return zlib::crc32(0, cptr(data), u32(data.len()));
    }
}
```

`cptr(data)` is the `const Bytef *` the header declares, and the length is the `uInt`. Every field
of `z_stream` is at the offset C puts it at, which is what `Z_STREAM_SIZE`/`Z_STREAM_OFFSET_*`
record, and `grail bindgen` compares them with the C compiler's own `sizeof`/`offsetof` in
`tools/bindgen-test.mjs`.

What it refuses, it refuses by name: a bit-field, a packed struct, `#pragma pack`, `long double`,
an anonymous union member - each with its `file:line`, because a binding that silently disagrees
with C is worse than no binding. A file-scope variable or a function-like macro has no Grail
spelling at all, so it is reported as a note and left out (`--strict` refuses those too).

What still has no expression: pointer arithmetic (an array of dynamic length is a fixed-capacity
record with its count checked afterwards). A C callback writes into the struct C hands it by taking
`p: &mut R`, and `byval` records work on every ABI, Windows included. `docs/ffi.md` states each
remaining limit with the diagnostic it produces.
