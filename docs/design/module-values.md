# Module values: `static`

Status: **stage 1 (the baked tier) built** on `gaps12-statics-impl` - see "Stage 1 as built" at the
end; the lazy tier waits for `sync::Once` (`gaps12-sync`). Branch `gaps12-statics` (from `gaps10-view`). Nothing in the compiler
changes until the decisions below are taken. Line numbers are for this branch's
`compiler/native.grl` (N), `compiler/runtime.grl` (R) and the probe files in
`.work/statics-probes/` (not committed; their text is quoted where it matters).

## 0. Decisions for the owner

| # | Decision | Recommendation |
|---|---|---|
| S1 | Surface | **`[pub] static NAME: T = expr;` at module level only**: type always written, no generic statics, no function-local statics. |
| S2 | `static mut`? | **No, in any module.** Mutation goes through a `Share` type (`Mutex<T>`, `Atomic<T>`); the runtime keeps its process-state words (R:2466-2510) and needs nothing new. |
| S3 | What a static may hold | **`T` must be `shareable` and hold no borrow** (no reference types, no lifetime parameters). Reading `X` is a shared borrow of a place that never ends; moving out is refused. |
| S4 | Baked or lazy: who decides | **The initialiser's spelling, with no silent fallback**: a constant expression or `@f(...)` is baked at compile time; anything else runs once, lazily, on first use. A `@` initialiser that cannot bake is an error, not a quiet switch to lazy. |
| S5 | Cycles | **Refused at compile time** where the initialiser call graph is visible; a re-entrant first use at run time (through a closure or `dyn`) **aborts** with the static's name. |
| S6 | A failing lazy initialiser | **Aborts the process, never contained**: there is no unwinding to reset the once-guard, and a guard left "running" would hang every later reader. |
| S7 | Drop at exit | **Lazy statics are dropped at the end of `main`, in reverse order of initialisation, after the main thread's locals and before `rt_leak_exit`**, so the leak check stays exact. Skipped (with the leak check) while a detached thread runs. Reading a static after its drop aborts. |
| S8 | Thread-locals | **No `thread_local` keyword.** `static TALLY: thread::Local<Tally> = thread::local(make_tally);` is an ordinary lazy static (`Local` is `Share`); its value is reached only through `with(ctx, f)` and a non-`Send` `thread::Ctx`, as concurrency-model D5 decided. |
| S9 | `@no_alloc` / `@no_panic` | **Honest edges**: reading a lazy static is a call to its initialiser (allocates if that does) and to the cycle/poison abort, so `@no_alloc` and `@no_panic` bodies may read only baked statics. No "pre-warm" exemption. |
| S10 | Today's table/string constants copy on every read (probes 2, 8) | **Leave `const` a value; teach statics as the shared-table form.** Making a `string` constant's read a static view (no `rt_string_lit`) is a separate small change worth doing. |
| S11 | Diagnostic bug found by the probes | **Fix separately**: a record- or `Mutex`-returning `NAME := f();` reports its error at `lib/result.grl:129`, not at the binding (probes 4, 5). |

### Decided by the director, 2026-11-16

- **S1, S2, S3, S4, S5, S7, S8, S9:** as recommended.
- **S6, changed:** the lazy tier is built on `sync::Once` from concurrency stage 3 (branch
  `gaps12-sync`). An initialiser that fails sends the `Once` back to empty; the failing caller is
  contained like any task failure, and the next reader runs the initialiser again. A waiting reader
  parks through the same parking operation. Statics get `Once`'s semantics, not a process abort, and
  the runtime has one once-mechanism, not two. §3.3 and §3.5 below describe the superseded design
  and are rewritten when the lazy tier is built. **The lazy tier is not built until `gaps12-sync`
  lands.**
- **S10:** `const` semantics stay. "A string or table constant allocates or copies on every read"
  (probes 2, 3, 8) is a **named follow-up and a performance defect**, not only a design question:
  `const-read-copies` in §9.
- **S11:** yes, a separate small fix; it may go first.
- **Go:** stage 1 (the baked tier: constant expressions and `@f()` baked into the image, the
  interface record, the per-function cache surface, refusals, book section) and S11, on branch
  `gaps12-statics-impl`.

## 1. What exists today

### 1.1 `const` and the module binding

- **Parsing.** A top-level item after an optional `pub` goes to `declaration_item` (N:20131); `const`
  goes to `constant_declaration` (N:20144 → N:18233). A bare `NAME := ...;` at module level is
  `module_binding` (N:20102 → N:18185). `static` is not a keyword: `static COUNT: u64 = 1;` is
  `error: expected \`fn\`, found \`static\`` (probe 1).
- **Registration happens in pass 1** so `@if` and later declarations can fold against it
  (N:18237-18245); a duplicate is refused through `refuse_duplicate_constant` (N:6337).
- **Storage in the compiler.** One table, `c.constants: Constant[]` (N:611). A `Constant` is
  `{module, name, declared_at, public, ty, value, text}` (N:262-272): a 64-bit `value`, plus `text`
  for a string's bytes or a table's elements. A call whose value is not known yet has
  `ty == CT_PENDING` (N:48) and its call's source text in `text` (N:18200-18209).
- **Accepted values.** A literal, a constant-tier expression (`ct_expr`, N:17390; names other
  constants through `ct_primary`, N:17369-17386, ints, bools and floats), a negative or float literal
  with its type (N:18249-18290), or — run tier — a call. The run tier's result must be "an integer,
  a bool, a string, bytes or a vector of integers"; a record or a `Mutex` is refused (probes 4, 5,
  same message). `ct_pending_type` (N:17731) and `ct_seq_elem` (N:17757) define that set.
- **Emission: a constant is a value, re-made at each read.** `constant_value` (N:18353): an
  integer or bool is an immediate (N:18432); a string is its bytes in `.rodata` plus a call to
  `rt_string_lit` (N:18415-18431) — **a heap allocation per read**; a table is its elements in
  `.rodata` plus `rt_carray_load` into a fresh vector (N:18393-18414) — **a copy per read**.
  Probe 2 (`@no_alloc fn third() -> u64 { return TABLE[3]; }`) is refused with
  `it calls third -> rt_new -> rt_alloc`; probe 8 (`NAME.len()` on a `const NAME: string`) with
  `first -> rt_string_lit -> rt_lit -> rt_new -> rt_alloc`. Probe 3 shows two reads give two vectors.
- **Interface files.** A constant is an item with tag `IFACE_TAG_CONST` (12, N:39169), written by
  `iface_enc_const` (N:40373-40398: module, name, public, type, then kind 0 int / 1 text / 2 table
  with the value and bytes) in name order among the module's items (N:40467-40494), and read back
  into `c.constants` by `iface_rec_const` (N:41363-41414). **The value travels; nothing is linked.**
  An importer re-emits the bytes into its own object.
- **Per-function cache.** A unit's key carries the run's declaration surface (`fn_key`, N:14833),
  which includes every constant's module, name, text, public bit, value and type (`fn_surface_now`,
  N:14958-14970), because a constant's value is baked into the reader's text. A body that adds a
  constant to the run (a pending one resolved during it) moves `fn_marks` (N:14799) and is not filed
  (N:15884-15890).

### 1.2 Comptime (docs/design/comptime.md)

Two tiers. The constant tier folds inside the parser (`ct_expr`). The run tier (`run_tier`,
N:17817) writes a probe program, compiles it with this compiler in probe mode, links it static
(N:17997) and runs it with `GRAIL_COMPTIME=1`, under which the Linux runtime refuses files, clock,
network and processes (probe 7: `compile-time code cannot use files, the clock, the network or
processes`). Pending constants resolve on first use (`resolve_pending_named`, N:17689) or at the end
of the compile (`resolve_all_pending`, N:17719). A cycle is found by listing the constants being
computed in `GRAIL_COMPTIME_PENDING` (N:17704-17710); a probe that reads one stops
(`rt_comptime_cycle`, N:18363-18377) and the compiler reports it (N:18013; probe 6:
`compile-time call \`fa()\` reads a constant that is still being computed`). Results are cached in
`.work/comptime/<digest>/value`.

### 1.3 Start-up and exit: there is no module initialisation

The entry stub is written by the compiler's own `main` (N:43560) into a synthetic part `__start`
(N:44483). On Linux it stores argc/argv/envp into `rt_state` and calls `rt_thread_init`
(N:44504-44530), which installs the main thread record and the profiler (R:3064-3074); then it calls
the entry function directly (N:44542). After it: `rt_leak_exit` (N:44560; R:1147 — anything live is
an abort, unless a task failure was contained), `rt_shutdown` (R:1168, unmaps arenas), exit.
**No module code runs before `main`, and modules have no order at run time** — they exist only as
symbols in one image. This is the property to keep: every static must be either data in the image
or code run on first use, never a constructor.

Two runtime precedents the design reuses:

- **A lazily created process singleton with a CAS guard**: `rt_pool` (R:2544-2558) — load; if 0,
  CAS a creation word, the loser waits, the winner publishes with a release store.
- **Static blocks**: a block header whose state word is 2 is never freed (`rt_free`, R:1053-1055);
  the compiler already emits `view("literal")` as a string object plus descriptor entirely in
  read-only data behind such headers (`static_literal_view`, N:21532-21537). A baked table can be
  the same: a real vector object, in data, that nothing frees.

### 1.4 Sharing and trust

`transfer_capability` (N:9303) derives `transferable`/`shareable` structurally: plain data is both; a
`Mutex<T>` is shareable when `T` is transferable (N:9407-9410); a view or typed slice is shareable only
when read-only (N:9323-9335); an undeclared foreign handle, C pointer or `cfn` is neither. `unsafe
module` is reserved for `runtime` and `darwin` (N:18817-18852); ordinary code has item-level `unsafe
fn` / `unsafe struct` (N:20109-20116).

### 1.5 Effects and the prover

`@no_alloc` / `@no_panic` are proved over the call graph the emitter records (`call_out` and
friends; docs/design/effects.md:12-40); the roots are the allocator and the failure entries
(effects.md:55-58). An indirect call is an unknown edge that both allocates and fails. The prover
reads facts off source tokens; a term is a local's name, `v.len`, a stable field path or a literal
(`pv_term`, N:7439-7493), compared by text, and anything it cannot read it does not assume
(N:7347-7356).

### 1.6 The threads work

`thread::Local<T>` on `gaps12-threads` is `{ key: u64, make: fn() -> T }` (lib/thread.grl:284-290
there), a handle passed around because there is nowhere to declare it (docs/design/threads.md:86-96
there, "What that needs": a module binding with an initialiser, a sharing rule, a drop rule). The
concurrency model (docs/design/concurrency-model.md on `gaps12-concurrency-design`, D5 and §2.7)
fixes that a thread-local is read only with a `thread::Ctx`, which is neither `Send` nor `Share`.

### 1.7 Where the need shows up

`compiler/pkg.grl:223` rebuilds the 64 SHA-256 round constants on every `sha256_bytes` call
(pkg.grl:344); `compiler/cli.grl:3324` rebuilds the flag table (records, so it cannot be a constant
at all); every engine that wants one allocator handle, one log sink or one interned-name table passes
it through every signature.

## 2. The surface

```grail
static ROUND_K: u64[] = @sha_round_constants();   // baked: computed at compile time, in the image
static PAGE_MASK: u64 = PAGE - 1;                   // baked: constant tier
pub static LOG: Mutex<Log> = Mutex(Log::new());     // lazy: built on first use, dropped at exit
static TALLY: thread::Local<Tally> = thread::local(Tally::new);  // lazy; per-thread values via Ctx

fn word(i: u64) -> u64 { return ROUND_K[i]; }      // a borrow of the static: no copy, no allocation
fn note(s: &[u8]) { LOG.lock_with(|log| log.push(s)); }
```

- **Where**: module level, after optional `pub`; `pub` exports it exactly like a function.
- **Type**: always written (S1). A static is a *place*, and its type is its ABI across modules.
- **Reading**: `X` names the place. A `u64`/`bool`/float read copies the word; any other read is a
  shared borrow (`X[i]`, `X.len()`, `X.method()`, `&X`). `y := X;` for an owned non-copy `T` is
  refused: `a static cannot be moved out of; borrow it or call .copy()`. `X = ...` and `&mut X` are
  refused: `a static is immutable; put the mutable part in a Mutex or an Atomic`.
- **Not allowed**: generic statics (`static X<T>`), statics inside functions, `static mut` (S2),
  `extern static` (C globals stay behind `unsafe` FFI as today).
- **`const` vs `static`**: `const` is a value the compiler pastes into each use (and, for strings
  and tables, re-materialises at each use — §1.1); `static` is one object at one address. The book
  says: use `const` for numbers and flags you compare against, `static` for anything with an
  identity, a table, or a lock.

### 2.1 Which types (S3)

1. `shareable(T)` (the existing walk, N:9303) — a static is reachable from every thread at once.
   So `static S: u64[]` is fine, `static M: Mutex<u64[]>` is fine, `static F: File` is refused
   (`a static is reachable from every thread, and File is thread-affine`), `static C: thread::Ctx`
   is refused by the same rule.
2. **No borrows**: no `&`/`&mut`/slice/`view` type anywhere in `T`, and no lifetime parameters.
   Grail has no "lives forever" region (lifetimes.md: lifetimes are relations between inputs), and
   inventing one for a single feature is not worth it; a static that wants text owns it
   (`string`, `u8[]`). A baked string static is itself static data, so this costs nothing.
3. For the **baked** tier additionally: `T` is a data type the run tier can serialise (today: ints,
   bool, string, bytes, integer vectors; records and enums of those in stage 4).

What a static is *not*: an escape from `Share`. Interior mutability exists only where it already
does — `Mutex`, `RwLock`, `Atomic` — so a static adds no new unsound state; it only gives an
existing `Share` value a name everybody can reach.

### 2.2 Why no `static mut`, not even in an unsafe module

A `static mut` is an unsynchronised global — the thing `Share` exists to forbid — and the only
trusted modules (`runtime`, `darwin`) already have the process-state block with a documented word map
(R:2466-2510). Rust is retreating from `static mut` (2024 edition denies references to it). If a
case appears that `Atomic<T>` or `Mutex<T>` cannot serve, it should arrive with a concrete program;
`unsafe static` as an item hatch (like `unsafe fn`) is the shape it would take.

## 3. Initialisation (S4, S5, S6)

### 3.1 Two tiers, chosen by spelling

| initialiser | tier | at run time |
|---|---|---|
| constant expression (`ct_expr`: literals, constants, `size_of`, `target`, arithmetic) | baked | data |
| `@f(...)` (the run tier) | baked | data |
| anything else (`Mutex(...)`, `thread::local(...)`, a plain `f()`) | lazy | once, on first use |

A plain call is lazy even when it would bake: the author did not ask for compile-time evaluation,
and the compile-time tier refuses effects a run-time initialiser may need (reading the environment,
a config file). `@f()` that cannot bake is an error that says so (`@sha_round_constants() reads the
clock; drop the @ to compute it on first use`). The tier is therefore stable under edits to the
initialiser's body, which matters for the cache and for `@no_alloc` in other modules (§5, §6).

### 3.2 Baked

The value comes from the constant tier or `run_tier` (N:17817), exactly as a constant's does, and is
emitted **once, in the declaring module's part**, as static blocks: a scalar is a word in
`.rodata`; a string or vector is a real object (header with state 2, R:1053) plus its elements, the
layout `static_literal_view` already emits. Reads are a `leaq NAME(%rip)`; nothing is copied,
nothing is freed, nothing runs. The comptime cycle machinery (`GRAIL_COMPTIME_PENDING`) covers baked
statics unchanged, since they are evaluated the same way.

### 3.3 Lazy

Storage: `size_of(T)` bytes in `.bss` plus one guard word, and an initialiser function `NAME.init`,
all in the declaring module's object. The guard is 0 (not started), 1 (running), 2 (ready),
3 (dropped). An access compiles to

```
    mov   GUARD(%rip), %rax        ; acquire load (plain mov on x86-64; ldar / fence on AArch64, RV64)
    cmp   $2, %rax
    jne   .Lslow                   ; cold: call rt_static_get(&GUARD, NAME.init, &STORAGE, &SITE)
    lea   STORAGE(%rip), %rax
```

**Cost**: one load, one compare, one predicted-not-taken branch per access; the optimiser may hoist
it within a body once the static is known ready (it never goes back except at exit, after `main`).
`rt_static_get` follows `rt_pool`'s pattern (R:2544-2558): CAS 0→1; the winner records its thread in
the guard's second word, runs `init`, writes the value, pushes `{storage, dropper}` onto the drop
list (§4), and publishes 2 with a release store, waking waiters. A loser waits on the guard word —
**parking its task when it is a green task** (through the blocking-call path, as `Thread` joins do),
so an initialiser that itself waits cannot deadlock its worker.

Dependency: the acquire load is not lowered on AArch64 and RISC-V today
(concurrency-model.md §2.6, runtime.grl:2849 there); stage 2 needs it, or the fast path must use the
full atomic load on those targets.

### 3.4 Cycles

- **Compile time (the common case).** Each lazy initialiser's body is emitted like a function, and
  the emitter already records its direct call edges for the effect analysis (effects.md:12-40). The
  same graph, plus an edge "body reads static Y", gives a static-dependency graph; a cycle among
  statics through direct calls is refused naming the path:
  `static A depends on itself: A.init -> fa -> B -> B.init -> fb -> A`.
- **Run time (the backstop).** Through a closure or a `dyn` call the graph has an unknown edge; then
  `rt_static_get` finding the guard at 1 *and owned by the calling thread* aborts:
  `error: static A read during its own initialisation`. Another thread finding it at 1 waits.

### 3.5 Failure (S6)

A check failing inside `init` would, on a task or a spawned thread, be *contained* (the stack
discarded, task-failure-containment.md). The guard would stay at 1 forever and every later reader
would hang. So the thread record carries an "initialising a static" depth, and `rt_containable`
answers no while it is non-zero: the failure aborts the process with the static's name in the
report. Rust's `LazyLock` poisons instead; poisoning needs unwinding, which Grail does not have.

### 3.6 No life before `main`

Nothing is added to the entry stub's start (N:44504-44542). A lazy static's initialiser runs on the
thread that first reads it, after `rt_thread_init`, with the full runtime available; a baked one never
runs. Module order does not exist at run time and does not need to.

## 4. Drop at exit (S7)

The entry stub's exit sequence (N:44558-44562: `rt_leak_exit`, `rt_shutdown`, exit) becomes:

1. the entry function returns;
2. the main thread's `thread::Local` table is dropped (as on `gaps12-threads`);
3. **`rt_statics_drop`**: the drop list, newest first. Each entry's guard goes to 3 before its
   dropper runs, so a `Drop` impl that reads a static already dropped aborts
   (`static LOG read after it was dropped at exit`) instead of reading freed memory. Reverse
   initialisation order means a static is dropped before anything it read during its own
   initialisation, which is the order dependencies need;
4. `rt_leak_exit` (R:1147), unchanged — and still exact, because everything a static owned has been
   freed;
5. `rt_shutdown`, exit.

When a detached thread is still running, step 3 is skipped together with the leak check (the
`gaps12-threads` rule): the thread may be using a static. `host::exit`, an abort and a contained
failure that ends the process do not run step 3, as they do not run any other drop.

The drop list is two new process-state words (claim in the R:2466-2510 table: 3424 list head, 3432
its lock; both free today). Baked statics are not on it: they own nothing.

## 5. Thread-locals (S8)

```grail
static TALLY: thread::Local<Tally> = thread::local(Tally::new);

fn count(ctx: &thread::Ctx) { TALLY.with(ctx, |t| t.hits += 1); }
```

`Local<T>` is `{ key, make }`, plain data, so it is `Share` and an ordinary lazy static: the first
reader allocates the key. The per-thread values stay where `gaps12-threads` put them (a table off the
thread record, dropped by the thread at its end, the main thread's before the statics). The only way
to reach a value is `with(ctx, f)`, and a `Ctx` cannot be captured by a task or job closure because it
is neither `Send` nor `Share` — concurrency-model D5 needs nothing more from the language. A keyword
(`thread_local static`) would add a second storage class to every rule here for no rule it enables.
Stage 3 rewrites `lib/thread.grl`'s comment and its tests to declare their `Local`s as statics.

## 6. Separate compilation and the per-function cache

- **Storage lives in the declaring module's object**: the data (baked) or storage + guard + `.init`
  (lazy), under symbols derived from `module::NAME` like a function's. Nothing is weak, nothing is
  re-emitted by importers — the opposite of today's constants, whose bytes every reader re-emits
  (§1.1), and the reason a static has one address.
- **Interface record**: a new tag `IFACE_TAG_STATIC`: module, name, public, type, tier, symbol, and
  for a lazy static the effect summary of its initialiser (allocates / may fail) so an importer's
  `@no_alloc` / `@no_panic` check can follow the edge without the body. **The value is not in the
  interface** — readers do not need it — except that a baked scalar may also carry its value, for
  the prover (§7). `iface_rec_*` grows a reader beside `iface_rec_const` (N:41363).
- **What the cache records.** The declaration surface (`fn_surface_now`, N:14945-14970) adds every
  static's module, name, public bit, type, tier and symbol: those decide a reader's emitted text
  (a `leaq` vs a guarded access). The initialiser's body and a baked value do not, since readers
  reach both by symbol — so editing `Log::new` or the table's contents rebuilds the declaring module
  and nothing else. Reading a static registers nothing in the run, so `fn_marks` (N:14791-14803) is
  unchanged and such a body is still filed. The body's effect facts carry the edge to `NAME.init`,
  which the whole-program fixpoint resolves as for any call.
- The probe (`run_tier`) compiles the module's statics like any other code; a lazy static read
  inside compile-time code is initialised inside the probe like at run time.
- **LLVM backend**: the guarded access is ordinary loads, a compare and a call, all in the
  instruction set `llvm.grl` already lowers; data symbols are emitted as the native stream emits them.

## 7. The prover and the effects (S9)

- **Effects.** A baked read adds no edge. A lazy read adds an edge to `NAME.init` (recorded by
  `call_out` like any call, so `fx_end`'s count stays exact) and to the failure entry (cycle, read
  after drop). Result: `@no_alloc fn f() { LOG.lock_with(...) }` is refused with
  `f -> LOG.init -> Log::new -> rt_alloc`; `@no_panic` refuses every lazy read. That is the truth: the
  first read on some path does allocate. A frame loop that wants `@no_alloc` passes the handle in or
  uses a baked static. No exemption for "already warmed", which the compiler cannot prove.
- **Prover.** A static's name is a term like a local's (`pv_term` already returns any identifier,
  N:7493). It is sound because a static is immutable as a binding: `ROUND_K.len()` cannot change, so
  no kill rule is needed, and a shadowing local hides it like any name. A baked integer static may
  also contribute its value as a fact (`PAGE_MASK == 4095`), the way a literal does; values behind a
  `Mutex` are never terms (they are only reached inside `lock_with`).

## 8. Alternatives considered

- **Rust: `static` (const-evaluated only) + `OnceLock`/`LazyLock` in the library; `static mut`
  unsafe.** The split is right — compile-time data vs a once-guarded lazy value — and this design
  keeps it. It differs in putting the lazy form in the language: Grail has no `'static` region and no
  way for library code to declare the place a `LazyLock` would live in, so the library route needs
  the language feature anyway. `static mut` is the part Rust regrets.
- **Zig: container-level `var`/`const`, initialised at compile time, mutable globals unchecked.**
  Compile-time-only initialisation is attractive (no guard ever), but it excludes exactly the
  motivating cases: a `Mutex` is a runtime allocation (R:2287-2292), a thread-local key is a runtime
  counter. Unsynchronised mutable globals contradict `Share`.
- **C++: dynamic initialisation before `main`, and function-local "magic statics".** Before-`main`
  constructors bring the static-initialisation-order problem across translation units — with
  separate compilation and no run-time module order (§1.3) Grail would have to invent one. Function
  -local statics are the guarded-lazy model this design uses, but at module level, where they can be
  shared and named in an interface.
- **Go `init()` / D module constructors** (dependency-ordered start-up code): life before `main`, an
  order to compute across objects, and failures before the program's own error handling exists.
- **Make every `const` a static** (one object per table/string): changes what `a := TABLE` means
  today (an owned vector, probe 3). Kept separate (S10).
- **Always lazy, no baked tier**: simpler, but puts a guard and an `@no_alloc` edge on tables that
  are pure data — the SHA constants, the flag table.

## 9. Staged plan

| stage | builds | accept cases | refuse cases |
|---|---|---|---|
| 1. baked statics | `static` keyword, pass-1 registration beside constants, the type rules (§2.1), baked tier via `ct_expr`/`run_tier`, static-block emission in the declaring part, borrow reads, `IFACE_TAG_STATIC`, surface entry; migrate `pkg.grl` SHA constants | `static-baked-int`, `static-baked-table-no-copy` (`@no_alloc` read, the probe 2 shape), `static-baked-string-no-alloc`, `static-pub-across-modules` (interface-only importer), `static-in-prover-term` | `static-needs-type`, `static-mut-refused`, `static-assign-refused`, `static-move-out-refused`, `static-holds-borrow-refused`, `static-not-shareable-refused` (a `File`), `static-generic-refused`, `static-in-fn-refused`, `static-at-cannot-bake` (`@` + clock), `static-name-clashes-const` |
| 2. lazy statics | guard + `.init` + `rt_static_get`, green-task parking, static-dependency graph, run-time re-entry abort, non-containable init failure, drop list + exit order, effect edges, acquire load on AArch64/RV64 | `static-lazy-mutex-counter` (many tasks and threads increment, one total), `static-lazy-once-under-race` (init runs once, 64 threads), `static-lazy-drop-at-exit` (Drop prints, leak check clean), `static-lazy-drop-reverse-order`, `static-lazy-reads-env` | `static-cycle-refused` (direct calls, names the path), `static-cycle-runtime-abort` (through a closure), `static-init-failure-aborts` (from a task: not contained), `static-read-after-drop-aborts`, `static-lazy-in-no-alloc-refused`, `static-lazy-in-no-panic-refused` |
| 3. thread-locals | after `gaps12-threads` lands: `Local` statics in `lib/thread.grl` docs/tests, threads.md "what that needs" closed | `thread-local-static-per-thread`, `thread-local-static-dropped-per-thread` | `thread-local-static-ctx-in-task-refused` (existing `Ctx` rule, now with a static) |
| 4. baked records | run-tier serialisation of records/enums of data; migrate `cli.grl` flag table | `static-baked-record-table` | `static-baked-handle-refused` |
| 5. prover values | baked scalar values as facts | `static-baked-value-proves-bound` | - |
| follow-up `const-read-copies` | a `string` constant read is a static view and a table constant read is a borrow of one static object where the use only borrows (S10: the meaning of `a := TABLE` is unchanged) | probes 2 and 8 accepted under `@no_alloc` | - |

Book: a new section **"Module values: `const` and `static`"** in `book/chapters/modules.md` (when to
use which, the two tiers, the type rule, exit order), a paragraph and cross-link in
`book/chapters/compile-time.md` (`@` on a static's initialiser), and the thread-local example in
`book/chapters/concurrency.md` rewritten to a static once stage 3 lands. CHANGELOG with each stage.

## 10. Probes

Run with this branch's compiler (`grail run FILE --no-cache`):

| # | program | result |
|---|---|---|
| 1 | `static COUNT: u64 = 1;` | `error: expected \`fn\`, found \`static\`` |
| 2 | `TABLE := squares();` read in a `@no_alloc` fn | refused: `third -> rt_new -> rt_alloc` (read copies) |
| 3 | `a := TABLE; b := TABLE;` | `9 49` — two separate vectors |
| 4 | `ORIGIN := origin();` returning a record | refused (data only); error located at `lib/result.grl:129` |
| 5 | `LOCK := make();` returning `Mutex<u64>` | same refusal and the same misplaced location |
| 6 | `A := fa(); B := fb();` mutually dependent | refused as a cycle |
| 7 | `SEED := clock();` | refused: compile-time code cannot read the clock |
| 8 | `const NAME: string` read in `@no_alloc` | refused: `rt_string_lit -> rt_lit -> rt_new -> rt_alloc` |
| 9 | `const N: u64` read in `@no_alloc` | accepted, `8192` |

## Stage 1 as built (2026-11-16)

- **Parse.** `declaration_item` sends `static IDENT` to `static_declaration` (compiler/native.grl).
  Pass 1 registers `module::NAME` in `c.statics` (`Static`: module, name, declared position, public,
  type, imported) and refuses `static mut`, a generic list, a missing type and a name a constant or
  another static already has. Pass 2 parses the declared type, so a read in any module's body (pass
  3) knows it. Pass 3 checks the type rules (no borrow; shareable through `transfer_capability`;
  a baked type: integer, `bool`, `string`, vector of integers or bytes), computes the value - the
  constant tier (`ct_expr`, with a negative literal for a signed type) or `@f(...)` through
  `run_tier` - and emits it. A plain call is refused as the lazy tier; a float static is refused
  (use `const`).
- **Storage.** In the declaring module's part (`part(unit_module(module))`), in `.rodata`
  (`__DATA,__const` on Mach-O): a scalar is the word at global symbol `s_<module>_<name>`; a string
  or vector is an object `{data, len, cap}` and its data, each behind a 16-byte block header in state
  2 (never freed), and the symbol's word points at the object. A table from the run tier arrives in C
  layout and is re-laid as the runtime lays vectors out (a byte per `u8`, four bytes per 32-bit
  element, a word otherwise, sign-extended).
- **Reads.** `static_value`: `leaq SYM(%rip)`; a scalar is then loaded; anything else is a value of
  type `&T` whose target is an external place (`add_external_capture`, the same model as a borrowed
  parameter's referent). So `r := X` binds a borrow (not a refusal, as §2 first proposed), `X.push`
  is "mutation through readonly frame", an owned parameter is a type mismatch (`found &u64[]`), and
  `X = v` says a static is immutable.
- **Interfaces.** Tag `IFACE_TAG_STATIC` (19): module, name, public, type, tier (1 = baked; a reader
  refuses another). No value travels. `grail iface dump` prints `static m::n public=P <type> tier 1`.
- **Cache.** `fn_surface_now` adds each static's module, name, public bit and type; not its value or
  initialiser.
- **Probes.** In a compile-time probe computing static `X`, `X`'s storage is a placeholder and a read
  of it calls `rt_comptime_cycle`, so `static T: u64 = @f();` with `f` reading `T` is refused as a
  cycle, the way a module constant's is.

Found while building, not changed here:

- **`@no_alloc` refused every bounds-checked index** (the failure report allocated). Fixed in its own
  commit: the dying report is written in a process-state block and allocates nothing.
- **The run tier read signed results wrong** (a negative vector element stopped the probe; a negative
  scalar did not parse; integer results were typed `u64`). Fixed in its own commit.
- **The run tier scales badly with many values.** Each probe compiles the whole program, and every
  run-tier value a body of that program reads is resolved inside it by a probe of its own, so a cold
  build with N run-tier values runs nested probes N deep: 4 values took 6.5 s, 8 took 16 s, and a
  program with 20 did not finish in 20 minutes. Constants and statics share it; the corpus covers
  each signed width in its own case for that reason. The cure is a probe that compiles only what the
  probed call reaches.
- **No `'static`** - the named follow-up `static-region` below.
- **`--jobs` and probes.** A corpus run with `--jobs 8` saw a probe's compiler path go "(deleted)" mid-
  run; the same cases pass serially. A harness race, not a compiler fault.
- Not done in stage 1: the prover term for a static (stage 5); records in the baked tier (stage 4).

## Stage 4 as built: baked records

- **Types.** `static_baked_type_at`: an integer, bool, string, bytes, a vector of baked types, or a
  plain record (not C-laid-out, not an enum, not opaque, not generic) whose fields are baked types,
  to depth 16. Enums and generic records are refused with their own message (not built yet).
- **Run tier.** `static_structured` types (a record, or a vector whose elements are not integers)
  get a probe that prints the value in a flat form (`static_dump_src`): a number per line (signed
  types through `i64`, a bool as 0/1), a string as its length then `println("{}", s)`, a vector as
  its length then its elements, a record as its fields in declaration order. The text comes back
  whole in `CTRes.text`.
- **Emission.** `static_bake` reads that form and emits nested objects first: a string or vector of
  integers as `{data, len, cap}` plus data (the stage 1 layout), a vector of objects as a word table,
  and a record as one word per field (`rt_rec`'s layout: field k at 8k), each behind a state-2
  header. The static's word points at the outermost object.
- **Refusals.** A record with a thread-affine handle fails the shareable rule; a module binding or
  an `@f()` expression whose result is structured is refused (a constant is pasted into each use, so
  it cannot be one object) with a message naming `static`.
- **The compiler's own tables are not migrated.** `cli.grl`'s `flag_table` and `pkg.grl`'s SHA
  constants would be statics, but the bootstrap seed compiles the compiler's sources and does not
  know `static`; they move after the next reseed.

## Follow-up `static-region`: a borrow that outlives every frame (design question, not built)

Decided by the director (2026-11-16): written up here, not built; it is tied to the regions the
closure-bounds work (`docs/design/closure-bounds.md`, branch `gaps12-closures`) gives the checker.

**The probe.**

```grail
static SQ: u64[] = @t();
fn t() -> u64[] { return u64[1, 2]; }
fn table() -> &u64[] { return SQ; }      // error: elided output reference needs one input lifetime
pub fn main() { println("{}", table().len()); }
```

A read of `SQ` is a `&u64[]` whose target is an external place (`static_value`, the borrowed-
parameter model), but there is no lifetime a signature can write for it: Grail's lifetimes are
relations between inputs (book/chapters/lifetimes.md), and a function with no reference input has
nothing for its output to be related to. So a static can be read anywhere, but a borrow of it cannot
be returned, stored in a `struct Cursor<a>` that outlives the call, or captured by an escaping
closure.

**What `'static` would need from the region checker.**

1. **A spelling.** One reserved region name, e.g. `&static T` (the lifetime position already takes a
   bare name, `&a T`), meaning "outlives every region". It is never bound by a signature.
2. **A place kind.** Reads of a static (and `view("literal")`, `cstr("literal")`, whose storage is
   also static data) produce a reference whose origin is one distinguished external place - the
   image - instead of an anonymous one. Nothing ends a loan on it, so no conflict check fires
   against it, and it is never a frame's.
3. **Subsumption.** `&static T` is accepted wherever `&a T` is expected, for any `a` (it is a valid
   instantiation of every region parameter); the reverse is refused. The return check accepts a
   `&static T` output with no input lifetime, so `fn table() -> &static u64[]` is a signature.
4. **Records and closures.** A record `Cursor<a>` instantiated at `static` may outlive any frame; a
   closure whose captures are only `&static` borrows has no frame origin, so the closure-bounds
   rules (`Owned`, `Send`) treat it as a closure with no borrows. This is the part that depends on
   the closure-bounds regions: until a closure type carries its captures' regions there is nothing
   to put `static` into.
5. **Interfaces.** The region travels in the interface's type records like any region; a function
   returning `&static T` is callable across modules with no caller-side obligation.

What it does not need: a run-time representation (a `&static` is the same pointer word), or any
change to statics themselves - their reads would be typed `&static T` instead of carrying an
anonymous external origin.

## Stage 5 as built: statics in the prover

- **Terms.** A static's name was already a term (`pv_term` returns any identifier), and sound as one:
  a static never changes, and a local that shadows it is found first.
- **Known values.** `pv_known_literal`: in `pv_term`, a name that is an integer static or an integer
  constant of this module with a value the prover's integer reading holds (not negative, below
  2^62) reads as that literal; `NAME.len()` on a string or vector static reads as its length. A
  callee's obligation renamed to the caller's terms (`v.len` with `v := SQ`) goes through the same
  mapping (`pv_rename_known`), so both sides meet on the literal.
- **Evaluated when asked.** `static_resolve` evaluates a static's initialiser once, at its own
  position, whoever asks first - the prover in a body, the interface writer, the function cache's
  surface, or the declaration in the third pass - and keeps the value on the entry (`static_fact`).
- **Interfaces and the cache.** The static record carries the fact (`fact_kind` 1 value, 2 length)
  and the function-cache surface includes it, because a reader's emitted call (`.proved` or not) now
  depends on it.
- **Not covered.** A qualified name (`table::LIMIT`) is not read as its value - the prover takes only
  this module's names - and a direct `SQ[i]` in `for i in SQ.len()` keeps its bounds check: the
  bounds-check pass (`pv_bce`) still serves refined parameters only.
