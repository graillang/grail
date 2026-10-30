# Experiment 05: dependency state transformers

Ongoing research, not a new adopted language design or full compiler. The concrete failure mode is
false retention after clearing/replacing a container, or lost retention when returning old data while
mutating the caller's storage. Existing read-only contracts cannot guard this stateful interface.

## Domain and boundaries

Types reuse a restricted subset of experiment 02's structural vocabulary. This experiment admits unit/shared-view
leaves, records and lists; generic T ranges ONLY over this view-data domain.
Bytes, callbacks, exclusive references, arbitrary destructors and finish-or-abandon resources are
excluded. Dropping view-data has no external dereference/effect in this model. Runtime allocation,
container backing-storage borrows, raw pointers, actual async I/O and code generation are not modeled.

Shared views refer to external owner generations. Mutable access changes view-containing values,
not those external owners. A Vec-like container stores view payloads; no first-class pointer to its
own element slots is admitted. Record paths can be projected; arbitrary index/heap updates are not
admitted. Nonoverlapping mutable caller locations are required before strong updates apply.

## Contract meaning

For each result/post-state position the contract names a union of ENTRY-state argument positions.
An opaque generic prefix route preserves the descendant dependency positions of T. A source is
`pre(argument,path)`, never a reference to the caller's already-updated current argument.

The post-state map is complete for every mutable parameter. It can:
- preserve dependencies (an explicit entry-state source),
- add new sources (union),
- replace them (only the new source), or
- erase them (empty route map, when the value is empty/unit).

Result and mutable post-states are instantiated from ONE entry snapshot and committed together.
Composition substitutes a callee's entry sources through the caller's current state. Unknown branch
choices join each state's possible dependencies; branch correlations are not preserved. Public bounds
must overapproximate both returned and retained sources. A bound preserving extra roots is safe but
can reject useful clients. This experiment does not claim universally principal/minimal contracts.

## IR and ownership fragment

Small procedural operations: append a moved payload, clear a sequence, replace a value while saving
its old value, move all elements out, swap disjoint places, make empty data, call an imported contract,
structured branch, and return a moved/copied value. Parameter modes are read/mut/take. Copy is derived
only for unit/views/records thereof; opaque T is not assumed Copy. Noncopyable arguments/locals must
be explicitly moved. Moves here enforce abstract binding availability, not physical allocation rules.

Conditional resource ownership, strong updates through shared aliases, loops/recursion and failure
paths are later extensions. Keep the first experiment small enough to compare to a separately written
finite concrete evaluator before adding any of them.

## Testing and trust

Infer symbolic transformers from typed bodies, serialize, hide bodies from consumers, and check
clients using the contracts. Compare with concrete sequence/record operations and external owner
generations, using distinct sources and finite branches. Detect snapshot/order mistakes and reject
aliased mutable arguments. Test public refinement and deliberately incorrect artifacts.

There is no machine-checked proof or semantic authentication of an arbitrary artifact. The producer,
abstract type/domain restrictions and loaded interface are in the TCB. No passing result establishes
the full Grail memory model, optimizer correctness, runtime speed or general source inference.

Base types are unified independently of dependency sets. Two values may instantiate the same T
while depending on different owners; the transformer explains the resulting state. This is a
research choice, not a proof that qualified first-class mutable-reference types can ignore variance.

## Restricted preservation statement (proof obligation, not proved)

Let support(v,p) be the external owner-generation tokens in concrete value v at data position p.
A concrete state is covered by an abstract state when base shapes agree and support at each position
is a subset of the corresponding dependency set. List positions union element support at `*`.
Entry sources are interpreted using the caller's entry snapshot, including opaque prefix expansion.

Candidate statement: if entry states are covered, input views are valid, mutable/move access is
exclusive, and imported contracts satisfy the same statement, then every **normal** execution of an
accepted procedure has its returned value and mutable post-state covered by the inferred contract.
No body step changes external generations. Caller invalidation is a separate operation, permitted
only after all retained dependency sets exclude that owner's old generation.

The intended induction obligations are: clear has empty support; append takes the union; replacement
saves old support and installs new support; swap uses the same old state for both sides; move transfers
binding availability; local drop has no relevant effect in this domain. Each branch is included in
the union, and contract substitution is monotone. Calls additionally require disjoint write places,
shape substitution and the imported-contract hypothesis. A frame argument is required for untouched
record fields. This is an explicit proof outline, **not** a checked theorem or completed proof.

The client harness uses explicit drops of dead bindings, not a general liveness analysis. Copy take
arguments are snapped before mutable access; noncopy take moves are exclusive. Read access to a
container and mutable access to an overlapping place are rejected. A shared view is to an external
owner, not to the mutable slot holding the view. Those are different forms of aliasing.
