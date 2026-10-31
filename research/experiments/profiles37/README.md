# Actual native profile gate

Run `python research/experiments/profiles37/check.py`. Uses installed stable/clang and existing private
nightly/TinyCC, offline Cargo, job-owned scratch under `.work`; no model/provider/default changes.
The Rust test exercises public driver commands, not an alternative emitter or manually built program.

All positive scanner results must match independent Python over a hash-identified prefix of actual
seed source. Repeated module IDs/executable bytes must match for each profile; emitted C must match
across profiles. Three-run wall-clock medians include process startup and full driver work. Native
unit tests additionally check relocated immutable dependency stores, hidden providers, runtime guards,
empty/growing heap operations and crossings to/from optimized providers.

Reproducible for fixed selected native tools/libraries, not a complete hermetic bootstrap package,
final executable recipe manifest, full lexer or self-hosting demonstration.
