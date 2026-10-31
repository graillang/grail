# Actual native release profile

`checks.json` is the successful 30-command gate with exact commands, versions, outputs, statuses,
environments and source hashes. Stable and pinned nightly each pass **59 checker/source/hash +
13 native tests** (72 total), followed by explicit mixed-profile and optimized UTF-8/publication tests.
No provider/model/default host toolchain settings change; offline Cargo and existing installed tools.

The new native test uses the real driver in development (`clang`), optimizing (`clang-release`) and
configured TinyCC modes. It removes generic type/function provider sources, relocates immutable
provider stores, and requires the same module IDs, C and executable bytes on repeated/relocated
builds within a profile. Across profiles interfaces and C agree, while optimization changes actual
object bytes. Optimized-provider/TinyCC-caller and TinyCC-provider/optimized-caller execution pass.
Empty slices/copies/text, nested owned generic payloads, byte-vector growth, wrapping results,
zero-remainder/bounds/unwrap abort guards and failed-build publication preservation are exercised.
Existing UTF-8 controls additionally run under the real release driver, and release artifacts pass
concurrent publication, stale snapshot, corrupt-convenience-copy and corruption-failure controls.

## Real-driver costs

The checked-in `scan.grl` classifies word bytes and accumulates a wrapping hash over 32768 bytes
from actual seed parser source, repeated 128 times (4 MiB scanned). Independent Python computes
checksum `17069790510499222019`; corpus/input hashes are retained. This is a scanner precursor,
not a complete lexer or self-hosted compiler. All builds use the same emitted C. Three repetitions
per profile must reproduce artifact generations and executable hashes exactly.

| profile | full driver build median | process/runtime median | object bytes | executable bytes |
| --- | ---: | ---: | ---: | ---: |
| clang development (`-O0`) | 76.41 ms | 25.89 ms | 2152 | 16192 |
| clang release (`-O2`) | 83.20 ms | 4.72 ms | 1104 | 16112 |
| TinyCC development | 6.65 ms | 24.58 ms | 1984 | 5098 |

Here optimizing runtime is about 5.5× faster with a modest build-time increase; TinyCC remains the
fast-build option. These small workloads/three samples are not broad compiler performance claims;
measurements include process startup. No optimizer settings were weakened to preserve allocation
counter observations. Allocator-trace instrumentation remains a separate test, not release semantics.

Rust/Python LSP diagnostics are clean and retained. `python-lsp-before.json` preserves a repaired
possibly-unbound recorder variable diagnostic, not a compiler safety failure. The first launcher also
failed before running Python because its scratch log directory was absent; final launch uses the
created directory. Development test drafts initially used invalid builtin/view syntax, corrected
without weakening language checking.

Reproducibility is for fixed selected tools, inputs and dependency objects/system libraries. The
module manifest binds C/API/object bytes but not a complete final executable/toolchain/link recipe.
Hermetic bootstrap packaging, explicit linked implementation inventories, the actual Grail compiler
port and deterministic stage-2/stage-3 demonstration remain required, unfinished v0 work.
