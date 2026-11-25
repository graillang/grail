# Closures

A closure is a function written inline that can use values from where it was created. It is
written the way a named function is, without the name:

```grl
add_offset := fn(x: u64) -> u64 { x + offset };
```

takes a `u64`, returns a `u64`, and captures `offset`. `|params| body` is the abbreviation of the
same thing: `|x: u64| -> u64 x + offset` is exactly `fn(x: u64) -> u64 { x + offset }`, with the same
type and the same captures. The bar form also takes an expression for its body, where the `fn` form
always takes a block. In both, the `-> u64` may be left out when the body's value fixes it -
`|x: u64| x + offset` has the type of `x + offset` as its result - and must be written when a block
returns a value with `return`.

{{example:closures}}

Whatever one form does the other does: either is an argument, a binding or a returned value, and
both infer parameter types where the call fixes them (see *Inferred parameter types* below), so
`v.map(fn(x) { x * 2 })` and `v.map(|x| x * 2)` are the same call. Use whichever reads better; the
formatter keeps the one you wrote.

## Local functions

`fn name(params) -> R { body }` inside a function body binds `name` to that function literal. It is a
closure with a name: it captures what it uses from the body around it, by the rules below, and it is
called, passed and returned like any closure. It may also call itself; nothing else could then say
what it returns, so a local function that calls itself writes its result type, and leaving it out
is refused with a help line that shows where it goes.

{{example:local-functions}}

A local function that calls itself may not write what it captured: each call would write the one
environment the calls still running are using. Pass what it changes as a parameter instead. A local
function has no type or lifetime parameters; a generic one is declared at the top level.

Top-level functions stay what they were: they capture nothing, and their signatures are written out
in full, because they are the module's interface (and what the build cache compares).

### Refactoring between them

Because the forms differ only by the name, moving code between them is moving text. A computation
starts as a literal at the one call that needs it:

```grl
fn report(prices: &u64[]) -> u64 {
    sum_by(prices, fn(p: u64) -> u64 { p + p / 5 })
}
```

When it grows, or a second call wants it, it gets a name where it is used:

```grl
fn report(prices: &u64[]) -> u64 {
    fn with_tax(p: u64) -> u64 {
        p + p / 5
    }
    sum_by(prices, with_tax)
}
```

and when other functions want it, the same text moves to the top level:

```grl
fn with_tax(p: u64) -> u64 {
    p + p / 5
}
fn report(prices: &u64[]) -> u64 {
    sum_by(prices, with_tax)
}
```

Only the name and the placement changed. A local function that captures something - say a `rate`
of `report`'s - becomes a top-level one by making each capture a parameter.

## Closures and function pointers: `Fn(..)` and `fn(..)`

`Fn(T) -> R` accepts any callable: a closure, a function literal, a local or a named function. `fn(T)
-> R` is a plain function pointer with no environment, for C callbacks and tables of functions. A
closure that captures nothing is a function, so it converts to `fn(..)` where one is expected - an
argument, a binding, a record field, a result:

```grl
fn twice(f: fn(u64) -> u64, x: u64) -> u64 {
    f(f(x))
}
twice(|x|x + 1, 5); // 7
table := (fn(u64) -> u64)[fn(x: u64) -> u64 { x * 2 }, |x.. u64|x + 1];
```

A closure that captures cannot: the pointer has nowhere to keep what it captured. The refusal names
the captures and suggests the type that takes them:

```text
error: this closure captures `k`, so it is not a function pointer `fn(..)`: a function pointer has no room for what a closure captures
  = help: take `Fn(u64) -> u64` instead, which accepts closures and named functions
```

So a parameter that only calls what it is given takes `Fn(..)`; take `fn(..)` only when a raw
function pointer is what you need.

Closures have the type `Fn(params) -> result`, so they can be passed to and returned from
functions. Numbers and other plain values are copied into the closure; owned values such as the
text in `words` are moved into it, and the original name can no longer be used. A closure is
called like a function and can be called many times; when it goes out of scope, the values it
captured are cleaned up with it. Closures work inside generic functions; the checker keeps their
captures affine like other values.

A closure that only reads what it captured is `Fn`, and calling it only reads the closure, so it is
callable through a shared reference and stays usable where a shared call is promised.

## Mutating a capture: `FnMut`

A closure that writes what it captured is `FnMut(...)` instead of `Fn(...)`. Writing means the body
stores to the capture or to a place rooted at it (`count += 1`, `s.field = 2`, `v[0] = 7`,
`*r = 5`), borrows it mutably (`&mut count`), or calls a method that may change its receiver. The
binding that holds the closure must then be mutable, and calling it borrows the closure
exclusively: a call cannot overlap another call of the same closure, and it cannot overlap a
shared reference to the closure that is still live.

{{example:fnmut}}

Only the captures the body actually writes change mode; an untouched capture is still read-only
inside the body, even when what it holds is a `&mut`. Two closures have separate environments, so
one being called does not block the other, and calls in sequence are fine — the exclusive borrow
ends when a call returns. A closure that writes a capture still cannot outlive what it captured.

`Fn` and `FnMut` are different types. A closure that writes a capture is rejected where an `Fn` is
required, with a message that says why, rather than being silently made exclusive. A closure that
writes nothing is `Fn` and is accepted where `FnMut` is expected, because a call that takes the
closure exclusively is a stricter promise than the shared call an `Fn` makes.

`FnMut` is written in a type position the same way as `Fn`. A function that has to call the
caller's closure exclusively takes `&mut FnMut(...)` and calls it through that reference:

```grl
fn apply_once<a>(step: (&a mut FnMut(u64) -> u64), start: u64) -> u64 {
    step(start)
}
```

## Capturing a borrowed value

A closure may also capture a reference or view — `&T`, `&[T]`, `&[u8]`, `&mut T` — and that is how
a closure reads something that lives outside the value it is given. The reference moves into the
closure, pointer and loan together, so the name it moved from cannot be used afterwards, and the
closure may not outlive what it borrows: returning it, or storing it somewhere the borrow does not
reach, is rejected.

```grl
groups := &b.groups;
order.sort_by(|x, y| {
    gx := &groups[*x];
    gy := &groups[*y];
    gx.depth > gy.depth
});
```

A struct or enum that merely holds a borrow is not captured (its layout and cleanup are its own):
bind the reference itself, or reach the value through one.

## Sorting with a closure

A closure's parameters may be references, borrowed afresh on each call, so a closure works as a
comparator. `v.sort_by(...)` sorts stably: elements that compare equal keep their order.

{{example:sorting}}

Any function with a matching signature can be passed where a callback is expected, so
`tasks.sort_by(by_priority)` works too. `v.sort_by_key(k)` sorts by a computed `u64` key, and
`v.insert_sorted(x)` / `v.binary_search(&x)` keep a vector as a sorted set.

The stdlib callbacks that run on your thread, one call at a time — the vector methods `map`,
`filter`, `filter_map`, `flat_map`, `fold`, `reduce`, `any`, `all`, `count`, `find`, `position`,
`for_each`, `sort_by` and `sort_by_key`, the iterator adapters on `iter::Iter`, an option's `map`
and the second callback of `pool::join` — take `FnMut`, so a comparator or predicate may write what
it captured. To see the result in the caller, capture a `&mut` and write through it; a captured
number is the closure's own copy:

```grl
mut compares = 0;
counter := &mut compares;
items.sort_by(|a, b| {
    *counter += 1;
    a < b
});
println(compares);
```

The `pool` callbacks that run on workers (`par_map`, `into_par_chunks`, `par_chunks_mut`, `pool::run`, `pool::range`, `pool::reduce`) stay `Fn`:
every worker shares one closure, so a closure that writes its captures is refused there with the
`FnMut, not Fn` message.

## Saying what a closure may capture

A closure type can state three facts about what the closure captured, in angle brackets after `Fn`
or `FnMut`:

| Written | Means |
|---|---|
| `Fn<Send>(T) -> R` | every capture may move to another thread |
| `Fn<Share>(T) -> R` | every capture may be used from several threads at once (`Fn` only) |
| `Fn<Owned>(T) -> R` | every borrow it captured is named in its own type, so whatever keeps it carries the borrow |

`Owned` precisely: every lifetime of every borrow the closure captured appears among the lifetimes
of its own type - its parameters or its result. A closure that captures `&a Map` and returns
`&a K?` is `Owned`, and an `Iter<(&a K)>` built from it keeps the map borrowed for as long as it
lives (this is how `map.keys()` works); one that also captured `&b Other`, or any borrow of a local,
is not. A closure that captures no borrow at all is always `Owned`.

A lifetime may stand in the list too: `Fn<s>() -> u64` borrows only from `s`, and a record labelled
`s` (`struct Holder<s> { items: (Fn<s>() -> u64)[] }`) may keep it - the record then keeps the
closure's borrows alive for as long as it lives. A closure parameter without `Owned` or a lifetime
borrows for the call: the callee may call it and pass it on, but not return or store it.

They combine (`FnMut<Send, Owned>() -> R` is what `pool::spawn` takes). They are checked where a
closure expression meets the type - the captures are known there - and carried by the type from
then on. A bare `Fn(..)` states none of them: it is not `Send` or `Share`, so a record with a
`Fn(..)` field cannot cross a thread, and a parameter typed `Fn(..)` cannot be handed to one that
asks for `Fn<Send>`:

```grl
struct Work {
    run: Fn<Send>() -> u64
} // a Work may now be sent to a worker
fn start<R: Send + Owned>(f: FnMut<Send, Owned>() -> R) -> Job<R> {
    parallel_spawn(f)
}
```

A type that says more is accepted where less is asked; the reverse is refused, because the value no
longer shows its captures. A named function captures nothing and meets every bound. `Owned` is also
a bound on a type parameter (`R: Send + Owned`): the type holds no borrow.

**Try it:** use `words` again after creating `length` and read the compiler's message.

## What is not supported

These are refusals with a diagnostic, not silent behaviour:

- A function parameter is not mutable storage, so a `FnMut` value taken *by value* cannot be called
  in the callee directly. Move it into a mutable binding first (`mut call = f;`, as the stdlib does)
  or take `&mut FnMut(...)` (shown above).
- Handing a captured `&mut` to another function, or iterating a captured view mutably, is only
  accepted inside a `FnMut` closure; the forms the compiler recognises as writes are the ones
  listed above.


## Inferred parameter types

A closure passed to a function, or bound with a function type, takes its parameter types from that
type, and its result from that type or its body, as in Rust: `iter::of(v).map(|x| x * 2)` and
`f: Fn(u64, u64) -> u64 = |a, b| a * b`.

A closure called immediately takes them from the call's arguments:

```grl
println((|x|x + 1)(41)); // x is u64
n: u32 = 20;
println((|x|x + 1)(n)); // x is u32
println((|p|p.x)(Point { x: 2, y: 3 }));
```

An argument that is itself a closure, and an argument borrowed (`&buf`) whose parameter would then
be a reference, do not fix the parameter: write it out, `|v: &[u8]|`. Where nothing fixes a
parameter's type at all (`f := |x| x + 1`), the error names the parameter and suggests its
annotation: ``write |x: T|`` (``write fn(x: T)`` for the `fn` form). The `fn` form infers exactly
where the bar form does: `fn(x) { x + 1 }` passed to a typed parameter, or called at once.

## Callable bounds

A generic function can take a closure by its own type instead of an erased `Fn(..)`:

```grl
fn apply<F: Fn(u64) -> u64>(f: F, x: u64) -> u64 {
    f(x)
}
```

`F` is the type of the closure given at each call, so every call site gets its own copy of `apply`
and the call `f(x)` is direct - the optimiser can inline it. The closure's parameter and result
types are inferred from the bound, and a closure that does not fit is refused at the call. The
`vecs` callback methods and the typed iterator adapters (`iter::over(v).map(..).filter(..)`) take
their callbacks this way.

A reference in the bound's parameters whose lifetime the bound names nowhere else is new on every
call, as in Rust (`F: FnMut((&mut T), C) -> R` means "for any lifetime of that `&mut T`"). So the
closure or function given for `F` must not tie that parameter's lifetime to anything else it can
reach - another parameter, its result, or something it captured:

```grl
fn leak<a, b>(v: (&a mut u64[]), out: (&b mut Out<a>)) -> u64 {
    out.slot.push(v);
    0
}
with_lock(&mut m, &mut out, leak); // refused: parameter 1 is fresh on every call, but `leak`
// ties it to `out`, so it could be kept past the call
```
