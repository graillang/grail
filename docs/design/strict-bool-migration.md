# Strict bool migration

Grail is a language where `bool` and integers do not mix, and that rule is now enforced: an
`if`/`while` condition must be a `bool`, and a `bool` operand does not appear beside an integer one.
This note records what the checker reported before the migration, which helpers had to change type
first, in what order the work landed, and how the rule is kept from regressing. The body below is
the plan as written at the start; section 6 records how it finished.

Base: `lang-par` at 3916d9a. Every line number below is from that commit, except in section 6.

## 1. The rule, and what the check covers

### 1.1 Three diagnostics

`compiler/native.grl` carries the whole check: `strict_bool_check` (line 16646) for binary operators
and `strict_condition` (line 16670) for `if`/`while` conditions. There are exactly three messages,
and they are the three "kinds" used throughout this document:

| kind (verbatim message) | rule |
|---|---|
| `a condition must be a bool; compare explicitly (n != 0)` | an `if`/`while` condition must be `bool` |
| `bool and integer do not mix; use && / \|\| / ! for logic and compare integers explicitly` | `==`, `!=`, `<`, `>`, `&`, `+`, ... with one `bool` and one integer operand |
| `arithmetic on bools; use && and \|\| for logic` | two `bool` operands under `+`, `-`, `*`, `/`, `%`, `<<`, `>>`, `**` |

Two spellings stay legal, on purpose:

- `&&`, `||`, `!` on bools, and `&`, `|`, `^` on two bools: `strict_bool_check` returns early when
  `k == 38/124/94` and both operands are bool. So `same(a, b) & same(c, d)` will *not* be reported
  after the helper becomes `bool`; the `||` rewrite is a style decision, not a rule.
- `==`/`!=` between two bools, including `x == false` (see 1.3).

```grail
b := 1 > 0;
n := 3;
c := b == 0;        // bool and integer do not mix
d := b + 1;         // bool and integer do not mix
e := b & true;      // accepted: logic on two bools
f := true + true;   // arithmetic on bools
g := b == false;    // accepted today
if n { return 1; }  // a condition must be a bool
```

### 1.2 Modes

| flag | `c.strict_bool_report` | behaviour |
|---|---|---|
| (none) | 0 | stop at the first violation (`fail`), exit status 1 |
| `--strict-bool-report` | 1 | print `file:line:column: message` for every violation, keep compiling, exit status 0 |

The survey mode is what drove this migration: it never fails the build, so a partially migrated tree
still compiles and can be measured. Before the rule was enforced it was `--strict-bool` (mode 1) with
two further modes beside it — the disabled default and a mode 3 that printed machine-readable `FIX ...`
records for a `tools/strict-bool-fix.py` that never existed in the tree. Both are gone; see section 6.

### 1.3 What the check does not cover yet

The stated goal has four parts; the implemented check covers two of them. That decides how much of
the migration the report can drive:

| part of the rule | covered? |
|---|---|
| `if n` on an integer | yes, `strict_condition` at both `if` and `while` |
| `&`/`+` mixing bool and integer, arithmetic on bools | yes, `strict_bool_check` |
| a `u64` function returning a comparison (`fn f(n: u64) -> u64 { return n == 0; }`) | **no** — `return` only calls `require_type`, which accepts `bool` in a `u64` result |
| `x == false` | **no** — bool against bool is legal |

Two further conversions are silent: `mut x = 0; x = predicate();` and passing a `bool` where a `u64`
parameter is declared. Neither is a binop or a condition, so neither is reported.

The practical consequence is that **the 111 predicate helpers in section 3 are invisible to the
report as declarations.** While `eat(...)` returns `u64`, the report blames its 120 call sites
("a condition must be a bool") instead of the one declaration that is actually wrong. That is why
phase 1 comes first, and why it needs its own tool.

Both of these compile clean under `--strict-bool` today, which is why phase 0 exists:

```grail
fn zero(n: u64) -> u64 { return n == 0; }   // a predicate declared u64: no report

mut comma = 0;
comma = is_even(4);                          // bool into a u64 local: no report
if comma != 0 { return 1; }                  // still reads as an integer test
```

## 2. Reproducing the report

### 2.1 Build the compiler from the tree

```sh
cd /home/shulgin/grail
bun tools/native.mjs build          # prints the path of the built compiler
```

`buildCompiler()` (in `tools/native.mjs`) hashes `tools/native.mjs`, the bootstrap assembly and
`compilerSources`, and caches the binary under `.work/native/<hash>/grail`; the path it prints is the
one to use below. Set `GRAIL_COMPILER=/path/to/grail` to substitute a development compiler instead.

### 2.2 Compile the compiler's own sources with the report on

The compiler's sources are the ten files in `compilerSources`. The first to be *parsed* must be the
entry file, because it holds `pub fn main`. `--default-u64 --typed-refs` are the modes the compiler
is built in, and they change which literals and receivers are `u64`.

```sh
cd /home/shulgin/grail
G=$(bun tools/native.mjs build)
$G --default-u64 --typed-refs --strict-bool-report /tmp/strict-bool.s \
   compiler/native.grl compiler/lexer.grl compiler/ownership.grl compiler/machine.grl \
   compiler/optimize.grl compiler/llvm.grl compiler/fmt.grl compiler/cli.grl \
   compiler/runtime.grl compiler/os-linux.grl > /tmp/strict-bool.txt
wc -l /tmp/strict-bool.txt     # 2733
```

The report goes to stdout; the exit status is 0 (that is the point of mode 2). Counts:

```sh
cut -d: -f1 /tmp/strict-bool.txt | sort | uniq -c | sort -rn
awk -F': ' '{print $2}' /tmp/strict-bool.txt | sort | uniq -c | sort -rn
```

### 2.3 Current counts

Per file and per kind, at `lang-par` 3916d9a — 2,733 reports over 8 of the 10 sources:

| file | a condition must be a bool | bool and integer do not mix | arithmetic on bools | total |
|---|---|---|---|---|
| `compiler/native.grl` | 1261 | 360 | 244 | **1865** |
| `compiler/optimize.grl` | 106 | 82 | 42 | **230** |
| `compiler/fmt.grl` | 76 | 74 | 33 | **183** |
| `compiler/machine.grl` | 142 | 1 | 3 | **146** |
| `compiler/llvm.grl` | 89 | 19 | 14 | **122** |
| `compiler/cli.grl` | 69 | 6 | 1 | **76** |
| `compiler/ownership.grl` | 35 | 12 | 13 | **60** |
| `compiler/lexer.grl` | 13 | 30 | 8 | **51** |
| `compiler/runtime.grl` | 0 | 0 | 0 | **0** |
| `compiler/os-linux.grl` | 0 | 0 | 0 | **0** |
| **total** | **1791** | **584** | **358** | **2733** |

`runtime.grl`, `os-linux.grl`, `os-windows.grl` and `darwin.grl` are `unsafe module runtime;`, and
both checks are skipped when `c.raw != 0` (`compiler/native.grl:16614`, `18136`, `18706`). They
contribute zero reports and are out of scope: the runtime's `rt_*` routines are ABI surfaces called
by name from codegen, not helpers to retype.

### 2.4 The standard library, Abundance and Borg are already clean

The same command over every standard-library module plus the runtime reports nothing:

```sh
cd /home/shulgin/grail
G=$(bun tools/native.mjs build)
printf 'use core;\nuse strings;\nuse fs;\nuse json;\nuse hashmap;\nuse vecs;\nfn main() { return (); }\n' > /tmp/stdlib-probe.grl
$G --default-u64 --typed-refs --strict-bool-report /tmp/stdlib-probe.s /tmp/stdlib-probe.grl \
   $(ls lib/*.grl) compiler/runtime.grl compiler/os-linux.grl | wc -l    # 0
```

`lib/core.grl` already declares its option predicates `-> bool` (`is_some`, `is_none`), so the
standard library is both clean and the worked example for the compiler's own helpers.

### 2.5 With the check on, instead of reporting

```sh
G=$(bun tools/native.mjs build)
$G --default-u64 --typed-refs --strict-bool /tmp/strict-bool.s compiler/native.grl ...
# compiler/...: bool and integer do not mix; ...   (first violation only)
# exit status 1
```

## 3. Helpers declared `-> u64` that are predicates

### 3.1 How they are found

`tools/strict-bool-predicates.mjs` reads the sources and classifies every `-> u64` function whose
`return` expressions are all bool-shaped — a comparison, `true`/`false`, 0/1, a logical combination,
or a call to another such function (fixpoint) — and then splits that set by how the value is
consumed:

- **predicate** — the value is tested somewhere (`if f(...)`, `f(...) && ...`, `!f(...)`);
- **status** — the value reaches an integer position: the process exit status (`main` and everything
  returned straight through it), `mut status = f(...)` followed by `status == 0`, or a `u64` record
  field;
- **void** — only ever returns literal 0/1 and is never tested: a routine spelled `return 0`.

```sh
bun tools/strict-bool-predicates.mjs                 # predicates, per file
bun tools/strict-bool-predicates.mjs --calls         # + every call site as file:line:column (context)
bun tools/strict-bool-predicates.mjs --status        # the ones that must stay u64
bun tools/strict-bool-predicates.mjs --integer-sites # predicates with a call site in an integer position
bun tools/strict-bool-predicates.mjs --json
```

It parses the eight safe modules by default (the two `unsafe module runtime` files are skipped, like
the checker does) and accepts explicit file arguments for any other tree.

### 3.2 The predicates: 111 declarations, 1507 call sites

These must become `-> bool`. Per file, with the shape of every call site: "in a condition" counts a
site already in an `if`/`while` truth position or an operand of `&&`, `||`, `&`, `|` — no edit; a
"`+` operand" needs `||`; "vs a number" (`f(...) == 0`) needs `!`; "local" means the `u64` local that
receives the result should be declared `bool`; "other" is a `return` or a plain argument.


**`compiler/native.grl`** (58 declarations, 936 call sites)

| helper | line | returns | sites | in a condition | `+` operand | vs a number | local | other |
|---|---|---|---|---|---|---|---|---|
| `same` | 331 | 0/1 | 434 | 303 | 105 | 8 | 6 | 9 |
| `eat` | 3529 | 0/1 | 120 | 70 | 0 | 34 | 12 | 0 |
| `is` | 3438 | bool expr | 83 | 48 | 13 | 17 | 5 | 0 |
| `is_f32` | 11942 | bool expr | 43 | 27 | 3 | 4 | 7 | 1 |
| `is_float` | 11935 | bool expr | 35 | 21 | 6 | 8 | 0 | 0 |
| `needs_drop` | 1849 | bool expr | 19 | 12 | 3 | 2 | 2 | 0 |
| `is_bool` | 11966 | bool expr | 18 | 3 | 7 | 4 | 4 | 0 |
| `span_has` | 1330 | 0/1 | 12 | 10 | 0 | 2 | 0 | 0 |
| `is_union` | 4432 | bool expr | 12 | 8 | 0 | 4 | 0 | 0 |
| `literal_target` | 11962 | bool expr | 11 | 8 | 2 | 1 | 0 | 0 |
| `span_is` | 1319 | 0/1 | 10 | 10 | 0 | 0 | 0 | 0 |
| `integer` | 12010 | bool expr | 10 | 0 | 6 | 4 | 0 | 0 |
| `is_comparison` | 15303 | bool expr | 10 | 5 | 3 | 1 | 1 | 0 |
| `adopt_literal` | 12176 | bool expr | 8 | 8 | 0 | 0 | 0 | 0 |
| `is_local_slot` | 2592 | 0/1 | 6 | 2 | 1 | 3 | 0 | 0 |
| `is_at` | 4648 | bool expr | 6 | 5 | 0 | 0 | 0 | 0 |
| `is_char` | 11958 | bool expr | 6 | 4 | 2 | 0 | 0 | 0 |
| `intersects` | 2143 | 0/1 | 5 | 5 | 0 | 0 | 0 | 0 |
| `is_result_union` | 4424 | bool expr | 5 | 1 | 0 | 1 | 2 | 0 |
| `scalar` | 11970 | bool expr | 5 | 2 | 0 | 3 | 0 | 0 |
| `concrete_type` | 4128 | 0/1 | 4 | 2 | 0 | 2 | 0 | 0 |
| `is_text` | 11924 | bool expr | 4 | 2 | 0 | 1 | 0 | 1 |
| `ref_to_text` | 11928 | bool expr | 4 | 2 | 2 | 0 | 0 | 0 |
| `is_option_storage` | 12187 | bool expr | 4 | 4 | 0 | 0 | 0 | 0 |
| `is_map_type` | 14462 | bool expr | 4 | 2 | 0 | 1 | 0 | 1 |
| `numbers_equal` | 3603 | 0/1 | 3 | 3 | 0 | 0 | 0 | 0 |
| `callable_contract` | 4152 | bool expr | 3 | 0 | 0 | 2 | 0 | 1 |
| `starts_with` | 11582 | bool expr | 3 | 1 | 2 | 0 | 0 | 0 |
| `closure_free_name` | 12584 | bool expr | 3 | 3 | 0 | 0 | 0 | 0 |
| `subword` | 14204 | bool expr | 3 | 1 | 0 | 2 | 0 | 0 |
| `simple_type_head` | 14344 | bool expr | 3 | 1 | 1 | 1 | 0 | 0 |
| `statement_builtin` | 17209 | 0/1 | 3 | 3 | 0 | 0 | 0 | 0 |
| `has_bonds` | 2889 | 0/1 | 2 | 1 | 0 | 1 | 0 | 0 |
| `is_ordinary_union` | 4416 | bool expr | 2 | 1 | 0 | 0 | 0 | 1 |
| `lifetime_candidate` | 4632 | bool expr | 2 | 2 | 0 | 0 | 0 | 0 |
| `ffi_direct_type` | 5395 | bool expr | 2 | 2 | 0 | 0 | 0 | 0 |
| `stdlib_module` | 7200 | bool expr | 2 | 0 | 0 | 1 | 1 | 0 |
| `ffi_record_has_float_deep` | 7853 | 0/1 | 2 | 2 | 0 | 0 | 0 | 0 |
| `borrow_place_ahead` | 8009 | bool expr | 2 | 0 | 0 | 2 | 0 | 0 |
| `typed_binding_ahead_at` | 8308 | bool expr | 2 | 1 | 0 | 0 | 0 | 1 |
| `format_arg` | 10562 | bool expr | 2 | 0 | 0 | 0 | 1 | 0 |
| `element_index_ahead` | 16000 | bool expr | 2 | 1 | 0 | 1 | 0 | 0 |
| `flex_read` | 19128 | bool expr | 2 | 1 | 0 | 1 | 0 | 0 |
| `contains_text` | 389 | 0/1 | 1 | 0 | 0 | 1 | 0 | 0 |
| `satisfies_interface` | 3856 | bool expr | 1 | 0 | 0 | 1 | 0 | 0 |
| `token_starts_type` | 4603 | bool expr | 1 | 0 | 0 | 0 | 0 | 1 |
| `type_keyword` | 4610 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `slice_ahead` | 4676 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `is_keyword` | 5201 | 0/1 | 1 | 1 | 0 | 0 | 0 | 0 |
| `impl_has_for` | 6755 | bool expr | 1 | 0 | 0 | 1 | 0 | 0 |
| `ffi_record_has_float` | 7831 | 0/1 | 1 | 1 | 0 | 0 | 0 | 0 |
| `ffi_record_has_nested` | 7842 | 0/1 | 1 | 1 | 0 | 0 | 0 | 0 |
| `typed_binding_ahead` | 8304 | bool expr | 1 | 0 | 0 | 0 | 0 | 1 |
| `char_method` | 13451 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `type_literal_ahead` | 14406 | bool expr | 1 | 0 | 0 | 1 | 0 | 0 |
| `proven_index` | 15787 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `simple_index_ahead` | 15917 | 0/1 | 1 | 1 | 0 | 0 | 0 | 0 |
| `map_assignment_ahead` | 16940 | bool expr | 1 | 0 | 0 | 1 | 0 | 0 |

**`compiler/optimize.grl`** (8 declarations, 45 call sites)

| helper | line | returns | sites | in a condition | `+` operand | vs a number | local | other |
|---|---|---|---|---|---|---|---|---|
| `same` | 48 | bool expr | 23 | 21 | 0 | 2 | 0 | 0 |
| `movelike` | 694 | bool expr | 6 | 4 | 1 | 0 | 0 | 1 |
| `arith` | 697 | bool expr | 3 | 0 | 3 | 0 | 0 | 0 |
| `slot_read` | 816 | bool expr | 3 | 3 | 0 | 0 | 0 | 0 |
| `reg_fact_valid` | 901 | bool expr | 3 | 2 | 0 | 1 | 0 | 0 |
| `dead_after` | 1315 | bool expr | 3 | 2 | 0 | 1 | 0 | 0 |
| `promotable_use` | 1581 | bool expr | 3 | 3 | 0 | 0 | 0 | 0 |
| `slot_written` | 829 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |

**`compiler/fmt.grl`** (17 declarations, 65 call sites)

| helper | line | returns | sites | in a condition | `+` operand | vs a number | local | other |
|---|---|---|---|---|---|---|---|---|
| `is` | 226 | bool expr | 25 | 1 | 22 | 0 | 0 | 1 |
| `opens` | 810 | bool expr | 7 | 7 | 0 | 0 | 0 | 0 |
| `shuts` | 813 | bool expr | 7 | 7 | 0 | 0 | 0 | 0 |
| `prefix_position` | 377 | bool expr | 4 | 2 | 0 | 0 | 0 | 2 |
| `keyword` | 244 | bool expr | 3 | 1 | 0 | 0 | 0 | 2 |
| `binary` | 254 | bool expr | 3 | 2 | 0 | 1 | 0 | 0 |
| `chain_dot` | 925 | bool expr | 3 | 3 | 0 | 0 | 0 | 0 |
| `unary` | 400 | bool expr | 2 | 1 | 0 | 0 | 0 | 1 |
| `opener` | 784 | bool expr | 2 | 2 | 0 | 0 | 0 | 0 |
| `breakable` | 835 | bool expr | 2 | 2 | 0 | 0 | 0 | 0 |
| `space` | 411 | bool expr | 1 | 0 | 0 | 0 | 1 | 0 |
| `closer` | 792 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `trailing_ok` | 861 | bool expr | 1 | 0 | 0 | 0 | 1 | 0 |
| `arm_break` | 904 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `chain_break` | 942 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `list_break` | 991 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `op_break` | 1043 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |

**`compiler/machine.grl`** (5 declarations, 184 call sites)

| helper | line | returns | sites | in a condition | `+` operand | vs a number | local | other |
|---|---|---|---|---|---|---|---|---|
| `eq` | 14 | bool expr | 174 | 103 | 59 | 5 | 4 | 2 |
| `starts` | 25 | bool expr | 7 | 2 | 3 | 2 | 0 | 0 |
| `small_reg` | 201 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `atomic_instruction` | 680 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `c_abi` | 799 | 0/1 | 1 | 1 | 0 | 0 | 0 | 0 |

**`compiler/llvm.grl`** (11 declarations, 169 call sites)

| helper | line | returns | sites | in a condition | `+` operand | vs a number | local | other |
|---|---|---|---|---|---|---|---|---|
| `eq` | 49 | 0/1 | 106 | 51 | 34 | 19 | 0 | 1 |
| `starts` | 60 | 0/1 | 23 | 14 | 1 | 6 | 0 | 2 |
| `set_has` | 1269 | 0/1 | 16 | 3 | 1 | 10 | 1 | 0 |
| `has` | 92 | 0/1 | 7 | 1 | 1 | 5 | 0 | 0 |
| `ends` | 71 | 0/1 | 4 | 3 | 0 | 1 | 0 | 0 |
| `is_local_label` | 240 | bool expr | 4 | 3 | 0 | 1 | 0 | 0 |
| `legacy_base` | 371 | bool expr | 3 | 0 | 0 | 3 | 0 | 0 |
| `occurs_at` | 84 | 0/1 | 2 | 2 | 0 | 0 | 0 | 0 |
| `is_xmm` | 444 | bool expr | 2 | 2 | 0 | 0 | 0 | 0 |
| `member` | 131 | 0/1 | 1 | 0 | 0 | 1 | 0 | 0 |
| `callee_saved` | 1344 | bool expr | 1 | 0 | 0 | 1 | 0 | 0 |

**`compiler/cli.grl`** (6 declarations, 72 call sites)

| helper | line | returns | sites | in a condition | `+` operand | vs a number | local | other |
|---|---|---|---|---|---|---|---|---|
| `eq` | 20 | bool expr | 54 | 30 | 18 | 2 | 0 | 2 |
| `ends` | 42 | bool expr | 11 | 7 | 4 | 0 | 0 | 0 |
| `starts` | 31 | bool expr | 4 | 3 | 1 | 0 | 0 | 0 |
| `contains_name` | 270 | 0/1 | 1 | 0 | 0 | 1 | 0 | 0 |
| `is_macho` | 411 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `is_command` | 1083 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |

**`compiler/ownership.grl`** (4 declarations, 34 call sites)

| helper | line | returns | sites | in a condition | `+` operand | vs a number | local | other |
|---|---|---|---|---|---|---|---|---|
| `ancestor` | 52 | 0/1 | 23 | 20 | 0 | 1 | 0 | 1 |
| `loan_ancestor` | 201 | 0/1 | 4 | 2 | 0 | 2 | 0 | 0 |
| `can_cleanup` | 531 | bool expr | 4 | 2 | 0 | 2 | 0 | 0 |
| `overlaps` | 65 | bool expr | 3 | 3 | 0 | 0 | 0 | 0 |

**`compiler/lexer.grl`** (2 declarations, 2 call sites)

| helper | line | returns | sites | in a condition | `+` operand | vs a number | local | other |
|---|---|---|---|---|---|---|---|---|
| `whitespace` | 22 | bool expr | 1 | 1 | 0 | 0 | 0 | 0 |
| `punctuation` | 25 | bool expr | 1 | 0 | 0 | 0 | 0 | 1 |

Totals: **111 declarations, 1507 call sites** — 921 in a condition, 304 under `+`,
183 compared with a number, 48 assigned to a local, 33 returned or passed as an argument.
27 of the 111 only ever return literal 0/1 (`same`, `eat`, `eq` in `llvm.grl`, ...) and are
predicates only because a caller tests them.

For completeness, the `void` group — 0/1 only, never tested, never to be retyped:

| helper | where | call sites |
|---|---|---|
| `extern_has_body` | `compiler/native.grl:6121` | 1 |
| `mutating_method_name` | `compiler/native.grl:17090` | 1 |
| `reborrow_argument` | `compiler/native.grl:17145` | 1 |

### 3.3 The opposite list: helpers that must stay integer

Six bool-shaped `u64` functions are integer values. Converting them would be wrong; the comparison
inside them gets an explicit conversion instead (`return u64(failed != 0);` compiles and is clean
under `--strict-bool`):

| helper | where | call sites | shape |
|---|---|---|---|
| `compile_mode` | `compiler/cli.grl:432` | 3 | 0/1 only |
| `test_command` | `compiler/cli.grl:774` | 1 | bool expr |
| `fmt_command` | `compiler/cli.grl:826` | 1 | bool expr |
| `new_command` | `compiler/cli.grl:860` | 1 | 0/1 only |
| `fetch_command` | `compiler/cli.grl:905` | 3 | 0/1 only |
| `frame_split` | `compiler/llvm.grl:1379` | 1 | 0/1 only |

- `test_command` (`compiler/cli.grl:774`) ends with `return failed != 0;` and is threaded into
  `run()`'s result (`cli.grl:1118`), which `main` returns as the process exit status
  (`compiler/native.grl:19641`). Same for `fmt_command`, `new_command`, `fetch_command`,
  `check_command`, `run_command`, `build`, `add_command`, `debug_command`.
- `compile_mode` (`cli.grl:432`) returns 0/1 as a compile status; `check_command` stores it in
  `mut status` and tests `if status == 0` (`cli.grl:734`, `cli.grl:743`).
- `frame_split` (`compiler/llvm.grl:1379`) is a yes/no flag stored into `l.split`, the `u64` field of
  the lowering state `L` (`compiler/llvm.grl:46`, assigned at `llvm.grl:1501`); it could become
  `bool` only if `L.split` did too.

The rule for future helpers: if the value is ever compared with a number, stored in a `u64` field,
handed to `host::exit`, or returned through `main`, it is an integer. Only a value that is purely
tested is a predicate.

### 3.4 Call sites that need an edit when a return type flips

The set generated by `--integer-sites`: every call site of a predicate that the checker will flag
once the helper returns `bool` — a comparison against a number, a dropped value in statement
position, or a `u64` record field.

- `same` (`compiler/native.grl:331`): `compiler/native.grl:4351`, `compiler/native.grl:4354`, `compiler/native.grl:4630`, `compiler/native.grl:6165`, `compiler/native.grl:6933`, `compiler/native.grl:7247`, `compiler/native.grl:13074`, `compiler/native.grl:13461`, `compiler/native.grl:13758`, `compiler/native.grl:14576`, `compiler/native.grl:15729`, `compiler/native.grl:15800`
- `eq` (`compiler/machine.grl:14`): `compiler/machine.grl:210`, `compiler/machine.grl:359`, `compiler/machine.grl:379`, `compiler/machine.grl:709`, `compiler/machine.grl:735`, `compiler/machine.grl:1294`
- `eat` (`compiler/native.grl:3529`): `compiler/native.grl:3538`, `compiler/native.grl:3963`, `compiler/native.grl:4549`, `compiler/native.grl:4843`, `compiler/native.grl:4865`, `compiler/native.grl:4892`, `compiler/native.grl:5138`, `compiler/native.grl:5146`, `compiler/native.grl:5170`, `compiler/native.grl:6049`, `compiler/native.grl:6060`, `compiler/native.grl:6077`, `compiler/native.grl:6228`, `compiler/native.grl:6370`, `compiler/native.grl:6690`, `compiler/native.grl:6704`, `compiler/native.grl:6884`, `compiler/native.grl:6955`, `compiler/native.grl:8516`, `compiler/native.grl:9450`, `compiler/native.grl:9746`, `compiler/native.grl:9754`, `compiler/native.grl:10371`, `compiler/native.grl:10440`, `compiler/native.grl:10722`, `compiler/native.grl:12601`, `compiler/native.grl:12604`, `compiler/native.grl:14004`, `compiler/native.grl:17524`, `compiler/native.grl:17614`, `compiler/native.grl:17744`, `compiler/native.grl:17785`, `compiler/native.grl:17820`, `compiler/native.grl:18054`, `compiler/native.grl:18506`, `compiler/native.grl:18558`, `compiler/native.grl:18604`, `compiler/native.grl:18650`, `compiler/native.grl:18677`
- `eq` (`compiler/llvm.grl:49`): `compiler/llvm.grl:258`, `compiler/llvm.grl:704`, `compiler/llvm.grl:707`, `compiler/llvm.grl:711`, `compiler/llvm.grl:714`, `compiler/llvm.grl:718`, `compiler/llvm.grl:727`, `compiler/llvm.grl:806`, `compiler/llvm.grl:915`, `compiler/llvm.grl:924`, `compiler/llvm.grl:949`, `compiler/llvm.grl:977`, `compiler/llvm.grl:995`, `compiler/llvm.grl:1000`, `compiler/llvm.grl:1122`, `compiler/llvm.grl:1162`, `compiler/llvm.grl:1355`, `compiler/llvm.grl:1423`, `compiler/llvm.grl:1662`, `compiler/llvm.grl:1857`
- `is` (`compiler/native.grl:3438`): `compiler/native.grl:3929`, `compiler/native.grl:3932`, `compiler/native.grl:5042`, `compiler/native.grl:5053`, `compiler/native.grl:6042`, `compiler/native.grl:6209`, `compiler/native.grl:6674`, `compiler/native.grl:6832`, `compiler/native.grl:6893`, `compiler/native.grl:7057`, `compiler/native.grl:8910`, `compiler/native.grl:16744`, `compiler/native.grl:17210`, `compiler/native.grl:17625`, `compiler/native.grl:17626`, `compiler/native.grl:17633`, `compiler/native.grl:17652`
- `eq` (`compiler/cli.grl:20`): `compiler/cli.grl:412`, `compiler/cli.grl:753`, `compiler/cli.grl:845`, `compiler/cli.grl:1097`
- `is_f32` (`compiler/native.grl:11942`): `compiler/native.grl:6575`, `compiler/native.grl:15114`, `compiler/native.grl:16465`, `compiler/native.grl:16471`, `compiler/native.grl:17985`
- `is_float` (`compiler/native.grl:11935`): `compiler/native.grl:7078`, `compiler/native.grl:7117`, `compiler/native.grl:7711`, `compiler/native.grl:7717`, `compiler/native.grl:7763`, `compiler/native.grl:7812`, `compiler/native.grl:10729`, `compiler/native.grl:12371`
- `is` (`compiler/fmt.grl:226`): `compiler/fmt.grl:251`
- `starts` (`compiler/llvm.grl:60`): `compiler/llvm.grl:266`, `compiler/llvm.grl:899`, `compiler/llvm.grl:1082`, `compiler/llvm.grl:1438`, `compiler/llvm.grl:1662`
- `same` (`compiler/optimize.grl:48`): `compiler/optimize.grl:2123`, `compiler/optimize.grl:2506`
- `ancestor` (`compiler/ownership.grl:52`): `compiler/ownership.grl:66`, `compiler/ownership.grl:490`
- `needs_drop` (`compiler/native.grl:1849`): `compiler/native.grl:2046`, `compiler/native.grl:3357`
- `is_bool` (`compiler/native.grl:11966`): `compiler/native.grl:7133`, `compiler/native.grl:16671`, `compiler/native.grl:16677`, `compiler/native.grl:18212`
- `set_has` (`compiler/llvm.grl:1269`): `compiler/llvm.grl:1087`, `compiler/llvm.grl:1096`, `compiler/llvm.grl:1328`, `compiler/llvm.grl:1707`, `compiler/llvm.grl:1806`, `compiler/llvm.grl:1807`, `compiler/llvm.grl:1818`, `compiler/llvm.grl:1857`, `compiler/llvm.grl:1885`, `compiler/llvm.grl:1902`, `compiler/llvm.grl:1905`
- `span_has` (`compiler/native.grl:1330`): `compiler/native.grl:1482`, `compiler/native.grl:1485`
- `is_union` (`compiler/native.grl:4432`): `compiler/native.grl:8217`, `compiler/native.grl:8573`, `compiler/native.grl:9043`, `compiler/native.grl:15447`
- `literal_target` (`compiler/native.grl:11962`): `compiler/native.grl:12345`
- `integer` (`compiler/native.grl:12010`): `compiler/native.grl:13967`, `compiler/native.grl:15029`, `compiler/native.grl:15056`, `compiler/native.grl:15083`
- `is_comparison` (`compiler/native.grl:15303`): `compiler/native.grl:16575`
- `has` (`compiler/llvm.grl:92`): `compiler/llvm.grl:670`, `compiler/llvm.grl:1316`, `compiler/llvm.grl:1384`, `compiler/llvm.grl:1476`, `compiler/llvm.grl:1647`
- `starts` (`compiler/machine.grl:25`): `compiler/machine.grl:726`, `compiler/machine.grl:1451`
- `is_local_slot` (`compiler/native.grl:2592`): `compiler/native.grl:13246`, `compiler/native.grl:14109`, `compiler/native.grl:17037`
- `is_at` (`compiler/native.grl:4648`): `compiler/native.grl:4646`
- `is_result_union` (`compiler/native.grl:4424`): `compiler/native.grl:4433`, `compiler/native.grl:15357`
- `scalar` (`compiler/native.grl:11970`): `compiler/native.grl:15864`, `compiler/native.grl:18235`, `compiler/native.grl:18254`
- `ends` (`compiler/llvm.grl:71`): `compiler/llvm.grl:1438`
- `is_local_label` (`compiler/llvm.grl:240`): `compiler/llvm.grl:283`
- `concrete_type` (`compiler/native.grl:4128`): `compiler/native.grl:4135`, `compiler/native.grl:4142`
- `is_text` (`compiler/native.grl:11924`): `compiler/native.grl:13373`
- `is_map_type` (`compiler/native.grl:14462`): `compiler/native.grl:14571`
- `loan_ancestor` (`compiler/ownership.grl:201`): `compiler/ownership.grl:258`, `compiler/ownership.grl:503`
- `can_cleanup` (`compiler/ownership.grl:531`): `compiler/native.grl:3094`, `compiler/native.grl:19018`
- `binary` (`compiler/fmt.grl:254`): `compiler/fmt.grl:840`
- `legacy_base` (`compiler/llvm.grl:371`): `compiler/llvm.grl:377`, `compiler/llvm.grl:389`, `compiler/llvm.grl:401`
- `callable_contract` (`compiler/native.grl:4152`): `compiler/native.grl:4210`, `compiler/native.grl:4222`
- `subword` (`compiler/native.grl:14204`): `compiler/native.grl:14224`, `compiler/native.grl:14252`
- `simple_type_head` (`compiler/native.grl:14344`): `compiler/native.grl:8023`
- `reg_fact_valid` (`compiler/optimize.grl:901`): `compiler/optimize.grl:905`
- `dead_after` (`compiler/optimize.grl:1315`): `compiler/optimize.grl:1348`
- `has_bonds` (`compiler/native.grl:2889`): `compiler/native.grl:2236`
- `stdlib_module` (`compiler/native.grl:7200`): `compiler/native.grl:7251`
- `borrow_place_ahead` (`compiler/native.grl:8009`): `compiler/native.grl:11013`, `compiler/native.grl:14143`
- `format_arg` (`compiler/native.grl:10562`): `compiler/native.grl:10444`, `compiler/native.grl:10735`
- `element_index_ahead` (`compiler/native.grl:16000`): `compiler/native.grl:16034`
- `flex_read` (`compiler/native.grl:19128`): `compiler/native.grl:15274`
- `contains_name` (`compiler/cli.grl:270`): `compiler/cli.grl:300`
- `trailing_ok` (`compiler/fmt.grl:861`): `compiler/fmt.grl:1012`
- `member` (`compiler/llvm.grl:131`): `compiler/llvm.grl:140`
- `callee_saved` (`compiler/llvm.grl:1344`): `compiler/llvm.grl:1469`
- `contains_text` (`compiler/native.grl:389`): `compiler/native.grl:431`
- `satisfies_interface` (`compiler/native.grl:3856`): `compiler/native.grl:3884`
- `impl_has_for` (`compiler/native.grl:6755`): `compiler/native.grl:6829`
- `type_literal_ahead` (`compiler/native.grl:14406`): `compiler/native.grl:14900`
- `map_assignment_ahead` (`compiler/native.grl:16940`): `compiler/native.grl:18790`

Reconciliation of the 1507 sites: 921 in a condition and 33 in a `return`/argument
position need no edit; 304 need `||`, 183 need `!`, 48 need a `bool` local, and the
rest are statement-position calls whose value is dropped.

The 304 `+` sites are not in the list above because `+` on two `u64` values is not a violation
today; they become `arithmetic on bools` reports the moment the helper flips, and phase 2 clears them.

### 3.5 Judgement calls found while building these lists

- `rt_int_neg` (`compiler/runtime.grl:2012`) returns `9223372036854775807 < v` — a comparison, but
  the name promises a number. It is in an unsafe module and exempt; if it ever moves out, rename it.
- `native.grl` and `optimize.grl` both define `same`, and `machine.grl`, `llvm.grl` and `cli.grl`
  each define their own `eq`/`starts`/`ends`. The tool resolves a call to the definition in the
  caller's own file first, so the counts are per module, not per name.
- `format_arg` (`native.grl:10562`) is a predicate whose result is assigned to a `u64` local
  (`numeric`) that is then tested with `if numeric` (`native.grl:10735`). It converts and the local
  becomes `bool`; the dropped result at `native.grl:10444` is a stale call that should go.
- `overlaps` (`compiler/ownership.grl:65`) returns `ancestor(a, b) + ancestor(b, a)` — a sum of two
  0/1 predicates. It is a predicate too, and its body is exactly the `||` rewrite of phase 2.

## 4. Phased migration

The invariant is that the tree builds and self-hosts after every phase. That is possible only while
the check is opt-in (mode 2 reports without failing), so the flag is deleted last.

### Phase 0 — make the checker able to enforce phase 1

Without this, phase 1 has no gate: nothing stops a new `fn f(...) -> u64 { return a == b; }`.

1. Check `return` values. In the `return` statement handler (`compiler/native.grl:17852`), after
   `require_type(&mut c, v.ty, result)` (line 17861), call a new
   `strict_return(&mut c, result, v.ty)` that reports
   `a u64 function returns a bool; declare it -> bool` when `result` is an integer type and
   `v.ty` is bool. Guard it with `c.raw == 0` like the other two.
2. Decide `x == false`. Either add it to `strict_bool_check` (both operands bool, one a `true`/`false`
   literal → `compare a bool with a literal; write !x`), or drop it from the goal and say so in the
   book. Recommend adding it: same rule, mechanical, few sites.
3. Re-run 2.2. Expect the total to rise — the `return`s of the 111 predicates become visible.

Checks: `bun tools/test-selfhost.mjs`, `bun tools/test-native.mjs x86_64`, and
`awk -F': ' '{print $2}' /tmp/strict-bool.txt | sort | uniq -c` shows the new kind.

### Phase 1 — predicates become `bool`

One module per commit, ascending by call sites (the numbers are from 3.2):

1. `compiler/lexer.grl` — 2 declarations, 2 sites: `whitespace`, `punctuation`.
2. `compiler/ownership.grl` — 4 declarations, 34 sites: `ancestor`, `loan_ancestor`, `overlaps`
   (also the first `||` rewrite, since its body sums two predicates), `can_cleanup`.
3. `compiler/optimize.grl` — 8 declarations, 45 sites: `same` (23), `movelike`, `arith`, `slot_read`,
   `slot_written`, `reg_fact_valid`, `dead_after`, `promotable_use`.
4. `compiler/fmt.grl` — 17 declarations, 65 sites: `is` (25), `keyword`, `binary`, `opens`/`shuts`,
   the `*_break` family, `trailing_ok`.
5. `compiler/cli.grl` — 6 declarations, 72 sites: `eq` (54), `starts`, `ends`, `is_macho`,
   `is_command`, `contains_name`.
6. `compiler/llvm.grl` — 11 declarations, 169 sites: `eq` (106), `starts`, `ends`, `has`, `set_has`,
   `member`, `is_xmm`, `is_local_label`, `legacy_base`, `callee_saved`, `occurs_at`.
7. `compiler/machine.grl` — 5 declarations, 184 sites: `eq` (174), `starts`, `small_reg`,
   `atomic_instruction`, `c_abi`.
8. `compiler/native.grl` — 58 declarations, 936 sites: `same` (434), `eat` (120), `is` (83),
   `is_f32`/`is_float`/`is_bool`, `span_has`, `is_union`, ... — the bulk, last.

Per helper: change the result type; `return false`/`return true` stay; `return 0`/`return 1` become
`return false`/`return true`; any `mut flag = 0` that receives the result becomes `mut flag = false`.
Then repair the sites in 3.4 in the same commit.

Expected report delta: at most −921 (several predicate calls can share one condition, so the
drop is smaller) and up to +304 (`+` chains now count per operator, not per call) plus
+183 (`f(...) == 0`). The total can move either way; judge a phase by `--strict-bool-report` per
kind, not by the total.

Checks after each commit: `bun tools/test-selfhost.mjs` (stage 2 and stage 3 must be byte-identical —
this is what catches a `bool` threaded into a `u64` local), `bun tools/test-native.mjs x86_64`, and
`bun tools/book.mjs check`.

**Status.** Landed on `strictbool-preds`. 110 of the declarations in 3.2 return `bool`; the tool now
reports two predicates left, and both are deliberate:

- `is_f32` (`compiler/native.grl:12004`) — one caller reads it as a number, not a test:
  `fret = 1 + is_f32(&mut c, ret)` builds the callback return code (1 f64, 2 f32), which is later
  compared with `fret == 2`.
- `is_comparison` (`compiler/native.grl:15437`) — `p := is_comparison(k) * 3` sizes the operand list
  in `binary`, so the value is a count, not a truth value.

Both need a caller rewrite (a separate `mut fret` / `mut p` decided by an `if`) before they can flip;
doing it as part of the mechanical pass would have hidden a number behind `u64(...)`.

Two smaller corrections to 3.2 while landing this: the list is 112 declarations, not 111, because
`capture_borrow` (`native.grl:12659`) arrived with closures; and the tool misses predicates whose
bodies it cannot classify, which is why `task_walk` (`native.grl:11435`), `punct` (`fmt.grl:243`) and
`letter`/`digit` (`lexer.grl:16`, `:19`) are still `u64`. Each of those is tested by a caller and
belongs in a later pass.

### Phase 2 — operators

Now the `arithmetic on bools` and `bool and integer do not mix` reports that appeared in phase 1:

- `a + b` on predicates → `a || b`: `(x == 1) + (y == 2)` → `x == 1 || y == 2`.
- `bool & integer` → decide which operand was meant. `code & (a == 0)` was `code & 1`; write
  `(code != 0) && a == 0`.
- `bool & bool` is legal, so the `&` → `&&` sweep is *not* enforced by the check. Do it by hand in
  the same pass (`same(a, b) & same(c, d)` → `&&`), and let 5.3 keep new ones out.

Checks: the same three, with the report now showing only `a condition must be a bool`.

### Phase 3 — conditions

The remaining `if n` / `while n` / `if status == 0`. There is no mechanical rewrite: `if n` becomes
`if n != 0`; `if failed` where `failed` counts becomes `if failed != 0`; a condition that tests the
same comparison twice collapses. This is the phase where the compiler's own code reads differently,
so review it as code, not as a sweep.

Checks: the same three, and `wc -l /tmp/strict-bool.txt` is now 0.

### Phase 4 — make the check the default and delete the flag

With the count at zero the flag has no remaining purpose:

1. `compiler/native.grl:19510`: `strict_bool: 0,` — the field goes; the check becomes
   unconditional.
2. Delete the `--strict-bool` / `--strict-bool-report` / `--strict-bool-fix` arm of option parsing
   (`compiler/native.grl:19711`–`19724`) and the `strict_bool` field itself (line 227).
3. Delete mode 3: `strict_fix_record` (line 16683), its two call sites (lines 16660, 16674), and the
   stale `tools/strict-bool-fix.py` reference in the comment above it.
4. Collapse `strict_bool_fail` (line 16713) to `fail(&mut c, msg)` and drop the mode-2
   `file:line:column` printer; drop the `c.strict_bool == 0` early return in `strict_bool_check` and
   the `c.strict_bool != 0` guard in `strict_condition`.
5. Refresh the seed, because the compiler's sources changed:
   `bun tools/bootstrap.mjs update all` (the tool refuses a single-arch update when sources moved),
   then `bun tools/bootstrap.mjs verify all`.

Because the check is now on, the self-hosting fixpoint becomes the gate: the new compiler compiling
its own sources runs it on them. Any reintroduced mixing fails `bun tools/test-selfhost.mjs` instead
of waiting for review.

Checks: `bun tools/test-selfhost.mjs`; `bun tools/test-native.mjs x86_64` (and `aarch64`,
`riscv64` where QEMU is available); `bun tools/book.mjs check`; `bun tools/test-cli.mjs`;
`bun tools/abundance-test.mjs` and `bun tools/borg-test.mjs` for the library trees.

### The book

`book/chapters/numbers.md` already says "Comparisons produce `bool` values, which combine with `&&`,
`||` and `!`". Phase 4 adds one paragraph to that chapter stating the rule and the two consequences
a reader needs: `if n` must be `if n != 0`, and a `+` chain of comparisons must be `||`. No example in
`book/examples` needs to change — they are already written in the target dialect, and
`bun tools/book.mjs check` is the gate that keeps them so.

## 5. Preventing regressions once the check is on

Three layers, cheapest first.

### 5.1 The compiler itself

With phase 4 landed nothing else is needed for the compiler's own sources: the check is the default
and `bun tools/test-selfhost.mjs` compiles `compilerSources` twice with it. That is the strongest gate
available and it is already part of CI. If phase 4 slips, the same effect is available earlier by
adding `--strict-bool` to the flag list in `tools/test-selfhost.mjs` (`const flags`) — the sources
must be clean for stage 2 to build at all.

### 5.2 A lint target for the trees that are not self-hosted

`lib/`, `borg/`, `abundance/` and the examples are not compiled by the self-host test, so they need
their own check. Add `tools/strict-bool.mjs`:

```js
// tools/strict-bool.mjs: fail if a tree that is meant to be clean reports anything.
import { buildCompiler, command, compilerSources, root } from './native.mjs';
const result = command([buildCompiler(), '--default-u64', '--typed-refs', '--strict-bool-report',
  `${root}/.work/strict-bool.s`, ...compilerSources, /* the tree's own entry and modules */]);
const report = result.stdout.toString().trim();   // command() returns Buffers
if (report !== '') { console.error(report); process.exit(1); }
```

Wire it into `justfile` as `check-bool` and into `tools/ci.mjs lint` next to the existing static
checks, so `just test-tooling` runs it.

### 5.3 The predicate lint (the one phase 1 actually needs)

The self-host gate cannot see the predicate problem: a `u64` helper returning a comparison is only an
error once phase 0's `strict_return` exists. If phase 0 is deferred, keep
`tools/strict-bool-predicates.mjs` in CI instead and assert it finds nothing:

```sh
if bun tools/strict-bool-predicates.mjs --json | grep -q '"verdict": "predicate"'; then
  echo "strict-bool: a u64 helper is a predicate again" >&2
  exit 1
fi
```

That is the same information as `strict_return` without a compiler change, and it stops the list in
3.2 from growing back.

### 5.4 Fixtures

`compiler/tests/booleans.grl` already covers the accepted forms. Add rejecting fixtures to
`tests/native-cases.json` (`reject: true`) so the diagnostics cannot regress: an integer condition, a
`bool & integer`, and — after phase 0 — a `u64` function returning a comparison.
`tools/test-native.mjs` runs them for every selected target.

## 6. How it landed

Branch `strictbool-full` off `main` at 33f37af (phase 1 was already merged as `strictbool-preds`).
Every number below is `--strict-bool-report` over the ten compiler sources with
`--default-u64 --typed-refs`, measured at the commit named.

| step | commit subject | reports |
|---|---|---|
| start | phase 1 merged | 1595 (847 condition, 424 mixing, 324 arithmetic) |
| phase 1.5 | predicates the extractor could not see | 1409 (741 / 361 / 307) |
| phase 2 | operators | 405 (0 mixing, 0 arithmetic) |
| phase 3 | conditions | 0 |
| phase 4 | enforced by default | 0 |

**Phase 1.5.** The extractor was the real gap, not the code: it split a body on `+` and on
`&&`/`||` only, so a predicate written `(47 < d) & (d < 58)` or one returning its own recursive
call was invisible. Splitting on `&`/`|`/`^` and treating a self-call as bool turned 2 predicates
into 20 — the four this note predicted (`task_walk`, `punct`, `letter`, `digit`) plus
`tls_bridge`, `contains_borrow`/`borrow_walk`, `is_hex_digit`, `contains_task`, `is_default_i64`,
`chained_field_assignment_ahead`, `assignment_ahead` and the two below. `is_f32` and
`is_comparison` flipped once their integer callers were rewritten as section 3.3 predicted: the
callback return code is built by an `if` (`fret = 1`, then `fret = 2`) and the comparison operand
width by `mut p = 0` set to 3, and `ffi_float_store`'s `single` parameter became `bool`.
`bun tools/strict-bool-predicates.mjs` now reports 0 predicate, 6 status, 3 void.

**Phase 2.** 668 operator sites. The mechanical shapes (a top-level `+` or `&` chain of comparisons,
`(cmp) == 0`) were rewritten by a throwaway script driven by the report and validated by
precedence — `+` binds tighter than `==` in Grail, so only chains whose operands are all
comparisons qualify. The rest were decided from the operand declarations: an integer flag used as
logic reads `flag != 0`, a bool local compared with 0 reads `!flag`, and a 0/1 sum handed to a u64
parameter keeps its value as `u64(a || b)`. Locals that only ever held a disjunction became `bool`
(`carrier`, `empty`, `complete`, `checked`, `x86`, `closes`, `nested`, `ok`, `when`).

**Phase 3.** 405 conditions became explicit comparisons; `while 1` became `while true`. This is the
phase where the compiler reads differently, so it was reviewed as code rather than swept: the
common shapes are `if x.len() != 0`, `if flag != 0`, and `if ((writes(&o, k) >> 1) & 1) != 0`.
The one idiom the sweep could not express was a condition that summed two comparisons
(`if exclusive + mode`), which is now `if (exclusive + mode) != 0`.

**Phase 4.** `C.strict_bool` became `C.strict_bool_report` (0 = enforce, 1 = survey),
`strict_fix_record` and the `--strict-bool` / `--strict-bool-fix` flags were deleted, and
`strict_bool_check`/`strict_condition` were collapsed to their enforced form. The sources needed no
seed refresh at the time of writing: the pre-strict-bool seeds still compile them, and
`bun tools/bootstrap.mjs update all` is the follow-up that bakes the current compiler into the seed.

The corpus needed 13 small edits to follow the rule: `if flag` -> `if flag != 0` in
`compiler/tests/{generic_functions,cleanup,higher_order,structural_union}.grl`,
`compiler/examples/native_numbers.grl`, `book/examples/{cleanup,enums}.grl` (where the parameter
became `bool`, since both call sites already pass `true`), `examples/loops/cleanup.grl` and two
inline cases in `tests/native-cases.json`; `(a > b) == 0` -> `!(a > b)` in the `comparison-operators`
case and `async_io.grl`; the local `some` and `is_none` helpers return `bool`; `booleans.grl`
counted comparisons with `(1 == 1) + (2 == 2)`, which is now `u64(1 == 1) + u64(2 == 2)`; and the
three cleanup rejection cases spelled `if 1` / `while 1` as `if true` / `while true` so they keep
rejecting for the reason they are named after instead of for a bool condition.

Verification at the end of the branch: `bun tools/test-selfhost.mjs` (stage 2 and stage 3
byte-identical), `bun tools/test-native.mjs x86_64` (755 cases), `bun tools/book.mjs check`
(49 examples + 49 Rust comparisons), `bun tools/test-cli.mjs` (187 checks, cross-target section
skipped: no qemu on the host), `bun tools/abundance-test.mjs` and `bun tools/borg-test.mjs`.

**Still open.** Three things section 5 asked for and this branch did not do:

- `strict_return` (phase 0) is not implemented: a `u64` function returning a comparison still
  compiles. `tools/strict-bool-predicates.mjs` is the stand-in, and it now reports nothing for the
  compiler's sources; wiring it into `tools/ci.mjs lint` is the cheap gate.
- `x == false` is still legal. It is rarer than the note expected — the corpus had one
  (`some(...) == false`, migrated by hand) — but the rule remains unstated.
- `tools/strict-bool.mjs` (§5.2) does not exist, so `lib/`, `abundance/` and `borg/` are only
  covered by the checker when their own test suites compile them. All three are clean today.
