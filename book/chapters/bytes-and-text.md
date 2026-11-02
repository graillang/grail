# Byte buffers and text

`bytes()` creates an owned growable byte sequence. `push` appends one byte; `len` reports its
length. Read individual bytes through a view with `at`.

{{example:bytes}}

A quoted literal is an owned UTF-8 `string`. Text length is measured in **bytes**, not Unicode
characters or grapheme clusters. `append_text` appends validated text; arbitrary byte sequences
and text are deliberately different concepts.

{{example:text}}

`append_text` mutates owned storage, so `greeting` is declared with `var`.
`print` writes exactly the supplied bytes; `println` adds a newline. Both borrow their input
for the call, so `greeting` remains usable afterward.

**Try it:** use a non-ASCII greeting and compare its byte length with the number of visible letters.
