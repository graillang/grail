# Bytes and text

`u8[]` creates an empty owned growable byte sequence; `u8[10, 20, 30]` initializes one directly,
and `u8[0; n]` makes `n` copies of one byte (a value above 255 stops the program).
`data.push(byte)` appends a byte, `data.pop()` removes the last byte, and `data.len()` reports its
length. Read an individual byte with `data[index]`.

{{example:bytes}}

`&data` is a readonly byte view and `&mut data` is an exclusive one. A quoted literal is already an
owned UTF-8 `string`; no `.text()` call is needed. `.text()` converts borrowed bytes into owned text.
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
    return label.len();
}
println(length("hello"));  // owned string adjusted to the view
println(length(&"hello")); // explicit view
```

A function that changes bytes takes `&mut [u8]`, and its caller writes `&mut data`.

## Working with text

Text values (`string`, `u8[]` and string literals) compare by content with `==` and `<`, join with
`+`, and answer methods for everyday work: `trim`, `split`, `contains`, `starts_with`, `ends_with`,
`replace`, `to_upper`, `to_lower`, `is_empty` and `chars`. Prefer the methods; the `strings` module
keeps only the helpers that are not methods, such as `find`, `parse_num`, `join_with`,
`char_count` and `push_char`.

{{example:text-methods}}

Methods that change text return a new value and leave the original alone. `split('=')` returns a
vector of borrowed byte views, so `fields[1]` is the text after the `=`. `part[:1]` is a view of the
first byte.

A loop over views borrows them: bind the result first (`parts := name.split(' ')`) and loop over
`&parts`.

**Try it:** print `clean.len()` and `line.len()` to see what `trim` removed.

Also try a non-ASCII greeting and compare its byte length with the number of visible letters.
