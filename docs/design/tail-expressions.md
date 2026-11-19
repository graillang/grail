# Tail expressions (implicit returns)

2026-11-19. The last item of a block, written without `;`, is the block's value - Rust's rule:

```grl
fn f(a: u64) -> u64 { a }
fn sign(n: i64) -> i64 { if n < 0 { -1 } else if n == 0 { 0 } else { 1 } }
g := |x: u64| { y := x * 2; y + 1 };
v := if c { t := load(); t + 1 } else { 0 };
area := { w := 3; w * w };
```

`return` stays valid everywhere, as the early exit and as a last statement.

## Telling a tail from a statement

Grail statements end in `;`, and a construct (`if`, `match`, a loop, `{ }`, `unsafe { }`) ends at
its last `}`. So the items of a block can be told apart by tokens before any of them is compiled
(`item_end` in `compiler/native.grl`): an item runs to its `;` at the block's own depth, or to the
end of the construct it starts. The **tail** is the last item when it has no `;`. `block()` asks
that of each item (`block_item`) and compiles every other item as the statement it always was.

A last item that is a statement - it starts with a statement word (`while`, `let`, `mut`,
`return`, ...), binds (`:=`), or assigns (`=`, `+=`, ...) at its own depth - is not a tail: it is
compiled as a statement and still needs its `;` (`x := 1 }` is *expected `;`, found `}`*).

## What a tail does: the block's mode

How a block ends is set by what opened it (`tail_mode`, taken by `block()` on entry so that every
nested block starts as a statement block unless its construct hands the mode on):

- **A function or closure body (mode 1).** The tail is returned: `return_exit`, the code of
  `return x;`, with the expression ending at the `}` instead of a `;`. The two spellings are one
  program - same checks, same ownership (the value moves out, the body's locals drop, references are
  checked against the signature's lifetimes), same code. `tools/test-cli.mjs` holds the formatter
  to that: the compiler, formatted (which rewrites thousands of final returns), compiles to the same
  assembly. A unit body's tail goes the same way, and a non-unit value there is refused: *this body
  returns `unit`, but it ends in a `u64` value*, help *end it with `;` to discard the value, or
  declare the result: `-> u64`*.
- **A value block (mode 2)**: an arm of an `if` or `match` expression, a block expression `{ }`,
  `unsafe { stmts; v }`. The tail is stored by the block's *sink* into the frame word the value is
  joined in (`sink_store`): the `if` expression's shared word (checked against the other arm), the
  `match` expression's (checked against the arm that fixed the type), or the block expression's own.
  The store moves the value out before the block's `}` drops its locals, and the word is owned once
  afterwards - the lowering `docs/design/if-expression.md` describes, unchanged. A value block that
  ends in a statement has no value, which only a block that always leaves (`return`, `break`) may do.
- **Any other block (mode 0)** - a loop body, a statement `if`'s arm, a nested `{ }` statement. Its
  value is not taken, so a tail must be unit (`while i < n { step(i) }`); a value is refused: *this
  block ends in a `u64` value, and a statement block has none*, help *end it with `;`*.

A final **construct** passes its block's mode to its own blocks. In a body, a final `if` (and its
`else if` chain, and `if let`), `match`, `{ }` or `unsafe { }` returns from each arm, and a
`match` arm that is one expression (`P => x,`) is returned too. This is a statement with returning
arms, not an `if` expression followed by a return, so nothing about the expression form's limits
applies: an arm's value may borrow (`fn f<a>(p: &a P, q: &a P, c: bool) -> &a u64 { if c { &p.x }
else { &q.y } }`) and `if let` works. Without an `else` there is no value when the condition is
false, and in a function that returns one this is refused at the `if`: *this `if` ends a function
that returns a value, so it needs an `else`*. In a value block, a final construct that has a value
(`construct_has_value`: one of its blocks ends in one, or a `match` arm is an expression) is that
value's expression; one without is a statement.

## Diagnostics for a missing value

A body that can reach its `}` without a value says the type it owes: *function may fall through
without a value: it returns `u64`*, help *end the body with its value (an expression without `;`),
or `return` one*. When its last statement is an expression of that type ended by `;`, the caret is
on the `;` and the help says to remove it.

## Closures

A closure's block body is a body (mode 1). With no `->` and no expected type, a block that ends in a
value has that value's type: the block is compiled once in isolation as a block expression
(`closure_body_type`, as an expression body already was). A block that also `return`s a value early
still asks for the result type.

## Formatter

`grail fmt` (`tail_returns` in `compiler/fmt.grl`) writes a function's or closure's final
`return x;` as `x`. It leaves early returns, a bare `return;` and `return ();` (a unit body simply
ends; deleting them would also change the generated code), and a returned `if`/`match`/`unsafe`/block,
whose tail form returns from each arm - the same result, compiled differently. A brace that holds a
`;` of its own is laid out as a block wherever it is written, so a value block with statements gets
a line per statement.

## Limits kept

A value `if`/`match` (not at a body's end) or a block expression still cannot produce a borrowed
value: one word cannot name two arms' loans (`docs/design/if-expression.md`). `return`, `break` and
`continue` are statements and keep their `;`. A loop is never a value.

Corpus: the `tail-*` cases in `tests/native-cases.json`.
