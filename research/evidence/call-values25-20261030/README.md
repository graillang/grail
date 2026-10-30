# Left-to-right argument values

Before: at c90d6f5 the new source regression fails (`before.txt`): `take(b,len(b))` accepted
an owner use after its argument should already have moved. This is a language evaluation/affinity
bug, not a demonstrated memory corruption exploit. The same check now rejects Bytes, Text and
read/write views; numeric values, precomputed lengths and explicit readonly reborrows pass.

Every user-call argument now lowers to an immediate value copy/move. Builtin place/borrowing rules
are unchanged. Public checked IR already represents value operands; ABI/schema/runtime unchanged.
`tests.txt` includes the full 28 checker/source tests plus three native tests, including hidden-source
owned-string/byte providers and C/LLVM control flow. LSP, format, Clippy and release build pass.
General mutable-reference effects and field/index expression evaluation remain unimplemented gates;
these primitive tests are not evidence for their future correctness.
