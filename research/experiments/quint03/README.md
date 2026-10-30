# Quint exploration 03

Uses the existing local `@informalsystems/quint` 0.30.0 installation, run with Bun 1.4.4 and its
TypeScript simulator in a network/home-isolated bubblewrap environment. No installation occurs.
The inspected current repository is 0.33.1; a matching v0.30.0 source tag was also inspected.

Run from the Grail root:

```sh
python research/experiments/quint03/check.py
```

Requires Linux/bubblewrap, Bun and the existing global package at the path in `run.py`. Change
`MODULES` for another local installation; record its version and hashes. The sandbox mounts global
node_modules read-only, not the user's home/configuration. The Node 26 attempt failed loading the
local yargs dependency; no installed package was patched. Bun executed the package successfully.

Eight expected outcomes:

- Static acceptance: cancellation model and an effect-polymorphic higher-order combinator.
- Static rejection: pure state read, state read hidden through a callback, duplicate state update.
- Sampled simulation: no safety violation in the guarded cancellation model under requested bounds.
- Two counterexamples: releasing storage before cancellation acknowledgment; reallocating it while
  the parent is alive but a child retains an old-generation loan.

The corrected model permits stuttering: its safety checks say nothing about eventual acknowledgment
or bounded cleanup. The abstract `acknowledge` event assumes the child/device has actually stopped
using storage. This is not a scheduler, kernel-I/O implementation or verified ownership compiler.

Results and ITF traces go to `research/evidence/prior-art03-20261030/`. The simulations request up
to 1,000 samples of at most 12 steps, with seed 20261030; bad cases stop when a violation is found.
No Apalache/TLC run or machine-checked theorem was performed. No Java toolchain was installed.
