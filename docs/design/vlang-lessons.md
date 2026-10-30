# V: targeted lessons for Grail

Inspected 2026-10-30 at `cdfaf29913ae17c06d60ce06591cdb50631b1b33`. This is a bounded documentation/source-tree review,
not a V safety audit or reproduced build/runtime benchmark. No third-party build script was run.

## Worth learning

- Read-only arguments by default, concise mutable access conventions, Option/Result syntax,
  expression-oriented matching, and postfix collection transformations are useful ergonomic references.
  Surface convenience does not establish allocation-free fusion or ownership guarantees.
- Development versus production compilation is a real engineering distinction. V documents normal
  use of TinyCC on supported hosts and optimizing C compilers for production. Evaluate end-to-end
  cost, portability and debug mapping before considering a C backend for Grail.
- Integrated formatting/testing/documentation and a short edit/build/run workflow are valuable product
  lessons, independently of the memory model.
- The repository's compiler-performance protocol distinguishes frontend/C generation from full builds,
  uses fixed fixtures, and records retired instructions alongside latency/memory. Learn the measurement
  discipline; do not repeat LOC/s or self-compilation headlines as established cross-language results.

## Not a solution to Grail's central memory requirement

The current memory-management documentation says tracing GC is the default; autofree inserts frees
for many objects but relies on GC for the remainder, and remains WIP with advice to avoid it until
stable. Disabling GC selects manual management, not automatically Rust-class static safety.
No conclusion about every current ownership check follows from this bounded inspection.

The slicing documentation says mutable slice assignments can insert an implicit clone (with a notice),
while immutable slices may share storage. This illustrates a concrete simplicity/cost trade-off.
Grail should not hide copies merely to accept conflicting mutable accesses.

FastC is explicitly experimental, bypasses the regular parser/checker/AST pipeline, and currently
has documented sum-type copy-semantics differences from the default C backend. This is not a claim
that regular V compilation skips checking. For Grail, fast and release paths must preserve the same
safety contract and observable semantics, rather than trading them away for headline speed.

## Recommendation

Study V selectively for ergonomics, tooling, backend trade-offs and measurement practice. Keep
Hylo/Rust/Goose/Cogent as higher-priority memory-model research. Do not import built-in application
DSLs or feature count as evidence of minimality, nor present experimental autofree as solved ownership.

## Pinned evidence

- [Language documentation: memory, slicing, access modes, results](https://github.com/vlang/v/blob/cdfaf29913ae17c06d60ce06591cdb50631b1b33/doc/docs.md)
- [Backend/build choices and qualified performance claims](https://github.com/vlang/v/blob/cdfaf29913ae17c06d60ce06591cdb50631b1b33/README.md)
- [FastC support and semantic limitations](https://github.com/vlang/v/blob/cdfaf29913ae17c06d60ce06591cdb50631b1b33/doc/fastc.md)
- [Compiler measurement protocol and recorded results](https://github.com/vlang/v/blob/cdfaf29913ae17c06d60ce06591cdb50631b1b33/vself_speed.md)

The linked performance figures are project-authored results, not independently reproduced here.
