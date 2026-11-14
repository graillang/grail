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
return. There are no tail-expression returns: a function that produces a value uses `return`, and
`return ();` is still available for an explicit early exit.

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
