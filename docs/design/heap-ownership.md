# First heap ownership gate: byte vectors

> Design history: seed/C prototype details below are historical. The authoritative implementation
> and current build/test commands are in [compiler/README.md](../../compiler/README.md).

2026-10-30. This is a v0 progress checkpoint, not complete strings, generic vectors or self-hosting.

## Implemented

- `bytes[]` creates an empty owned byte vector; `owner.push(value)` grows it geometrically and
  stores the low eight bits. `owner.len()` reads its length. `owner_or_view.copy()` explicitly
  deep-copies bytes into an independent owner. No implicit owner copy, GC or reference counts.
- `bytes` parameters/results transfer ownership through separately checked interfaces. Returning
  a local owner is supported; returning a view into a consumed owned parameter is not.
- Growth, owner movement and release are rejected while any view remains live, irrespective of
  whether a particular push might fit existing capacity. After a view's last use, growth is allowed.
- Loans end at last use; **owners drop at lexical scope exit in reverse binding order**, or at an
  explicit `drop`. Loop/branch local owners drop each time their block exits. Returned/moved owners
  are not freed by the old binding. Checked IR must end or return every heap owner.
- The C representation is pointer/length/capacity, with checked growth and allocation failure aborts.
  Empty slicing avoids C null-pointer arithmetic; empty copies do not call memcpy with null pointers.

Signatures now use schema **2**, with an owned byte type. Old schema-1 artifacts must be rebuilt;
there is no compatibility decoder. This is not a finalized public ABI.

The C backend implements ownership. The experimental LLVM comparison backend explicitly rejects
heap layouts rather than misrepresenting them as two-word borrowed views. It still supports the
previous non-heap subset; LLVM heap support is not required for C-backed v0 self-hosting.

## Independent validation

`seed/tests/heap.rs` checks growth with retained views, last-use release, borrowed-owner moves into
calls, local/owned-parameter escapes, affine transfers, scope composition and schema rejection.
`seed/tests/heap_native.rs` links allocator wrappers independently of checker state. It checks:

- returned owners and independent clones, with 1,000 pushes and several reallocations;
- no leaked allocations or repeated frees;
- unused owners remaining live until lexical exit, rather than disappearing at last use;
- cleanup of loop/branch local allocations;
- the final two enclosing owners freed in reverse allocation/binding order.

The audit's `live` function is a declared numeric **test-only** observer, not a production language
primitive. Pointer bookkeeping and counters live in the external C test harness. They are not runtime
borrow checking or a proof for arbitrary programs. Existing source/native tests also continue to pass.
The owned producer/client run through both clang and TinyCC. Their numerical result, 125717, checks
byte truncation, clone independence and growth of the original while reading the separate clone.

## Remaining gates

No references stored inside heap elements yet; no generic `Vec<T>`, UTF-8 String invariants, HashMap,
owned replacement assignments, user destructors, Result cleanup or early-return cleanup. Byte-vector
success does not discharge those. In particular, introducing reference-containing elements requires
written lifetime/type bounds and recursive cleanup, not treating them as unstructured bytes.

Build/check commands:

```sh
cargo test --manifest-path seed/Cargo.toml --offline
cargo test --manifest-path seed/Cargo.toml --offline --test heap_native -- --ignored
cargo test --manifest-path seed/Cargo.toml --offline --test native -- --ignored
cargo clippy --manifest-path seed/Cargo.toml --offline --all-targets -- -D warnings
```
