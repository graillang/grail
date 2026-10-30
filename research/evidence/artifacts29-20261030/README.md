# Immutable native generation checkpoint

`checks.json`: full native-inclusive tests, format/Clippy/release, explicit TinyCC artifact/module
runs, real parser build/execution timings, file hashes and independent manifest SHA-256 verification.
The native generation test compiles real programs, verifies repeat/relocation identity, runs parallel
compiler processes and synchronized publishers/readers, ignores corrupted convenience copies, links
an older captured provider and rejects corrupted immutable bytes without replacing a valid client.
A native-backend failure also preserves the previous pointer/executable. Pure artifact unit tests use
synthetic bytes only for metadata/integrity admission and never execute them.

## A rejected reproducibility assumption

`tcc-before.json` retains a failed pre-fix control: two objects from identical API/C have equal `.text`
digests but different full bytes. ELF `FILE` symbols contain unique work-directory paths. Clang did
not expose that issue in the same test. The fix supplies relative source basenames from each isolated
job cwd (and absolute captured dependency paths); it does **not** rewrite or normalize object bytes.
Both backends now produce identical generation IDs and executable bytes across repeats and output
relocation for this corpus. This is not stage-2/stage-3 self-compilation or a universal backend theorem.

## Store and trust boundary

`.grail-store/<id>/` contains canonical header, generated C, native object and their hash manifest.
`<module>.artifact` selects it by atomic rename. Compiler readers capture the pointer once and verify
the generation; native links never read replaceable convenience objects. New files are written only
to fresh job directories, then atomically moved into the store. Existing generations are validated,
not overwritten. Executables are built privately and installed only on native success.

Old native flat outputs must be rebuilt; metadata-only declarations remain valid for independent
checking/FFI fixtures, not as a native-link fallback. Store hashes establish byte identity, not
producer honesty, a compiler soundness proof or protection against a hostile mutation **after**
verification. No fsync/power-loss durability promise, generation GC or automatic dependency rebuild
is implemented. All generations are retained; deleting them while builds use snapshots is unsupported.
The store uses standard filesystem rename guarantees; tests/evidence are Linux x86-64 only.

Real build timings here cover the existing two-module borrowed-number parser (`12+34+5` → 51),
including metadata/object verification and publication. TinyCC and clang are explicit separate
configurations; dependency ABI is unchanged. Host timings are small-sample engineering observations,
not optimized-compiler or general throughput claims. Full aggregates/generics/stdlib/self-hosting
acceptance criteria remain unfinished.

Reproduce with `python research/evidence/artifacts29-20261030/check.py` after installing the
project-local pinned nightly described in `research/experiments/rust_next20/README.md` and the
configured TinyCC build. The runner retains commands, environments, complete outputs and hashes;
its stable-release versus nightly-debug comparison is an output control, **not** a compiler-speed
comparison or a self-hosting claim. Ruff/CLI Pyright validate the runner; Rust workspace LSP is clean.
