# Closures

```grl
fn make_adder(n: num) -> Fn(num) -> num {
    return |x: num| -> num x + n;
}
fn main() {
    offset := 10;
    add := |x: num| -> num x + offset;
    println(add(5));
}
```

Syntax: `|name: Type, ...| -> Result body` where the body is an expression or a block; `|| -> R`
takes no parameters; without `-> R` the result is unit. Parameter types are written explicitly.
The type is `Fn(T, ...) -> R` (at most five parameters).

Semantics (v1):

- Captures are found from the enclosing function's locals named in the body. Plain values
  (`num`, sized integers, `bool`, function values) are copied; owned values are moved in, so the
  original binding is unavailable afterwards. A direct reference or view (`&T`, `&[T]`, `&[u8]`,
  `&mut T`) moves in as well, pointer and loan together: its lifetime becomes part of the closure's
  type, so the closure cannot outlive what it borrows (returning it from the function is rejected)
  and the enclosing function's loan checks still see the borrow. A struct or enum that merely holds
  a borrow is not captured, because its layout and dropper are its own.
- Inside the body a capture the body does not write is a read-only field of the closure's
  environment: it can be read and borrowed shared, not assigned, mutably borrowed or moved out.
- A closure value is affine (it owns its environment): moving it transfers ownership, calling it
  does not consume it, and dropping it drops its captures. Copying requires moving.
- Representation: a heap record `{code, drop function, captures...}`; calls pass a pointer to the
  closure as a hidden first argument. Named functions remain thin `fn(T) -> R` pointers; an `Fn`
  parameter accepts closures only.
- Closures may appear inside generic functions; each specialization compiles its own closure body.
  A closure can call a captured closure or function value.
- A capture the body writes makes the closure `FnMut(...)`: the environment field is mutable in the
  body, the body's hidden environment parameter is `&mut Env`, and calling the closure takes
  exclusive access to the closure for the call. Only written captures change mode, so a closure
  that writes nothing stays `Fn` and keeps its shared-call contract. `Fn` and `FnMut` are different
  types; a `Fn` closure is accepted where `FnMut` is expected (wider call contract), the reverse is
  rejected. The rules and the known limitations are in
  [the B6 decision](decisions-b2-b6.md#b6-references-captured-fnmut-implemented).
- Not yet: mutable/borrowed closure parameters (a by-value `FnMut` parameter cannot be called
  because parameters are not mutable storage; take `&mut FnMut(...)`), Send/Share for closures, and
  coercing named functions to `Fn`.

## Inferring the parameters of an immediately invoked closure

`(|x| x + 1)(41)` is a closure literal whose only use is the call written directly after it. The
call fixes the parameter types, so the literal may leave them out, on the same "the expected
function type says what the parameters are" rule as an argument or a typed binding
(`closure_hint`). The shape is one the literal cannot see on its own: the callee is parsed before
the arguments.

Mechanically, `expr_expected` recognises `( | ... ) (` before parsing the primary and types each
argument ahead of time (`immediate_call_hint`). Each argument is compiled once in isolation by
`isolated_body_type` - the same machinery that infers an expression-bodied closure's result - with
the enclosing locals it names bound to their types, and the emitted code and checker state thrown
away. The resulting types become the closure's `hint_params`; the result stays unknown so the body
decides it, exactly as for a closure passed to a generic call. The real call then compiles each
argument again with its own expected type (an unsuffixed literal may still adopt a parameter type
there), so nothing the probe decided is trusted beyond the parameter types.

Refusals, each with the parameter named:

- An argument that is itself a closure is not used: its type would need the callee's parameter
  type, which is what this is computing, and general closure-to-closure inference is not part of
  this increment. `(|f| 1)(|y| y)` reports that `f` needs a type.
- A parameter type that holds a borrow is not inferred from the argument. A reference parameter is
  borrowed afresh on every call, so its type needs the closure's own input lifetime rather than the
  caller's; `(|v| v.len())(&buf)` reports that `v` needs a type and suggests `|v: T|`. Write the
  reference explicitly (`|v: &[u8]|`) as before.
- Anything else that fixes nothing keeps the existing diagnostic, which now names the parameter
  and repeats it in the suggested annotation: "closure parameter `x` needs a type here (nothing
  fixes it): write |x: T|".

Corpus: `ergo-closure-infer-call-{scalar,two-params,record-arg,string-arg,no-params}`,
`ergo-closure-infer-argument-position`, `ergo-closure-infer-typed-binding`, and the rejections
`ergo-closure-infer-reject-untyped-local` / `-invocation-borrow`.
