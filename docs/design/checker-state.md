# Path state and the monotonic type ledger

The first early-return/propagation checkpoints copied every historical scalar Value and register
Ty map at every branch. Scalar-only functions therefore showed roughly quadratic checking growth:
1,000 `if` exits took about 0.4 s; 1,000 `?` sites took about 1.7 s. These were real seed measurements,
not a type-system requirement. The state34 checkpoint removes that avoidable work.

## Invariants

- Register types are a single monotonic function-local ledger. Branch checks share its builder;
  every write checks the register's fixed type. Conflicting types still reject even on separate
  terminating paths. The completed checked function owns the resulting plain ordered map. No owner,
  loan, access counter, capture state or capability is shared mutably between path states.
- Scalar values (number/unit) have no resources, origins, descendants or loan ancestors in the
  current language. Backwards liveness discards only their unused Value facts. Every use must still
  find an actual defined Value; a known type never creates one. Reference/owner Values are not
  removed by scalar pruning. Heap destruction remains lexical, not last-use destruction.
- A separate compact bitmap preserves scalar **definedness**, including dead bindings. Explicit
  endings clear it; continuing branches intersect it; closed loop/test scopes restore it as before.
  This preserves counted-loop index freshness. The initial optimization missed this fact and a new
  adversarial test caught the accidental acceptance of a reused dead parameter as an index. That
  version was never landed.
- Structured body checking preserves entry scalar facts needed for the existing back-edge checks.
  Dead arm-local payload bindings are killed in match live-in computation; they are not inputs to
  their own definition. If live-in is the union of its arm live-ins plus the condition, not a union
  with registers defined only inside those arms.
- The source frontend uses the same IR liveness helpers while validating inserted cleanup. Raw IR
  checking also prunes copy facts but still independently validates all ownership transitions and
  every return. No unchecked frontend escape or alternate decoder path is introduced.

General typed references to scalar storage are not implemented yet. Their introduction must account
for address/borrow liveness of that storage before applying copy-value pruning; current byte-view
operations cannot borrow numbers or unit. Likewise this is not a bound on large live-resource maps,
origin unions, deep ancestry, generic instantiation or whole-program compilation.

## Retained checks

`research/experiments/state34/check.py` builds a frozen before compiler from commit
`2dea0f1` in an isolated directory. A deterministic compile-only corpus compares 1,200 raw-IR and
400 source cases (numeric definedness/types, branches/loops/reused indices, view authority, owned
bytes, shadowing, strings and propagation). The final corpus has 379 accepted cases; their 487 C/API
outputs are byte-identical, with identical rejection of the rest. Random raw loops are never run.
All 16 cost-case C/API outputs are also byte-identical to the pinned original output hashes.

The full stable and pinned-modern-nightly suites, native allocator release traces, mixed backends
and Rust controls are rerun. Targeted regressions retain undefined-number rejection, strict loop
freshness, explicit ending/reuse, block/branch definitions, fixed register types, and a loan surviving
2,000 dead scalar bindings.

Three local repeats give median host release-seed checking times of 406 ms → 4.2 ms for 1,000
branches, and 1.69 s → 12 ms for 1,000 propagation sites. Timings are wall-clock observations;
byte identity/acceptance comparison and conformance checks are the hard gates. No schema/native
ABI change is needed. This is not a self-hosted compiler result or a formal safety proof.
