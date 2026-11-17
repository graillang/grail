# Checked effects: `@no_alloc`, `@no_panic`, `@bounded(n)`

Status: implemented (gaps round, G26); effects moved from the emitted text to the call graph the
front end records, per specialisation, with drop glue followed through dispatch (gaps2 round); the
proof is per run, against per-function summaries carried in interfaces (gaps12, *Summaries*).

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
- `call_import_out` emits a call through the import table to a named operating-system function
  (`call *__imp_CreatePipe(%rip)`). In the runtime it is what a `syscall` instruction is on Linux:
  the OS does the work, so it neither allocates on the Grail heap (whose roots are `rt_alloc` and
  `rt_grow`) nor reaches a failure entry, and it records no edge. In user code an imported function
  is code the compiler does not see, and stays an unknown edge.
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

A claim is checked in the run that emits the body: a function's in its own module's run, a generic's
in every run that emits one of its instances.

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

## Summaries

Checking a call never needs the callee's body (`docs/design/compile-speed.md`, the standing rule): it
needs the callee's **summary**. Every run that emits code records every body it emits - not only
claimed ones - and solves the fixpoint over them; the solved facts of each function are its summary:

- `alloc` and `fail`: whether calling it can reach an allocation, or a failure entry;
- `entry`: whether its checked entry runs a refined parameter's check (the caller's obligation unless
  the call proved it, the edge kind 8 of `call_proved_out`);
- for each fact that is set, its **witness**: the callee the fact came through.

The summary travels three ways:

- **Interfaces.** A `facts` record (format 7) lists the summary of every function the interface lists,
  claimed or not, in symbol order, inside the surface - so a changed fact is a changed surface and
  every run that read it runs again. The record is added once the bodies are solved: the interface is
  written in pass 1, before any body, and rewritten with the record (`iface_emit_facts`). A run that
  emits no code (a check) writes none, and a function with no summary is unknown to its callers -
  assumed to allocate and to fail, so a missing summary refuses a claim and never accepts one.
  `--verify` compares declarations and leaves the record out: it is a function of the bodies, which
  the source digest pins.
- **`runtime.facts`.** The runtime has no interface (every run knows its declarations), so the run that
  emits its bodies writes its summary beside the interfaces; every run that reads interfaces there
  reads it first. In a module's own run, `rt_push` allocates and `rt_abort` fails because the
  runtime's run said so.
- **Function units.** A unit carries its body's record - own facts, entry, call count and edges, with
  positions relative to the `fn` token - and a replay puts it back; the fixpoint runs per run over
  replayed and fresh edges alike, so a unit never carries a solved fact that could be stale. The claim
  is not in the unit: it is read from the declaration as this run parses it.

A row's facts install as the callee's own facts and its witness as the next link, so a refusal in
module A names the chain through B and the runtime exactly as a whole-program build does:
`loud -> push_one -> grow -> rt_push -> rt_grow` (`tools/test-cli.mjs` holds the two equal).

Modules build in dependency order (a `use` cycle is refused by the per-module driver), so every
summary a run reads exists before it starts; recursion inside a run is the fixpoint's.

### The `dyn` drop

Dropping a `dyn I` value runs the drop of whichever implementation it holds. When `I` is private to
the module that drops it, every implementation and every box site is in that module, so the drop
resolves to their helpers (*Drop glue*). When `I` is public, an implementation in a module this run
cannot see may be the one dropped, so the drop is an unknown edge: a claim over it is refused,
naming the reason - "the drop of a `dyn I` value, whose implementations this module cannot see". The
answer is the same in every build shape. To claim such code, put the claim where the implementations
are known: on the implementing types' `Drop` (each proved in its own module), or on a function in the
module that declares `I` privately and does the drop.

### Follow-up: closure-parametric summaries

A closure call is an unknown edge, so `vecs::map`, `split` with a callback and every adapter that
takes one cannot carry a claim today. A summary that says "allocates if parameter *k*'s callee does"
would let an instantiation be checked against the closure literal passed there - its own summary -
instead of assuming the worst. The place for it is the closure-bounds work's region machinery
(`docs/design/closure-bounds.md`), which already tracks what a closure value carries; it is not needed
for per-module proofs and is not built.

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

- **A `dyn` value of a public interface** keeps an honest unknown: an implementation from another
  module may be the one dropped (*The `dyn` drop*).
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
