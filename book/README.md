# Grail by Example

An offline, example-first introduction to the **implemented native language**: 20 chapters,
30 checked Grail programs, and 24 optional Rust comparisons. Rust is collapsed by default;
expanding it aligns code and output beside Grail on wide screens, with a comparison note below.
Narrow screens stack the two versions. Search, copy buttons, theme switching and keyboard
navigation work locally without a server or CDN.

## Read and run

From the repository root, with **Bun 1.4+** and **just** installed:

```sh
just book                  # Build and open your default browser.
just book-build            # Build without opening a browser.
just book-run hello        # Run the three-line hello world.
just book-run arguments 'two words'
just book-check            # Verify Grail programs AND Rust comparisons.
just book-check-grail      # Verify only Grail, without requiring Rust.
just book-test             # Test rendering, navigation and opener integration.
```

The HTML entry is `.work/book/html/index.html`. `just book` uses `xdg-open` on Linux, `open`
on macOS, and `start` on Windows. In a headless environment, build without opening and copy
that path to your browser, or set `GRAIL_BOOK_OPENER` to an opener executable (one path, no shell
arguments). An opener failure is reported rather than silently claiming a browser opened.

Building/reading needs no Grail toolchain. Running Grail examples requires **Linux x86-64** and
GNU **as/ld**. The runner assembles `compiler/bootstrap/native.s`; it needs neither Rust nor a
C compiler to run Grail. Checking Rust comparisons additionally needs **rustc with edition 2024**.
Those are independent programs compiled for validation, not a dependency of the Grail runtime.

## Contribute an example

- Chapters live in `chapters/`; `book.json` orders them and defines example expectations.
- `{{example:hello}}` includes the real source from `examples/hello.grl`, its expected output
  or rejection diagnostic, its run command, and its optional Rust counterpart from `rust/`.
- `{{source:examples/arithmetic.grl}}` embeds a supporting source file without an executable entry.
- Successful examples check exact stdout and optional output files. Compile-fail examples must
  fail with the expected diagnostic and leave a prior assembly artifact untouched. Rust
  comparisons also compile/run or check their intentional rejection diagnostics.
- File examples declare fixtures and expected files in the manifest. Execution happens in a fresh,
  per-example scratch directory under `.work/book/runs/`, never the project root.
- Edit the actual source, not a duplicate Markdown snippet. Run `just book-check` afterward.

The layout takes inspiration from [Go by Example](https://gobyexample.com/hello-world) and
[Rust by Example](https://doc.rust-lang.org/rust-by-example/hello.html): compact navigation,
readable code, adjacent outputs and short explanations. Comparisons should be accurate, not
marketing: identify shared strengths and current Grail limitations as well as differences.
