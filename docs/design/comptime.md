# Compile-time evaluation

Status: **design** (G10). Implemented in stages C1-C4 below; each stage lands with native cases and a
book section.

Grail runs code at compile time with one sigil, `#`. Everything Zig's `comptime` does - constants,
static branches, unrolled loops, value parameters, reflection, compile errors - is spelled with `#`
in front of the construct it changes, and nothing else is new syntax. The aim is Zig's model (the
compiler runs ordinary Grail, there is no second macro language) with less ceremony: `comptime` is
an eight-letter keyword that appears on every such construct; `#` is one character and always means
the same thing - *this is decided before the program runs*.

## The forms

```grail
// A module-level binding is a compile-time constant: there is no run-time module initialiser,
// so its value is computed while compiling and baked into the program as read-only data.
CRC_TABLE := crc_table();          // runs crc_table() at compile time
PAGE := 4096;

fn crc_table() -> u32[] { ... }    // an ordinary function; nothing marks it

fn main() {
    // `#expr` inside a function: the same thing for one expression.
    limit := #fib(30);

    // `#if`: a static branch. The branch not taken is parsed but not type-checked or emitted, so
    // it may name declarations that exist only on another target.
    #if target.os == .windows {
        win32_init();
    } else {
        posix_init();
    }

    // `#assert`: a compile error, with the message, when the condition is false.
    #assert(size_of(Header) == 16, "Header must stay 16 bytes: it is read from disk");

    // `#for`: an unrolled loop over a compile-time list. Here, reflection over a record's fields.
    #for f in fields(Header) {
        println("{}: {}", f.name, header.#f);
    }
}

// `#n` in a generic list is a value parameter: one specialisation per value, like a type.
fn rotl<#k: u64>(x: u64) -> u64 {
    #assert(k < 64, "rotate amount out of range");
    return (x << k) | (x >> (64 - k));
}
struct Ring<T, #N: u64> { slots: T[], head: u64 }

r := rotl<13>(seed);
```

| Zig | Grail |
|---|---|
| `const x = f();` (container level) | `X := f();` (module level) |
| `comptime f()` | `#f()` |
| `if (comptime cond) ... else ...` / `@import("builtin").os.tag == .windows` | `#if target.os == .windows { } else { }` |
| `inline for (fields) \|f\|` with `@typeInfo(T).Struct.fields` | `#for f in fields(T) { }` |
| `@field(v, f.name)` | `v.#f` |
| `fn f(comptime n: u32, x: u32)` | `fn f<#n: u32>(x: u32)` |
| `@compileError("...")` / `if (!c) @compileError` | `#assert(c, "...")` |
| `@sizeOf(T)`, `@alignOf(T)`, `@typeName(T)` | `size_of(T)`, `align_of(T)`, `type_name(T)` |
| `@embedFile("x")` | `#embed("x")` |

Value parameters go in the generic list, not among the run-time parameters, because that is what
they are: part of which function is called. `rotl<13>` and `rotl<14>` are two functions, exactly as
`max<u8>` and `max<u64>` are. Inference fills them when an argument fixes them, as it does types.

## What can run at compile time

Any Grail function, with three limits that make compile-time results reproducible:

1. **No ambient effects.** File, network, clock, environment, process and thread operations are
   refused while evaluating a `#` form (`cannot read the clock at compile time`). A program that
   wants a file's bytes says so with `#embed("path")`, which also records the file as a build input.
2. **Bounded work.** Evaluation stops with a compile error after a step budget (default 10^9
   instructions, `--comptime-steps N` to change it), so a non-terminating `#` form is an error,
   not a hung build.
3. **Results must be data.** A compile-time value becomes read-only data in the program, so its
   type must be spellable as a literal: integers, floats, `bool`, `char`, `string`/bytes, vectors
   of those, records and enums of those, and types themselves (in `#if`, `#for` and generic
   arguments). Handles, references, closures and C pointers cannot cross from compile time to run
   time (`a closure cannot be a compile-time constant`).

An abort during evaluation - a failed bounds check, `!` on `None`, a `#assert` - is a compile
error at the `#` form, with the call stack.

Compile-time code sees the **target**, not the host: `target.os`, `target.arch`,
`target.pointer_bits`, `size_of(T)` describe the program being built. Every Grail target is a
64-bit little-endian machine, so values computed on the host are bit-identical on the target.

## How it is built

Two tiers, chosen per form by what it needs.

**The constant tier (C1, C2).** `#if`, `#assert`, value generics and module constants whose value
is a literal expression - arithmetic, comparisons, `size_of`/`align_of`, `target.*`, other
constants - are folded inside the compiler as it parses. No code runs. This covers platform
switches, layout assertions and const generics, which are most uses.

**The run tier (C3).** A `#` form that calls a function is evaluated by running it. The compiler
builds a probe program from the module (the functions the form reaches, plus a `main` that writes
the form's value in a fixed serialisation), compiles it for the host with the same compiler in
`--comptime` mode (effects refused at the runtime boundary, steps counted), runs it, and parses the
value back as data. Probes are cached by the content hash of their inputs, so an unchanged module
never re-runs one. Because the probe is the real compiler's output, compile-time behaviour cannot
drift from run-time behaviour: it is the same code.

Order: module constants may refer to each other and to functions; the compiler evaluates them in
dependency order, and a cycle is an error naming it (`CRC_TABLE depends on itself through
table_size`).

**Reflection (C4).** `fields(T)` yields one compile-time `Field { name: string, type: type, offset:
u64 }` per field of a record; `variants(E)` the same for an enum. `#for` unrolls its body once per
element, binding the loop name as a compile-time value, and `v.#f` is the field `f` names. The
body is type-checked per iteration, with the element's types substituted - this is what makes a
generic `show`, `hash` or serialiser a few lines.

## Stages

- **C1** module constants (literal expressions), `#if` on constants and `target.*`, `#assert`,
  `size_of`/`align_of`/`type_name`. Native cases for each, including a `#if` whose untaken branch
  names a function that does not exist, and a failing `#assert` as a rejected case.
- **C2** value generics `<#n: T>` on functions and records: monomorphised like types (a value is
  interned as a type-level constant, so `type_key`, specialisation and the interface format handle it
  with no second mechanism).
- **C3** the run tier: `#expr` and module constants that call functions; effect refusal, the step
  budget, the probe cache, dependency order.
- **C4** `fields`/`variants`, `#for`, `v.#f`, `#embed`.
