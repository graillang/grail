# Ownership/capture prior-art update

2026-10-30. Documentation and selected source inspected; no Swift, Mojo or OxCaml execution or
cross-language speed comparison. This qualifies the external review, not a final architecture vote.

## Swift: nonescapability is real, and generic support is a design problem

[SE-0446](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md)
and [SE-0465](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md)
are marked implemented in Swift 6.2 in the inspected proposals. They distinguish noncopyability
from nonescapability; those are different restrictions. The proposals and
[lifetime-dependency discussion](https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638)
also distinguish supported features from still-evolving dependency syntax.

Concrete lesson: wrappers must propagate dependencies. SE-0465 generalizes Optional/Result to
nonescapable payloads and explicitly discusses convenience APIs that require further lifetime support.
SE-0446 describes generic `~Escapable` constraints and restrictions on storing such values. This is
not simply "references without lifetime syntax": it introduces kinds/defaults that affect generic
libraries. Do not infer support for all returned/container/closure API shapes from the word Span.

For Grail, decide whether a generic T may contain views by default, how wrappers inherit those
origins and when a generic API may retain a value. Our shared-view prefix experiment addresses only
a small part of that question; it excludes owning moves and exclusive references.

## OxCaml: a common framework does not make properties identical

The [mode introduction](https://oxcaml.org/documentation/modes/intro/) distinguishes value type
(what it is) from mode (how it is used). It describes locality, uniqueness/linearity, portability
and contention, submoding and mode crossing. "Past" and "future" modes refer to use history versus
permitted future use, NOT whether a feature is on the roadmap.

The [stack-allocation reference](https://oxcaml.org/documentation/stack-allocation/reference/)
shows scoped regions and inference/annotation trade-offs. Global storage still uses GC: this is
not itself Grail's no-GC reclamation model. Mode crossing can depend on representation and abstract
type information; for example, an int-like handle may need abstraction to retain scope restrictions.

Lesson: representation-copyability is not semantic duplicability of resources. A file descriptor
wrapped in an integer must not become freely duplicable/escapable authority just because its bits
fit a register. Library/FFI boundaries must declare the appropriate ownership/authority invariants.

## Mojo: substantial origin overlap, not a blanket safety conclusion

The [origin manual](https://docs.modular.com/mojo/manual/values/lifetimes) documents symbolic compile-
time origins, automatic cases, parametric mutable/immutable origins, unions and explicit-origin APIs.
This strongly overlaps the raw "infer where references come from" idea. Do not claim that idea as
Grail novelty or assume origin annotations have been eliminated everywhere.

The same manual documents untracked and unsafe origins. Their presence is not evidence that every
safe API is unsound, just as Rust's unsafe allocation internals do not invalidate safe wrappers.
Audit which operations preserve tracked ownership, invalidate storage, cross device boundaries or
rely on unsafe obligations before comparing actual guarantees. No such full audit was done here.

## Quint Connect: model-to-implementation testing is implemented prior art

Pinned source `4f018f54fc7dd4cef341d10111427bab59d3b307`:
[Driver](https://github.com/quint-co/quint-connect/blob/4f018f54fc7dd4cef341d10111427bab59d3b307/connect/src/driver/mod.rs),
[State projection](https://github.com/quint-co/quint-connect/blob/4f018f54fc7dd4cef341d10111427bab59d3b307/connect/src/driver/state.rs).
The framework replays generated model transitions through a Rust driver and compares projected
implementation state. A stateless/unit projection explicitly disables state comparison. This is
an assurance-coverage choice, not a discovered vulnerability.

A driver/projection is part of the test's meaning. A bad or incomplete adapter can hide mismatches;
finite trace agreement is not an all-executions implementation proof. Tests should inject plausible
implementation/adapter mistakes and check whether the harness notices. The code was read, not built.

Implication for Grail: "AI writes a formal model and tests generated code against it" is not unique.
Potential added value would need demonstrated improvements in the native language, mandatory safety,
shared semantics/reduced adapter drift, assurance evidence or developer workflow. Sharing definitions
still cannot establish that requirements express independent human intent.

## Next high-value comparisons

- Conditional generic containment: Optional/Result/Vec of shared views, scoped exclusive views and
  captured values. Compare user annotation burden AND implementation rules.
- Fixed checked public bounds versus body-minimal inferred APIs, with real input-to-input stores.
- Permission/capture transport across scoped tasks, cancellation and opaque FFI/resource handles.
- Small representative real APIs before a fifty-crate exact-inference project or another compiler.

All items remain research recommendations. No new surface syntax, generic kind system or dependency
on these runtimes has been adopted.
