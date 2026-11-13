# Expression match arms

2026-11-13. An ergonomics increment to `match`, not a change to what `match` is: it remains a
statement that selects one arm, and it still produces no value.

An arm body used to be a block, always:

```grl
match n {
    0 => { println("zero"); },
    _ => { println("many"); },
}
```

...which costs braces and a semicolon for the one-expression arm that is the common case. An arm
body may now also be a single expression, ending at `,` or at the match's `}`:

```grl
match n {
    0 => println("zero"),
    1 => println("one"),
    _ => println("many"),
}
```

The two spellings compile to the same code. The expression's temporaries are released at the end of
the arm exactly as the `expr;` statement inside `Pat => { expr }` releases them, and an owned value
the expression produces (a constructor call, a call returning an owned record) is dropped there.
The arm loop, the guard, the payload binding and the per-arm ownership merge are the same code for
both forms; an expression arm adds one expression statement to the arm.

## Trailing comma

The arm list's rule is unchanged and now uniform: every arm may end with `,`, and the last arm
before `}` may omit it. An expression arm must therefore be followed by `,` or `}`; anything else
is a precise error ("expected `,` or `}` after this match arm") instead of a confusing one from a
later production.

## What is refused, by name

- A statement body needs braces. `Pat => if c { ... }` (and `while`, `for`, `loop`, `match`,
  `let`, `return`, `break`, `continue`, `mut`, `unsafe`, `drop`, `write`, `assert`) is refused with
  "this arm body is a statement, so it needs braces: write `Pat => { if ... }`". The block is the
  only form that can hold statements, so accepting the bare keyword would either build an
  expression that does not exist or silently swallow the following arm.
- One expression is not a statement list. `Pat => println("x");` reports "an expression arm ends
  at `,` or `}`", and `Pat => x = 1` / `Pat => x += 1` report "an arm body is one expression, not a
  statement: write `Pat => { x = 1; }`". Assignments stay statements.

## A struct literal needs no parentheses here

`_ => P { x: 1, y: 2 }` is accepted with the braces exactly as written. Rust's "wrap it in
parentheses" rule exists for the *header* positions - `if`/`while`/`for`/`match` conditions - where
a `{` could begin the body, so a struct literal there is ambiguous. An arm body begins after `=>`,
where no block can start (a block starts with `{`, and a path followed by `{` is a struct literal
in expression position, as in a binding initializer). Requiring parentheses would add a rule that
never disambiguates anything, so Grail does not.

A `{` immediately after `=>` is still a block, and a block is a statement list: `_ => { P { x: 1,
y: 2 } }` needs the semicolon its expression statement requires (`{ P { x: 1, y: 2 }; }`), while
`_ => P { x: 1, y: 2 }` is the compact form of the same arm.

## Formatter

`compiler/fmt.grl` is token-based layout, so the new form needed no formatter change and
round-trips (`tests/fmt/messy.grl` already contained a one-expression arm). Verified with
`grail fmt` and `grail fmt --check` on expression arms, nested matches and a struct-literal arm.

Corpus: `ergo-match-expr-arm-scalar`, `-last-comma-omitted`, `-enum-payload`, `-nested`,
`-struct-literal`, `-drops-value`, and the rejections `-reject-keyword`, `-reject-semicolon`,
`-reject-missing-comma`.

## `match` in expression position

The same increment's other half: `match` also produces a value where one is required.

```grl
n := match flag { 0 => 1, 1 => 2, _ => 3 };
label := match e { A(v) => v + 1, B => 0 };
```

It is the statement `match`, unchanged - the scrutinee, the patterns, the per-arm ownership
snapshots, the failed-match `rt_abort` and the exhausted-match check are all the same code
(`match_statement`) - with one flag set (`c.arm_value`): an arm body writes its value into one frame
word instead of discarding it. That word is owned once, after the arms join (`own` in
`match_value`), so exactly one value exists however many arms wrote it, and each arm's cleanup runs
on a temporary that was moved out. `if` in expression position is lowered the same way
(`docs/design/if-expression.md`), and an `if` expression is an ordinary arm body: `0 => if c { 1 }
else { 2 },`.

Rules, refused by name:

- Every arm that reaches the join produces a value. A block arm has none, so it is refused at the
  arm (`this arm of an expression `match` is a block of statements, so it has no value`, with the
  help to write one expression or diverge) - unless it diverges, which needs no value: `_ => {
  return 9; }` is a fine arm and the other arms decide the type.
- The arms agree in type; the first arm that produces a value fixes it, and a later arm's mismatch
  is reported at that arm with the primary line naming both (`the other arm is `u64`, this one is
  `bool``) and a label at the arm that fixed it.
- A value that borrows is refused, for the same reason `if` refuses one: the result is one word and
  a place has one loan, so `r := match n { 0 => &a, _ => &b }` cannot be represented. The refusal
  says to use the reference inside each arm.
- No arm producing a value is not an expression: `x := match n { 0 => { return (); }, _ => { return
  (); } };` is refused by name.

`x := match ...` takes the type the binding declares, and a literal or `None` arm adopts it
(`o: u64? := match n { 0 => Some(1), _ => None };`), exactly as the `if` form does. Corpus:
`exprif-match-scalar`, `-enum-optional`, `-record`, `-nested-if`, `-diverging-arm`, `-drops-value`,
and the rejections `-type-mismatch`, `-statement-arm`, `-borrows`, `-no-value`.
