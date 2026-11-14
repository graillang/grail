# Checked effects: `@no_alloc`, `@no_panic`, `@bounded(n)`

Status: implemented (gaps round, G26); effects moved from the emitted text to the call graph the
front end records, per specialisation, with drop glue followed through dispatch (gaps2 round).

`@no_alloc` and `@no_panic` on a function, and `@bounded(n)` on a loop, are claims the compiler
proves. None of them is trusted.

## How the proof works

The compiler does not have a separate statement IR: `compiler/native.grl` emits the checked word
stream statement by statement, and that stream is its IR. The effect facts are recorded **where a
statement is emitted**, not by reading the assembly back:

- `call_out` / `call_proved_out` emit a direct `call` and record an edge to the callee's linker
  symbol - a user function, a specialisation, a runtime entry (`rt_new`, `rt_push`, `rt_free`, ...),
  or a drop helper the compiler itself named.
- `call_slot_out` emits `call *%rax` / an import thunk in **user code**: a closure call, a function
  value, a `dyn` method slot. Nothing names what it reaches, so it is an **unknown** edge, and an
  unknown call both allocates and may fail. It also records **why** the target has no symbol
  (`fx_why`), because the site is the only place that knows: a `dyn` receiver's site passes
  `iface_reason(contract)`, so the edge carries "interface `Shape` of module `m`", and the other
  sites say "a closure call", "a function value", "an imported function" or "a call through a value
  the compiler did not name". A refusal therefore reads "it makes an indirect call the compiler
  cannot follow (the target is interface `Shape` of module `m`)".
- `call_dispatch_out` emits the compiler's own dispatch inside trusted code (a closure's drop through
  the slot its body installed). Every body it can reach is a body of this build already, so it is not
  an unknown.
- `call_entry_out` emits a refined parameter's check in the checked entry. That check is the
  **caller's** obligation, so it is an entry fact of the body, not an edge of it.
- `fx_vtable_drop` resolves a `dyn` value's drop through the vtable's first word to the drop helper of
  every concrete type whose vtable for that interface this build recorded (see *Drop glue* below).

These six functions are the only places a `call` line is written. `fx_end` counts the `call` lines in
the bytes each body emitted and refuses a body whose count disagrees with the calls it recorded, so a
new call site that bypasses them is a compiler error rather than a silently weaker proof.

**That count is no longer a text scan.** The typed IR (`compiler/ir.grl`) parses every body into
instructions and records its calls, so the check is made against the parse instead of the bytes:
`fx_end` records what each claiming body emitted (with the range of a replayed `.proved` prologue),
`optimize::body` hands back `Body.calls`' count per body through `ir::count_calls`, and
`fx_check_calls` holds the two together once the optimizer has walked the whole program. A call site
that bypassed the recording helpers still leaves the IR with a call the recorder never saw, so the
proof is exactly as loud as before, and nothing reads emitted bytes to decide a fact.

Two details the move had to get right, both of which produced a false refusal before they did:

- the `.proved` entry replays a byte copy of the checked entry's prologue, so the parse holds those
  `call` instructions twice while the recorder counted them once. The front end records the replay
  range per body (`fx_body_lo`/`fx_body_hi`, which used to be `fx_skip_lo`/`fx_skip_hi` for the scan)
  and `ir::count_calls` counts only calls outside it;
- `parse` re-tags nine runtime accessors (`call rt_slot`, `call rt_at`, ...) into pseudo-instructions
  40..48, which `emit_line` may inline. They are still calls the front end wrote with `call_out`, so
  the count includes those opcodes; counting only opcode 15 refused `effects-accepted` by three calls.

The roots are the runtime's allocator (`rt_alloc`, `rt_alloc_unlocked`, `rt_grow`) and its failure
entries (`rt_abort`, `rt_fail`, `rt_trap`, `rt_refine`, `rt_error`). A fixpoint marks every body that
reaches one, and each claim is checked after the whole program - the runtime, the drop helpers, the
vtables' drop slots and every specialisation - has been emitted. A refusal prints the chain that
reached the root, with the position of the call that continued it.

Recording the statement instead of scanning the text matters for three reasons:

- a check the prover removed is not in the IR at all, so it is not an edge. `@no_panic` is exactly as
  strong as the refinement prover and bounds-check elimination: it fails where a check is left, and a
  function whose access the prover made check-free has nothing for the fixpoint to reach;
- the callee is the symbol the front end chose, so dispatch the compiler built itself - a vtable's
  drop slot - is resolved from recorded vtables instead of guessed from a register name;
- the count of `call` lines in a literal, or in the replayed prologue of a `.proved` entry, cannot be
  mistaken for a call, because no byte is ever read for a fact.

## Per-specialisation records

One record per **emitted body**, keyed by the symbol that body is emitted under - for a generic, the
specialisation's content-addressed symbol (`fill$<16 hex>`, the same key `specialize` deduplicates
by). A generic's declared claim is the obligation and each instance's own body is what proves or
refuses it, so:

- `fill<u8>` and `fill<File>` are judged apart: one allocating instance does not mark the other, and
  a `@no_alloc` caller that only reaches the quiet instance is accepted;
- a claim **on the generic itself** is checked once per emitted instance, and the diagnostic names the
  instance (`fill<main::File>`), because that is the code whose instantiation has to change. Before
  this, the claim sat on the template's symbol - which has no body - so an allocating instantiation of
  a claimed generic was silently accepted.

`grail build` compiles a program that claims an effect in one run, since the proof needs every body.

## Drop glue

Dropping a value runs compiler-generated glue, and the glue is followed:

- a record's or a vector's helper calls the field's or the element's drop helper directly
  (`drop_call_out`), so the user `Drop` at the end of that chain is an ordinary edge;
- a `Vec<T>` helper drops its elements in a loop it emits itself and then frees the storage with
  `rt_drop_seq`, which only releases the two allocations - so elements are never dropped behind a
  function pointer there;
- a `dyn I` value's helper runs the vtable's first word. The vtable is the compiler's own, built from
  the entries `register_vtable` recorded at each `dyn` box site, so **the slot is resolved to the drop
  helper of every concrete type a vtable of that interface in this build holds** - one real edge each.
  It is deliberately an over-approximation: which of them the value is cannot be known, so any of them
  that allocates or fails makes the claim false.

## Interface files

Interface files carry `effects <no_alloc> <no_panic> <strict>` rows after a function, written from the
declaration's claim - and now also from a generic template's claim, which is what an importer's
instantiation inherits. An `--interface` build keeps the rows on the imported declarations, and
`fx_solve` seeds the attributes from exactly those declarations: a callee whose body is not in this
build is trusted through its recorded claim, which is the definition module's own proof. An absent row
leaves the attribute clear, so the callee is unknown and a claiming caller is refused.

The rows are facts, not text the importer re-derives: `tools/interface-test.mjs` asserts that a
claimed function publishes `effects 1 0 0`, that an unclaimed one publishes no row at all, that an
importing module builds against the row, and that a row edited out of an interface is refused by the
manifest rather than honoured. Stage 2 still requires every module's source on the command line
(`--interface` changes what the checker sees, not what it is given), so a build that omits a module's
source is stage 4's problem, not this one.

## `@bounded(n)`

`@bounded(n)` is proved syntactically: `while i < K` (or `<=`, or with the bound on the left), where
`i` is an unsigned counter the body changes only by a positive constant step, and `K` is a constant
or a refined parameter's bound with `K <= n`. A `for i in a..b` with constant ends needs `b - a <= n`.
Anything else is refused, and the refusal names what is missing.

## Limits

- **A `dyn` value whose vtable this build never recorded** (it arrived as a parameter or a field from
  another object, so no `dyn` box site in this compilation named its concrete type) keeps an honest
  unknown: the drop may allocate and may fail. Whole-program builds always have the box site.
- **A closure's environment drop** goes through the slot the closure's own body installed
  (`call_dispatch_out`): the captures' drop helpers are reached by the compiler's dispatch, and the
  compiled bodies of those helpers are what the fixpoint sees, but the slot itself is not resolved to
  a symbol the way a vtable's is.
- **A `drop` of a `dyn` value is an over-approximation** over the interface's recorded vtables, so a
  `@no_alloc` function that drops a `dyn I` is refused when *any* implementation's `Drop` allocates,
  even if the value that flows there is one that does not.
- **A never-called specialisation** is not emitted, so its claim is not checked - the obligation is on
  code that exists.
- Recording happens per emitted body, so a body recompiled after a literal-hint retry drops the edges
  of the discarded attempt with its bytes.
