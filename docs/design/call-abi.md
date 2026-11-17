# The cost of a call in Grail: the convention as it was, the approved one, and where it stands

Status: report approved by the director 2026-11-16; plan S1-S7 approved in the order S1, S2, S3,
S4/S5, S6 (after unboxed stage 3a), S7. Done: S1, S2, S3, S4, S5, S7 (see "Progress" at the end).

Tree: gaps12-callabi = origin/gaps13-int-b at 5dc07da. Measurements: perf_event user-mode instruction
and cycle counters (own wrapper, `.work/probe/icount`; no `perf` binary on this host), load 20-30.
N: = compiler/native.grl, M: = machine.grl, L: = llvm.grl, O: = optimize.grl, R: = runtime.grl.

## 1. The convention as it is

The pipeline: the front end emits an x86-64-spelled word-machine text (every value a 64-bit word);
on the **native** backend optimize.grl rewrites it and machine.grl lowers it to x86-64, AArch64 or
RV64; on the **LLVM** backend llvm.grl lifts the *unoptimised* front-end text function by function into
IR, and a function it cannot lift is kept as that raw text.

**Hidden registers: none on the native backend.** There is no closure-environment register on a
direct call, no failure context (checks call `rt_trap`/`rt_fail`/`rt_refine`, which never return;
a failing task abandons its stack via `rt_contain_tail`), no runtime-state register (the thread
record is TLS: `%fs:rt_tls_record@tpoff` on x86-64, tp on RV64, N:2915-2970, M:1323-1331) and no
stack-limit register or prologue check (a guard page and a fault handler, R:63-69). The "three hidden
registers" seen in the LLVM build are not a convention: they are an artefact of the lifter (below).
The one hidden-register-like rule is the check failure protocol: before a checked op the front end
loads the operand into %rcx and, on the failing path, the kind into %rdx (`movabs $1,%rcx` on the
hot path of every checked `n - 1`).

**Arguments.** Every argument is one word, floats included (an f64 as its bits, an f32 as the
binary64 of the same value, M:826-829), in rdi, rsi, rdx, rcx, r8, r9 (`argreg`, N:3935-3952), which
machine.grl maps to x0-x5 / a0-a5 (M:104-147). **More than six**: the first five go in registers and
the rest in a heap record from `rt_rec` whose address is the sixth register; the callee copies the
record into its frame and calls `rt_free` (`load_call_args` N:3958-3988, `store_params` N:3990-4015).
Runtime helpers are limited to six (`invoke`, N:4016-4021). Records travel as one word, the address
of a box (stage 1a: the record's own address).

**Results.** Word 0 in rax, word 1 in rdx for two-word values (`&dyn` pairs, N:3176, N:39997). On
AArch64/RV64 rax is x9/t0, not x0/a0 (M:104-109), so every `ret` is `mov x0,x9; ret` and every call
is `bl f; mov x9,x0` (M:1117-1150); rdx is x2/a2, so an internal word 1 is x2/a2 while the C
boundary uses x1/a1 (N:15389). Every lifted LLVM function returns `{i64, i64}` (L:5593-5596).

**Prologue / epilogue** (N:17253-17320 functions, N:32510-32530 closures): `push %rbp; mov
%rsp,%rbp; sub $.F,%rsp`; every parameter stored to its frame slot; then **the whole rest of the
frame zeroed with `rep stosq`** so drop flags and owned slots start at 0. The optimiser
(O:1668-1712) forwards and deletes slot traffic, promotes the hottest non-escaping slots into
rbx, r12-r15 (only those it uses), and then emits a **second** `subq $16*ceil(n/2),%rsp`, a `movq`
save of each chosen register to the frame, and a `movq $0,%reg` for each one (the frame was zero);
`rep stosq` becomes per-slot `movq $0` when the frame is small. Epilogue: `movq` restores, `leave`,
`ret`, plus an unreachable fall-through `xor %rax,%rax; leave; ret` per function. rbp is always a
frame pointer. Callee-saved set = the platform's (rbx, rbp, r12-r15 -> x19-x23, x29 / s0-s5,
M:159-195); every SSE register is caller-saved. The x86-64 Windows target keeps this SysV-style
internal convention and wraps every export in a thunk that saves rdi, rsi and xmm6-15
(N:17200-17222).

**Closures.** A closure value is a pointer to a heap record `{code, drop, captures...}` built by
`rt_rec` at the literal. A call puts **the address of the frame slot holding that pointer** in rdi
(two loads to reach a capture), shifts the declared arguments up by one, so an Fn takes at most five,
and does `call *code` (N:26356-26368; `grail_fn_thunk` adapts a plain function). A callee given an
owned `Fn` drops it on return (drop helper -> `rt_free`).

**C boundary.** `extern "C"` calls and exported callbacks use the platform ABI (float registers,
narrow integers, stack arguments, Win64 home area: N:15010-15400, N:23469, `callback_params`),
independent of the internal rule.

**LLVM backend.** Each lifted function is `define {i64,i64} @f(i64 %a0, ..., i64 %a5)`, and **every
call passes the current contents of all six argument registers** (`call_args`, L:1904-1916). So in
fib %a1, %a4 and %a5 (rsi, r8, r9, which fib never writes) are passed through to both recursive
calls; LLVM keeps them alive in r14, r15 and r12 across the first call, and that is the five pushes.
The `{i64,i64}` result makes rdx part of every result: fib returns its second call's rdx, which
blocks clang's accumulator rewrite of fib, and in `leaf` the high half of `b*3` (a `mul`, not a
`lea`) is computed because rdx is returned. A function is internal only if no native text names
it, and the native part carries a `.type f,@function` line for lifted functions, so fib stays
external (L:5732-5755). **Verified:** the lifted fib IR, unchanged except `define internal`, compiles under
clang -O2 to exactly clang's C fib (dead-argument elimination drops the pass-throughs and the rdx
result, and the accumulator rewrite follows): `.work/probe/fib_int.ll`. **The lifter refuses every indirect call** (`call *%reg`, L:2038-2041) and
the >6-argument prologue, so every function that calls a closure, a vtable slot or a function value
(25 sites in the compiler) and every 7+-parameter function (46 in the compiler) ships as the raw,
unoptimised front-end text in a release build: `rep stosq`, every temporary in memory.

## 2. What a call executes beyond C

fib(32) = 7.05 M calls; per-pattern loops are 10 M iterations, empty loop subtracted.

| fib(32) | instructions | cycles | per call |
|---|---|---|---|
| clang -O2 | 67.1 M | 25-26 M | 9.5 |
| Grail LLVM (wrap) | 112.8 M | 44-46 M | 16.0 |
| Grail native, checked (the bench's build) | 155.1 M | 70-77 M | 22.0 |
| Grail native, wrap | 144.6 M | 52-63 M | 20.5 |
| Go | 102.9 M | 44-53 M | 14.6 |
| Rust dev | 169.5 M | 71-72 M | 24.0 |
| Zig Debug | 186.8 M | 90-98 M | 26.5 |
| clang -O0 | 120.0 M | 52-57 M | 17.0 |

**fib, native** (objdump, per non-leaf call), compared with a C frame: second `sub $16,%rsp` (1);
`mov $0,%rbx` after the save, dead because rbx := rdi follows (1); `movq $0,-16(%rbp)`, zeroing a
slot written before it is read (1); the first result spilled to the frame and reloaded instead of
held in a second callee-saved register (2); `movabs $k,%rcx` trap operand on the hot path (2,
checked only); `mov %rbx,%rax; sub $1,%rax; mov %rax,%rdi` for `lea -1(%rbx),%rdi` (2 x 2); an
unreachable `jmp` after `ret`. And no shrink-wrapping: the n < 2 leaf path, half the calls, runs the
whole prologue and epilogue (11 instructions where LLVM, Go and C run 3-4).
**fib, LLVM**: 5 pushes and 5 pops, 3 moves out to callee-saved registers and 3 moves back per call
(the pass-through registers), plus no accumulator rewrite (the rdx result).

**leaf** `a ^ (b*3)`: C is 3 instructions (`lea; xor; ret`). Native: +15 per call (frame 4,
parameter spills and reloads 4, `movabs`/`mul`/`jae` overflow check and copies). LLVM: inlined,
because it is internal and has no native caller; out of line it is `mov; mov $3; mul; xor; ret`,
where `mul` is forced by the rdx result.

**seven** (7 parameters): native **+359 instructions (134 cycles) per call** against +27 for the
six-parameter version: caller `movabs $2,%rdi; call rt_rec` (allocator) plus 4 stores; callee 2
loads, 2 stores, `mov %r9,%rdi; call rt_free`. LLVM: **+197**, because `seven` is not lifted (raw
text: 15-word `rep stosq` and every temporary through memory) and keeps the rt_rec/rt_free. C:
the 7th argument at 8(%rsp), ~10 instructions in total.

**closure** `apply(|x| x ^ k, t)`: native **+458 per call**, LLVM **+233**. The parts: `rt_rec(3)`
and 3 stores at the literal; drop flags in the caller; `apply` keeps a drop flag, passes `&slot`
(rdi = address of the slot holding the record pointer), loads the code word, `call *%rax`, then the
drop helper -> `rt_free`; the body does `mov (%rdi),%rax; mov 16(%rax),%rax` to reach `k`. With the
closure passed as `&Fn` (no allocation) it is +39 native / +41 LLVM, and on LLVM `apply` is still
raw text because of the indirect call. C (`fn(env, x)` through a pointer): `apply` is `mov; mov;
mov; jmp *%rax`, and the body is `mov; xor (%rdi); ret`.

**Targets.** AArch64/RV64 add `mov x0,x9` before every `ret` and `mov x9,x0` after every call (the
rax mapping) on top of the native x86 text, lowered instruction by instruction (frame size by
`movz/movk`, flags by `cset`).

## 3. Proposed convention

Scalars and words; records and record results are stage 3's (below).
1. **No hidden registers.** As today on native, and stated: a function receives exactly its declared
   words. Runtime state stays in the thread record (TLS); failure stays non-returning calls; the
   stack limit stays a guard page. The check protocol's %rcx operand is loaded on the cold path
   only.
2. **Exact signatures on LLVM.** The front end writes a per-body signature fact (argument words,
   result words 0/1/2, which words are floats later); the lifter defines `iN @f(i64 x n)` and passes
   exactly the callee's argument count. Every call target's signature is known: direct calls from
   the fact table and the interfaces, indirect calls from the Fn/vtable type at the site. Lifted
   functions native text does not *call* are internal (the `.type` line no longer counts). This is
   register-for-register the SysV assignment the native side uses, so native and lifted code still
   link. Indirect calls are lifted (`call %fp(...)`).
3. **More than six words go on the stack**, in the platform's layout (SysV/AAPCS64/RV64: the caller
   stores words 7.. at 0(%rsp).. in its outgoing area; the callee reads 16(%rbp)+8k). This replaces
   the heap record. It is also what `extern "C"` already does, so the internal and C rules agree for
   integer arguments. The Fn five-argument limit goes. Unboxed stage 3c's hidden destination is
   argument 0 under this rule (agreed with /root/unboxed_design).
4. **Save policy: save what is used, on the path that uses it.** One frame adjustment
   (`sub $(.F + saves)`); a callee-saved register is saved only if the allocator uses it, and is
   zeroed only if its slot is read before written; the frame is zeroed only in the slots that need a
   zero (drop flags, owned slots read on an exit path), named by a front-end fact, not `rep stosq`
   over the whole frame; **shrink-wrapping**: when the entry block is a guard that returns without a
   call (fib's n < 2), the prologue moves after it. On LLVM all of this is LLVM's once item 2 lands.
5. **Closures: `{code, env}` with the environment in a register, storage by address.** A closure value
   is two words: the code pointer and the address of its environment `{drop, captures...}`. A literal
   builds the environment in its own frame (like a stage-3a record), never `rt_rec`. A call is
   `call *code` with rdi = env, one load to reach a capture (today two). An `Fn` argument is passed as
   those two words by address (stage 3b's rule); a callee that stores it beyond the call (a field, a
   vector, a task, `pool::spawn`'s `Owned` closures, a return) boxes it at that store, exactly as 3a
   boxes a record captured by a closure. The owner drops the captures in place (stage 4's in-place
   drop helper) and nothing is freed. Non-escaping closures, the ones handed to `join`, `with_class`,
   `parallel_map`, `read_with`, iterators and so on, therefore allocate nothing.
6. **AArch64/RV64 results**: a machine.grl peephole drops `mov x9,x0` after a call and `mov x0,x9`
   before `ret` when the result goes straight back. A full remap is not possible while rdi and rax
   are both live.

**C boundary**: unchanged. `extern "C"`, exported callbacks, byval and variadics keep the
platform rule; items 3 and 5 never apply to an `extern "C"` signature, and a Grail closure handed
to C still goes through its callback thunk.
**Interfaces and the build store**: the ABI line gains `args = 6 registers then stack` (item 3),
`closure = code env` (item 5) and, from stage 3c, `record result = registers` (unboxed's), so a
module compiled for the old convention is refused at read. The build store already keys on the
compiler's identity (cli.grl:1572-1592), so objects are rebuilt with no new key component. Items 2,
4 and 6 change no interface: they are code quality on one side of an unchanged register assignment.

**Where this touches the others**
- /root/unboxed_design, stage 3: record arguments by address (3b) and record results in rax:rdx or a
  hidden destination as argument 0 (3c) are theirs. Agreed with them: the destination is argument 0
  under my stack rule; they publish the result width in the kind-4 fact `facts_dyn_result`
  (`width` = words), which my item 2 reads for the LLVM result type; plus a body fact "argument 0 is
  a destination of N words" for `noalias`. Item 5's environment is a 3a frame aggregate, and their
  "closure capture boxes on store" becomes "a capture is copied into the frame environment; the
  environment is boxed when the closure escapes". Needs their sign-off.
- /root/prover_wrap: `f.proved` and the checking wrapper are ordinary functions under this
  convention. Item 2's signature fact is per body symbol, so the wrapper and `f.proved` each get
  one. A wrapper with more than 6 words re-passes stack words (no record to re-forward). Their
  `call_proved_out` (N:21251) shares the call lowering I change.
- /root/optimiser_labels owns register allocation in optimize.grl. Item 4's save code sits in their
  promotion pass (O:1668-1712). I propose the rules (one frame adjustment, no `movq $0` for a
  register whose slot is written first, shrink-wrap) and implement them with their agreement, or
  hand them over. The zero-only-what-needs-it fact is front-end work and mine.
- /root/concurrency_design: see below.

**pool::join<u64,u64>: 6 heap allocations per call** (callgrind: 4 `rt_rec`, 2 `rt_enum`, 6
`rt_alloc` and 6 `rt_free` per join; the fork itself allocates nothing):
1-2. the caller's two closure literals (`rt_rec`): **mine** (item 5);
3. the inner closure `|| { *out = Some(here()); }` in pool.grl:146 (`rt_rec(4)`): **mine** (item 5);
4. `slot: B? = None` (pool.grl:144): the `None` is a heap `rt_enum(1,0)`, freed when it is replaced;
5. `Some(here())`: another `rt_enum`;
6. the `Pair` result (`rt_rec(2)`): unboxed stage 3c (a 2-word result in rax:rdx).
**4 and 5 are pool's own** and go to the scheduler owner. `rt_parallel_with` requires the second
branch to return unit and write through a capture, so join builds an Option to carry a `B`. Options:
let `parallel_with`'s second branch return its word (`rt_parallel_with` returns both words, rax:rdx),
or write `B` into a plain out slot. Unboxed stage 5 (enums inline) would also remove them, but it is
far off. After items 5 and 3c plus pool's change, join allocates nothing, as rayon does.

## 4. Staged plan (each step: selfhost fixed point, filtered corpus, commit and push)

Baselines: dev compiler self-compile **294.7 G instructions** (167 G cycles, 18 s wall, multi-thread
totals); release compiler self-compile **127.1 G instructions** (54-56 G cycles), same output.

| step | what | fib serial native / LLVM (instructions) | expected rival row |
|---|---|---|---|
| S1 | LLVM: internal linkage fixed (the `.type` token), then exact signatures for what stays external (item 2) | 155 M / 112.8 M -> 155 M / ~67 M | LLVM fib 10.4 -> ~3.5 ms (C++ 3.4) |
| S2 | LLVM lifts indirect calls (item 2) | - | closure/vtable callers optimised in release; `apply` +41 -> ~5 |
| S3 | >6 words on the stack, both backends, ABI line (item 3) | - | seven +359 / +197 -> ~+30 native / inlined LLVM |
| S4 | prologue: one adjustment, no dead zeroing, frame zero by fact, trap operand cold (item 4) | 155 M -> ~120 M | native fib 18.8 -> ~14 ms |
| S5 | shrink-wrapping of the early-return guard (item 4, with optimiser_labels) | ~120 M -> ~95 M (Go 103 M) | native fib -> ~11 ms, below Go |
| S6 | closures `{code, env}`, frame environments, box on escape, ABI line (item 5) | - | closure call +458 -> ~+20; join 6 -> 3 allocations (0 with 3c and pool's change) |
| S7 | AArch64/RV64 result moves (item 6) | 2 instructions per call on those targets | - |

S1 and S2 are LLVM-only, and their self-compile effect shows on the release compiler (every
compiler function is lifted with exact arity). S3-S5 show on the dev compiler. Expected
self-compile effect: S1 a few percent of release instructions (every call passes six words today);
S3 46 functions lose an allocation per call; S4-S5 a few percent of dev instructions (every frame).
Each figure is measured at its step and reported with its counts; none is promised before then.
Order: S1 first (largest win, no ABI change), then S3 (ABI line, unblocks unboxed 3c), S4/S5 with
optimiser_labels, then S6 after unboxed 3a lands (it builds on 3a's frame aggregates).

## Progress

- **S1 (LLVM linkage and signatures).** `.type` lines no longer make a lifted function external;
  each body's argument words are a typed-IR fact (kind 5) and the lifter defines and calls it with
  exactly those, returning one word unless a `dyn_result` fact makes it two. Address-taken
  functions keep the six-word form. Wrong facts: caught at the body (argument register read past
  the fact) and at the caller (`%rdx` read after a one-word call), dropped with a re-lowering, an
  error under `--verify-facts`; forged-fact tests in tools/test-facts.mjs. fib(32) LLVM: 112.8 M ->
  74.9 M instructions (clang -O2 67.1 M).
- **S2 (indirect calls lifted, x86-64).** `call *%rax` becomes a six-word IR call through the
  pointer; a `cfn` call is spelled `call *%r11` and stays native. The runtime's own `rt_` runners
  were kept native for a while (lifting them raced on the thread pointer); with every %fs read made
  opaque (gaps12-join, gaps12-llvm-tp) they are lifted again. `apply(&g, x)` loop (10 M): 430 M ->
  120 M instructions on LLVM.
- **S3 (more than six words on the stack, all targets).** `load_call_args` reserves an outgoing
  area (`subq $N,%rsp`; `cstack` on AArch64/RV64), stores words 6.. at 8k(%rsp), and
  `release_call_args` frees it after the call; `stack_params` copies 16 + 8k(%rbp) into the
  parameter slots after the frame is cleared. The optimiser accepts that load (`ir::incoming_arg`;
  the body keeps its rbp mention, so it is never inlined into another frame). The lifter lifts both
  sides: the area becomes the call's arguments past the sixth, the load becomes `%a6..`, and a
  read past the signature fact is a wrong fact. ABI line: `args = 6 registers then stack`. 7-arg call
  loop (10 M): native 3,670 M -> 430 M instructions (6-arg: 350 M), LLVM 1,990 M -> 17.5 M.
- **S4 (save policy, native).** optimize.grl `function`: the promotion pass's save area is folded
  into the prologue's `subq $.Fn+16k,%rsp` (the Win64 SEH writer adds the `+N` to
  `.seh_stackalloc`); `slots_live_in` (a backward slot liveness over the label graph; any slot whose
  address is taken counts as read) decides which promoted registers get `movq $0` after the saves
  and which slots of the cleared range are zeroed. fib(32): 155.1 M -> 134.0 M.
- **S5 (shrink-wrapping, native).** `shrink_wrap`, a pass over the function's emitted text: the
  prologue, saves and argument copies, then `cmpq; jCC L` and a guard of moves into %rax, restores,
  `leave; ret` with no call, becomes the compare and the return on the argument registers before
  `pushq %rbp`, with the prologue behind `.Lsw_NAME` jumping to `L`. fib(32): 134.0 M -> 112.8 M
  (Go 102.9 M); base case `cmpq $2,%rdi; jae; movq %rdi,%rax; ret`. Corpus: callabi-shrink-wrap-guard,
  callabi-one-frame-adjustment. What is left of fib's gap is the optimiser's: two dead trap-operand
  `movabs` (block-local dead_defs), the first result spilled to the frame, `mov; sub; mov` for `lea`.
- **S7 (AArch64/RV64 moves, native).** machine.grl `same_moves`, the last pass of `lower`: a value
  number per integer register follows `mov D,S` (64-bit moves only: `mov w9,w10` zero-extends), drops a
  move whose two registers already share a number, gives every register any other line names a
  fresh one, and forgets everything at a label, branch, call, return, system call or encoded
  instruction. Probe program: 227,979 -> 224,637 lines on AArch64, 228,896 -> 225,600 on RV64;
  fib's base case returns with `mov x10,x0; mov x9,x10; ret`.
- **S8 (planned after measurement).** A float called out of line through a function value (10 M
  calls): C -O2 12 instructions per call, Grail LLVM 19 (+58 %; +9 % cycles), native 62. The
  difference on LLVM is the GPR<->xmm moves at each edge. S8a lifts C-boundary float calls with a
  typed call from a per-symbol FFI fact; S8b gives internal lifted bodies `double` parameters where
  the signature fact says a word is a float. Neither changes the native convention.
- **S8a (C-boundary float calls lifted, x86-64).** native.grl `ffi_signature_fact` records, per C
  symbol, the integer words, the float arguments (f32 mask) and the result kind for a call whose
  arguments are all in registers (no stack area, not variadic, no records); llvm.grl
  `lower_ffi_call` passes the floats from %xmm0-7 as `double`/`float` and puts the result back in
  %rax or %xmm0, and the symbol is declared with those types. Disagreeing call sites leave a symbol
  untyped. The stay-native rule remains for every other shape (it now fires only there).
  Fixture: compiler/tests/ffi_float_calls.grl in tools/test-facts.mjs.
- **S8b (internal float parameters on LLVM): built, measured, dropped.** Bodies with float words
  were defined as `NAME.d(double ...)` with a word-form shim `NAME`, and lifted direct calls went to
  `.d`. Measured against main (user instructions): nbody 1,340,697,902 -> 1,340,697,610, xform_f64
  716,595,875 -> 716,595,208, dot_f64 1,063,971,042 -> 1,063,970,836, matmul unchanged; outputs
  identical. Direct calls to small float functions are inlined, so the GPR<->xmm moves vanish
  either way. The cost measured in the microbenchmark (19 vs 12 instructions per call) comes from
  calls through function values, which must keep the word form for native and dyn callers. Not
  worth the second entry per float function. If it matters later, it belongs in the closure
  convention (S6: `{code, env}` with a typed code pointer), not in direct calls.
- **Dyn dispatch (record vtable adapters).** The adapter is a load and a tail jump instead of a
  framed call (landed 3fe042c). dyncall: native 1,645 M -> 1,565 M, LLVM 779 M -> 719 M; Rust -O
  648 M.
- **Indirect calls pass only their words (LLVM).** native.grl `indirect_fact`: a `call *%rax` set up
  by load_call_args with no call in between records its word count (fact kind 7, keyed by its ordinal
  among the function's `call *%rax` lines); lower_indirect_call passes `poison` past it. The check:
  the frame-slot loads into argument registers in the run of moves just before the call must not
  reach past the count. dyncall LLVM 719 M -> 679 M.
