# Remembering what checking a standard generic costs (design)

Status: design, step 0 of the specialisation cache (owner: driver_speed; keys agreed with
incremental_units before step 2).

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
