# Generic value layouts and type-only modules

This records the first **implemented generic-layout slice**, following the
[lowering assessment](generic-lowering-gates.md). It is not completion of bootstrap v0 or generic
functions/general typed references at that checkpoint. [Generic functions](generic-functions.md)
now implement the subsequent by-value body/IR/invalidation gate; the descriptions below of
concrete-only functions and module schema 4 record the earlier slice, not the current format.

## Source surface

`seed/std/core.grl` is a real source-hidden type-only library, not a module with a dummy entry:

```grl
module core;
pub enum Option<type T> { None, Some(T) }
pub enum Result<type T, type E> { Ok(T), Err(E) }
pub struct Pair<type T, type U> { first: T, second: U }
```

Declarations distinguish lifetime parameters from type parameters explicitly. Lifetimes precede
`type` parameters, e.g. `struct Mixed<a, type T> { span: read<a>, value: T }`. Applications use
`Mixed<a, string>` or `Result<Token<a>, string>`. Parameters are positional within their respective
namespaces, and duplicate/reserved parameter names diagnose. Named type arguments must resolve even
when physically unused by a phantom layout.

Constructors can give their complete type:

```grl
let result = core::Result<core::Pair<num, string>, string>::Ok(
    core::Pair<num, string>{first: 7, second: "name"}
);
let pair = result!;
```

Omitted constructor type arguments can be taken from the written function result when its nominal
name matches, so `return core::Result::Ok(value);` and `Err(error)` work. This is not general local
inference: otherwise generic constructors require explicit arguments. `?` carries the **complete
written enclosing result type**, so propagation can change the success type while preserving the
error type/mode/origin. No error conversion, rollback, or exception runtime is added.

Public `struct`/`enum` declarations are exported even without a function mentioning them. Reachable
layout definitions and nominal type arguments form a closed interface. Types-only modules have
**no entry**, compile to real immutable C/object/API artifacts, and participate in dependency hashes.
Attempting to build one as an executable diagnoses; it does not fabricate a callable alias or entry.
Existing first-public-function entry behavior remains for modules with function exports.

## Checking and substitution

`Ty::Param` is a template metadata variable; no unresolved parameter reaches a value-checking state,
function signature, or native lowering. Layout declarations are checked symbolically for parameter
scope, references, arities, and bounded by-value expansion. Application substitutes lifetime slots in
**template syntax** and substitutes type slots with actual arguments. An inserted type argument is
not recursively rebound through the callee's lifetime slots: it retains its enclosing lifetime scope.
The mixed-two-lifetime test would fail or return the wrong origin if this distinction were lost.

Concrete instances reuse the existing recursive ownership, captured-root, mode, partial-move,
match/unwrap/propagation, and default-destruction checks. Nested generic shape/mode mismatches reject;
actual producer returns still independently verify all captured origins against their written results.
Nominal aggregates remain affine even when all instantiated fields are numeric; numeric/unit fields
retain their scalar copy behavior. No blanket clone or trait machinery is implied.

The old name-only layout dependency walk was removed. Physical expansion uses substituted fields:
`A { p: Phantom<A> }` is finite when `Phantom<T>` stores only a number, whereas `Wrap<A>` storing
`A`, or an indefinitely growing `Growth<Wrap<T>>`, rejects. Type-expression depth and expanded
physical-layout depth are bounded at 64, expression/expanded-layout nodes at 4096, lifetime/type
parameters and fields/variants at 64, and declaration counts at 4096. Empty nominal nodes count too.
There is no global 4096-**native-instance** cap silently inferred from the declaration cap.

C emits only reachable **concrete physical instances**, in dependency order. Instance identities
contain nominal names, concrete argument shapes/modes, and lifetime-slot arities, but erase lifetime
**values** recursively. They never include caller/root/loan IDs. Generic C names hash that canonical
physical key; non-generic C names retain their prior spelling. Separate native objects agree on
layouts without exposing provider source or borrowing inference. There is no generic-function body
specialization cache yet: its checked-template/private-helper/body-invalidation requirements remain
those in the lowering assessment.

## Canonical boundary

Module schema **4**, function schema **6**; old artifacts must rebuild, with no compatibility reader.
The nominal word retains its name/lifetime prefix and appends length-delimited argument words,
e.g. `tcore::Result@[1#n1#s]`. Commas remain unambiguous function-parameter separators. Template
variables have indexed words (`p0`, etc.); unbound occurrences reject.

Decoders bound lengths, arities, depth and nodes before recursive expansion. Producers also bound
expressions **before formatting** and enforce the complete 64 KiB function / 8 MiB module limits.
Canonical re-encoding rejects leading-zero lengths, redundant empty argument lists, malformed UTF-8
boundaries, truncations and obsolete schemas. Public fingerprints include template arity, bodies of
layout definitions, argument structure, variant order and entry absence; dependency checks follow
transitive contracts separately from the public surface hash.

## Evidence and remaining gates

Reproduce: `python research/experiments/generic36/check.py`.

The retained gate includes full stable/pinned-nightly suites, clang/TinyCC ABI crossings in both
directions, immutable-source-hidden `core → parse → client → app`, independent Rust numeric/error
results and complete destructor traces, allocator balance, and optimizing ASan/UBSan C probes.
Variant reordering in the type-only provider invalidates a transitive stale build while preserving
its previously published artifact/executable. New tests also cover mixed lifetime/type substitution,
phantom references, nested sums/records, ownership/mode/origin negatives, byte bounds and schemas.

Exact allocation traces require observation-preserving flags for optimizing C probes: clang `-O2`
can legitimately remove unobserved malloc/free pairs. The retained negative control has zero
allocations; with allocator builtins disabled the wrapped trace is `[3,4,2,1]`. This does not change the
production native driver's profiles or promise observable allocator calls in optimized programs.

Cost measurements compare a frozen prechange compiler, unchanged explicitly expanded programs,
and actual generic-layout programs at 8/32/128/256 instantiations, with three repeats and deterministic
C/API checks. See the [retained evidence](../../research/evidence/generic36-20261031/README.md).
These are compiler-shape/layout workloads, not a self-hosted compiler or proof of generic scalability.

General typed borrowing/mutation of aggregates, mutable-container invariance and opaque writeback,
real generic function bodies, vectors of arbitrary `T`, reusable cursor APIs, the Grail compiler port
and deterministic stage-2/stage-3 bootstrap **remain unfinished**.
Actual [native development/release profiles](native-profiles.md) are now delivered separately.
The existing by-value byte-view constructor lifetime placeholders are not evidence for a sound
`&mut T` implementation; the hard invariance/writeback gates have not been weakened.
