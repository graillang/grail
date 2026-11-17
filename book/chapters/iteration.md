# Iteration

`for x in v` walks a vector, `for k, v in &m` a map, and `for i in 0..n` a range. Any other type
becomes iterable by having one method: `fn next(self: &mut Self) -> T?`. `for x in it` calls `next`
until it returns `None`, binding each `Some` value to `x`.

{{example:iterators}}

`for x in it` takes the iterator; `for x in &mut it` only lends it to the loop, so a loop that
breaks early leaves the rest for later. `for x in &it` is refused, because `next` has to advance
the iterator. An iterator that holds a reference, like `Items<a>`, keeps its vector borrowed for as
long as it lives, so pushing to `prices` inside the loop is a borrow error, exactly as it is in
Rust. Lending works for either kind: `for x in &mut it` twice resumes where the first loop
stopped, whether the iterator owns its state, like `Countdown`, or borrows a collection, like
`Items`.

Grail has no traits, so the protocol is structural: the compiler looks for an inherent `next` with
that shape. A plain `for` over a vector is unaffected and compiles to the same counted loop as
before.

An element that is a tuple can be opened in the header: `for (i, x) in it.enumerate()` binds
both halves, and `for (_, value) in indexed` skips one. The pattern has to name exactly as many
fields as the element has; a non-tuple element is refused naming its type, and an owned field such
as a `u8[]` moves out of the element, whose record is then freed.

## Adapters

The `iter` module chains work lazily over an `Iter<T>` - a closure that yields the next item:

{{example:iterator-adapters}}

`upto(lo, hi)` counts, `of(v)` moves the elements out of a vector, and `map`, `filter`, `take`,
`enumerate` and `zip` wrap one iterator in another; `collect` pulls everything into a vector.
`Iter<T>` is itself an iterator by the protocol above, so any adapter chain can sit in a `for`. `iter::Iterator` is the interface behind them (`type Item; fn next(self: &mut Self) -> Self::Item?`):
implement it for your own type and generic code takes `I: iter::Iterator` and names `I::Item`.
Each adapter is also a method, so a chain reads left to right:
`iter::of(v).filter(|x: &u64| -> bool *x > 1).map(|x: u64| -> u64 x * 2).collect()`; `count()` and
`fold(init, f)` consume one.
The closures passed to adapters are `FnMut`, so they may update their own captures. `refs(&v)`
yields references into a vector you keep, so a loop or a chain such as `take` can use borrowed items
without copying them; the vector stays borrowed while the chain or any item from it is in use.
`filter` over reference items hands its predicate a reference to each item, as Rust does, so it
takes `&&T` and reads through both with `**x` (or copies the inner reference out, `r := *x`):

```grl
for x in iter::refs(&v).filter(|x| **x % 2 == 1) {
    total = total + *x;
}
```

`map` from reference items to owned ones works too: `iter::refs(&v).map(|x: &u64| -> u64 *x * 2)`
is an `Iter<u64>` that still reads `v`, so `v` stays borrowed until it is done - as in Rust, a
generic function's result keeps the borrows of its arguments' type parameters. The same
holds for any closure whose type returns a reference: `Fn() -> &a T` keeps what it captured
borrowed for lifetime `a`.
