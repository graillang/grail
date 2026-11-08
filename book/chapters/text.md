# Working with text

Text values (`string`, `u8[]` and string literals) compare by content with `==` and `<`, join with
`+`, and answer methods for everyday work: `trim`, `split`, `contains`, `starts_with`, `ends_with`,
`replace`, `to_upper`, `to_lower`, `is_empty` and `chars`. Prefer the methods; the `strings` module
keeps only the helpers that are not methods, such as `find`, `parse_num`, `join_with`,
`char_count` and `push_char`.

{{example:text-methods}}

Methods that change text return a new value and leave the original alone. `split('=')` returns a
vector of borrowed byte views, so `fields[1]` is the text after the `=`. `part[:1]` is a view of the
first byte.

In the approved model a loop consumes its iterable; `for part in &parts` reads each part
instead. Direct temporary iteration (`for part in name.split(' ')`) is the approved consume form, but
this preview compiler does not accept it yet, so the example keeps the explicit `parts` binding.

**Try it:** print `clean.len()` and `line.len()` to see what `trim` removed.
