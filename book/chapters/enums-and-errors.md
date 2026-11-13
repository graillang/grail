# Enums, match and early exits

An enum chooses one variant. A variant may carry an owned payload, and `match` consumes the
enum and hands the active payload to its arm. Cover every variant.

{{example:enums}}

`T?` is the concise spelling of `result::Option<T>`: `Some(value)` holds a value and `None` holds
nothing. A structural union such as `T | U` holds a value of either member type: return a member
directly and match it by type. Matches must cover every member, or use a final `_` arm.

A result `S |? F` separates success alternatives from failure alternatives. Postfix `?` returns a
failure member to a compatible result return, while postfix `!` extracts success and aborts on
failure. `?` yields `S`; every `F` must map to a distinct failure alternative in the caller's result,
and a failure cannot silently become the caller's success.

`?` is a rule about *shape*, not about names. Any type with exactly one success member and one
failure member propagates:

| operand | success member |
| --- | --- |
| `result::Result<T, E>` | `Ok(T)` |
| `T?` (`result::Option<T>`) | `Some(T)` |
| an ordinary union `S \| F` | the first member |
| a result union `S \|? F` | its success members |

An enum whose variants are not named `Ok`/`Err` or `Some`/`None` still propagates by declaration
order: the first variant is the success, the second the failure. A shape that cannot say which
member fails - an enum with three variants, or an ordinary union with three members - is refused
with a diagnostic that names the type and its members, because guessing there would make the meaning
of `?` depend on instantiation.

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

## The standard `Result` and `Option`

`lib/result.grl` declares the two shapes by name, so a function can say what it answers without
inventing an enum per module:

```grl
use result;

pub fn halve(n: u64) -> result::Result<u64, string> {
    if n % 2 != 0 { return result::Result::Err("odd".text()); }
    return result::Result::Ok(n / 2);
}

pub fn maybe(n: u64) -> u64? {          // The same as result::Option<u64>.
    if n > 3 { return None; }
    return Some(n);
}
```

Both are ordinary generic enums, so a payload may itself be another instance
(`result::Result<u64?, string>`), a reference, or a record, and `?` walks a chain of layers with
the same rule it applies to a union. `Ok(v)`, `Err(e)`, `Some(v)` and `None` are the constructor
spellings; `result::Result::Ok(v)` and `result::Option::Some(v)` name the type explicitly where the
context does not.

The combinators are methods, and none of them panics: `is_ok`, `is_err`, `unwrap_or`, `map`,
`map_err`, `ok` and `err` on `Result`; `is_some`, `is_none`, `unwrap_or`, `map`, `ok_or` and
`to_result` on `Option`. `ok_or` and `to_result` turn absence into a failure you write -
`to_result` answers a `Result<T, E>`, `ok_or` answers the union `T | E` - and `!` remains the
explicit abort for the case that is a bug.

## A standard error value

Matching every failure by hand does not scale past two layers: each caller would have to know every
error type beneath it. `errs` is the standard library's answer - a `Report` that owns a root message,
the context frames each layer added, a typed standard-library origin and, when the caller asks, the
stack where it was created.

{{example:errs}}

A fallible function returns that one payload, `fn load(path: &[u8]) -> u8[] |? errs::Report`. `?`
carries the same type up through any number of layers - the failure type must match, as everywhere
else, whether the shape is a union or a `Result<T, E>` - so a layer that wants to add framing writes
it on the failure path,
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
that is a statement (`if`, `while`, `for`, `loop`, `match`, `let`, `return`, `break`, `continue`,
`drop`, `write`, `assert`, or an assignment) needs the braces: `_ => if c { ... }` is refused with
that reason. A record literal needs no parentheses in an arm: `_ => Point { x: 1, y: 2 }` is the
literal, and `_ => { Point { x: 1, y: 2 } }` is the block that builds and drops it.

## Matching through a borrow

`match &value` inspects the enum in place: payloads are bound as references instead of being
moved out. The borrow ends at the last use of those payload references, so an arm may then assign
`value` itself. Using a payload after that assignment is rejected.

{{example:match-update}}

**Try it:** swap which flag reaches `forward`, and use `match` to inspect both paths.
