# Remembering what checking a standard generic costs (design)

Status: step 1 built (owner: driver_speed; key and registrations agreed with incremental_units).
As built, step 1 is not a separate memo but the per-function store itself: a validating replay is
a unit (`fn_on`), keyed like every unit - the run's declaration surface, the body's text and
signature, the compiler - and its registrations (specialisation, drop, effect records) are recorded
and made again on a hit (`fn_apply`), as incremental_units required. A body that asks for something
a unit does not record is not a unit (the FN_* rules; a `parallel_for_zip` adapter is one now). Its
key names the whole run's surface, so it serves repeated and edited checks of a program; the
owner-scoped key below, which would serve a new project's first check, is step 1b.

**What it costs.** A first check files the template checks it ran, and with the whole-surface key a
new project's first check never hits the ones `grail cache warm` filed. Measured on main 1cc4bee4
(compile-perf, dev compiler, GRAIL_JOBS=1): hello 0.044G with `GRAIL_TEMPLATE_MEMO=0`, 0.046G with
it (+4.5%: core's generics are filed once), syn1000/syn4000/build_syn1000 unchanged (+0.0%), and
build_syn1000_edited 6.384G -> 6.380G. The compile-perf baseline carries the 0.046G (75ba9530). Step
1b's owner-scoped key is what would take the hello cost back: the warm store's checks would then
be the ones a new project's first check asks for.

## What the time is

A check of `bench/iterchain.grl` with every standard module already in the store (`grail cache
warm`) is 0.22G instructions, against Rust's 0.13G. The module run for `main.grl` is ~250M of it, and
`emit_specializations` is ~119M of that:

- **~107M validation.** Before any code is emitted, `emit_specializations` replays every template the
  run instantiates (`instantiated`) or owns, once, with the template's own parameters as opaque
  types (`c.validating = 1`), and throws the text away. It is the check a caller owes a generic it
  uses. For a program that uses `iter`'s adapters that is dozens of standard templates, re-checked
  from their interface bodies on every check of every program.
- **~12M emission** (`drain_specs`): the specialisations themselves, per type-argument list.

So the first lever is not the specialised code but the *validation*: its result depends on the
template and on what the template's body can see, and not on the program that asks for it.

## Step 1: a memo of passed template checks

A template whose validation passed under the same inputs passes again: the check is a function of
the compiler, the flags that change checking, the template's text, and the declarations its body can
name. A run records, for each template it validated, a key; a later run that computes the same key
skips the replay.

**Key** (one `fast_hash` over this text, `grail-template-check 1`):

- the compiler's identity (`--fn-cache-id`, what the per-function cache already keys on) and the
  flag vector the run was started with (overflow mode, target, `--deny-ambient-host`, ...);
- the template's owner module and symbol, and its kind (free function, inherent method, generic
  impl method), so two templates with one text are two keys;
- the template's body text: the token range `func` replays (`file`, `pos`), as the bytes of its
  source or of the interface record it came from;
- the **surface of every module the owner can see**: the owner's interface surface (the bytes
  before its trailer, `native::iface_surface`) and the surfaces of the modules in the owner's
  transitive `use` closure. Not the program's other modules: a template's body cannot name them,
  which is why a new project using the same standard modules hits.

**Where it plugs in:** `emit_specializations`, around the `replay_function(&mut c, i)` of the
validation loop. With `--fn-cache DIR` (the driver passes the store's `fn/` directory to every
module run, checks included), a hit skips the replay; a miss replays and, when the run ends without
an error, files the key (one empty file under `DIR/tcheck/`, written through a staging name).

**What must be shown before it lands:** that the validation replay has no effect a later step reads.
It truncates `c.out` and restores the label counters already; anything else it leaves behind
(interned types, closure or specialisation requests, effect facts, diagnostics state) must be absent
or harmless. The proof is the per-function cache's: every corpus case's assembly, and the compiler's
own, byte-identical with the memo on and off (`GRAIL_FN_CACHE=0` style switch,
`GRAIL_TEMPLATE_MEMO=0`), plus a case where an edited standard template is checked again and fails.

## Step 2: the checked and emitted specialisation

Keyed by step 1's key plus the type-argument list's `type_key` spelling (closures in the arguments:
keyed by the closure literal's text and its captures' types, or not cached at all in the first
version), the store keeps a specialisation's emitted text and the requests it made, replayed as the
per-function cache replays a unit. This overlaps incremental_units' unit layer (`fncache.grl`) and
is designed with them; it is worth ~12M on iterchain, where step 1 is worth ~107M.

## Ownership

- driver_speed: the memo (step 1), its key, the switch, the proof.
- incremental_units: `fncache.grl` and the unit store; step 2's record format and replay, which
  should be a kind of unit rather than a second store.

## Why step 1b is not built: the orphan rule is stated, not enforced

An owner-scoped key - one that names only the template's own module and the modules it `use`s -
would let a new project's first check hit the checks `grail cache warm` filed (hello pays about 2M
instructions to file ~33 template checks that never hit: 45.8M with the memo against 43.8M without,
measured on main b8a4cc4e). It is sound only if nothing outside that closure can change how the
template's body checks. docs/design/first-principles-architecture.md states the orphan rule that
would guarantee it ("an implementation lives with either the type or the interface"), but
native.grl does not enforce it: a user module may write `impl core::X for result::Option<T>` and
change method resolution inside a `core` generic. Until the rule is enforced (a language change),
the key names the whole run's declaration surface - now as a digest of it (`grail-fnkey 5`) - and
the 2M on a first check is the accepted cost; edited checks keep their 25-34%.
