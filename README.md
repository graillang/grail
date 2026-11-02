# Grail

A programming-language research project. Source files use **`.grl`**.

## Learn by example

```sh
just book
```

Open **[Grail by Example](book/README.md)**: 20 chapters, runnable examples, and collapsible
side-by-side Rust comparisons. Building the offline book needs Bun 1.4+ and `just`.

```grl
fn main() {
    println("Hello, world!");
}
```

Run it with `just book-run hello`. Check all Grail examples and their Rust comparisons with
`just book-check` (Linux x86-64, GNU as/ld and rustc).

## Current implementation

The [Grail-written native compiler](compiler/NATIVE.md) self-compiles directly through assembly,
with a Grail-written runtime, ownership/borrow checking, deterministic cleanup and generic
specialization. Its Linux x86-64 path needs neither a C compiler nor libc. The
[Rust seed](seed/README.md) and [older C bootstrap](compiler/README.md) remain independent
checking and recovery routes.

This is still a research implementation, not a proof of language soundness or a portable,
release-qualified language. See the native implementation boundaries and the book's final chapter.
Initial [seed measurements](docs/design/seed-measurements.md) cover a restricted typed IR,
not full-language performance or safety.

## Living design record

- [Bootstrap v0 decisions and implemented source subset](docs/design/bootstrap-v0.md)
- [Self-hosted compiler and bootstrap artifact](compiler/README.md)

- [Argument evaluation and call activation](docs/design/call-activation-boundary.md)
- [Lifetime roots and exclusive-access authority](docs/design/authority-boundary.md)
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
