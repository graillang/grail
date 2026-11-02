# Grail-written compiler (bootstrap v0)

`grailc.grl` (with `lexer.grl`) is a Grail compiler written in Grail. It translates the source
subset it is itself written in to C, and reproduces itself byte for byte.

```sh
# Stage 1: the Rust seed checks and builds the compiler.
cargo build --manifest-path seed/Cargo.toml --release --offline
W=seed/.work/bootstrap; mkdir -p $W
seed/target/release/grail-seed host $W
seed/target/release/grail-seed compile compiler/lexer.grl $W $W
seed/target/release/grail-seed build compiler/grailc.grl $W $W
# Stage 2 and 3: the compiler compiles itself; the outputs are identical.
$W/grailc $W/stage2.c compiler/grailc.grl compiler/lexer.grl
clang -O1 -I compiler $W/stage2.c -o $W/stage2
$W/stage2 $W/stage3.c compiler/grailc.grl compiler/lexer.grl
cmp $W/stage2.c $W/stage3.c
# Automated check, including seed-versus-grailc behaviour on examples:
cargo test --manifest-path seed/Cargo.toml --offline --test bootstrap_native -- --ignored
```

`grailc OUT.c ENTRY.grl [MODULE.grl...]` compiles whole programs: every module is passed as a
source file, and the first public function of the first file (no parameters, or `argv[1]` as a
byte view) is the entry. The output `#include`s `grail_rt.c`, so compile it with `-I compiler`.

`bootstrap/grailc.c` is the committed stage-2 output. It builds the compiler with only a C
compiler (`cc -I compiler compiler/bootstrap/grailc.c -o grailc`), without the Rust seed. The
bootstrap test fails when it is stale; regenerate it by copying a fresh stage-2 output.

## What it does not do

- **No ownership or borrow checking.** Programs are assumed to have passed the seed; `grailc`
  only parses, resolves names and field/variant indices, and emits C. Its own source is checked
  by the seed when stage 1 is built.
- **Uniform values and no freeing.** Every value is one 64-bit word; sequences, records and enums
  are heap objects that are never freed. Fine for a short-lived compiler, not for general use.
- **Subset:** explicit `module` files; records, enums, `match`, `?`/`!`, loops, typed references,
  `vec<T>`, bytes/strings/views and the host interface. Not supported: implicit modules, generic
  functions or types (other than `vec<T>`), holders, `buffer`, `hold`. Unknown names abort with a
  byte offset.
