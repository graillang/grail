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
  original binding is unavailable afterwards. Capturing a borrowed reference or view is rejected
  (lifetimes of closure environments are not tracked yet).
- Inside the body captures are read-only fields of the closure's environment: they can be read
  and borrowed shared, not assigned, mutably borrowed or moved out.
- A closure value is affine (it owns its environment): moving it transfers ownership, calling it
  does not consume it, and dropping it drops its captures. Copying requires moving.
- Representation: a heap record `{code, drop function, captures...}`; calls pass a pointer to the
  closure as a hidden first argument. Named functions remain thin `fn(T) -> R` pointers; an `Fn`
  parameter accepts closures only.
- Closures may appear inside generic functions; each specialization compiles its own closure body.
  A closure can call a captured closure or function value.
- Not yet: borrowed or mutable captures (`FnMut`), closure parameters that hold borrows,
  Send/Share for closures, and coercing named functions to `Fn`.
