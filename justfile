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

# Build the sole Grail-written compiler from its assembly bootstrap.
build:
    bun tools/native.mjs build

# Cross-build the Windows x86-64 PE/COFF target and inspect objects and images.
windows-check:
    bun tools/windows.mjs check

# Run preserved language safety/execution regressions on a selected CPU.
test *args:
    bun tools/test-native.mjs "$@"

# Self-hosting fixpoint: the compiler compiles itself twice with identical output.
test-selfhost:
    bun tools/test-selfhost.mjs

# Run the Abundance CPU-port parity tests (math, compared bit-for-bit with Abundance's own C++).
abundance-test:
    bun tools/abundance-test.mjs

# FFI: extern "C" declarations/calls against a freestanding C shim, all targets.
test-ffi:
    bun tools/test-ffi.mjs

# Run the Borg Agent CPU-port suites: JSON, TOML, protocol, ownership, framing, supervision,
# transport, journal, transcript events and permission gates against their references.
borg-test:
    bun tools/borg-test.mjs

# Persist/reload session state through the C OS ABI (needs cc + clang; links the FFI backend).
borg-store-test:
    bun tools/borg-store-test.mjs

# Check Mach-O objects and executables for macos-x86_64 and macos-aarch64 without executing them.
test-macos:
    bun tools/test-macos.mjs

# Print a Mach-O image's dylib dependencies and validate its ad-hoc signature.
macos-inspect bin:
    bun tools/macos.mjs inspect "{{bin}}"

# Verify direct compiler self-hosting on all supported CPUs (QEMU needed for cross execution).
bootstrap-check:
    bun tools/bootstrap.mjs verify all

# Install the `grail` tool: PREFIX/bin/grail plus runtime and standard library in PREFIX/lib/grail.
install prefix="~/.local":
    #!/usr/bin/env sh
    set -eu
    prefix=$(eval echo "{{prefix}}")
    grail=$(bun tools/native.mjs build)
    mkdir -p "$prefix/bin" "$prefix/lib/grail/std"
    cp "$grail" "$prefix/bin/grail.new" && mv "$prefix/bin/grail.new" "$prefix/bin/grail"
    cp compiler/runtime.grl "$prefix/lib/grail/runtime.grl"
    cp compiler/os-linux.grl "$prefix/lib/grail/os-linux.grl"
    cp compiler/darwin.grl "$prefix/lib/grail/darwin.grl"
    cp lib/*.grl "$prefix/lib/grail/std/"
    echo "installed $prefix/bin/grail (needs clang and ld.lld for building programs)"

# Formatter and grail tool regressions (also checks ARM64/RV64 under qemu).
test-cli:
    bun tools/test-cli.mjs

# Print the cross-platform support matrix and lane status.
platforms:
    bun tools/ci.mjs matrix

# Print the full CI lane/artifact plan as JSON.
ci-plan:
    bun tools/ci.mjs plan

# Run tooling unit/static checks; no compiler or QEMU needed.
test-tooling:
    bun test tools/platforms.test.mjs tools/archive.test.mjs tools/sign.test.mjs tools/objects.test.mjs
    bun tools/ci.mjs lint

# Build the compiler for a platform (e.g. just build-platform linux-x86_64).
build-platform platform:
    bun tools/ci.mjs build --platform {{platform}}

# Build, test and package a platform into dist/.
package platform:
    bun tools/ci.mjs package --platform {{platform}}

# Build every locally buildable release target from the checked-in seed, then assemble and verify.
release-dry-run:
    bun tools/release.mjs dry-run --out dist/release

# Build one target's release assets and metadata into dist/release/PLATFORM.
release-build platform:
    bun tools/release.mjs build --platform {{platform}} --out dist/release/{{platform}}

# Merge built targets into dist/release/upload with SHA256SUMS, release.json and RELEASE-README.md.
release-assemble:
    bun tools/release.mjs assemble --dir dist/release --out dist/release/upload
    bun tools/release.mjs verify --dir dist/release/upload

# Validate a release tag against VERSION (usage: just release-version v0.1.0).
release-version tag:
    bun tools/release.mjs version --tag {{tag}}

# Print signing/notarization commands; add --execute after setting credentials.
sign platform artifact:
    bun tools/ci.mjs sign --platform {{platform}} --artifact {{artifact}}

# Cross-platform OS ABI headers and C contract tests (needs a host C compiler).
abi-test:
    bun tools/abi-test.mjs

# Native Linux FFI wrapper test; needs a compiler built from this tree.
ffi-runtime-test:
    bun tools/test-ffi-runtime.mjs


# Executed Windows ABI evidence under Wine (needs zig, wine, clang).
abi-wine-test:
    bun tools/test-abi-wine.mjs



# Build a non-executable COFF/Mach-O object bundle (windows-x86_64 or macos-*).
objects platform:
    bun tools/ci.mjs objects --platform {{platform}}

# macOS Mach-O object and executable static checks (nothing is executed).
macos-check:
    bun tools/test-macos.mjs

# Verify DWARF .debug_line/.debug_info and `grail debug lines|info` (requires a compiler).
debug-lines-test:
    bun tools/test-debug-lines.mjs

# Run the Grail LSP MVP on stdio (requires GRAIL_LSP_COMPILER or GRAIL_COMPILER).
lsp:
    bun tools/lsp.mjs

# LSP protocol and compiler-diagnostic tests over a real stdio session.
lsp-test:
    bun test tools/lsp.test.mjs
