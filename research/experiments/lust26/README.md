# External aggregate/region controls

Read [review and results](../../../docs/design/lust-and-blu-notes.md). Fixtures are Rust, not Grail.
The three new rejection files are intentionally invalid and must never execute. Earlier
`referents14` rejection/precision controls are also compile-only. `SAFE` is an execution whitelist,
not a claim that every other source is dynamically unsafe.

From the Grail root, on Linux x86-64:

```sh
git clone https://github.com/t3dotgg/lust-lang.git ../lust-lang
git -C ../lust-lang checkout 240e08d91d4aed0299639f6f11fd522912b248f9
bash ../lust-lang/scripts/build-tcc.sh
cargo build --manifest-path ../lust-lang/Cargo.toml --bins
# Install the project-local pinned nightly described in rust_next20/README.md first.
python research/experiments/lust26/check.py
```

The runner checks the external source pin/clean tree, copies inputs into ignored `.work` before
calling Lust (which writes a cache next to its input), and retains source/compiler hashes and
commands/diagnostics/results in `research/evidence/lust26-20261030/checks.json`. It never starts a
daemon. Every accepted execution must also be whitelisted and accepted by the pinned modern Rust.
Rust is an independent execution/type-checking oracle here, not a proof of the external compiler.
The full Grail bootstrap and aggregate gates remain incomplete.

Validation: Ruff, CLI Pyright and focused LSP diagnostics of the runner are clean; Rust fixtures
pass rustfmt and are compiled by the pinned real Rust compiler (three new ones intentionally fail
type/borrow checking). The installed broker's Python workspace report is partial due to the known
`workspace/diagnostic` timeout; retain that raw limitation rather than claiming a clean full LSP
pass. The Agent source fixes for this broker behavior were already pushed earlier in this goal.
