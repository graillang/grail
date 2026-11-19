# Functions and recursion

Functions name parameters and result types. Calls evaluate arguments left to right and snapshot
each value before evaluating the next argument. Recursion uses ordinary native calls.

{{example:functions}}

This is a deliberately small recursive Fibonacci example, not an efficient implementation.
It passes a capture-free function value to `apply` and returns the tenth Fibonacci number.
`fn(u64)->u64` describes the callback contract; named function values can be copied, passed and
returned. Generic function items need explicit arguments when used as values (`identity<u64>`).
Closures can copy or move values into themselves and read those captures in their bodies; a closure that writes a capture is `FnMut` and is called exclusively (see [Closures](closures.html)). The Rust example uses a plain function pointer. A function may return an owned buffer or record as well
as a scalar; moving that result transfers responsibility for cleanup to its caller.

Grail functions have fixed arity and any number of parameters; `extern "C"` declarations are
the only variadic form (see [Cleanup and current boundaries](cleanup-and-boundaries.html)).
`unit` is the no-value type,
written `()` as a value; a function with no result annotation returns unit. Its closing brace supplies the normal
return.

The last expression of a block, written without a `;`, is the block's value - Rust's rule. A
function's body is a block, so `fib` above ends in `fib(n - 1) + fib(n - 2)` and that is its result:
the tail returns exactly as `return fib(n - 1) + fib(n - 2);` would, moving the value out to the
caller. `return` is still the early exit (`fib`'s `return n;`), and still valid as the last
statement. The same holds for a closure's block and for any block used as a value - an `if` or
`match` arm, or a plain `{ ... }` (see [Branches and loops](control-flow.html)). A final `if` or
`match` hands the tail on to its arms, so each arm's last expression is the result:

```grl
fn sign(n: i64) -> i64 {
    if n < 0 { -1 } else if n == 0 { 0 } else { 1 }
}
```

A function that returns a value and can reach its closing brace without one is refused, and the
diagnostic names the type it owes; when the body ends in `expr;` of that type, it points at the `;`
to remove. A tail in a block whose value nobody takes - a unit function's body, a loop's body - must
itself be unit: `fn f() { a + 1 }` is refused with the help to end it with `;` or declare `-> u64`.
`grail fmt` writes a body's final `return x;` as the tail `x`. Early returns, `return;`, `return ();`
and a returned `if`/`match`/block (whose tail form returns from each arm instead) stay as written.

## Naming arguments, and letting the declaration fill them in

A call may name the parameter each argument fills. Positional arguments come first; after the first
named one every argument is named, so the argument list reads as a set of slots rather than a
sequence a reader has to count:

```grail
println(rect(1, height: 2, width: 5));   // 1 is `area`; the other two say which they are
```

A parameter may also carry a default - `fn scaled(value: u64, by: u64 = 2, plus: u64 = 0)` - and a
call that leaves it out gets it. The default is a value the *declaration* supplies, compiled where
the call is written and owned exactly as an argument is, so it can build an owned value in the
caller's frame. A parameter with a default may not be followed by one without, so dropping arguments
always drops a suffix.

{{example:named-arguments}}

Every parameter must be supplied exactly once. A name the declaration does not have, a parameter
named twice, a positional argument after a named one, and a parameter left without an argument and
without a default are each refused at the call, naming the parameter and the callee. The Rust example
has neither feature, so it writes the parameters in declaration order and turns the optional ones
into a struct of options with a `Default` impl.

**Try it:** give `rect` a default for `height` of `1` and call it as `rect(width: 3, area: 0)`.
