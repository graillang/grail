# Opaque ownership and pending work

[Findings, source explanation and limits](../../../docs/design/opaque-resource-boundary.md).

```sh
# Repository root; the inspected active Rust 1.98.0 toolchain, Python, bubblewrap.
python -m research.experiments.resources15.check
ruff check research/experiments/resources15
ruff format --check research/experiments/resources15
pyright research/experiments/resources15
rustfmt --edition 2024 --check research/experiments/resources15/*.rs
```

The seven cases produce three completed executions, three compile rejections and one bounded
stall observation. The latter **is not completion**: the child and scope-body markers must appear,
`scope_returned` must not appear, and the process must time out at 8s. A normal-drop control returns.
The source explains why this version's leaked packet reference prevents scope accounting release;
wall-time sampling alone is not a proof. Marker order is deliberately not tested.

No rejected fixture executes, including unexpected acceptance. Rust execution/compilation uses
read-only toolchain/input mounts without home/network. Timed-out owned processes are checked for
residue. The registry/channel/Arc implementation is observed Rust behavior, not Grail's chosen ABI,
a no-RC claim or a performance benchmark.

`std-provenance.json` pins three inspected source hashes/URLs to the compiler commit. Their installed
copies were compared with the public commit when acquired. The runner rejects a compiler mismatch;
when matching rust-src is installed, it rechecks those hashes and records availability explicitly.
No network or toolchain installation is required by a normal check.
