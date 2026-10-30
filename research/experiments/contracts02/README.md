# Contract inference experiment 02

A bounded executable design experiment, not a compiler, full ownership checker or soundness proof.
Read [SPEC.md](SPEC.md) for assumptions and unsupported constructs before interpreting green tests.
All code uses Python's standard library. No system dependency installation is needed.

From the Grail repository root:

```sh
python -m unittest discover -s research/experiments/contracts02 -v
python research/experiments/contracts02/run_experiment.py
python research/experiments/contracts02/stress.py
python research/experiments/contracts02/benchmark.py
ruff check research/experiments/contracts02/*.py
pyright --project research/experiments/contracts02/pyrightconfig.json
```

The isolated consumer step requires Linux/bubblewrap and reuses `memory01/sandbox.py`.
The consumer sees only four consumer/model modules, contracts and clients. It cannot access the
provider IR, inference implementation, user's home or network. The provider and stress tools run
locally on generated test inputs; no third-party code/build scripts are executed by this experiment.

Outputs go to `research/evidence/contracts02-20261030/`; rerunning overwrites that run's files.
The final manifest records source hashes and versions. Keep another run directory when comparing
changed implementations. `.work` contains generated consumer inputs and is excluded from Git.

## What's implemented

- Shared-view origins inferred from typed constructors, projections, choices and calls.
- Fixed-point summaries for a recursive tree-construction fixture.
- Opaque generic forwarding and composition using imported contracts only.
- Captured-view dependency tracking, field-sensitive future-use checking, invalidation rejection.
- A fixed scoped-callback protocol; direct/aggregate/capture/generic escape rejected.
- Interned source sets, deterministic export, structural decoding and dependency digests.
- An independent bounded concrete dependency evaluator and a separate allocation-epoch client model.
- A naive client lookup retained as a tested performance/correctness reference for the root index.

## What is NOT implemented

No parsing of Grail or Rust source, lowering correctness, general imperative control flow, own-value
moves, mutable-view returns, arbitrary higher-order inference, node allocation/drop checking,
real runtime closures, graph alias analysis, async I/O, effects beyond this scoped protocol, proof
certificates, or native performance claims. The parser-shaped IR is an abstract recursive constructor
workload, not the real parser from experiment 01 translated automatically.

`input-ir.json` supplies types and parameter access conventions but no result-origin annotations.
`contracts.json` is an inferred interface, not a proof certificate. Tests deliberately show a
schema-valid forged contract fooling the consumer: provenance/producer trust remains in the TCB.
The independent evaluator catches that particular forgery, not every possible implementation bug.
