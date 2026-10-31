# Loop-exit validation

Run `python research/experiments/loops38/check.py`. Uses installed stable/clang and existing pinned
nightly/TinyCC, offline Cargo, isolated ignored `.work`, no provider/model/default changes.

- Full suites and explicit clang/clang-release/TinyCC controls; C and LLVM numeric execution.
- Independent Rust numeric results and destructor traces; deliberate safe-Rust/Grail precision gap.
- Selected-object release audits and allocation-preserving optimized ASan/UBSan C probes.
- Frozen `a1dd4ee` rebuilt with `git archive`; 1,200 raw / 400 source checks compare acceptance and
  C/API bytes. Generated IR is compile/lower-only, never executed.
- Three-run sequential counted/while and new exit checking/emission medians at 32/128/512/1000 sites.

This does not complete conditional owner-state joins, typed mutable references/containers, generic
function templates or bootstrap self-compilation. See the design record and retained evidence.
