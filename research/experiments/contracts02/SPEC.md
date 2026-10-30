# Origin/capture inference experiment: bounded contract semantics

This is a typed-IR dependency experiment, NOT a Grail compiler, complete borrow checker, parser,
interpreter of machine code, formal proof, or settled language design. Python standard library only.

## Fragment

Types: unit, owning byte-storage places (inputs only), shared views, records, uniform lists,
recursive trees with a fixed payload type, opaque type variables, captured-value records, and a
single scoped-callback protocol. The types/parameter access modes are supplied; origins are inferred.
Output records/lists/trees own their descriptor structure conceptually; node allocation/reclamation
and moves of owning values are NOT modeled. All exported views are shared. Generic values may
contain shared views but not owning storage or exclusive references in this experiment.

Provider expressions: parameter, projection, borrow input storage, record/capture construction,
list/tree constructors, nondeterministic choice, function call, unit, and scoped visit. A deliberately
invalid local-view expression tests escape rejection. No pointer arithmetic, external global state,
user-defined destructors, allocation effects, arbitrary mutable view returns, or arbitrary handlers.
Unknown operations/types are rejected, not treated as pure or safe.

Provider functions that invoke modifying callbacks return unit; they cannot mix arbitrary mutation
with view-producing expressions. Callbacks use fresh invocation-bounded views and a restricted body
language. They may inspect/modify their item and read declared captures, but cannot retain the fresh
view in caller storage, including through aggregates/captured values. This models a protocol, not
inference of arbitrary higher-order function types or general callback effects.

## Contract meaning

For each result field/container-payload path, a finite set names possible sources:
- `storage(i,path)`: returned view refers into owning input storage at parameter i/path.
- `loan(i,path)`: returned view preserves an incoming shared view's origin.
- `prefix(i,path)`: opaque generic forwarding preserves ALL descendant view paths without
  enumerating the instantiated type. Composition substitutes paths, not caller root identities.

Paths through homogeneous containers use `*`; recursive tree depth is collapsed to the payload
path. Union loses branch and element correlations. A projection keeps only the selected subtree.
This does not distinguish different nodes/elements of one container.

Recursive functions use a dependency worklist and monotone least-fixed-point origin sets. An
existential may-return flag prevents exporting an entirely nonproductive recursive definition as
an origin-free fabricated view. This is not a termination proof; supported definitions may diverge.
Input/result type skeletons are given, not inferred by theorem proving. No root-per-client analysis
or specialization occurs. Generic calls substitute types and provenance symbolically.

Source sets are interned in serialized contracts; paths refer to set IDs. This avoids repeating
identical sets, not all possible quadratic relational information. Dense distinct field/source sets
are an adversarial size test, not hidden behind a universal compactness claim.

## Client checking

Clients see serialized contracts only. Owning-place names designate storage, not duplicable owning
values. Operations create owners, call functions, project values, create callbacks, use values,
invalidate storage, end storage, or drop a binding. Future SSA uses end view lifetimes automatically;
field-sensitive future uses can release an unused sibling field's dependencies. Whole-value use
keeps all fields. Invalidation/end is rejected while an overlapping live view remains.

Input read/modify access modes reserve transient access for a call. Conflicting arguments or
captured aliases are rejected. Shared outputs retain substituted input dependencies. Record fields
are disjoint; wildcard elements and prefix paths conservatively overlap. Bounds, array slices,
true address aliasing, arbitrary control-flow liveness, ownership transfer and task scheduling are
outside this model. The checker is only meaningful under this storage/path model.

## Trust and falsification

Inference checks typed provider bodies and emits source/dependency digests. Decoder validates
shape, route indices and kinds; it does NOT prove a semantically plausible contract truthful.
Consumers trust this experimental inference implementation/export artifact, as ordinary compilers
trust type exports. A well-typed forgery can violate that assumption: tests must demonstrate this.
No inference result is described as independently proof-certified.

An independently implemented finite concrete dependency evaluator enumerates bounded choices and
recursive unfoldings. Every concrete returned dependency must be admitted by the inferred contract.
Randomized finite checks and adversarial tests detect bugs but are NOT a soundness proof. Truncated
or zero-result explorations are reported, not counted as checked executions.

Primary targets: recursive borrowed-parser-shaped trees, leaves projected from input ASTs, independent
record fields, generic identity/wrapping, captured views, callback non-retention, aliases/invalidation,
recursion, unsupported operations and summary growth. These tests model dependency behavior, not a
complete real parser implementation or its semantic correctness.
