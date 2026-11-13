# Owned UTF-8 text checkpoint

> Design history: seed/C prototype details below are historical. The authoritative implementation
> and current build/test commands are in [compiler/README.md](../../compiler/README.md).

2026-10-30. An extension of [heap byte ownership](heap-ownership.md), not complete strings,
generic collections or self-hosting.

## Contract

- `string` is an owned, valid UTF-8 byte sequence. Its C layout is the byte vector's pointer,
  byte length and capacity. It moves across functions and drops at lexical scope exit.
- A quoted literal constructs an owned string. Source decoding supports `\n`, `\r`, `\t`, `\0`,
  `\\`, `\"` and `\xHH`. Decoded UTF-8 is checked in the source frontend **and** in the typed-IR
  checker, so directly constructing a bad literal IR cannot bypass the invariant.
- `storage_or_view.text()` explicitly validates and copies bytes into independent owned text.
  Invalid UTF-8 aborts for now; a recoverable Result-based constructor remains a future gate.
- `owner.append(storage_or_view)` validates its source and appends, preserving UTF-8.
  It requires the destination to be unborrowed. Direct self-append is rejected; make an explicit
  copy when needed. No hidden copy-on-write, reference counting or dynamic borrow tracking.
- `&string` yields a **byte view**, not a separately typed UTF-8 `str` view. Byte slicing
  may split a code point; converting that slice back to text validates again. `.len()` counts bytes.
- Mutable byte borrowing of strings and raw byte `.push(...)` on strings are rejected. `.copy()`
  can make an independently mutable byte-vector copy without weakening the string invariant.
- `let` fixes the binding; uniquely owned contents may be modified by their operations. `mut`
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

## Mutability of a binding that holds text

2026-11-13. Recorded while making the diagnostics for this case precise.

A string literal constructs an owned `string`: UTF-8-validated, immutable text. `mut` on the
binding therefore makes the **binding** reassignable — it may name a different string — and never
makes the bytes writable. This is exactly Rust's rule for `let mut s = "x"`, whose type is
`&'static str`: `s = "y"` compiles, `s[0] = 65` does not, and `&mut s[0]` does not borrow writable
bytes. Grail keeps the same prior art because the alternative — `mut` reaching through a handle
into read-only text — would make the checker's `mut` mean two different things depending on the
type behind it, and a literal's bytes are shared static data anyway.

Editing bytes is a separate, explicit step. `s.copy()` produces an independently owned `u8[]`
(already documented above as the way to make mutable byte storage without weakening the string
invariant), and that vector's elements can be written. `view("literal")` is the same rule without
an allocation: a static readonly byte view, writable only by copying it into mutable storage.

The two places that used to report only the shape of the place now name the reason:

- `s[0] = 65` and `&mut s[0]` on a `string` report `a string's bytes are immutable: a string
  literal is read-only text, and `mut` on a binding makes the binding reassignable, not the
  bytes; copy them into a mutable byte vector to edit`.
- Writing through a readonly byte view (`&[u8]`) keeps its own message: it needs an exclusive
  view, `&mut [u8]`.

Corpus: `ergo-mut-string-literal-reassign`, `-typed-reassign`, `-copy-editable`,
`-refuse-write`, `-refuse-mut-borrow`.
