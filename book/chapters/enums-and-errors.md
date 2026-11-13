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

## A standard error value

Matching every failure by hand does not scale past two layers: each caller would have to know every
error type beneath it. `errs` is the standard library's answer - a `Report` that owns a root message,
the context frames each layer added, a typed standard-library origin and, when the caller asks, the
stack where it was created.

{{example:errs}}

A fallible function returns that one payload, `fn load(path: &[u8]) -> u8[] |? errs::Report`. `?`
carries the same type up through any number of layers - payload types must match, as everywhere else -
so a layer that wants to add framing writes it on the failure path,
`return err.context(view("while opening /x"))`. There is no implicit `From`: `errs::from_os` is the
conversion a boundary writes, and `origin()` hands the `io::Error` back.

`context` consumes the report and returns it, so a chain is built by reassignment and every frame it
holds is owned by the value; nothing is borrowed from the frame that phrased the message. `depth()`,
`frame(i)`, `cause()` and `origin()` walk the chain, `show()` is its one-line text, and `to_stderr()`
prints that line followed by the captured stack.

Capturing that stack is a call-site choice, because it allocates: `errs::report` records no stack and
`errs::traced` records the stack where the error was created. A build that carries no call-site
tables (macOS, the LLVM backend, `--debug`) captures nothing and prints the message alone rather than
a stack it would have had to guess; `docs/design/standard-errors.md` states the frame-walk
assumptions.

`errs::Error` is the interface underneath: one method, `message`, implemented by `errs::Report`,
`errs::Message` (a message-carrying record) and `io::Error`, for code that reports whatever error it
was handed without knowing which one it was.
## Arm bodies

An arm body is one expression, or a block of statements in braces:

```grl
match n {
    0 => println("zero"),
    1 => { println("one"); println("only one"); },
    _ => println("many"),
}
```

The expression form releases its temporaries at the end of the arm, exactly as the same expression
with a semicolon inside the block form does, and the last arm before `}` may omit its comma. A body
that is a statement (`while`, `for`, `loop`, `let`, `return`, `break`, `continue`, `drop`, `write`,
`assert`, or an assignment) needs the braces: `_ => while c { ... }` is refused with that reason. A
record literal needs no parentheses in an arm: `_ => Point { x: 1, y: 2 }` is the literal, and
`_ => { Point { x: 1, y: 2 }; }` is the block that builds and drops it.

## `match` as a value

`match` is also an expression, so it can be bound, returned or passed as an argument:

```grl
n := match flag { 0 => 1, 1 => 2, _ => 3 };
```

Every arm that reaches the end then produces a value, the arms agree in type, and the diagnostic
names both when they do not. An arm may still be a block, as long as that block always leaves the
branch (`return`, `break`): it needs no value, so the other arms decide the type. The shapes that
cannot be one value are refused by name - a block arm that falls through, and an arm whose value
borrows (`match n { 0 => &a, _ => &b }`), since one result word cannot name both loans. An `if` with
an `else` is a fine arm body here: `0 => if c { 1 } else { 2 },`.

{{example:match-values}}

## Matching through a borrow

`match &value` inspects the enum in place: payloads are bound as references instead of being
moved out. The borrow ends at the last use of those payload references, so an arm may then assign
`value` itself. Using a payload after that assignment is rejected.

{{example:match-update}}

**Try it:** swap which flag reaches `forward`, and use `match` to inspect both paths.
