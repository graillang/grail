# Owned UTF-8 text checkpoint

2026-10-30. An extension of [heap byte ownership](heap-ownership.md), not complete strings,
generic collections or self-hosting.

## Contract

- `string` is an owned, valid UTF-8 byte sequence. Its C layout is the byte vector's pointer,
  byte length and capacity. It moves across functions and drops at lexical scope exit.
- A quoted literal constructs an owned string. Source decoding supports `\n`, `\r`, `\t`, `\0`,
  `\\`, `\"` and `\xHH`. Decoded UTF-8 is checked in the source frontend **and** in the typed-IR
  checker, so directly constructing a bad literal IR cannot bypass the invariant.
- `text(storage_or_view)` explicitly validates and copies bytes into independent owned text.
  Invalid UTF-8 aborts for now; a recoverable Result-based constructor remains a future gate.
- `append_text(owner,storage_or_view)` validates its source and appends, preserving UTF-8.
  It requires the destination to be unborrowed. Direct self-append is rejected; make an explicit
  copy when needed. No hidden copy-on-write, reference counting or dynamic borrow tracking.
- `read(string)` yields a **byte view**, not a separately typed UTF-8 `str` view. Byte slicing
  may split a code point; converting that slice back to text validates again. `len` counts bytes.
- Mutable byte borrowing of strings and raw byte `push` on strings are rejected. `copy_bytes`
  can make an independently mutable byte-vector copy without weakening the string invariant.
- `let` fixes the binding; uniquely owned contents may be modified by their operations. `var`
  permits rebinding (currently numerical rebinding only). This matches the already implemented
  vector operations; it is not Rust's binding-mutability syntax.

The C primitives validate continuation bytes, truncation, overlong forms, surrogates and values
above U+10FFFF. The validator is trusted implementation code, not a proved Unicode library.
Empty strings/slices/copies avoid invalid null-pointer arithmetic and zero-length null memcpy.
Literal construction allocates; static-literal representation/hoisting and temporary-lifetime
optimizations are not implemented or benchmarked here.

Seed signatures are now **schema 3**. Rebuild schema-2 objects/interfaces. String and byte-vector
ownership are distinct even though the physical layouts match. The LLVM comparison backend
continues to reject owned heap layouts explicitly; the C production path is the implementation.

## Validation

`seed/tests/text.rs` checks escapes, invalid UTF-8 in direct IR, forbidden byte mutation, retained
view growth, last-use release, self-aliasing append, owned moves and imported string signatures.
`seed/tests/text_native.rs` compares 26 selected byte sequences with Rust's UTF-8 validator through
both clang and TinyCC. It includes valid boundary scalars, controls, empty/Unicode input, invalid
continuations, overlong encodings, truncated forms, surrogate encodings and out-of-range scalars.
Valid programs must preserve bytes after copying, appending and owned call/return; invalid inputs
must abort with SIGABRT. The source of the owned-string producer is removed before client checking.

The existing allocator audit still checks no leaked/repeated frees and reverse enclosing-owner
cleanup; this is not arbitrary-program safety or complete UTF-8 conformance evidence.

```sh
cargo test --manifest-path seed/Cargo.toml --offline
cargo test --manifest-path seed/Cargo.toml --offline --test text_native -- --ignored
GRAIL_TCC_ROOT="$PWD/research/experiments/memory01/.work/goose-build" \
GRAIL_NATIVE_TEST_BACKEND=tcc \
  cargo test --manifest-path seed/Cargo.toml --offline --test text_native -- --ignored
```

Next library gates include recoverable conversion errors, borrowed text abstractions, equality,
search/splitting, input/output and generic containers. Do not count this primitive as a finished
String standard library or completion of the full v0 goal.
