# Generic ABI and typed-reference boundary evidence

`checks.json` retains all commands, compiler versions, source/input hashes, expected accept/reject,
raw timings, median summaries, provider symbols and output sizes. Inputs/outputs are reconstructed
under ignored `.work`. clang links all profiles deliberately; no silent backend fallback or LTO.
These are C backend prototypes plus Rust reference controls, not Grail generic/reference features.

The first failed attempt is retained in `header-limit-before.json`: this TinyCC header set lacked
`max_align_t`. The private native alignment witness fixes that header dependency; it does not impose
boxing or establish arbitrary alignment support. Explicit runtime alignment guards remain.

All runtime samples check an independent Python checksum and token/allocation counts against the
same retained source corpus. Owned text/token/node cleanup and borrowed spans compose in these
programs. Mixed-provider/client runs test ABI, while positive ASan/UBSan runs check these workloads
for memory errors. Dynamic stack temporaries and selection/freeing of owned values pass. The
snapshot control deliberately observes the **defined semantic mismatch** 7 / 99 / 7, not unsafe UB.

All 12 stable/modern-nightly Rust controls match their expected outcomes. Negative lifetime/alias
controls are compile-only and never execute. They constrain the next Grail implementation rather
than being passed by its currently unsupported syntax. C LSP fallback flags are explicitly not a
build-context proof; actual native compilations and sanitizer commands are retained.

Measurements expose the trade-off: static code is faster for numeric operations in this fixture,
shared code is smaller and substantially cheaper under optimizing clang at high instance counts;
owned-workload runtime differences are small. They do not establish whole-compiler performance or
capture checking, lifetime inference, recursive layout, private generic artifact or module-cache
correctness. Those remain implementation gates, not concessions to v0 scope.
