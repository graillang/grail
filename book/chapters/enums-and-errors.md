# Enums, match and early exits

An enum chooses one variant. A variant may carry an owned payload, and `match` consumes the
enum and hands the active payload to its arm. Cover every variant.

{{example:enums}}

A conventional `Result` uses `Ok` and `Err`. The postfix `?` propagates an error through a
compatible result-returning function; postfix `!` unwraps success and aborts on error.

{{example:errors}}

Propagation is an early return with cleanup, not an exception or a garbage-collector operation.
`!` is appropriate for an invariant, not routine failure handling. For expected failures, match
both variants or propagate them to a caller.

**Try it:** swap which flag reaches `forward`, and use `match` to inspect both paths.
