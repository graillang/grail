# Generic lowering and reference gates

## Decision for the first implementation

Start with static type/layout specialization and explicit instance accounting. This does **not** mean
checking functions separately for caller roots, specializing by loan identity, or inferring private
post-states at calls. Generic bodies must check against declared symbolic types/lifetimes/bounds;
code generation may then substitute concrete type layouts. Regions/origin sets are not native
instance keys. A shared development ABI remains viable, but is not a second production path yet.

The earlier memory01 Rust fixture measured compile cost without runtime/container work. generic35
extends that evidence with separately compiled C providers/clients, number/text/token/node vectors,
borrowed spans into a retained real seed-source corpus, owned names, 0/16/64/256 extra nominal
instances, native allocation balance and an independent Python checksum. It also executes 12 Rust
reference/lifetime controls on stable and pinned modern nightly. These are preimplementation gates,
not implemented Grail generics, container safety or general references.

Three-run exploratory samples at 256 extra types initially showed:

| Profile | Specialized build | Erased build | Specialized numeric | Erased numeric |
|---|---:|---:|---:|---:|
| TinyCC development | 34 ms | 32 ms | 8.4 ms | 13.9 ms |
| clang development | 328 ms | 129 ms | 8.1 ms | 13.0 ms |
| clang optimized | 1.10 s | 0.37 s | 6.6 ms | 10.5 ms |

The numeric workload performs one million pushes/reads/pops; the owned token/node workload scans
174,610 bytes / 18,434 lexical spans. Owned-workload differences are small and do not establish a
winner. Optimized object totals at 256 types were about 302 KB versus 111 KB. Static specialization
has a real code-size/release-build cost; TinyCC makes this small prototype's development difference
modest. Final rerun samples are retained, not rounded table values as hard thresholds. All links use
clang intentionally to hold linker choice constant; TinyCC rows measure its object generation, not
an end-to-end Grail driver build. No LTO, CPU pinning, cache flushing or confidence interval claim.

The prototype's erased ABI is not mandatory heap boxing or RC. A separate dynamic-frame control
swaps a runtime-sized 2 KB value on an aligned C stack buffer and moves/drops owned text on both
compilers. But it does not cover generic record field-layout descriptors, recursive generic graphs,
Grail checking/instantiation cost, template artifact encoding or real compiler self-hosting.

## Hard semantic conditions

1. **Eager arguments.** Passing an erased value by address is not automatically a value snapshot.
   A defined-C control gives 7 for a by-value argument, 99 for a wrong address-forwarding convention,
   and 7 after a caller snapshot when another argument mutates the old slot. Preserve the existing
   left-to-right argument materialization and error-path cleanup.
2. **Outer loan versus captured lifetime.** Copying a shared source descriptor from a short cursor
   borrow can return its long captured source lifetime. Reborrowing a unique source field through
   that short outer loan cannot simply return the long lifetime named by the field. The current
   by-value carrier getter consumes its carrier and is a different, valid case. Origin-path matching
   alone is not a general typed-reference validity rule.
3. **Invariance.** `&mut Cell<&a T>` and `&mut Vec<&a T>` must not be shortened to accept a source
   valid only for their short outer borrow. Both the bad generic body and the short-lived caller
   storage control must reject. Local constructor lifetime witnesses cannot remain placeholder
   region zero when general typed references are added.
4. **Opaque mutable writeback.** Calls which may store captures through a typed mutable input must
   retain every source admitted by declared region/type relationships, not merely pre-call sources.
   Use conservative G0 type/lifetime bounds, not callee-body-specific G1 post-state inference.
5. **Authority is not an origin union.** take/pop may transfer a unique value out while the residual
   container has conservative overlapping may-sources. Preserve linear capability transfer and
   distinguish storage/frame loans from captured referent lifetimes; do not equate same lifetime
   labels with aliasing or assume arbitrary projections are Copy.
6. **Typed scalar storage.** The state34 scalar optimization concerns value facts. General references
   must extend address/borrow liveness before scalar storage can be forgotten. Keep the existing
   definedness/type and loan regressions when introducing that feature.

## Implementation boundary to deliver next

- Generic record/enum type expressions and bounded canonical substitution/codec, including nested
  concrete instances, Result/Option payloads, owned names and borrowed token fields.
- Type-only public modules rather than dummy functions to publish ordinary generic Result/Option.
- Deterministic specialized layouts/code keys and interface invalidation. Generic function codegen
  will need checked template/body artifacts (and private helper closure) in addition to public
  checking contracts; body edits must invalidate affected native instances even when ABI is stable.
- Then general typed-reference/invariance and real container/cursor programs, using the above controls
  as executable acceptance/rejection requirements rather than counting unsupported syntax as proof.

The C allocator/ASan/UBSan checks validate these positive ABI workloads, not a source-language safety
proof. The initial TinyCC failure was a missing `max_align_t` header definition; a private native
alignment union removed that dependency while retaining an alignment guard. It is not evidence of
an impossible erased ABI, and does not promise support for user-requested over-aligned values.
