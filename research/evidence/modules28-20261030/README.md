# Public module contracts and transitive native linking

`checks.json` retains the full native-inclusive suite, format, Clippy, release build and repeated
module-native tests with explicit TinyCC selection. Clang and TinyCC clients execute transitive
hidden-source providers; a separately lowered LLVM provider matches. Tests change a private body
without changing the public header, then change a public signature and require stale-client rejection
before replacing prior client outputs. Valid native objects behind a cyclic metadata graph cannot
link through the source driver. Qualified borrowed returns preserve owner/loan restrictions.
Explicit modules can put private helpers first and need no dummy module-named function.

The example headers here come from `seed/examples/modules`; the compiled app returns 16. The runner
independently reconstructed surface framing with Python hashlib and checked both dependency digests.
SHA-256 also has standard empty/short/multi-block known-vector tests. This is identity/invalidation,
not producer authentication. The current flat artifact store does not prevent a concurrent or hostile
object replacement race; immutable atomic publication is still unfinished. Type definitions, generic
containers and complete bootstrap/self-hosting are not demonstrated by these primitive modules.

`cost_harness.rs`: public-source checking and a separate encode/decode/fingerprint pass, release-built
seed, five repetitions per size, host-local medians. `costs.txt`: exports, bytes, check seconds, codec/hash
seconds. 250/1,000/4,000 exports occupy 9,430/37,931/154,931 bytes. This narrow synthetic probe is not a
real-compiler, native-build or runtime benchmark. Reproduce after building the release seed:

```sh
rustc --edition=2024 -O research/evidence/modules28-20261030/cost_harness.rs \
  --extern grail_seed=seed/target/release/libgrail_seed.rlib \
  -L dependency=seed/target/release/deps -o /tmp/grail-module-cost
/tmp/grail-module-cost
```

Rebuild prior source artifacts: source module schema 1 replaces standalone source signature files.
The active typed-IR fixtures retain function-signature schema 3, also used as module function payloads.
No parser fallback or nested helper-module storage remains in the source path.
