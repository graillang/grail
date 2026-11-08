# Enums, match and early exits

An enum chooses one variant. A variant may carry an owned payload, and `match` consumes the
enum and hands the active payload to its arm. Cover every variant.

{{example:enums}}

`T?` represents an optional value, with `Some` and `None` variants. A structural union such as
`T | U` holds a value of either member type: return a member directly and match it by type.
Matches must cover every member, or use a final `_` arm. An ordinary union is unordered and carries
no success/failure meaning, so `?` does not apply to it.

A result `S |? F` separates success alternatives from failure alternatives. Postfix `?` returns a
failure member to a compatible result return, while postfix `!` extracts success and aborts on
failure. `?` yields `S`; every `F` must map to a distinct failure alternative in the caller's result,
and a failure cannot silently become the caller's success.

A union may contain records, vectors, maps and optional values. Type arguments compose:
`u8[] |? io::Error`, `[K: V]?`, and `(u64 | string)[]` are all ordinary types. Parentheses are
needed when a union is an element type or the referent of a reference: `&T`, `&a T`, or
`&a mut T`. An enum payload may itself be a union.

```grl
struct ParseError { message: string }
fn parse(flag: u64) -> u64 |? ParseError {
    if flag == 0 { return ParseError { message: "missing" }; }
    return 42;
}
fn forward(flag: u64) -> bool | u64 |? ParseError {
    value := parse(flag)?; // Returns ParseError early; success continues as u64.
    return value;
}
```

Matching selects members by their types, not by declaration names. Name the payload in a member
pattern (`data: u8[]`) or match the bare type. There are no tuple patterns.
Generic calls and constructors infer a type parameter when exactly one unbound union member fits;
they reject the call if the choice is ambiguous or the inferred union would contain the same
member twice.

{{example:errors}}

Propagation is an early return with cleanup, not an exception or a garbage-collector operation.
`!` is appropriate for an invariant, not routine failure handling. For expected failures, match
all member types or propagate failures to a caller.

## Matching through a borrow

`match &value` inspects the enum in place: payloads are bound as references instead of being
moved out. The borrow ends at the last use of those payload references, so an arm may then assign
`value` itself. Using a payload after that assignment is rejected.

{{example:match-update}}

**Try it:** swap which flag reaches `forward`, and use `match` to inspect both paths.
