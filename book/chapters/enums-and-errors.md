# Enums, match and early exits

An enum chooses one variant. A variant may carry an owned payload, and `match` consumes the
enum and hands the active payload to its arm. Cover every variant.

{{example:enums}}

`T?` represents an optional value, with `Some` and `None` variants. A structural union such as
`T | E` holds a value of either member type: return a member directly and match it by type.
Matches must cover every member, or use a final `_` arm. In a union used for propagation, the
first member is success; postfix `?` returns any other member to a compatible return union, while
postfix `!` extracts success and aborts on failure.

{{example:errors}}

Propagation is an early return with cleanup, not an exception or a garbage-collector operation.
`!` is appropriate for an invariant, not routine failure handling. For expected failures, match
all member types or propagate failures to a caller.

## Matching through a borrow

`match borrow(value)` inspects the enum in place: payloads are bound as references instead of being
moved out. The borrow ends at the last use of those payload references, so an arm may then assign
`value` itself. Using a payload after that assignment is rejected.

{{example:match-update}}

**Try it:** swap which flag reaches `forward`, and use `match` to inspect both paths.
