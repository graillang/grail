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

A source file may begin `module name;` followed by imports, private helpers and `pub fn` exports.
Explicit modules use their first public function as the primary export/build entry; no dummy
function matching the module name is required. Without a module declaration, its first function
supplies the implicit module name and is exported. Headers are collected before independent body
checks, allowing forward/self/mutual calls. Local variables and lifetime-name scopes do not cross
functions. Other module exports are called through `module::function`; the imported module name
also aliases its primary export. Functions optionally declare region names:

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
name registers and the source file, not rich source spans. Lexical shadowing and standalone blocks
and nested/early returns are supported. Assignment requires `var` and currently succeeds only
for numeric registers. Shadowing creates a fresh binding and may change the name's type.

## Local loan ending, conservatively

A backwards register-liveness pass inserts explicit IR endings. The forward ownership checker
still validates every inserted operation; the frontend does not bypass it. Dead child views end
before their parents/owners. Root/access indexes keep numeric temporaries out of resource cleanup.

Branch and loop entry resources are kept across their structured body, and back edges/joins
require unchanged ownership. Local loans may end inside those blocks. This is not Rust's complete
NLL/partial-move/conditional-initialization analysis. Unconditional standalone blocks instead keep
actual ownership effects: an enclosing owner may be consumed there, but cannot then be used outside.
New block owners clean up there; shadowed outer owners retain their original lexical lifetime.
Origin sets, liveness snapshots and deep
ancestry can still become expensive; earlier typed-IR timings do not cover this source frontend.

## Module/native boundary

`compile FILE OUT IMPORT_DIR [clang|tcc]` checks source, emits C, compiles an object, then publishes
its `.api`. `build` additionally links an executable with direct imported objects. Imports consume
`.api`/`.o` files, never provider source. Source module schema 3 carries public function signatures, reachable nominal record/enum layouts,
entry identity and direct dependency surface hashes; standalone signature schema 5 is the function
payload. Old source artifacts must be rebuilt. Builds validate and link transitive metadata
closures once per module, reject cycles/stale contracts, and keep private helpers internal. Body-only
edits do not invalidate callers; changes to any public member conservatively do. A persistent build
cache and automatic rebuild scheduling remain unimplemented. Native linking captures immutable
content-verified module generations, with atomic generation-pointer and executable replacement.
A manifest binds header/C/object hashes; the replaceable convenience files are not link snapshots.
Compiler-owned concurrent publication is covered, but producers and host filesystems remain trusted:
a hostile mutation after verification is not prevented. Power-loss/fsync durability and generation
collection are not implemented. Stable relative native source basenames remove temporary paths from
TinyCC ELF file symbols; repeated/relocated native outputs are tested, not self-hosting stages.
An executable accepts no parameters, or one read byte view backed by argv[1],
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

## Heap byte checkpoint

[Owned byte vectors](heap-ownership.md) now implement real heap allocation, explicit deep copies,
growth restrictions and lexical cleanup, including ownership transfer through schema-2 interfaces.
They are the first heap gate, not generic containers or a completed standard library. The earlier
source-slice description above is historical where it excludes all heap ownership. Follow-up gates
remain records/enums, reference-containing elements, Result, general generics and self-hosting.

## Owned text checkpoint

[Owned UTF-8 text](owned-text.md) adds a distinct string invariant, explicit checked copying,
append operations and literal decoding, with schema-3 interfaces. Byte views remain byte views;
borrowed UTF-8 abstractions, recoverable conversion errors, generic containers and self-hosting
are still unfinished. Neither this nor heap byte ownership completes bootstrap v0.

## Readonly descriptor derivation

A readonly byte view is a pointer/length value: `read(read_view)` and a slice of it derive an
independent readonly descriptor, not a borrow of the old descriptor's storage. The old readonly
carrier may be read, moved or ended while the derived view lives. Its data owner must remain live,
and any exclusive ancestor stays restricted until **all** readonly descendants end. This is local
checking precision, not G1 post-state inference or a claim that arbitrary family projections are Copy.
It enables retaining lexer tokens while continuing to read the same source.

## While-loop checkpoint

The source/IR/C/LLVM paths now support `while condition { ... }` with repeated condition evaluation.
Condition temporaries have a distinct closed scope: owners are released before both body entry
and the final false edge, while enclosing owners stay live. Borrowed values needed on a back edge
remain live; a condition-only temporary view may end before the body grows its owner. Entry
ownership still must balance. General unequal partial-move joins and break/continue remain
unfinished rather than being declared unnecessary for v0.


### First record core (partial v0)

Explicit modules can declare `struct Token<a>{span:read<a>,name:string,offset:num}` before functions.
Construct, move/borrow fields, pass/return complete records, and recursively clean remaining owned
fields. Captured span loans are distinct from record/owned-name storage. Public layout definitions
participate in hashes; hidden-source clients and layout-only invalidation are tested. General
references to record/container objects, mutation through invariant reference-containing T, richer enum patterns,
Generic Result/Option, field assignment and unequal ownership joins remain unfinished. See
[record core](record-core.md) for exact current semantics, bounds and backend limitations.

### Unwrap shorthand and tagged enums

Postfix `!` now unwraps a two-variant `Ok/Err` or `Some/None` value: e.g.
`let token = result::parse(input)!;`. Failure aborts; it does not propagate or promise cleanup.
Exhaustive consuming `match` supports explicit recovery. Current enums have concrete payload types;
generic Result/Option remain subsequent v0 work. Postfix `?` now propagates matching errors or None
with ordinary checked return cleanup; see [propagation](error-propagation.md). See
[tagged enums](tagged-enums.md) for ownership, ABI, evidence and exact scope.

### Early return checkpoint

A `return value;` may terminate a block, either arm of an `if`, or an iteration of a loop.
Each exit checks the declared type and lifetime relationships. Remaining owned bindings are cleaned
in reverse-binding order (owned record fields recursively in declaration order), except for the
returned value. A moved-out field is not freed again. Default destruction ignores captured view
descriptors; live loans into owned fields still prevent release. Both native C and primitive LLVM
lowering honor terminators. See [return cleanup](return-cleanup.md) for join and performance limits.

## Generic functions checkpoint

[Universally checked by-value functions](generic-functions.md) now implement core library helpers,
static native materialization and transitive body invalidation (module 5 / artifact 2 / function 6).
Expression statements close results/temporary owners at statement end. General typed references,
arbitrary-element collections/cursors, remaining ownership joins and the real seed port plus
stage-2/stage-3/artifact delivery remain required; this is not completion of bootstrap v0.

## Typed storage groundwork

[Addressed scalar/owned storage](typed-storage.md) now supports lifetime-free typed references,
explicit reborrows and generic replacement with uniform mutable cell metadata updates. It does not
yet admit lifetime-bearing pointees; invariant witnesses, stored-source versus outer-frame bounds,
opaque capture writeback and real reference-containing containers/cursors remain required work.
