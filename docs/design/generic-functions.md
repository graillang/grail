# Checked by-value generic functions

This implements the first function gate in [generic lowering](generic-lowering-gates.md), on top
of [generic value layouts](generic-layouts.md). It does **not** complete bootstrap v0, typed
aggregate references, arbitrary-element heap vectors or the real compiler port.

## Source and ordinary checking

```grl
pub fn identity<type T>(value:T)->T{return value;}
pub fn some<type T>(value:T)->Option<T>{return Option::Some(value);}
fn second<type T,type U>(first:T,second:U)->U{return identity(second);}
```

Lifetime parameters precede `type` parameters. Calls infer type arguments from their actual inputs,
or write them explicitly: `core::ok<Token<a>,string>(token)`. Output-only arguments must be explicit,
e.g. `core::none<string>()`. Constructor inference remains the narrower same-nominal written-result
rule; otherwise constructors still need explicit type arguments. Left-to-right eager argument
snapshots apply to generic calls too. There is no implicit clone, specialization overload, trait
search, higher-ranked bound or full G1 post-state inference.

A parameter `T` is an **opaque affine value** in the body. It can move, drop, be placed in a record
or enum, be extracted/returned, or be passed through another declared generic contract. It cannot
be duplicated, synthesized from a number, indexed or assumed to have numeric/byte operations merely
because one caller happens to instantiate that type. Even unused definitions universally check.
Producer bodies check independently; checked IR loading rechecks the same universal definitions.
Callers use instantiated written signatures with their actual origins, loans and authority, never
private-body root inference. Specialization receives checked type/operation tables, not caller
ownership states, and does not rerun borrowing against caller roots.

Opaque parameters conservatively require cleanup. Concrete substitutions recover existing recursive
destruction and borrowed-capture behavior. Type arguments inserted into another binder retain their
own scope: a caller's second type parameter is not rebound to the callee's first parameter. Captured
byte-view lifetime labels are still distinct from referent identity and mutable authority. The
existing conservative origin unions can reject programs Rust accepts; this does not introduce
general typed-reference variance, nested writeback summaries or an escape hatch around those gates.

Expression statements, including qualified generic calls, close their result and temporary owners
at statement end. `core::discard(pair);` needs no dummy binding. Named owners outside that statement
keep their lexical lifetime unless consumed. Explicit binding/return retain values normally.

## Standard library and native materialization

`seed/std/core.grl` now provides `some`, `none`, `ok`, `err`, `pair`, `unwrap_option`, `unwrap_result`,
`discard` and `identity` in real Grail source, alongside Option/Result/Pair layouts. It has generic
exports but no executable entry. Modules with concrete exports select the first public **nongeneric**
function as entry; type-only modules remain valid without a dummy function.

Native C uses static concrete specialization of universally checked IR. Reachable instances and
private helpers get internal hash-qualified symbols. Recursive instances enter the memo before
processing their calls; repeated calls share one instance within a compilation. Lifetime **values**
and caller root/loan IDs are absent from native keys. Keys retain shapes, modes, lifetime-slot
arities, relevant caller-private layout definitions and implementation-closure hashes. No persistent
or cross-module specialization cache is claimed. Numeric generic code also uses the comparison
LLVM path; owned heap/nominal layouts retain that backend's explicit restriction.

Native materialization is bounded to 4096 functions, including ordinary reachable functions and
private helper copies. Type-expression depth/node bounds apply during substitution, before an
expanded tree is copied/formatted. Growing polymorphic recursion rejects rather than expanding
unboundedly. These are implementation limits, not evidence that large generic graphs are cheap.

## Separate compilation, canonical artifacts and invalidation

Module schema **5** / surface schema **5** carry ordinary and generic contracts, reachable public
layouts, ordinary dependency surface hashes, optional template body hash and implementation pins.
Function signature schema remains **6**. Artifact manifest schema **2** binds `.api`, `.c`, `.o`
and `.ir` hashes. `.ir` is empty for modules without local generic definitions. Rebuild obsolete
artifacts; there is no compatibility reader or alternate stale-object route.

Template bundle/checked-IR schema 2 uses canonical bounded netstrings, including literal bytes.
The bundle includes generic definitions, private concrete helpers and layout context. This first
closure is deliberately coarse: unused private helper/layout edits may invalidate consumers too.
Public concrete helper calls remain separately linked calls. Public fingerprints exclude function
body hashes/pins, but native consumers separately pin generic implementation closures. A private
body edit invalidates consumers even when its public surface is unchanged. **Transitive pins are
inside the closure hash**: rebuilding intermediate A after B changes must also invalidate old
consumers of A. Final linking checks the full dependency graph, including embedded specializations.

Metadata-only checking needs contracts, not dependency body bytes. Native consumers need verified
immutable IR and object generations, never provider source or replaceable convenience copies.
Publication rejects missing/mismatched generic payloads. Payload loading verifies hashes, module,
public layouts/contracts, helper ABIs, canonical shape and universal body checks before use.
Malformed/stale builds preserve the prior published executable/generation. The public emitter
`emit::module_c` now returns `Result`; external bodies use its bundle/resolver variants.

Bounds include 16 MiB IR/bundle, 4096 bundle functions, 262144 total operations, 65536 operations
per list, nesting 64, plus the existing 8 MiB module and 64 KiB function-contract limits. Limits are
not an adversarial-host sandbox. Host filesystem writers, native producers/compiler/linker/runtime,
IR codec and specialization implementation remain in the TCB. Hashes bind bytes, not producer
honesty or a soundness theorem; no hermetic whole-executable inventory or self-hosting is implied.

## Evidence and next gates

Reproduce `python research/experiments/templates39/check.py`; see
[retained results](../../research/evidence/templates39-20261031/README.md). Tests cover source-hidden
private helper closures, transitive body invalidation, malformed IR, mode/origin/alias negatives,
eager evaluation, ordinary and growing recursion, lifetime-only code sharing, caller-private layout
keys, recursive cleanup and Result propagation, mixed native profiles and independent Rust controls.
A 131072-token scanner composes borrowed spans/owned spellings with the actual generic library.

[Mutable referent witnesses and opaque writeback](mutable-references.md) now extend these generic
contracts. Arbitrary-element owned heap collections, remaining conditional ownership joins,
the **real seed port**, deterministic stage-2/stage-3 and a retained reproducible bootstrap artifact remain required, unfinished gates.
