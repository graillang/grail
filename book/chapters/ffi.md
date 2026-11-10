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
  `&mut` of a binding and reads the typed fields afterwards. An `extern "C"` record binding
  declared without an initializer is zero-filled, so a field the callee leaves alone has a defined
  value, and a handle slot it fills starts as the null handle.

`cptr` is `unsafe` for the same reason as `cptr` of a byte sequence: the pointer carries no length
and no lifetime once C holds it, so C must not keep it or free it. The record it points at must be a
name, not a temporary, and it cannot move, be dropped, or be handed to C a second time while the
pointer is live. The compiler says so by name:

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

## What crosses, and what does not

- A record parameter or a `cptr` address is one word: C reads or writes the fields at that address
  and Grail never copies the struct into or out of the call.
- Ownership does not change hands. Grail frees what Grail allocated, C frees what C allocated, and a
  pointer Grail hands over must not be freed by C. A callback's record parameter is C's storage for
  the same reason: it is borrowed, never freed.
- A `handle` is an opaque C token and still cannot be constructed: a null handle comes from a
  zero-filled record field or from a declaration's out-parameter.
- Records cannot yet be passed **by value** (`v: byval R` is decided and in progress), a callback
  cannot write through a pointer it is given (no deref-assignment), and there is no pointer
  arithmetic, so an array of dynamic length is a fixed-capacity record with the count checked
  afterwards.
