# Functions and recursion

Functions name parameters and result types. Calls evaluate arguments left to right and snapshot
each value before evaluating the next argument. Recursion uses ordinary native calls.

{{example:functions}}

This is a deliberately small recursive Fibonacci example, not an efficient implementation.
It passes a capture-free function value to `apply` and returns the tenth Fibonacci number.
`fn(num)->num` describes the callback contract; named function values can be copied, passed and
returned. Generic function items need explicit arguments when used as values (`identity<num>`).
Closures can copy or move values into themselves and read those captures in their bodies; borrowed and mutable captures are rejected. The Rust example uses a plain function pointer. A function may return an owned buffer or record as well
as a scalar; moving that result transfers responsibility for cleanup to its caller.

Functions have fixed arity; general variadics are not implemented. The current native ABI
supports at most six one-word parameters. `unit` is the no-value type,
written `()` as a value; a function with no result annotation returns unit. Its closing brace supplies the normal
return; `return ();` can still be used for an explicit early exit.

**Try it:** replace the recursive implementation with a loop using two numeric `mut` bindings.
