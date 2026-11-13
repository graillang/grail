# Interface objects behind `Rc` and `Arc`

2026-11-13. Verified and pinned, while checking the claim that `Rc<dyn I>` was refused. On this
branch it is not: the `&dyn` and owned-`dyn` work already make a shared pointer over a trait object
work end to end, and what was missing was a case that says so. This note records what the supported
forms are, what each step does, and the one rule that keeps the cross-thread side honest.

## The type and the object

A `dyn I` is one word: a heap cell `{value, vtable}` whose vtable is `{drop, method 0, method 1, ...}`
for the concrete type (type kind 33, `dyn_box`/`emit_vtables`). `Rc<T>` and `Arc<T>` are one word
too - a pointer to a block `[strong, weak, value]` - so `Rc<dyn I>` is an `Rc` whose stored value is
that cell word. Nothing special is needed to instantiate it: `Rc<T>` is an ordinary generic record
and `T = dyn I` is an ordinary type argument.

## Construction

The language's cast form is a typed binding to the `dyn` type (there is no `as` operator), so the
construction is:

```grl
o: dyn Shape = Rect { w: 3, h: 4 };   // the cast: the box is built here, its vtable registered
r: rc::Rc<dyn Shape> = rc::new(o);    // the handle owns the box
a: rc::Arc<dyn Shape> = rc::arc_new(o2);
```

An explicit type argument spells the same thing in one line:
`rc::new<dyn Shape>(Rect { w: 3, h: 4 })`.

Writing `r: rc::Rc<dyn Shape> = rc::new(Rect { ... })` is refused today: the call infers `T` from its
argument (`Rect`), so the result is `Rc<Rect>`, and generic inference does not seed `T` from the
expected result type. The two forms above are the supported spellings; a checker change to flow the
expected type into a call's type arguments is a separate, wider change (it would affect every
generic call in a typed position) and was deliberately not made here.

A *borrowed* object is not the thing to store: `Rc<&dyn I>` is accepted by the checker because
`&dyn I` carries no region when it is written without one (`parse_reference`'s `dyn_type_ahead`
exemption), and an owned generic container's borrow-escape rule does not see it. That hole is older
and wider than this item (`Rc<&a u64>` holding a reference to a dead local is accepted too), so it
is recorded here rather than fixed: store an owned `dyn I`, not a `&dyn I`.

## Method calls

`r.get()` is `&T` for `T = dyn I`, i.e. a `&dyn I`; calling a method dispatches through the cell's
vtable (`emit_resolved_call`'s `dyn_entry` path), and a `&mut self` method is not reachable through
`Rc`/`Arc` because they hand out a shared reference - which is the same rule as for any `T` and the
reason shared mutation is `Arc<Mutex<T>>`.

## Dropping

`impl<T> Drop for Rc<T>` reads the value's word out with `p.read()` and drops it. For `T = dyn I`
that drop is the object's drop glue, which calls the vtable's first entry: the concrete type's
destructor (a user `impl Drop`, then its fields) runs exactly once, when the last strong handle
goes. `Weak` keeps the block alive without the value, so `w.upgrade()` answers `None` after that.
`Arc` frees the two count cells the same way (see `lib/rc.grl`).

Cases pin the observable order: `ergo-rc-dyn-object` (drop after the last handle),
`ergo-rc-dyn-clones-keep-alive` (two handles, the value survives the first drop and the concrete
destructor runs once at the second), `ergo-arc-dyn-object`, `ergo-rc-dyn-weak-upgrade`,
`ergo-rc-dyn-record-field` (an `Rc<dyn I>` field of a record, dropped with it), and
`ergo-rc-dyn-explicit-type-argument`.

## The cross-thread rule, checked

The capability walk (`transfer_capability`) classifies a `dyn I` as *neither* transferable nor
shareable, by name: its concrete type is unknown where the value crosses, and a vtable could hold a
type that is thread-affine. So:

- `Rc<dyn I>` cannot cross a worker boundary. `parallel_map(items, &r, f)` is refused with
  `cannot share parallel_map context` (the context walk reaches the `Rc`'s raw pointer).
- `Arc<dyn I>` has atomic counts but is refused there for the same reason, with
  `no capability proof for the type parameter`: `Arc<T>`'s audited `shareable` contract requires its
  type argument to classify, and `dyn I` does not. `Arc<dyn I>` is therefore a local handle until an
  interface can state a capability contract for its objects (for example `interface I: shareable`,
  checked at each `impl`, which would let `dyn I` carry the bit). That is a language change, not
  made here.

Both refusals are pinned: `ergo-rc-dyn-reject-cross-thread`, `ergo-arc-dyn-reject-not-shared`. The
book's *Shared ownership* section states the same rule for the reader.
