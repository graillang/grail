# Tagged values, matching and unwrap

> Historical design record: examples and implementation status below describe an earlier compiler.
> The current language uses `T[]`, `T?`, `[K: V]`, and structural unions `T | E`;
> `core::Option`, `core::Result`, `core::Pair`, and tuple syntax are not current APIs.

Source modules may declare `enum Parsed<a>{Ok(Token<a>),Err(string)}`. Variants currently carry
one value or unit; use a record for a multi-field payload. Construct with `Parsed::Ok(value)` or
`Parsed::Err(error)`. A payload-free alternative is written `None` and constructed as `Option::None`.
This is a real tagged union, not a record holding both payloads.

`match value { Ok(payload)=>{ ... }, Err(error)=>{ ... } }` consumes its input. Every variant must
appear exactly once. Bindings are scoped to the arm; `Err(_)` still moves and destroys an ignored
owned payload. Arm returns clean every remaining function owner. Continuing arm states must agree
under the existing join rules. Field projection cannot bypass the tag check; nested field ownership
becomes available after extracting the selected payload. General recursive/nested patterns,
wildcard arms and direct multi-field variant syntax remain to implement.

Postfix `value!` consumes a two-member result shape, transfers the success payload, and aborts on
failure. It has higher precedence than arithmetic and may chain. There is no implicit error
conversion and no cleanup promise after abort. Postfix `?` propagates matching errors or None through
ordinary checked return cleanup; see [propagation](error-propagation.md). Generic `Result<T, E>` and
`Option<T>` are standard-library types (`lib/result.grl`), and `?`/`!` accept them through the
shape rule rather than through variant names; see [generic results](generic-results.md). `unit` /
`()` are genuine scalar unit type/value operations, including function interfaces.

## Ownership and representation

The checker keeps possible payload states, never exposing a variant without match/unwrap.
An actual constructor payload retains its own roots and capabilities; impossible alternatives have
no origins. Opaque input/result values conservatively cover all declared alternatives. On extraction,
other alternative states are removed and the selected payload transfers exactly once. Constructor
inputs must be complete, type/mode-compatible and unborrowed when owned.

C emits a 64-bit tag and union payload. Per-owned-leaf flags are initialized from tag predicates;
nested predicates short-circuit before any inactive union read. Move/argument transfer clears source
flags. Default destruction visits only initialized active payload leaves. Public values are complete
and carry no local drop flags. Unit-only enums need no payload union.

Module schema 3 identifies record versus enum layouts and covers ordered variant names/types in
public fingerprints. Function payload schema 5 adds unit. Previous schemas require rebuilding;
there are no compatibility decoder stubs. Hidden-source clients and layout-only stale rejection are
tested, including clang/TinyCC ABI composition in both directions. Primitive LLVM still rejects
used nominal/heap layouts; unit functions are exercised there independently.

Nominal output capture slots may be unanchored when no returned alternative actually borrows;
for example `fn error<a>()->Parsed<a>{return Parsed::Err("bad");}`. Every actual return origin must
still match a declared input reference path/slot; owned string/parameter storage and local owners
cannot fabricate that lifetime. Direct view interfaces retain their input-anchor rule. This is
universal written lifetime checking with empty alternatives, not inferred G1 post-state precision.

## Evidence limits

`research/experiments/enums32/check.py` retains stable/nightly conformance, native active-payload
allocation auditing, both mixed-backend directions, compile-only Rust negatives, executable Rust
controls and checking-cost samples. Recoverable decimal parsing tests zero, leading zeros, bad
bytes, empty input, maximum u64 and overflow; it does not claim a completed stdlib/compiler port.
The allocator wrapper and separate native execution are falsification evidence, not formal proofs.
Generic containers, general typed references/invariance, richer patterns and self-hosting
remain required v0 work.
