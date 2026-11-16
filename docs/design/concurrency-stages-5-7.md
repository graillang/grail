# Concurrency stages 5, 6 and 7: proposals

Status: proposals for the director, written on `gaps12-sched` after stage 1, the help bound and F1.
Nothing here is implemented. Claims about today's code are tagged **[V file:line]** (read at the
commit that adds this file) or **[A]** (assumed). Each stage ends with the decisions it needs.

## Stage 7: the atomics family

### What exists

- **The type.** `Atomic<T>` is type kind 11, and the checker refuses every `T` but `u64`:
  "Atomic currently requires u64 (one aligned 64-bit word)" [V native.grl:13034-13040].
  `Atomic::new` allocates one 8-byte heap word (`rt_atomic_new`, an `rt_alloc(8)`
  [V runtime.grl `rt_atomic_new`]), so an atomic is never inline in a record. It is `Send` and
  `Share` [V docs/design/parallelism.md, table].
- **The methods.** `load`, `load_relaxed`, `load_acquire`, `store`, `store_relaxed`,
  `store_release`, `fetch_add`, `fetch_sub`, `swap` and `compare_exchange` are accepted. Each is a
  call to a runtime function [V native.grl `atomic_method`, about :30480-30540]. `fetch_add`,
  `fetch_sub` and `swap` are compare-and-swap loops in the runtime [V runtime.grl
  `rt_atomic_fetch_add`/`_sub`/`_swap`], so every RMW is a call plus a loop.
- **The intrinsics underneath** (runtime-only, ids 110-116) [V native.grl:24715-24735, :25190-25210].
  x86-64 is the instruction stream itself; AArch64 and RV64 are produced from it by
  `compiler/machine.grl` [V machine.grl:682-760]:

  | intrinsic | x86-64 | AArch64 (machine.grl) | RV64 (machine.grl) | LLVM (llvm.grl) |
  |---|---|---|---|---|
  | load (SC) | `mov; mfence` | `ldr; dmb ish` | `ld; fence rw,rw` | `fence seq_cst` after a plain load |
  | load_acquire | `mov; lfence` | `ldr; dmb ishld` | `ld; fence r,rw` [A] | `fence seq_cst` |
  | load_relaxed | `mov` | `ldr` | `ld` | plain load |
  | store (SC) | `xchg` | `ldaxr/stlxr` loop + `dmb ish` both sides | `fence; amoswap.d.aqrl; fence` | `atomicrmw xchg seq_cst` |
  | store_release | `sfence; mov` | `dmb ish; str` [A] | `fence rw,w; sd` | `fence seq_cst` + store |
  | cas | `lock cmpxchg` | `ldaxr/stlxr` loop + `dmb ish` both sides | `lr.d.aq/sc.d.rl` loop + fences | `cmpxchg seq_cst seq_cst` |

  Two consequences. First, the comment in `rt_pool_wait` that the acquire load "is not lowered on
  AArch64/RV64" is stale: it is lowered, as a load and a barrier. Second, every ordering reaches
  LLVM as a `seq_cst` fence. That is correct, but it is the strongest possible lowering, and on x86
  the SC load pays an `mfence` it does not need (an x86 SC load is a plain `mov` when SC stores
  are `xchg`).

### Proposal

**Types.** `Atomic<T>` for `T` in `u8 u16 u32 u64 i8 i16 i32 i64 bool`. Plain C-like enums
come later, behind unboxed records. No atomic references or pointers in safe code.
- Until unboxed records land, an `Atomic<T>` stays a heap cell of 8 bytes and all widths use
  64-bit operations on it, with the value kept in the low bits, sign- or zero-extended. That is
  exact for every operation: arithmetic wraps at `T`'s width because the result is truncated
  before it is stored, which for RMWs means a CAS loop for the narrow widths. Store narrow
  `fetch_add` results the same way.
- When unboxed records give `Atomic<T>` an inline layout (the unboxed-records note), narrow widths
  become real 1/2/4-byte cells. The methods do not change, only the lowering: x86 has every
  width; AArch64 has `ldaxrb/h`, `ldarb/h` and so on; RV64 has 32/64-bit AMOs and LR/SC, so 8 and
  16 bits are a masked LR/SC loop on the containing aligned word.
**Methods** (orderings as suffixes, decided in D4; the unsuffixed name is sequentially consistent):
- `load`, `load_relaxed`, `load_acquire`
- `store`, `store_relaxed`, `store_release`
- `swap`, `fetch_add`, `fetch_sub`, `fetch_and`, `fetch_or`, `fetch_xor`, `fetch_min`,
  `fetch_max`, each also with `_relaxed`, `_acquire`, `_release` and `_acqrel`. `fetch_add/sub`
  wrap (modular), as `concurrency-v1.md` already promises; `bool` has only `swap`, `fetch_and`,
  `fetch_or` and `fetch_xor`.
- `compare_exchange(expected, new) -> T` (strong; returns the value seen, as now) and
  `compare_exchange_weak` (may fail spuriously; for loops), each also with `_relaxed`, `_acquire`,
  `_release` and `_acqrel`. The failure ordering is not spelled: it is `acquire` for `_acquire`
  and `_acqrel`, `relaxed` for `_relaxed` and `_release`, SC for the unsuffixed form. That is the
  C++ rule for a derived failure order, and it removes the invalid pairs.
- Free functions in `lib/sync.grl` (or builtins): `sync::fence()`, `fence_acquire()`,
  `fence_release()`, and `sync::spin_hint()` (`pause` / `yield` / `pause` hint on RV64 with
  Zihintpause, else `nop`).
- An invalid combination has no name, so it is a "no method" error naming the valid ones.

**Lowering: new instruction-stream ops, not fences.** Today an ordering exists only as an x86
fence that the later stages translate, and LLVM can only see `fence seq_cst`. The proposal is four
pseudo-ops in the word-machine stream that `native.grl` emits and `machine.grl` / `llvm.grl` lower
per target, each carrying `{op, ordering, width}`:
`atom.load O W`, `atom.store O W`, `atom.rmw OP O W` and `atom.cas O W` (strong, or `weak`).

| ordering | x86-64 | AArch64 (v8.0 baseline) | RV64 | LLVM |
|---|---|---|---|---|
| load relaxed | `mov` | `ldr` | `ld` | `load atomic ... monotonic` |
| load acquire | `mov` | `ldar` | `ld; fence r,rw` | `load atomic ... acquire` |
| load SC | `mov` | `ldar` | `fence rw,rw; ld; fence r,rw` | `load atomic ... seq_cst` |
| store relaxed | `mov` | `str` | `sd` | `store atomic ... monotonic` |
| store release | `mov` | `stlr` | `fence rw,w; sd` | `store atomic ... release` |
| store SC | `xchg` | `stlr` | `fence rw,w; sd` | `store atomic ... seq_cst` |
| RMW (any order) | `lock xadd` / `xchg` / `lock and/or/xor` (result unused) / `lock cmpxchg` loop (and/or/xor with result, min/max) | `ldxr/stxr` loop with `a`/`l` per order (`ldaxr`/`stlxr` for acqrel and SC) | `amoadd.d` / `amoswap.d` / `amoand.d` / `amoor.d` / `amoxor.d` / `amomin(u).d` / `amomax(u).d` with `.aq`/`.rl`/`.aqrl` | `atomicrmw OP ... ORDER` |
| CAS | `lock cmpxchg` | `ldxr/stxr` loop, acquire/release variants | `lr.d`/`sc.d` loop with `.aq`/`.rl` | `cmpxchg [weak] ... SUCC FAIL` |

These follow the standard C/C++11 mappings (x86 TSO, ARMv8 with `ldar`/`stlr` for SC, RISC-V
table A.6 of the unprivileged spec) [A: from the published mapping tables, to be pinned by tests].
AArch64 LSE (`ldaddal`, `swpal`, `casal`) is a later option, gated on the target feature; v8.0
LL/SC is correct everywhere. Windows on ARM64 and macOS AArch64 use the same AArch64 rows;
PE x86-64 uses the x86 rows.

**Inline, not a call.** The new ops are emitted at the method call, so `fetch_add` is one
`lock xadd` instead of a runtime call plus a CAS loop. The runtime's own `raw_atomic_*`
intrinsics stay as they are for runtime code, but their lowering moves onto the new ops too, so
the runtime gets cheaper acquire/release without a change in its source. That also fixes the
x86 SC-load `mfence`, which every `rt_task_wait` and `rt_job_await` pays today.

**Effects and checking.** No method allocates or fails (`@no_alloc`, `@no_panic` hold for every
one of them). `Atomic<T>` is `Send` and `Share` for every `T` above. As now, no `&mut` to the
inside can be formed; the cell is reached only through methods.

**How `Atomic<u64>` migrates.** Source is unchanged: every method name in use today keeps its
meaning. The type changes from kind 11 with no argument to kind 11 with the width as its argument.
Interface files carry `Atomic<u64>` already spelled with its argument [A: check the writer]; if
not, the interface format version goes up by one in the same change, as closure bounds just did
(format 6). `rt_atomic_load/store/...` and the CAS loops in `runtime.grl` are deleted once nothing
calls them (dead-code rule). The heap cell stays until unboxed records; then `Atomic::new` stops
allocating, which is the change that removes the last allocation from `concurrent_map`'s shard
counters and from every `Atomic` in a record.

### Files, tests, benchmark

- Files: `compiler/native.grl` (type check for the widths, the methods, the ops), `machine.grl`
  (AArch64 and RV64 lowering of the four ops), `llvm.grl` (atomic instructions with orderings),
  `runtime.grl` (intrinsics move onto the ops; dead helpers deleted), `book/chapters/concurrency.md`,
  `docs/design/concurrency-v1.md` (ordering section), `CHANGELOG.md`.
- Corpus cases:
  - `atomic-widths-wrap`: each width wraps at its own size, signed min/max.
  - `atomic-methods-every-order`: every method name runs, on all three targets.
  - `atomic-invalid-order-has-no-name`: `load_release` is refused, naming the valid loads.
  - `atomic-no-alloc-no-panic`: an `@no_alloc @no_panic` function using every method.
  - asm pins: x86 SC load has no `mfence`; `fetch_add` is `lock xadd` and makes no call;
    AArch64 acquire load is `ldar`; RV64 relaxed `fetch_add` is `amoadd.d` with no fence.
  - Litmus, as checks that cannot fail if the lowering is right: message passing with release
    and acquire, and store buffering with SC. qemu-user's TCG is not a weak machine, so these
    prove the code shape, not the hardware ordering, on aarch64 and riscv64. They run for real on
    an AArch64 host when one is available.
- Benchmark: `bench/atomics.grl`, with uncontended and 24-thread contended `fetch_add` rates, and
  an SPSC ring of release stores and acquire loads, before and after. Expected: `fetch_add` goes
  from a call plus a CAS loop to one instruction.

### Decisions for stage 7

1. Narrow widths now, on the 8-byte cell, or only when unboxed records give inline layout?
   **Recommend now**: the API is what users write, and the layout change is invisible to them.
2. AArch64 baseline v8.0 LL/SC, LSE later behind a target feature? **Recommend yes.**
3. Is `fetch_min/max` signedness taken from `T`? **Recommend yes** (no separate `umin` name).
