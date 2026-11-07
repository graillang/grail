# Working with text

Text values (`string`, `u8[]` and string literals) compare by content with `==` and `<`, join with
`+`, and have methods for everyday work: `trim`, `split`, `contains`, `starts_with`, `replace`,
`to_upper` and more.

{{example:text-methods}}

Methods that change text return a new value and leave the original alone. `split('=')` returns a
vector of strings, so `fields[1]` is the text after the `=`. `part[:1]` is a view of the first byte.
Iterating `borrow(parts)` visits each part without taking it out of the vector.

**Try it:** print `clean.len()` and `line.len()` to see what `trim` removed.
