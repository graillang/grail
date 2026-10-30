# Postfix error propagation

`let value = parse(input)?;` consumes a Result/Option-shaped enum. On Ok/Some, execution continues
with its payload. On Err/None, the enclosing function returns its matching failure alternative,
dropping remaining owners by the usual reverse-binding / recursive-field rules. `!` still aborts
instead. Both operators have higher precedence than arithmetic and may chain.

The enclosing return type must be an Ok/Err or Some/None enum of the same family. It may have a
different success payload and different declaration order. Error payload types/modes must match;
there is no implicit From conversion. Captured error origins must satisfy the enclosing written
lifetime contract. Concrete enum payloads are current functionality; generic Result/Option are not
yet implemented. This is not a concession to permanent nongeneric APIs.

The parser emits existing checked Match/Variant/Return operations directly, not an unlowered
operator stub or special exception runtime. It allocates the success binding and failure return
registers, then the ordinary liveness/ownership pass supplies cleanup. Consequently each generated
return is independently producer-checked, and a continuing success arm alone determines the state
following `?`. No new interface schema or native ABI is needed.

This composes with nested expressions, call argument evaluation, constructors, loop bounds and
repeated while conditions. Earlier arguments/fields are evaluated and moved first; if a later
expression propagates, those pending owned temporaries are destroyed exactly once. Failure while
evaluating a loop condition also destroys enclosing function owners. A failed operation does not
roll back prior writes or other side effects.

## Retained validation

The source-hidden number → annotation → client pipeline returns an owned error string through
separate nominal result types and preserves borrowed input spans on success. clang/TinyCC compose
in both directions. An independent allocator wrapper checks complete release traces for ordinary
success/failure, an earlier pending call argument, repeated while-condition failure, Option None,
and mutation before propagation. Wrapper trace access is test-only and retains its first 4096
release IDs; actual live-allocation and total-release counters still cover the whole run.

`research/experiments/propagate33/check.py` also executes Rust controls. The pending-argument case
independently confirms release order **3, 2, 4, 1** (pending argument, enclosing local, propagated
error, outer source). Rust and Grail both preserve the preceding mutation (9), and reject mismatched
error payloads/lifetimes. Negative controls compile only and are never executed.

Costs retain the expanded source/checked C sizes and host release-seed timings. The known cumulative
state-cloning overhead is still open, not hidden by this shorthand. This is not full generic error
handling, a complete stdlib/compiler port or self-hosting evidence.
