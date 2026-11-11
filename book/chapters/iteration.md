# Iteration

`for x in v` walks a vector, `for k, v in &m` a map, and `for i in 0..n` a range. Any other type
becomes iterable by having one method: `fn next(self: &mut Self) -> T?`. `for x in it` calls `next`
until it returns `None`, binding each `Some` value to `x`.

{{example:iterators}}

`for x in it` takes the iterator; `for x in &mut it` only lends it to the loop, so a loop that
breaks early leaves the rest for later. `for x in &it` is refused, because `next` has to advance
the iterator. An iterator that holds a reference, like `Items<a>`, keeps its vector borrowed for as
long as it lives, so pushing to `prices` inside the loop is a borrow error, exactly as it is in
Rust. One limit today: an iterator that holds a reference cannot be lent to a second loop after a
first one (the checker keeps a loan from the first loop's `next` calls live), so resume only
iterators that own their state, like `Countdown`.

Grail has no traits, so the protocol is structural: the compiler looks for an inherent `next` with
that shape. A plain `for` over a vector is unaffected and compiles to the same counted loop as
before.

## Adapters

The `iter` module chains work lazily over an `Iter<T>` - a closure that yields the next item:

{{example:iterator-adapters}}

`upto(lo, hi)` counts, `of(v)` moves the elements out of a vector, and `map`, `filter`, `take`,
`enumerate` and `zip` wrap one iterator in another; `collect` pulls everything into a vector.
`Iter<T>` is itself an iterator by the protocol above, so any adapter chain can sit in a `for`.
The closures passed to adapters are `FnMut`, so they may update their own captures. Items that
borrow from a vector cannot be produced through a closure yet, so borrowed iteration uses
`for x in &v` or a record iterator such as `Items<a>`.
