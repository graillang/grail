# Grail seed slice

A reusable Rust checker, first `.grl` source frontend, and C/LLVM emitters. This is a narrow
implementation slice, not a complete Grail compiler. No external Rust crates or network are required.

```sh
cargo test --manifest-path seed/Cargo.toml --offline
cargo clippy --manifest-path seed/Cargo.toml --offline --all-targets -- -D warnings
cargo build --manifest-path seed/Cargo.toml --offline --release
seed/target/release/grail-seed provider seed/.work/demo 0 1 c
seed/target/release/grail-seed client seed/.work/demo seed/.work/demo/scan.api 1024:2 c
seed/target/release/grail-seed scale 4096
```

`provider OUT BIAS VERSION c|llvm` and `client OUT API LEN:REPEATS c|llvm` construct fixed
workloads through the public typed-IR API. They write native source plus a canonical signature.
They are demonstration commands, not a surface-language parser or general build system.

## Supported semantics

- Owned local byte buffers and growable heap byte vectors; affine read/write views and carriers.
- Explicit region labels in signatures. Labels describe lifetime relationships, **not** target
  identity. Separate mutable input parameters have distinct abstract targets even with one label.
- Reborrows of exclusive carriers restrict them; readonly byte-view derivation copies the
  descriptor without freezing that readonly carrier. Moves preserve loan identity. Owner release/movement
  requires all views to end. Calls consume view arguments; explicit reborrows retain a parent.
- Returned references may originate only from suitable input regions. No local-buffer escape.
  Imported return bounds conservatively retain every compatible argument origin and parent.
- Counted and while loops require the same resource state at their back edge. Numeric state may change;
  loop-local resources must end. The lowered IR has explicit `End`; the source frontend infers
  borrowed-value endings and inserts lexical owner cleanup.
- Numbers are wrapping u64; buffers hold bytes. Native indexing and remainder have abort guards.
  `buffer` is stack allocated (individual maximum 1 MiB); `bytes` is heap allocated and grows
  only when unborrowed. Stack exhaustion is not prevented.
- A private validated wrapper gates lowering. Interfaces describe types/regions only, no G1
  post-state inference. Signature decoding validates schema and canonical form, not producer honesty.

Records, tagged enums, consuming match, early returns, `!` unwrap and `?` propagation are supported
with recursive default cleanup. [Generic value layouts](../docs/design/generic-layouts.md), public
types and type-only modules support concrete `Result<T,E>`/`Option<T>`/`Pair<T,U>` uses; functions
remain concretely typed. Generic function bodies, general typed references/containers, closures,
reference-containing heap elements, async, effectful custom destructors, capabilities, interface
authentication and a language soundness theorem remain unfinished.
Numeric branches and byte slicing are now supported in both emitters.
The compiler's own safe Rust is not a proof that the new checker is sound. The first scaling
probe exposed repeated whole-state scans. Indexed loan checks now remove those scans; deep
ancestry and origin unions still need measurement.

## Native boundary

C lowers the checked IR, including heap owners. LLVM currently rejects owned heap layouts
explicitly and remains a comparison backend for the earlier subset. The workload scans bytes, counts word starts, computes a
rolling hash and updates a byte bucket table. The client holds its input view in a carrier and
calls the body-hidden provider repeatedly. LLVM uses simple alloca-based locals; these emitters
are not optimized or portable-ABI-certified. Native execution is currently checked on Linux x86-64.

The TinyCC driver in the prior Goose build is usable, but is configured for embedded/JIT use.
Standalone linking needs explicit host CRT objects, libc paths and its staged support archive;
this is recorded by the measurement harness rather than changing third-party sources.

## Measurements

[Results and limitations](../docs/design/seed-measurements.md). Reproduce with:

```sh
python seed/measure.py --pairs 10 --length 262144 --repeats 16
```

Requires Linux wait4/bubblewrap, clang, rustc/cargo, and the existing pinned Goose/TinyCC build
under `research/experiments/memory01/.work/goose-build`. It rebuilds baseline `d6ac951` in owned
scratch, preserves all measured samples and aborts on nonzero exits or checksum mismatches.
The driver is Python orchestration; it is not a replacement for the Rust seed or its future
Grail implementation. It does not download tools, contact models, or modify external sources.

## First source-to-native path

[Bootstrap v0 rules and limits](../docs/design/bootstrap-v0.md). Requires clang for the default
native driver; Cargo itself still has no third-party crates.

```sh
cargo build --manifest-path seed/Cargo.toml --release --offline
seed/target/release/grail-seed compile seed/examples/number.grl seed/.work/source seed/.work/source
seed/target/release/grail-seed build seed/examples/sum.grl seed/.work/source seed/.work/source
seed/.work/source/sum '12+34+5'  # 51
cargo test --manifest-path seed/Cargo.toml --offline
cargo test --manifest-path seed/Cargo.toml --offline --test native -- --ignored
```

For the configured TinyCC driver, set `GRAIL_TCC_ROOT` to the existing Goose build root and append
`tcc` to both compile/build commands. There is no silent fallback or download. Source modules have
one exported function; only direct imports are linked. The parser example borrows slices rather
than allocating token copies. Malformed numeric input aborts, and the executable expects exactly
one text argument. Generic heap containers, Result and type generics are still follow-up work.

## Heap byte owners

[Semantics and limits](../docs/design/heap-ownership.md). `bytes()`, `push`, `copy_bytes` and
owned `bytes` parameters/results are supported by the C backend. Function-signature payloads are schema 5 (see the source-module format below);
rebuild old `.api` files. Heap owners drop at scope exit, not at borrowed-value last use.

```sh
seed/target/release/grail-seed compile seed/examples/make_bytes.grl seed/.work/heap seed/.work/heap
seed/target/release/grail-seed build seed/examples/use_bytes.grl seed/.work/heap seed/.work/heap
seed/.work/heap/use_bytes  # 125717
cargo test --manifest-path seed/Cargo.toml --offline --test heap_native -- --ignored
```

## Owned text

[UTF-8 contract and limits](../docs/design/owned-text.md). `string` values, quoted literals,
`text(...)` copying/validation and `append_text(...)` are supported in the C path. Reading text
produces byte views; arbitrary mutable byte access to strings is rejected. Rebuild schema-2 APIs.

```sh
seed/target/release/grail-seed compile seed/examples/echo_text.grl seed/.work/text seed/.work/text
seed/target/release/grail-seed build seed/examples/text_check.grl seed/.work/text seed/.work/text
seed/.work/text/text_check 'hé🙂'  # 389107
cargo test --manifest-path seed/Cargo.toml --offline --test text_native -- --ignored
```

## While loops

`while condition { ... }` re-evaluates the condition each time (unlike a counted range's captured
bound). Temporary owners/loans created by the condition end before entering the body or taking
its false exit. Continuing paths keep the balanced-ownership back-edge restriction. Early returns
clean the whole function; `break` and `continue` are not yet implemented.

```sh
seed/target/release/grail-seed build seed/examples/while_sum.grl seed/.work/while seed/.work/while
seed/.work/while/while_sum 123  # 150
```

## Lexical binding scopes

`let`/`var` may shadow an earlier binding, including a parameter or loop index. The initializer
still sees the old binding; each declaration creates a distinct register/storage identity. Inner
bindings leave the name environment at `}`. Duplicate parameter names remain errors.

Standalone `{ statements }` blocks create a lexical cleanup boundary without a branch. New owners
are released in reverse binding order there; shadowed enclosing owners remain alive until their own
scope ends. Unlike a conditional join or loop back edge, unconditional blocks preserve actual moves
and explicit drops of enclosing values: using a consumed outer binding afterward is rejected.
Borrowed temporaries still end at last use. Blocks do not yet yield expressions or support early
returns, `break`, or `continue`. Assignment remains numeric-only; shadowing can change a name's type.

See `examples/scopes.grl`. The source/IR checks and allocator-audited native suite cover shadowed
owners, moved/dropped outer owners, name restoration, and loans surviving name shadowing.

## Function argument values

User-function arguments evaluate left-to-right. Each numeric argument is copied and each affine
argument is moved to a fresh value **before** the next argument evaluates. Thus `take(b,len(b))`
is invalid when `take` consumes `b`; compute `let n=len(b);` first and call `take(b,n)`. Explicit
readonly reborrows such as `take(read(p),len(p))` retain `p` when the types permit them.
Builtin storage operations (`len`, `read`, `copy_bytes`, etc.) use their documented borrowing/place
rules; they do not consume an owner simply because it appears as an operand.

## Source modules, exports and recursion

An implicit module is named after its first function, which is exported. For a library, use an
explicit identity and mark its real public functions (private helpers may appear first):

```grl
module arithmetic;
fn next(n:num)->num { return n+1; }
pub fn add(n:num)->num { return next(n); }
pub fn twice(n:num)->num { return n*2; }
```

A client writes `use arithmetic;` and calls `arithmetic::add(7)`. Imported module names also alias
their primary export (the first public function); existing `use number; number(...)` source remains
usable. Within a module, local functions resolve by bare name. Headers are collected before each
independent body check, allowing forward, self and mutual calls without cross-body ownership
inference. Locals/lifetime-name scopes do not cross functions; unused helpers are also checked.
Duplicate function/import names are errors. Public native symbols are namespace-qualified;
helpers have internal linkage, so different modules may use the same private name.

`compile` emits `<module>.api` / `.o` / `.c`. Source interfaces now use **module schema 3**, carrying
all public function signatures, reachable nominal type layouts, the primary export, and expected direct-dependency surface hashes.
Rebuild prior source artifacts: there is no source-schema fallback. The standalone typed-IR fixture
commands still actively use function-signature schema 5, also the function payload inside a module.
`source::compile` returns a flat `CheckedModule`; use `emit::module_c` / `module_llvm`. The raw IR
checker and its single-function emitters remain available for the existing conformance fixtures.

`build` follows transitive metadata dependencies and links each object once, without provider
source. It rejects cycles, wrong module identities and stale dependency contracts before replacing
the client's artifacts. A private-body-only rebuild does not invalidate callers. Fingerprints use
SHA-256 over the canonical **public** surface, not implementation bodies or dependency build state.
A change to any public member conservatively invalidates every direct module-dependent artifact.
There is no persistent incremental build cache or automatic dependency rebuild yet.

Native builds use immutable, content-verified generations under `.grail-store/<id>/`, selected by
an atomically replaced `<module>.artifact` pointer. Each generation binds header, C and object
hashes in its manifest. Compiler link inputs are captured once from these generations, not from
the replaceable `.api`/`.o`/`.c` convenience copies. Metadata-only declarations can still be checked;
linking old flat objects requires rebuilding their producers. Failed native builds do not replace
the previous executable; successful binaries are also installed by atomic rename.

Compiler-owned concurrent publication is supported. This is not producer authentication or a
sandbox against hostile filesystem writers modifying a captured generation after verification.
Power-loss durability/fsync guarantees, generation garbage collection and automatic rebuilds are
not implemented. Old generations remain available for captured links and reproducible retention. Interfaces are bounded to 8 MiB, modules to 4,096 functions, and
link closures to 4,096 modules / 256 dependency depth. Native stack exhaustion is not prevented.
Basic by-value records, tagged enums and public layout metadata are implemented; generic containers,
general mutable references and self-hosting remain unfinished.

```sh
seed/target/release/grail-seed build seed/examples/functions.grl seed/.work/functions seed/.work/functions
seed/.work/functions/functions  # 146
```

Native C inputs use stable relative basenames inside isolated work directories. TinyCC otherwise
embeds the random job path in its ELF `FILE` symbol. The artifact suite tests identical generations
and executable bytes across repeated and relocated builds for clang and TinyCC, parallel compiler
jobs, synchronized publishers/readers, corruption detection and linking a previously captured version.
These primitive-program checks are not stage-2/stage-3 self-hosting.

## By-value records

See [record core](../docs/design/record-core.md) and `examples/records`. Mixed records can own a
string and capture a borrowed span. Nested field moves preserve remaining cleanup/loans; byte-view
borrows of fields do not consume them. Default record cleanup is recursive and skips moved fields.
This is not general `&Record` support, generic containers, full join/early-return cleanup, or v0
completion. The LLVM comparison backend explicitly refuses record layouts; native C supports them.

Structured bodies support early returns in branches, blocks and loops. Cleanup runs before each
return, excluding the returned owner; every exit checks its written lifetime contract. Equal resource
states (including equal partial moves) may join; unequal continuing resource states still diagnose.
Postfix `!` consumes an `Ok/Err` or `Some/None` enum, transfers success, and aborts on failure.
Exhaustive `match` provides explicit recovery; postfix `?` propagates matching errors/None with
normal return cleanup. Generic Result/Option remain unfinished.
See [tagged enums](../docs/design/tagged-enums.md).

## Generic value library

[Rules, evidence and remaining gates](../docs/design/generic-layouts.md). A type-only provider has
no callable/executable entry. Compile its real source before the concrete provider/client:

```sh
mkdir -p seed/.work/generics
seed/target/release/grail-seed compile seed/std/core.grl seed/.work/generics seed/.work/generics clang
seed/target/release/grail-seed compile seed/examples/generics/parse.grl seed/.work/generics seed/.work/generics clang
seed/target/release/grail-seed build seed/examples/generics/client.grl seed/.work/generics seed/.work/generics clang
seed/.work/generics/client 42  # 47
```

The client needs only immutable checked provider artifacts; source-hidden tests remove both provider
sources before compiling it. Rebuild prior artifacts for module schema 4 / function schema 6.

## Native profiles

The last `compile`/`build` argument is `clang` (default development, `-O0`), `clang-release`
(optimizing native release, `-O2`) or `tcc` (configured fast development). Both object compilation
and executable linking use it. Checking/interfaces/emitted C are unchanged across profiles.
[Reproducibility, tested crossings and limits](../docs/design/native-profiles.md).

This is distinct from Cargo's `--release`, which optimizes the **Rust seed executable itself**.
A full linked-executable recipe manifest and hermetic bootstrap toolchain are not implemented yet.
