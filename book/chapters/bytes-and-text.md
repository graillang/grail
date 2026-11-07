# Byte buffers and text

`u8[]` creates an empty owned growable byte sequence; `u8[10, 20, 30]` initializes one
directly. `data.push(byte)` appends a byte, `data.pop()` removes the last byte, and `data.len()`
reports its length. Read an individual byte with `data[index]`.

{{example:bytes}}

A quoted literal is an owned UTF-8 `string`. Text length is measured in **bytes**, not Unicode
characters or grapheme clusters. `greeting.append(text)` appends validated text; arbitrary byte sequences
and text are deliberately different concepts.

{{example:text}}

`.append(...)` mutates owned storage, so `greeting` is declared with `mut`.
`print` writes exactly the supplied byte buffer; `println` adds a newline. Both borrow their input
for the call, so `greeting` remains usable afterward.

**Try it:** use a non-ASCII greeting and compare its byte length with the number of visible letters.
