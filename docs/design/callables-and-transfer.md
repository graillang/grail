# Implemented callable and transfer foundations

This is a description of the current compiler, not a claim of a complete concurrency runtime.

## Capture-free function values

```grl
fn increment(value:num)->num{return value+1;}
fn apply<T,U>(function:fn(T)->U,value:T)->U{return function(value);}
fn identity<T>(value:T)->T{return value;}
fn main(){
    f:=increment;
    assert(apply(f,41)==42);
    assert(f(1)==2); // copying a permanent code address does not clone owned data
    specific:=identity<num>;
    assert(specific(42)==42);
}
```

Functions may take/return function values, and records/vectors may contain them. Function types
take any number of parameters, using the same convention as direct calls (five words in
registers, the rest in a record addressed by the sixth). Generic function items
require explicit type arguments when used as values; expected-type inference for bare generic
items is not implemented. Unsafe runtime function addresses cannot become safe callable values.
The callee and each argument are snapshotted left-to-right. Existing builtins keep their reserved
call resolution; a callable local is preferred over a same-named ordinary function. Non-callable
locals do not change the existing named-function lookup rules.

Signature checking preserves the relationship between input and output lifetimes, including
through generic callbacks. A function returning its first argument cannot be accepted under a
contract promising a borrow from only its second argument. Lifetime names themselves may differ.
Function-signature lifetimes are not captured storage: these values contain only a code address.
Capturing callables, callable interfaces and suspension/effect polymorphism remain in progress.

## Structural Send / Share

`fn transfer<T:Send>(value:T)->T` checks transfer permission. `T:Share` checks shared access;
combine them as `T:Send+Share`. Generic bodies need the corresponding proof even when unused.
Constraints are checked on function calls, explicit generic function values, record/enum type
arguments and inferred constructors. Forward-declared layouts are rechecked after collection.
There is no unsafe user assertion that an arbitrary type implements either capability.

Numeric/unit values, byte/string owners, atomic words and capture-free function pointers qualify.
Vectors and nominal aggregates require every contained type to qualify. Shared references need
a Share referent to transfer or share. Exclusive references may transfer when their referent is
Send; exclusive references and mutable views are conservatively not Share in this subset.
Their shared reborrows are distinct readonly types and may qualify. Bounds never extend a borrow's
lifetime, permit aliasing writes, or turn an unknown generic type into a copyable value.
Recursive structural checks are cycle-aware and have a finite analysis-depth limit.

## Atomic words

`a:=atomic(0)` creates one opaque, affine, aligned `atomic<num>`. Safe code cannot access its
payload through ordinary loads/stores or copy the owner. Aggregate/vector cleanup frees it once.

- `load()`, `store(value)`, `swap(value)`, `fetch_add(value)`, `fetch_sub(value)` and
  `compare_exchange(expected,desired)` are sequentially consistent.
- `load_relaxed()`, `load_acquire()`, `store_relaxed(value)` and `store_release(value)` select
  valid weaker orderings. Stronger-than-requested barriers are allowed; this is not a claim of
  an optimized minimal-fence implementation.
- Fetch arithmetic wraps modulo 2⁶⁴ regardless of checked ordinary arithmetic.
- Strong CAS returns the observed old value; equality with expected means success.

Operations require read authority, including through a shared reference, and retain a receiver
loan throughout argument evaluation. Interior mutation does not permit replacing/dropping the
owner, mutating adjacent fields or bypassing scope lifetimes. Current exclusive-parent loan
suspension remains conservative: use an explicit shared reborrow for nested calls through an
exclusive reference. RISC-V requires the A extension, hence RV64IMA rather than RV64IM.

Allocator locking and these primitives are prerequisites only. No task/thread scheduling,
capturing closures, scoped joining, cancellation or colourless I/O API is claimed here.
