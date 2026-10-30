# Grail

A programming-language research project. Source files use **`.grl`**.

We are settling the semantic foundations, not building a full compiler yet.
The ambition is a small, practical systems language with fast builds, deterministic
memory management, explicit effects, and independently checkable correctness evidence.
No performance or verification claims have been established for Grail.

## Living design record

- [Bundle construction, projection and ownership boundaries](docs/design/bundle-boundary.md)
- [Pending-work ownership and error cleanup](docs/design/cleanup-boundary.md)
- [Dependency state-transformer experiment](docs/design/experiment-results-05.md)
- [Assessment of the rooted-value proposal](docs/design/rooted-values-review.md)
- [Quint lessons and executed models](docs/design/quint-lessons.md)
- [Haskell successes, costs, and design lessons](docs/design/haskell-lessons.md)
- [Ownership/capture prior-art update](docs/design/ownership-prior-art-update.md)
- [Origin/capture inference results](docs/design/experiment-results-02.md)
- [First measured results](docs/design/experiment-results-01.md)
- [Initial architectural review](docs/design/initial-review.md)
- [Memory-model competition and response to critique](docs/design/memory-model-competition.md)
- [Decisions, open questions, and rejected directions](docs/design/decisions.md)
- [Illustrative surface language](docs/design/surface-sketch.md) — not a specification
- [Validation experiments and minimal prototype](docs/design/experiments.md)
- [Research sources and evidence boundaries](docs/design/sources.md)
- [Pinned repositories](research/evidence/repository-pins.json)

Research is evidence-led. A source inspection is not an independent benchmark,
and a checked source theorem is not automatically a theorem about machine code.
