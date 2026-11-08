# Grail

A self-hosted language/compiler exploring explicit ownership, checked arithmetic and compact,
uniform syntax. The compiler and runtime are written in Grail and emit native assembly for
Linux **x86-64, ARM64 and RISC-V 64**.

```grl
fn main() {
    mut data = u8[10, 20, 30];
    data.push(40);
    println(data[1]);
    println(data.pop());
}
```

- **Learn:** [Grail by Example](book/README.md), an offline book with runnable Rust comparisons.
- **Build / cross-compile:** [compiler/README.md](compiler/README.md).
- **Semantics:** [compiler/NATIVE.md](compiler/NATIVE.md).
- **Tests:** `bun tools/test-native.mjs` and `bun tools/book.mjs check`.
- **Proposed numeric types:** [docs/design/numeric-types.md](docs/design/numeric-types.md) (partly implemented: sized integers, `f64`, `f32`, `char`).

Build the compiler with `bun tools/native.mjs build` (Bun, Clang assembler and LLD required).
There is no Rust seed or C-backend dependency. `just book` builds and opens the offline book;
Rust is needed only to verify the book's Rust counterparts.

This remains a work-in-progress language, not a promise of complete v1 library support.
The Windows x86-64 backend emits and links PE32+ console images, and its runtime layer covers
console output, files, exit codes and argv under Wine; threads, sockets and unwinding are still
missing (see [docs/design/windows-backend.md](docs/design/windows-backend.md)).
Additional numeric primitives and structured concurrency are not yet implemented. Historical research under `research/` records earlier design experiments.
