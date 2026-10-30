# Grail bootstrap v0: decisions and implementation boundary

2026-10-30. This is the initial bootstrap contract approved for implementation, not a claim that
all of it exists. The [seed](../../seed/README.md) is its first source slice. Changes to these
choices should be explicit decisions with examples, rather than silent inference growth.

## Chosen direction

- **Ownership:** affine owned values, explicit cloning, deterministic destruction. Reference
  relationships crossing interfaces are written; body-local types and loan ending are inferred.
  Keep lifetime relationships separate from referent identity and access authority. Full G1
  changing-content/post-state inference is not the foundation.
- **Bootstrap language:** functions, records, enums, pattern matching, loops, references and basic
  generics sufficient to express the compiler. No general macros, overlapping impls, specialization,
  general higher-ranked bounds or elaborate trait system initially. These are a target feature
  set, not features all accepted by the current parser.
- **Cleanup/errors:** owned fields/containers need compiler-generated recursive destruction;
  local destruction is reverse binding order at scope exit, including normal Result error returns.
  Result is an ordinary explicit enum, not rollback. Panics abort; no unwinding initially.
  User-defined effectful destructors and a public `forget` facility are deferred, not approximated
  by unverified hidden effects. Destruction is not a substitute for eventual scope-owned work.
- **Calls:** left-to-right argument evaluation. The first source slice has eager explicit borrows,
  not a two-phase reservation/activation protocol. Some nested arguments will need temporaries.
  Ordinary cross-call ownership decisions use declared signatures, not body-specific post-states.
- **Compilation:** Rust seed, C development path with TinyCC and clang options, optimizing clang
  as the initial release route. Retain LLVM emission as a comparison, not a parallel production
  backend project. Backend selection is explicit; no silent fallback. All remain in the TCB.
- **Generics:** check against declared interfaces/bounds, not caller-root specialization. Start
  with a simple implementation, and measure specialization versus shared development code before
  promising fast generic builds. Generic lowering and bounds are not implemented in the first slice.
- **Self-hosting:** port the seed once owned containers and the source subset can express it;
  compare stage-2/stage-3 deterministic output and conformance. Retain a reproducible bootstrap
  artifact. No async runtime, verifier, optimizer or complete library is a prerequisite for that port.

## What the first source slice actually accepts

One function per file, preceded by `use name;` imports. Functions optionally declare region names:

```grl
fn first<a>(input: read<a>) -> read<a> {
    return slice(input, 0, 1);
}
```

`num` is wrapping u64; conditions use zero/nonzero. `read<a>` / `mut<a>` are byte views, not yet
arbitrary `&T`; `read_holder<a>` / `mut_holder<a>` are the existing one-field carrier shapes.
Region names are generic lifetime labels only, **not** type parameters or target addresses. Their
positions serialize to the seed's canonical numeric labels. Source syntax may be extended when
base types/generics arrive; this is not a claim that these byte-specific aliases are a full type system.

- `let name = expression;`, numeric `var` assignment, tail `return expression;`.
- `for index in count { ... }` over 0..count, evaluating count once; `if condition { ... } else { ... }`.
- `+ - * % ^ & == != <`, decimal u64 literals and parentheses. `% 0` aborts.
- `len(view)`, `at(view,index)`, `slice(view,start,end)` (half-open, checked).
- `read(place)`, `mut(place)`, `hold(view)`, `write(mut_view,index,value)` and `drop(name)`.
- `assert(condition)` aborts on zero. The numeric parser example aborts on malformed input;
  recoverable parser errors await Result, not an implicit exception implementation.
- `buffer(length,seed)` in a binding constructs the prior seed's patterned local byte buffer,
  not a heap allocator or standard-library vector. The length/seed must be literals.
- Byte accesses, slicing and division are guarded. Slices preserve source origin and carrier
  restrictions. Reference values remain affine in this first implementation; reborrow explicitly
  when retaining the original. General shared-reference copying is not implemented.

The compiler tokenizes borrowed spans of its UTF-8 source file; identifiers/numbers in the grammar
are ASCII and comments begin `//`. Parsing errors carry byte offsets. Ownership errors currently
name registers and the source file, not rich source spans. Shadowing and nested/early returns are
not supported; assignment requires `var` and currently succeeds only for numeric registers.

## Local loan ending, conservatively

A backwards register-liveness pass inserts explicit IR endings. The forward ownership checker
still validates every inserted operation; the frontend does not bypass it. Dead child views end
before their parents/owners. Root/access indexes keep numeric temporaries out of resource cleanup.

Branch and loop entry resources are kept across their structured body, and back edges/joins
require unchanged ownership. Local loans may end inside those blocks. This is not Rust's complete
NLL/partial-move/conditional-initialization analysis. Origin sets, liveness snapshots and deep
ancestry can still become expensive; earlier typed-IR timings do not cover this source frontend.

## Module/native boundary

`compile FILE OUT IMPORT_DIR [clang|tcc]` checks source, emits C, compiles an object, then publishes
its `.api`. `build` additionally links an executable with direct imported objects. Imports consume
`.api`/`.o` files, never provider source; transitive module graphs and a persistent build cache are
not yet implemented. An executable accepts no parameters, or one read byte view backed by argv[1],
and returns a number printed by the generated C entry shim.

Producer checks must succeed before the signature is published; a rejected body does not overwrite
an earlier valid interface. This is not a transactional artifact store: interrupted native failures
can leave scratch C/object output, and schema validation does not authenticate object/signature pairs.
TinyCC support presently uses the existing configured Goose build on Linux x86-64, via an explicit
`GRAIL_TCC_ROOT`; platform coverage, stable ABI certification and FFI policy remain open.

## Exit evidence and next implementation gates

The source examples lex '+'-separated decimal spans and pass each borrowed token to a separately
compiled numeric parser. The native integration removes producer source before checking its client,
checks values and wrapping arithmetic, requires SIGABRT for malformed input, preserves the prior
interface on a bad producer edit, and checks new slice/branch lowering through direct LLVM emission.

This milestone is **not self-hosting**. Next are real owned strings/vectors and move/drop semantics,
records/enums and Result, then basic generics and source-level module tooling needed by the compiler.
No heap ownership, arbitrary stored references, closures, async, capabilities, optional verification
or general soundness proof is supplied by this first path. Existing restricted proofs remain separate.
