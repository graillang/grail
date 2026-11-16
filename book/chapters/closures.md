# Closures

A closure is a function written inline that can use values from where it was created.
`|x: u64| -> u64 x + offset` takes a `u64`, returns a `u64`, and captures `offset`. The `-> u64`
may be left out when the body is an expression - `|x: u64| x + offset` has the type of `x + offset`
as its result - and must be written when the body is a block that returns a value.

{{example:closures}}

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
    return step(start);
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
order.sort_by(|x: &u64, y: &u64| -> bool {
    gx := &groups[*x];
    gy := &groups[*y];
    return gx.depth > gy.depth;
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
items.sort_by(|a: &u64, b: &u64| -> bool { *counter += 1; return *a < *b; });
println(compares);
```

The `pool` callbacks that run on workers (`pool::map`, `run`, `split`, `split_mut`, `range`, `reduce`) stay `Fn`:
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
`(&a K)?` is `Owned`, and an `Iter<(&a K)>` built from it keeps the map borrowed for as long as it
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
struct Work { run: Fn<Send>() -> u64 }      // a Work may now be sent to a worker
fn start<R: Send + Owned>(f: FnMut<Send, Owned>() -> R) -> Job<R> { return parallel_spawn(f); }
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
println((|x| x + 1)(41));          // x is u64
n: u32 = 20;
println((|x| x + 1)(n));           // x is u32
println((|p| p.x)(Point { x: 2, y: 3 }));
```

An argument that is itself a closure, and an argument borrowed (`&buf`) whose parameter would then
be a reference, do not fix the parameter: write it out, `|v: &[u8]|`. Where nothing fixes a
parameter's type at all (`f := |x| x + 1`), the error names the parameter and suggests its
annotation: ``write |x: T|``.
