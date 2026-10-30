# Assessment of the rooted-value proposal

2026-10-30. Reviewed the complete 1,425-line document on the external branch, not just its summary:
[review at d7fb6bf](https://github.com/graillang/grail/blob/d7fb6bf/docs/design/first-principles-architecture.md).
**Branch fetched without merging.** This response proposes refinements, not language decisions.

## Verdict

Rooted value semantics is a serious candidate. Second-class parameter accesses plus first-class,
type-structured dependencies are a useful formulation of the value-first direction. Stable public
contract bounds, explicit call modes and cancellation-acknowledgment semantics deserve further work.

The document is more specific than its predecessor: it ALLOWS stored/returned exclusive views,
recognizes invariant referents under mut ref, and gives an escape table. Do not criticize it as
merely banning every hard case. However, "one qualifier mechanism" and "removed concepts" currently
outpace the stated rules. The missing details below should be tested before a large API audit.

## 1. Additive flows are not complete mutation contracts

The review defines `s -> cache` as adding dependencies and says qualifiers grow through input flows.
Consider:

```text
cache.push(view(old_source))
use(cache)
clear(mut cache)
end(old_source)
cache.push(view(new_source))
use(cache)
```

The actual cache after clear is empty. With only `post = pre ∪ additions`, old_source remains a
possible dependency, preventing its release while the reused cache's elements are later observed.
Conversely, interpreting "no flows" as empty would be unsound for a callee that preserves contents.

A contract needs a **post-state transformer per position**, allowing preserve, add, replace and
empty, with explicit pre-state references. A returned old value may retain pre-state dependencies
even when the input container's post-state no longer does. This is not necessarily a new surface
construct: the tool-written interface could carry it. But it is more than an additive arrow.

[Six concrete probes](../../research/experiments/review04/README.md) establish that rustc rejects
the plain clear/reuse example, but accepts a consuming retyped-empty helper written in safe Rust.
That helper does not establish allocation reuse. The problem is therefore not an impossibility
result or proof of Grail novelty: API and type-state design can expose the necessary transition.

The [state-transformer experiment](experiment-results-05.md) now exercises this gap in a restricted
view-data fragment. It tests generic strong updates and returned old values, not general mutable-view
variance or arbitrary resource cleanup.

Generic `remember[T](cache: mut Vec[T], x: T)` also needs precise rules. Under read-by-default,
moving noncopyable T into the vector requires `take x` or an appropriate copy bound. More deeply,
how do the different incoming qualifiers of cache elements and x combine under one T? Is a flow
implicit in qualified type matching, or exported as a generic post-transformer? "The types agree"
is not yet a rule. Test opaque generic forwarding together with mutable storage, not separately.

## 2. Names can disappear; callable permissions cannot

The review replaces Fn/FnMut/FnOnce with Shareable and Once. Our rustc probes distinguish:

- A closure with a moved-in mutable integer has no borrowed external capture; it is Sync but
  cannot be invoked through shared Fn access.
- A Cell-owning closure is invoked through shared Fn access but is not Sync. Cell is not a GC or
  RC mechanism; it illustrates that read-callability and concurrent sharing are different axes.

This does not show the eventual design unsound. It shows that a structural "no exclusive captures"
test is insufficient by itself. Record the **implicit receiver's call mode** (read/mut/take)
independently from permission to transfer/share the callable across tasks. That reuses the proposed
mode mechanism and can eliminate trait names from ordinary source without erasing the distinction.
The claim that reentrancy is impossible without self-capture also needs an explicit callback/access
argument; indirect callbacks and FFI can reenter code without a literal self-reference in a lambda.

## 3. Exclusive split and reborrow authority need rules

Lifetime dependency on a parent root is not the same fact as permission to mutate a disjoint part.
`split_at_mut` can produce two live exclusive views with one owning lifetime root. A reborrow can
then temporarily block one view without blocking its disjoint sibling.

A trusted split primitive can justify disjointness, but the type system still needs to represent
and transport that permission and distinguish parent/child access. The vocabulary of binding roots,
field paths and collapsed indices must explain this. Do not claim reborrowing is semantically gone
merely because ordinary access parameters begin after argument evaluation. The latter is a useful
simplification for calls such as push(len), not a complete first-class-view rule.

## 4. One nominal slot is a substantive precision trade-off

The review intentionally proposes one merged dependency slot for a nominal type's nongeneric view
fields, while preserving type-argument positions. That loses cross-boundary independence for a
simple nominal record with left/right views into different owners. Our prior flat-union rejection
case is directly relevant. Local field precision cannot recover information absent from an imported
interface.

Test this explicitly. Options include derived per-field positions for nonopaque records, declared
abstract ports for opaque types, or a simple conservative default with opt-in multiple slots. None
is selected. A curated forty-API corpus can compare them, but a 10% pivot threshold is a proposed
product/research choice, not a theorem or population estimate from deliberately difficult examples.

## 5. Bundle needs a view-family and projection contract

Heap-stable owner storage plus a result depending only on the owner is promising, not a complete
specification for arbitrary V. If V is an AST owning its node allocations, `view(): V` cannot copy
it out of shared access. Define whether the accessor returns a view/projection of V or consumes it.

Specify covariance/re-rooting, allowed mutation, drop order, hidden internal dependencies and whether
exclusive V is permitted. A shared accessor must not create duplicate exclusive views. The
[actual Yokeable safety docs](https://docs.rs/yoke/latest/yoke/trait.Yokeable.html) require suitable
lifetime variance and restrict mutations that could install shorter references. The
[self_cell accessor docs](https://docs.rs/self_cell/latest/self_cell/macro.self_cell.html) distinguish
covariant accessors from callback-based access. Neither precedent is just StableBorrow plus any V.
Language support may improve on these APIs, but needs a corresponding rule/proof, not their names.

The [Bundle follow-up](bundle-boundary.md) now records eighteen concrete Rust/library probes,
including successful shared field escape from a noncovariant callback and inline-owner stabilization.
Those distinctions refine the needed rules; they are not a Grail implementation or crate audit.

## 6. Pending operation values are the cleanup boundary to settle

Non-droppable running tasks, stable frames, cooperative cancel and join-before-release are a strong
semantic direction. Stable frames hide a pinning discipline; they do not abolish address-stability
obligations for movable values elsewhere.

But the device section returns first-class in-flight operation values. Consider:

```text
op = upload(buffer)
fallible_operation()?  // exits before op.wait()
```

Who retains the buffer, acknowledges cancellation and joins the operation? Non-suspending abandon
cannot simply release it. Safe alternatives include non-abandonable pending values, operations
registered with a scope that joins on ALL exits, or owned-buffer/restricted APIs. A scope registry
is plausible: starting work adds dependencies to it, and completing work removes them. This is
another reason to define state-changing dependency contracts, rather than rely solely on last-use
of the user handle. No actual implementation bug has been demonstrated; the rule is missing.

Finish-or-abandon remains worth exploring but has generic/container obligations: filtering or
clearing T cannot silently discard success-linear resources. The existing
[Linear Haskell FAQ](https://github.com/tweag/linear-types/blob/master/Proposals/linear-haskell-proposal-faq.org)
and [linear exceptions discussion](https://borretti.me/article/linear-types-exceptions) already
examine normal-completion linearity versus interrupted/affine behavior. Do not infer novelty from
not finding the exact phrase. Protocol completion, best-effort abandonment and memory safety must
be separate claims. Aborting OOM/panics is a real host-process trade-off, not a minor library detail.

## 7. Qualify broad compiler/proof claims

- Nonsuspending does not imply nonblocking, bounded, panic-free, allocation-free or GPU legal.
- FFI lifetime mapping does not establish ABI compatibility with arbitrary Rust or prove foreign code.
- Require exact preconditions to be discharged at every unguarded call, including untrusted foreign
  entry points. "Every caller verified" is not enough if those proofs concern unrelated properties.
- Distinguish facts established by the trusted ordinary compiler from independently kernel-checked
  facts. T1 optimization cannot implicitly demand Lean certificates in every ordinary build.
- Pure captures, exclusive scopes and capabilities provide useful structure, but data-race freedom
  and functional adequacy still require the proposed formal theorems. They do not already emerge as
  established results from this document.

## Recommended immediate work

1. Build the smallest pre/post dependency-transformer experiment: append, clear, replace, and return
   an old element while installing a new one. Include branch joins and opaque generic values.
2. Specify ordinary call-receiver permissions, disjoint split tokens/paths, and pending-work scope
   ownership with small examples before adding more features to the checker.
3. State the preservation/refinement lemma for that core, then validate a small representative API
   sample. Expand the sample only when its contract vocabulary is stable.

The reachability/Capless/Capybara papers are important prior art, not automatic proofs of Grail's
resource model. Follow their assumptions, freshness/generic machinery and concrete implementation
limits before claiming one qualifier set handles every case. Continue research; do not merge this
proposal as an adopted architecture or mistake model-family agreement for independent evidence.
