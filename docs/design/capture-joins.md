# Retained-slot capture joins and loop fixed points

This extends [mutable captured storage](mutable-references.md) across ordinary control flow. It
removes the temporary exact-capture-state loop barrier, not the remaining ownership-join requirements
of [bootstrap v0](bootstrap-v0.md). The checker still does not implement conditional moves, differing
partial initialization, or joins that add/remove addressed scalar resources.

## What joins mean

Two continuing paths may retain the same storage positions while carrying different possible data
sources. Those sources, target places and parent ancestors are unioned. Storage type/lifetime
instances, reference capability identity, capture activity and field-initialization shape must agree.
A shared data source selected on either path remains borrowed after the join. A source overwritten
on both paths can be released. Unique authority is not inferred from nonoverlapping origin sets.

These are checked local and external cell states, not private function effects. Calls still use the
written G0 contract and retain all its eligible sources. Immutable type witnesses do not shorten to
fit a new branch/iteration. Real owned fields keep their existing recursive move/drop obligations.

## Loops

Counted and while loops share one analysis:

1. Start with the incoming retained state. Analyze the condition and body from that header.
2. Collect `continue`/fallthrough backedges separately from `break` exits. A return is checked as a
   function return; it is not a continuing loop edge. Edge snapshots exclude their own loop frame.
3. Join backedges with the initial state, preserving the possible zero-iteration counted path.
   Recheck the body from the widened header until the capture maps stabilize, with a 4096-round cap.
4. Join feasible exits. While-condition effects apply on the false/zero-body path too; the checker
   does not incorrectly restore the pre-test contents. Breaks do not become backedges.

A body valid on iteration one may become invalid later: a stored view may borrow an owner the next
iteration attempts to grow. Rechecking must reject that access. The earlier stale external-cell
counterexample still rejects, now because the widened source set cannot prove its claimed long
return, not because all mutation is prohibited.

Fresh temporary capability IDs are iteration-local. Retained reference slots keep their identities;
non-reference IDs are canonicalized after shape/bound checks. An ancestry edge to a destroyed local
carrier is removed, but every still-live parent in local values **or external memory** stays frozen.
Data roots are never removed by this normalization. Repeated unique Option pop / carrier destruction
is executable evidence for this distinction. This is not permission to revive or duplicate unique
parents, nor a general maybe-initialized-state model.

Index rebuilding follows actual source/target/ancestor growth. Stable facts reuse their existing
indexes. There is no generated-code or runtime lifetime representation for these joins, and no new
IR schema or compatibility route: IR/template bundles remain schema 2.

## Evidence, cost and unfinished work

Reproduce `python research/experiments/captures41/check.py --joins`; see
[retained results](../../research/evidence/joins43-20261031/README.md). Tests include local/external
branch mutation, mixed break/continue and zero paths, later-iteration growth, live/dead ancestry,
unique Option pop, hidden generic modules, deterministic destruction, C/LLVM descriptor execution,
independent stable/nightly Rust, frozen replay and a mutable-cursor lexer that updates storage from
inside its validation loop. Its control advances once per token; runtime differences include that
extra work, not just compiler changes.

The Rust controls distinguish plain assignment from initialized-value replacement: the initially
miswritten assignment control compiled, while matching Grail's `exchange` with `mem::replace` rejects.
The accepted assignment is retained as a positive Rust control, not counted as a negative success.

Explicit origin matrices still have quadratic worst-case storage/index costs. This finite workload
is not a whole-compiler scaling result or a soundness theorem. Conditional ownership/partial moves,
addressed-scalar initialization joins, more precise field/parent loan ending, regular recursive
reference graphs, real arbitrary-element heap collections, the real seed port, stage-2/stage-3 and
reproducible bootstrap artifact delivery remain required. No permanent v0 exclusions are approved by
this checkpoint. The checker, normalization, codecs, native producers/toolchains/runtime and host
remain in the TCB.
