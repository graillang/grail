# Dependency state-transformer experiment

A small typed-IR experiment, not a compiler. See [SPEC.md](SPEC.md) for the domain, assumptions,
contract meaning and unproved preservation obligation, and
[results](../../../docs/design/experiment-results-05.md) for evidence boundaries.

From the repository root:

```sh
python -m unittest research.experiments.transforms05.test_core
python -m research.experiments.transforms05.run_experiment
ruff check research/experiments/transforms05
ruff format --check research/experiments/transforms05
pyright --project research/experiments/transforms05
```

The runner requires Python 3.10+ and Linux bubblewrap for isolated clients. It regenerates evidence
in `research/evidence/transforms05-20261030` and uses ignored `.work` scratch. Unexpected files in
the consumer input bundle fail its inventory check rather than being silently deleted.

Inference uses current mutable state, generic entry-prefix routes and complete postconditions.
The body-free consumer validates exclusive locations before applying all outputs from one snapshot.
The concrete oracle does not import the transformer/inference implementation. Its client inputs
are the fixed one-element view lists/records described by the trace fixtures; it is not a general
concrete decoder for arbitrary abstract source-set maps.

Tests are justified by concrete failure modes: clear falsely retains old roots; replacement loses a
returned old root; sequential swap collapses the inputs; overlapping mutable aliases invalidate
strong updates; copying opaque T duplicates ownership; a schema-valid forged post-state lies about
the body. Ordinary type/lint checks cannot establish these dependency-state properties.
