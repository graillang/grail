# Syntax v2 scope and invariants

Status: implementation in progress. This is the agreed surface direction; it is not a claim that
every item is already implemented.

## Relationship to the original vision

Syntax v2 completes the ownership, borrowing, error, collection and numeric surface. Authority,
suspension effects, contracts/proofs, staging, exported summaries, iterator protocols, arenas,
devices and FFI remain v3 semantic work. They are deferred, not rejected.

## Frozen surface

- References: `&T`, `&mut T`, `&a T`, `&a mut T`; expressions `&value` and `&mut value`.
  `borrow` and `borrow_mut` disappear.
- Ordinary shared arguments use explicit `&`; method receivers auto-borrow. Owned `string`/`T[]`
  arguments and literals may be adjusted to immutable slice parameters when the expected type is
  already known. `&mut` is always explicit.
- Lifetimes on functions, methods and interfaces are implicit. Every elided input reference is a
  fresh lifetime; free names such as `a`/`b` are implicitly bound. An elided output uses the
  receiver lifetime, otherwise the sole input lifetime, otherwise it is rejected. Stored lifetimes
  remain explicit on nominal types.
- Slices: `[T]` is an unsized slice, `&[T]`/`&mut [T]` are slice references, `T[]` is an owned
  vector, and `(&T)[]` is a vector of references. `string` remains the owned UTF-8 type. No `str`
  or `char[]` in v2; `char` remains a scalar.
- Integers: contextual fallback `i64`; `u64` for sizes, indices and byte counts; no `num` or
  `usize`; checked overflow in every build, including exponentiation.
- Optionals: `T?`, `Some(value)`, `None`; no public `Option` spelling.
- Results: `S |? E` is a structural union with an explicit success/failure partition. Ordinary
  `T | U` is unordered and has no `?`/result-`!`. `?` propagates only result failures and optional
  absence; the two families do not implicitly convert.
- Result invariants: flatten only within ordinary sides; normalize success and failure separately;
  preserve nested result boundaries; preserve partitions when widening; no implicit recursive
  wrapping; alias expansion and generic substitution precede overlap checks; lifetime-only
  differences do not form alternatives.
- Patterns: nominal variant patterns remain; structural union patterns use `data: T`, bare `T`,
  and `_`. `T(data)` is not a structural-union constructor pattern.
- Iteration: consume the iterable; `&v` and `&mut v` borrow. Map iteration uses named `Entry`
  records, with `for key, value in map` as loop-header sugar, not a tuple protocol. Keys are never
  mutable through iteration.
- Maps: `[K: V]`; literals `[k: v, ...]`, with `[:]` when the context fixes the type; `[K: V]()`
  creates a randomly seeded map and `[K: V]::with_seed(s0, s1)` fixes the seeds. Method-first `len`,
  `contains`, `get`, `get_mut`, `insert`, `remove`, `entry`: lookups borrow the key and return
  optionals, while `insert` takes ownership. `m[key]` is a required place: a missing key aborts,
  `m[key] = v` upserts, and `m[key] += v` updates an existing key. `entry` returns an optional
  `Entry<a, K, V>` view with a shared key and a mutable value and has no `or_insert`; moving a
  non-copyable value out uses `remove`. Indexed assignment updates a named map or a field path.
- Syntax: `:=`, `mut`, `fn`, explicit `<T>`; record literals and patterns use field punning
  (`Point { x, y }`); no tail-expression returns, so a non-unit function returns with `return`; no
  tuples. Uppercase nominal/library types and
  interfaces (`Atomic<T>`, `Mutex<T>`, `Scope<C>`, `Task<R>`, `CancelToken`, `Fn`, `Self`);
  lowercase primitives, functions, fields and lifetimes; uppercase type parameters. `use
  module::Name` imports members; `::` paths; `.` fields and methods.
- Type aliases are intended for readable aggregates such as `type LoadError = IoError | ParseError`.
  They do not create nominal identity.
- Callable references such as `Fn(&T) -> &T` borrow freshly per invocation. Reference captures in
  closures are a separate mechanism.

## Cleanup baseline

Owned values are destroyed deterministically. Ordinary destruction is non-suspending and cannot
propagate recoverable errors. Abort makes no cleanup guarantee. A move suppresses later destruction
of the source. Fallible or suspending resource shutdown is an explicit operation. Affine ownership
guarantees at most one cleanup, not that every external resource receives a successful graceful
close.

## Deferred extension points

The following syntax is reserved for later semantic work and must not be accepted while ignored:

```grl
fn load(path: &[u8]) -> Document |? LoadError
    effects(suspend)
    requires(path.len() > 0)
    ensures(result.is_valid())
```

Capabilities are ordinary parameters, not effect names. A future entry point may supply an
authority root such as `fn main(host: Host) -> i64`. `host::` intrinsics are bootstrap conveniences,
not the final capability model. Compile-time execution must inherit an explicit authority model.

## V3 order

1. Capability/authority foundations and removal of ambient services.
2. Suspension effects, structured concurrency, cancellation and cleanup.
3. Exported ownership/effect summaries and ordinary/lending iterator protocols.
4. Contracts and optional verification.
5. Staging with explicit compile-time authority.

## Text note

Until a validated borrowed-text type exists, `split` yields byte views. String length and indexing
count bytes. A later `TextView<a>` can add validated borrowed text without changing reference syntax.
