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
