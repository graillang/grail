# Sequential dependency preservation core

A kernel-checked **pure dependency model**, not a Grail compiler, heap/ownership model or
certificate checker for the earlier Python experiments. See the
[architecture synthesis and exact limits](../../../docs/design/preservation-core.md).

## Reproduce (Linux x86-64, Python 3.14+)

From the repository root:

```sh
python -m research.experiments.core10.check --fetch
python -m research.experiments.core10.check --output /tmp/core10-proof.json
ruff check research/experiments/core10/check.py
ruff format --check research/experiments/core10/check.py
pyright research/experiments/core10/check.py
```

`--fetch` explicitly downloads the official pinned Lean 4.35.0 archive, verifies its exact
size/SHA-256, and extracts it with Python's data filter under ignored `.work/`. No global
installation, elan, Lake, Mathlib, Aeneas build or third-party repository change is needed.
The archive and extracted toolchain occupy about 3.6 GiB. The runner requires 10 GiB free
before fetching/unpacking and limits extracted file sizes to 8 GiB in total.

Checks use the existing bubblewrap helper: no network or home, read-only compiler and input,
writable disposable work, CPU/time/file-size bounds. Lean warnings are errors. The runner
records source/compiler/runner hashes, exact version, output and the seven theorem axiom
reports. Only the standard `propext` axiom is allowed; missing reports, proof-hole tokens,
the known `skipKernelTC` bypass setting and unexpected theorem axioms fail the audit.
This is a guard against accidental proof holes, not a hostile-Lean-source security boundary.
The compiler, its standard library, kernel and host execution remain trusted.

## What is proved

- Every execution of every finite program in `Core.lean` preserves dependency coverage,
  for arbitrary payload types, dependency predicates, list lengths, root/slot populations
  and nondeterministic branch choices.
- A checked wider public post-bound remains sound and composes with producer coverage.
- A root absent from all tracked bounds is absent from tracked data dependencies.
- Tracked data is valid **if** its dependency predicate is truthful and its bounds name live roots.
- Closed counterexamples reject a retained source certified as empty, and source 0 certified
  as source 1 (the returned-old-value mistake).

`propext` appears in preservation, checked-contract composition and the two counterexamples.
The public-bound, root-absence and tracked-validity lemmas have no axiom dependencies.
There are no introduced domain axioms or admitted proofs. Local theorem premises are still
premises: the axiom report does not prove their applicability to an implementation.

The model has skip, clear, append-input-list, replace-and-save-old, take-and-save-old, swap,
forget-saved, sequencing and nondeterministic choice. All places are mathematical Nat slots;
all payloads are treated as pure data. There are no physical references or source types.
The result register is explicit so clearing storage cannot erase a returned old dependency.
