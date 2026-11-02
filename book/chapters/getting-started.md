# Your first program

Our first program prints one line. This is the complete source file—no import, module declaration,
visibility modifier, return annotation, or manual byte view is needed.

{{example:hello}}

`main` is the program's entry point. `println` borrows its argument for the call and adds a newline.
The omitted result type is `unit`, and reaching the closing brace returns normally with status 0.
There is no automatic numeric output.

## Run it

From the repository root:

```sh
just book-run hello
```

The runner assembles the checked-in native bootstrap, compiles the example and the Grail runtime,
then uses GNU `as` and `ld` to create a static executable. Artifacts stay under `.work/book/`.
No global compiler installation is changed. Run `just book-check` to verify every example.

A checked Rust version is shown alongside the Grail version by default. Its code and output
are aligned, with a short note below explaining what differs and what is shared. Use **Hide Rust**
to turn comparisons off across the book, or collapse just one example.
On small screens the comparison stacks vertically; you can collapse it at any time.

For raw compiler commands and self-compilation instructions, see `compiler/NATIVE.md`.
A `main` may explicitly return `num` to set the process exit status; it does not print that number.
Ordinary functions use explicit result types when returning values. A source file may also declare
an explicit `module`, as later examples do to make their names clear.

**Try it:** add a second `println` call, or use `print("Hello, "); println("world!");` to control
where the newline appears.
