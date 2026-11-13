# Diagnostics

A rejected program gets errors in the shape rustc uses: the message, an `-->` location, a numbered
excerpt with the offending code underlined, secondary labels on the other lines that explain it, and
`help:` lines.

```
error[E0005]: assignment requires mut
 --> three.grl:3:5
  |
2 |     x := 1;
  |     - `x` is declared here, without `mut`
3 |     x = 2;
  |     ^
  |
  = help: declare it mutable: `mut x = ...`
```

## Several errors per compile

An error in a function body does not end the compile. The compiler reports it, then checks the rest
of the program with that body skipped - its signature still stands for its callers - and reports the
next one, up to 20, ending with `error: aborting due to N previous errors`. The program is rejected
and nothing is written (`tests/native-cases.json`, `errors-several-per-compile`).

An error outside any body - in a declaration or a signature - ends the compile at that error: what
follows would mostly be its consequences (`errors-declaration-stops`).

Each distinct diagnostic - its file, line, column and message - is printed once and counted once. A
generic template's body is replayed for its validation and again for every specialisation, so one
compile can reach the same source line several times; only the first reach is reported, and the
count in the summary is the number of distinct errors, not of replayed bodies. A body an earlier run
reported an error in is skipped whether it is checked directly or replayed, so the next run moves on
to the next error instead of spending the 20-error budget on the same one (`diag-dedupe-*`).

## Source the scanner cannot read

A malformed literal is an error like any other, not a crash: `'ab'`, a character literal that never
closes, an unterminated string, and a raw control byte inside a string are all reported with the
usual excerpt (`diagx-char-literal-too-long`, `diagx-string-raw-control-byte`). The scanner
(`compiler/lexer.grl`) has no diagnostic channel, so it hands the front end a token for what it could
not finish and the front end renders it. Nothing in the scanner asserts on source text: an assert on
input is a compiler bug, not a refusal, and it prints a compiler source line where a refusal belongs.

## Error codes

The diagnostics a program most often hits carry a code, and `grail explain CODE` prints what the
error means, a small example, and the usual fix:

```
$ grail explain E0006
E0006: use of a moved value
...
```

| Code | Error |
| --- | --- |
| E0001 | undefined name |
| E0002 | unknown function |
| E0003 | unknown type |
| E0004 | type mismatch |
| E0005 | mutation requires `mut` |
| E0006 | use of a moved value |
| E0007 | move of an unavailable value |
| E0008 | borrow conflict |
| E0009 | mutation through a read-only reference |
| E0010 | a reference outlives its lifetime |
| E0011 | non-exhaustive match |
| E0012 | type is not `Send` |
| E0013 | type is not `Share` |
| E0014 | type does not satisfy an interface bound |
| E0015 | literal out of range |
| E0016 | drop of a moved value |
| E0017 | private item |
| E0018 | wrong number of arguments |
| E0019 | `@assert` failed |
| E0020 | requires an `unsafe` block |

The table and the explanations live in `compiler/explain.grl`, compiled into the `grail` binary.
A diagnostic without a code is rarer, and its message says everything there is to say.
