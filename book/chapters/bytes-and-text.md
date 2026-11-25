# Bytes and text

`u8[]` creates an empty owned growable byte sequence; `u8[10, 20, 30]` initializes one directly,
and `u8[0; n]` makes `n` copies of one byte (a value above 255 stops the program).
`data.push(byte)` appends a byte, `data.pop()` takes the last byte off as an option (`data.pop()!` when there must be one), and `data.len()` reports its
length. Read an individual byte with `data[index]`.

{{example:bytes}}

`&data` is a readonly byte view and `&mut data` is an exclusive one. A quoted literal is already an
owned UTF-8 `string`; no `.text()` call is needed. A `string` is read-only text: `mut s = "x"` makes
the binding reassignable (`s = "y"`), not the bytes writable (`s[0] = 65` is refused, as in Rust's
`let mut s = "x"`). Copy it to edit bytes — `mut b: u8[] = s.copy()` — and write through the vector. `.text()` converts borrowed bytes into owned text.
Text length is measured in **bytes**, not Unicode characters or grapheme clusters.
`greeting.append(text)` appends validated text; arbitrary byte sequences and text are deliberately
different concepts.

{{example:text}}

`.append(...)` mutates owned storage, so `greeting` is declared with `mut`.
`print` writes exactly the supplied byte buffer; `println` adds a newline. Both borrow their input
for the call, so `greeting` remains usable afterward.

A function that only reads bytes or text takes a `&[u8]` view. An owned `string` or `u8[]` argument
is adjusted to that parameter automatically, and a literal can also be passed as `&"text"`:

```grl
fn length(label: &[u8]) -> u64 {
    label.len()
}
println(length("hello")); // owned string adjusted to the view
println(length(&"hello")); // explicit view
```

A function that changes bytes takes `&mut [u8]`, and its caller writes `&mut data`.

## Working with text

Text values (`string`, `u8[]` and string literals) compare by content with `==` and `<`, join with
`+`, and answer methods for everyday work: `contains`, `starts_with`, `ends_with`, `replace`,
`to_upper`, `to_lower`, `is_empty` and `chars`. The rest are `strings` methods on the same text (`use
strings;`): `trim`, `trim_start`, `trim_end`, `split`, `split_owned`, `lines`, `split_whitespace`,
`find`, `parse_u64`, `parse_i64`, `parse_f64`, `is_utf8`, `utf8_error`, `char_count`,
`is_char_boundary`, `slice_chars`, `char_indices`, `to_text_lossy`, with `chunks`, `windows` and
`push_char` on a byte vector and `join_with` on a vector of parts. A byte vector, a `string` and a
view are all byte text, so `bytes.find(x)`, `text.find(x)` and `view(bytes).find(x)` are one method.

{{example:text-methods}}

Methods that change text return a new value and leave the original alone. The ones that cut it -
`trim`, `split`, `lines`, `split_whitespace` - copy nothing: they return views of the text (Rust's
`&str` pieces), so `fields[1]` is the bytes after the `=` where they already are. The text has to
outlive the views and cannot change while one is live; `split_owned` (or `piece.copy()`) is the
copying form for a piece that must outlive it. `part[..1]` is a view of the first byte.

A loop over the pieces borrows them, whether it is `for part in name.split(' ')` or a loop over a
bound `&parts`. `parse_f64` reads a decimal number correctly rounded, as Rust's and Go's parsers do,
and `out.append_format("{}:{};", a, b)` writes `format`'s text onto the end of `out` without making a
string of its own (Rust's `write!`).

A placeholder may name what it prints: `format("x is {x}")` and `println("{p.name} at {p.x}")` read
the binding or field path in scope, and `{}` still takes the next argument. A lone `println` literal
whose braces name nothing in scope prints as written; `{{` and `}}` are braces everywhere.

**Try it:** print `clean.len()` and `line.len()` to see what `trim` removed.

Also try a non-ASCII greeting and compare its byte length with the number of visible letters.

## UTF-8

Text is bytes, so "one character" and "one byte" are different questions. The `strings` methods
answer them with Rust's `str` API: `text.is_utf8()` validates strictly (an overlong form, a
surrogate, a value above U+10FFFF and a truncated sequence are all rejected), `text.utf8_error()`
returns the offset of the first ill-formed sequence (`u64?`), and `text.char_count()` counts
characters rather than bytes.

`text.chars()` is a lazy iterator of `char` values and `text.char_indices()` of
`(u64, char)` pairs, the number being the byte offset each character starts at. Both are
`iter::Iter` values, so they chain with `map`, `filter`, `count` and `collect` like any other
iterator: `text.chars().collect()` is the `char[]` when a vector is more convenient.
`text.is_char_boundary(i)` answers whether an offset starts a character, and
`text.slice_chars(lo, hi)` cuts at two of them: an offset that is not a boundary stops the
program with a runtime error naming the call site, rather than handing back half a character.
`out.push_char(c)` goes the other way, appending a `char`'s one
to four bytes; `bytes.chunks(n)` and `bytes.windows(n)` are the runs and the sliding windows of a byte
vector.

Invalid input never stops a decode: it yields one U+FFFD for each **maximal subpart**, the longest
prefix of a well-formed sequence plus the byte that broke it, which is Unicode's recommended
practice and exactly what Rust's `from_utf8_lossy` produces. `E2 82 41` is therefore one replacement
character for `E2 82` followed by `A`, not three.

{{example:utf8}}

The Grail and Rust versions answer the same questions with the same numbers; two differences are
Grail's. `text.chars()` copies the bytes it walks, because an `iter::Iter<T>` carries no lifetime
and so cannot hold a borrow of the argument - Rust's `chars()` borrows the `str` and allocates
nothing. And a decoded code point is a `char` all the way through, where Rust casts to `u32` to print
it.

**Try it:** add a five-byte sequence such as `F8 88 80 80 80` to `bad` and watch the replacement
count grow by one per byte, then feed the result of `push_char` back into `is_utf8`.

## Why a validated string type beside the bytes

A `string` is text the language checks at its own boundaries, and a `&[u8]` is bytes: a slice of a
file, a socket's buffer, a piece of a packet. Handing those bytes to a function that wants text means
deciding when to check them - too early and a caller pays for a validation it already did, too late
and the check is missing somewhere, and "we always validate here" is a comment rather than a rule.

`utf8::Utf8String` makes the decision part of a type. It can only be built by a constructor that
validates (`from_bytes`), from text the language already validated (`from_text`), or through an
`unsafe fn from_unchecked` that a caller must open an `unsafe` block for. Its operations keep the
invariant by construction - a concatenation of valid text is valid, a slice at character boundaries is
valid, and a replacement of valid text by valid text cannot break a sequence, because a valid sequence
never appears at a non-boundary offset of valid text - so a function that takes one never has to
validate again, and a function that returns one proves it did.

The cost is a copy at the boundary and one rule to remember: bytes are the interface, and a validated
value is what crosses into code that must not re-check. The byte-slice API stays for everything that
does not need the promise, including `&[u8]` views of a `Utf8String`'s own storage.
