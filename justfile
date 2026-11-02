set positional-arguments

# Build Grail by Example and open it in your default browser.
book:
    bun tools/book.mjs open

# Build the offline HTML book without opening a browser.
book-build:
    bun tools/book.mjs build

# Compile/run every book example and check intentional compiler rejections.
book-check:
    bun tools/book.mjs check

# Run one example; optional arguments are forwarded literally.
book-run example *args:
    bun tools/book.mjs run "$@"

# Test the book renderer, manifest and browser-opener integration.
book-test:
    bun test tools/book.test.mjs

# Verify Grail examples without compiling the optional Rust comparisons.
book-check-grail:
    bun tools/book.mjs check --grail-only
