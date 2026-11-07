# Working with text

Text values (`string`, `u8[]` and string literals) compare by content with `==` and `<`, join with
`+`, and have methods for everyday work: `trim`, `split`, `contains`, `starts_with`, `replace`,
`to_upper` and more.

{{example:text-methods}}

Methods that change text return a new value and leave the original alone. `split('=')` returns a
vector of borrowed byte views, so `fields[1]` is the text after the `=`. `part[:1]` is a view of the
first byte. A `for` loop over a collection borrows non-scalar elements, so iterating
`name.split(' ')` directly does not require a temporary `parts` binding.

**Try it:** print `clean.len()` and `line.len()` to see what `trim` removed.
