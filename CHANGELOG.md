# Changelog

## Unreleased

- `for item in items` consumes vectors of owned elements in default-u64 mode too, including
  temporary vectors. Each iteration owns its element; early exits clean up the remainder.
  Borrow with `&items` to preserve the vector. Previously this worked only outside default-u64 mode.

- A rejected program makes the compiler exit with status 1 instead of aborting (which dumped core).
- An `impl` whose method signature does not match its interface is reported at that method; the
  error used to point at the end of the last input file (often `os-linux.grl`).
- Abundance port cleanup: the cluster builder and `.abgeo` reader use the float methods, `wrapping_u32`/`wrapping_u8`,
  `vecs::insert_sorted` and `vecs::sort_by_key` instead of hand-written helpers, and `!x` instead of `x == false`; the
  `.abgeo` test builds its lines with `format` and parses with `strings::split`/`parse_num`. Output unchanged.
- `hash::Equal::equal` and `hash::equal` return `bool` (they returned `u64`). The standard library no longer
  mixes bools and integers (`||`/`&&` instead of `+`/`&` on comparisons, `>=` instead of `(a < b) == 0`).
- `tools/test-selfhost.mjs` (`just test-selfhost`, a CI job): the compiler compiles itself twice and the outputs must
  be identical.
- Closures can take reference parameters (`|a: &T, b: &T| -> bool ...`), each borrowed afresh per call;
  they were rejected ("closure parameters cannot hold borrows yet").
- Functions are values of closure type: any function whose signature matches (up to lifetime names)
  can be passed where an `Fn(...)` is expected, including ones taking references
  (`fn less<a, b>(x: (&a T), y: (&b T)) -> bool` as `Fn(&T, &T) -> bool`). Before, only closures could.
- `vecs::sort_by` (stable, comparator), `vecs::sort_by_key`, `vecs::insert_sorted` and
  `vecs::binary_search`; `order::Ord` for `f32`.
- Float methods `ceil`, `trunc`, `round`, `min`, `max`, `is_finite`, `is_infinite`, `next_up` and
  `next_down` on `f64` and `f32`, bit-identical to libm; `floor(-0.0)` now keeps the sign.
- Borrows made to pass arguments end once the value is computed (when it holds no borrow itself):
  `b.words[i] = f(&b)` and `M { flags: word(&bytes, 0), bytes: bytes }` compile, as in Rust. A value
  that does hold the borrow still keeps it alive.
- `==`/`!=` compare vectors and slices of numbers, bool and char by length and elements (floats by value:
  `-0.0 == 0.0`, NaN unequal); before, only record fields of vector type could be compared.
- Typed slices: `&[T]` and `&mut [T]` for every element type (`v[a: b]`, `&mut v[a: b]`, open bounds,
  sub-slicing, indexing, element borrows, loops by value or reference, `len`, `copy`, `contains`,
  formatting), with the vector's ownership rules: a slice cannot outlive its vector, the vector
  cannot grow or be written elsewhere while a slice of it lives, and an exclusive slice excludes
  every other access. `&s`/`&mut s` on a slice binding reborrows it. Design:
  `docs/design/typed-slices.md`.

- `f32[]`, `u32[]` and `i32[]` store their elements in 4 bytes (they were 8-byte words), halving
  their memory and letting the LLVM backend use 32-bit loads, single-precision arithmetic and
  vector lanes (matmul: 3.2x -> 1.3x of C). Programs print the same output, and every element can
  still be borrowed (`&mut v[i]`, `for x in &mut v`, generic `&mut T`).
- Bytes can be borrowed: `&mut buf[i]` on a `u8[]` or a mutable byte view is a `&mut u8` (it was
  rejected). Borrowing a narrow field of an `extern "C" record` (`&mut rec.x` with `x: f32`) used to
  compile and silently lose writes made through the reference; it now reads and writes the field.
- New compiler intrinsics `raw_load32`/`raw_store32` (32-bit `movl` on every target, an `i32`
  load/store in LLVM); the LLVM lifter now handles `movd`, `cvtss2sd` and `cvtsd2ss`.
- Abundance port: `abundance/src/abgeo.grl` reads `.abgeo` cluster-geometry files with every check
  the C++ `MeshView::open` makes, decodes zstd-compressed pages (`zstd::frame_content_size` is new),
  and decodes clusters (bit-packed positions and uv0, octahedral normal + tangent frames, indices,
  alpha bits, colour), and selects LOD cuts (`select_cut` for a view with partial residency,
  `select_cut_error` at an object-space error). `abundance/tests/abgeo_test.grl` matches the C++
  reader on fixtures built by Abundance's own cluster builder, plain and zstd-paged: 486 lines,
  floats as bits, including 180 cuts.
- Abundance port: `abundance/src/cluster_builder.grl` builds `.abgeo` files from a source mesh
  (clusters, the per-material cluster-LOD DAG via grail-meshopt's clod, per-level BVHs, page packing
  and dependencies, attribute codec). Its output is byte-identical to Abundance's C++ builder on the
  three procedural test meshes (single material, three materials, two-sided foliage with wind).
  Canonical voxel meshes, alpha-contour trimming and voxel LOD levels are not ported yet and are
  refused. `tools/abundance-test.mjs` fetches grail-meshopt at a pinned commit into `.work/deps`
  (`GRAIL_MESHOPT` selects a local checkout).

- `lib/zstd.grl`: Zstandard decompression (RFC 8878), `zstd::decompress(bytes) -> u8[]?`: raw,
  RLE and compressed blocks, Huffman literals (one or four streams, FSE or direct weights,
  treeless), FSE sequence tables (predefined, RLE, compressed, repeat) with repeat offsets, the
  XXH64 content checksum and skippable frames; dictionaries are not supported. Checked against 101
  streams from the reference library (`tests/lib/reference/zstd_corpus.py`).

- `lib/xxhash.grl`: XXH64 (`xxhash::hash64(bytes, seed)`), identical to the reference `xxhash.h`; zstd
  frame checksums and Abundance fixture identities use it.
- Ownership: after a `while` or `for` whose body always returns or continues, locals are usable again.
  The dead end state of such a body (where `return` had dropped every local) was merged into the
  loop exit, so any use after the loop was rejected as a use of a moved value.

- LLVM backend: when every frame access in a function is a constant offset below rbp, each 8-byte
  slot becomes its own alloca, so borrowing one local no longer makes the whole frame escape and
  LLVM keeps the rest in registers. With `--backend=llvm` the benchmarks are now 1.2x (fnv, sieve),
  1.5x (sort), 2.3x (nbody) and 3.2x (matmul) of C `-O2`.

- Repeat literals: `u8[0; n]`, `u64[7; n]`, `f32[0.0; n]` make `n` copies of a plain value in a
  single allocation (Go's `make([]byte, n)`, Rust's `vec![0; n]`). A byte value above 255 stops the
  program; an owned element type is rejected. The sieve benchmark uses it in place of a push loop.
- Green-task stack switches on AArch64 and RISC-V save every register the C ABI preserves
  (x19-x28 and d8-d15; s0-s11 and fs0-fs11), not only those the native backend uses, so
  LLVM-compiled code survives a task switch. A new task's initial frame grows to match.

- `bytes[i]` reads the element straight from the sequence when the index is simple (names, integer
  literals, arithmetic, grouping): no temporary view is allocated, borrow-tracked and freed per
  access. Other index expressions keep the borrowed-view path, so moving or mutating the sequence
  inside them is still rejected. The fnv benchmark goes from 36.1 s to 3.0 s on the native backend
  and from 5.1 s to 0.63 s (1.1x C `-O2`) on `--backend=llvm`.

- `view("literal")` builds nothing at run time: the bytes, a `u8[]` object for them and the view
  descriptor are read-only data behind block headers marked static, which `rt_free` leaves alone.
  The literal used to be copied into a fresh string, UTF-8 checked and wrapped in a heap view on
  every evaluation; compiling the compiler is about 10% faster.

- LLVM backend (`--backend=llvm`, Linux x86-64): `compiler/llvm.grl` lowers the raw word stream to
  LLVM IR for every function it fully understands and keeps the rest (data, the entry, stack
  switching, indirect calls) as native assembly; the compiler writes `PATH.ll` beside `PATH`, and
  `clang -O2` compiles it. Registers, flags and frames become allocas that LLVM promotes, checked
  arithmetic becomes overflow intrinsics, check failures a cold noreturn path, atomics LLVM
  atomics, `syscall` inline asm, and `rt_f32_round` hardware rounding. Every executable native
  case gives identical output; the benchmarks in `bench/` run 1.3x to 39x faster than the native
  backend (`GRAIL_BACKEND=llvm bun tools/bench.mjs`). `compileProgram` and the test runners honour
  `GRAIL_BACKEND=llvm`.
- `tools/bench.mjs` and `bench/`: Grail against C `-O2` on five kernels, with matching output
  required.
- CodeView symbols on Windows x86-64: `--debug` now emits an S_GPROC32 per function (named
  `module::name`) with an S_FRAMEPROC and an S_REGREL32 for every parameter and local at its rbp
  slot, typed with CodeView's predefined base types (`__int64`, `double`, `bool`, `unsigned char`,
  ...). lld-link links the scopes into the PDB; `tools/test-debug-lines.mjs` checks the records
  with `llvm-pdbutil`.

- `&mut z.comps[i].data` and `&grid[y][x]` borrow the whole accessor chain; the borrow used to
  stop after the first index, so the following field was read as a value (a type mismatch).

- Dereference is `*r` and store-through is `*r = v` / `*r += v`, as in C, Rust, Go and Zig. Reading
  copies plain values and refuses owners ("use exchange"); `*r = v` drops the old value, and
  `exchange(r, v)` remains the way to move an owned value out. The `load(r)` builtin is replaced
  by `*r`; `lib/`, Borg, Abundance, the examples, the book and the tests were rewritten.

- The statement builtins `write`, `drop` and `assert` apply only before `(` and when no local
  shadows them, so a binding named `write` can be assigned (`write += 3`).
- Statement and expression keywords (`loop`, `while`, `for`, `if`, `match`, `return`, `mut`, ...) are
  reserved: naming a binding or parameter after one is rejected with "a keyword cannot name a binding". A binding named `loop` used to be
  accepted, and `loop[i] = x` then sent the compiler into an infinite loop.

- Byte reads (`bytes[i]`) are 0..255 words that adopt any integer type holding that range, so
  `hexval(text[i])` with `hexval(c: u8)` works without a conversion, while `bytes[i] << 24` still
  computes in a full word. Byte buffers and byte literals accept `u8` values.
- Storing or pushing a value above 255 into a byte buffer now stops the program, as documented;
  `buf[i] = v` and `buf.push(v)` used to keep only the low byte silently.

- `match m.get(&k) { Some(v) => ..., None => m.insert(k, x) }` works: a borrow whose holders are
  all dead (here the moved scrutinee's) ends before a conflicting borrow is refused, so the `None`
  arm may modify the map; modifying it while the `Some` payload is still used is still rejected.
- A `for` count bound is read once (Go semantics): `for y in z.comps[n].v { f(&mut z) }` no longer
  holds a borrow of `z` for the whole loop.
- An unknown method on text or a vector reports "unknown collection method" instead of the
  misleading "owned storage mutation requires mut".

- Functions, closures, interface methods and function types take any number of parameters; the
  six-parameter (five for closures) limit is gone. Grail's own convention keeps five words in
  registers and passes the rest in a record addressed by the sixth, which the callee copies into
  its frame; C calls and callbacks keep following the platform C ABI.

- A reference or view binding passed to a function by name is reborrowed instead of moved, so
  `total(v) + total(v)` and two `bump(v)` calls through a `&mut` parameter work, as in Rust. The
  borrow checker still rejects real conflicts (a `&mut` reborrow while a shared borrow is live).
- A module's own function, or a callable local, named like a builtin (`load`, `join`, `view`, ...)
  now shadows the builtin instead of failing with an unrelated error; non-callable locals do not.
- `.copy()` works on vectors of plain values (numbers, floats, bools, handles), not only byte
  collections; copying a vector of owners is rejected.
- Arithmetic between untyped integer literals is an untyped constant (Go-style): `65536 + 16777216`
  or `(1 << 20) - 1` adopts its context's type like a single literal, with the same range check.

- Assignment to nested places: `v[i][j] = x`, `world.items[i].hp -= 1`, `rows[i].cells[j] += 1`
  and any mix of indexes and fields, each step borrowed mutably for the statement. Mutating
  method calls through an index (`rows[i].push(x)`, `m[k].push(x)`, user methods taking
  `self: &mut`) borrow the element mutably instead of failing as a read-only access, which
  removes the old need to `exchange` an inner vector out to push to it.

- String literals decode escapes strictly: `\u{...}` (a Unicode scalar value, encoded as UTF-8)
  now works in strings as it already did in character literals, `\xHH` is limited to `\x7F` so
  a literal can never be invalid UTF-8, and an unknown escape such as `\q` is a compile error
  instead of being kept as literal text.
- `u8[]` has `.clear()` and `.truncate(n)` like other vectors (`clear` used to be a parse error).
- `module::Type[]` and `module::Type[...]` collection literals work for another module's types.
- In i64 mode an unsuffixed literal that does not fit `i64` (e.g. `9223372036854775808`) is a
  compile error; it used to wrap silently to a negative value.
- Standard-library modules are recognised by location (a file in the directory holding
  `core.grl`) rather than a hard-coded name list, so every `lib/` module, including new ones,
  compiles in the stdlib's own literal mode regardless of the program's mode.

- `f32_bits(x)` returns the IEEE binary32 bit pattern of an `f32`, and `f32_from_bits(u)` builds an
  `f32` from one (subnormals, infinities and NaN included). `bits(x)` on an `f32` still returns
  the 64-bit pattern of the internally widened value, so these are the way to read and write
  32-bit floats in binary formats.

- FFI bare data pointers: `CPtr` (`const void *`) and `CMutPtr` (`void *`) parameters, results and
  extern-record fields, made with `unsafe cptr(bytes)`, `unsafe cptr_mut(&mut bytes)` and
  `cnull()`. C APIs that take lone buffer pointers (libsodium keys and outputs, Vulkan `pData`)
  are now callable without a C shim. `tests/ffi/pointers.grl` runs on all three Linux targets.
- `grail build` / `grail test` honour the compiler's `// grail-link:` requests: bare library
  names become `-lNAME`, relative objects resolve against the entry file, and an executable that
  links a shared library gets the platform dynamic loader and system library directories
  (Linux), or the library inputs on the Mach-O link line. Previously the CLI linked every program
  statically and ignored foreign libraries, so only the test harness could link C code.
- `docs/ffi.md`: the supported-types table now lists narrow integers, floats, record results
  and the bare pointer types, which were already supported but documented as rejected.
- Borrow checker: a reference obtained from an unwrapped optional reference (`items := get(&v)!`)
  and used only inside one branch of an `if` no longer reports "cleanup conflicts with live loan"
  when its owner is cleaned up. The anonymous origin behind the returned reference was left
  "maybe live" by the branch join and never ended; it now ends once no live loan reaches it, so
  a reference still in use after the join keeps the owner borrowed exactly as before.
- Nested C records: an `extern "C" record` field may itself be an extern record, embedded by
  value at its C offset with C alignment and size. Reads and writes project through it in place
  (`o.inner.x = v`), whole-record assignment copies the bytes in, a value read copies them out,
  and nested records come back from C by value. Results with floats inside an embedded record
  are refused for now. `tests/ffi/nested_records.grl` checks `sizeof`/`offsetof` against clang
  and runs on x86-64, AArch64 and RISC-V 64 Linux and on Windows x86-64 (Wine).
- Standard library: `zlib` (DEFLATE/zlib inflate, Adler-32, and a lenient variant for image
  decoders), `png` and `jpeg`. The image decoders reproduce `stb_image` exactly (the library
  Abundance uses): PNG in every colour type and bit depth with Adam7, palettes, colour-key tRNS
  and stb's 16-to-8-bit and channel conversions; JPEG baseline and progressive with stb's integer
  IDCT, upsampling filters, fixed-point YCbCr and Adobe CMYK/YCCK handling. Tests compare against
  CPython's zlib and against stb itself for every requested channel count (53 streams, 570 PNG
  and 290 JPEG checks); all 95 PNG assets in the Abundance tree also decode bit-identically.
  `png::encode` and `zlib::compress` reproduce `stbi_write_png` byte for byte (its hash-chain
  compressor, adaptive filter choice and CRC; 444 encodings checked). Decoding is currently about
  160x slower than stb.

- DWARF debug info on Linux AArch64 and RISC-V 64: `--debug` emits the same line table and
  typed variables as on x86-64 (frame base `x29` / `s0`). Under qemu with gdb's remote stub,
  `info locals` shows `count = -3`, `ratio = 2.5`, `flag = true` on both; `test-debug-lines`
  checks the line rows, variable types and `llvm-dwarfdump --verify` for both targets.

- Variadic C calls on macOS arm64: each variadic argument (promoted to 64 bits or `double`) goes
  on the stack in its own 8-byte slot while named arguments keep their registers, per Apple's
  arm64 ABI. Checked statically in `test-macos` (no macOS runner); the call was refused before.

- C records with float fields returned by value: SysV classifies each eightbyte (all-float ->
  `xmm0`/`xmm1`, otherwise `rax`/`rdx`), AAPCS64 returns homogeneous float aggregates of 1-4
  fields in `s0`-`s3`/`d0`-`d3` at any size, RV64 returns one or two flattened fields with a float
  in `fa0`/`fa1` (and an integer in `a0`); everything else keeps the integer-register or hidden
  pointer rules (Win64 by size). `tests/ffi/float_record_results.grl` covers five shapes on three
  Linux targets and Windows x64.
- String literals decode escapes strictly: `\u{...}` (a Unicode scalar value, encoded as UTF-8)
  now works in strings as it already did in character literals, `\xHH` is limited to `\x7F` so
  a literal can never be invalid UTF-8, and an unknown escape such as `\q` is a compile error
  instead of being kept as literal text.
- `u8[]` has `.clear()` and `.truncate(n)` like other vectors (`clear` used to be a parse error).
- `module::Type[]` and `module::Type[...]` collection literals work for another module's types.
- In i64 mode an unsuffixed literal that does not fit `i64` (e.g. `9223372036854775808`) is a
  compile error; it used to wrap silently to a negative value.
- Standard-library modules are recognised by location (a file in the directory holding
  `core.grl`) rather than a hard-coded name list, so every `lib/` module, including new ones,
  compiles in the stdlib's own literal mode regardless of the program's mode.
- `Some(value)` and `None` are the only option spellings: `core::some` / `core::none` are now
  rejected in every build mode (the legacy `--default-u64` mode used by the test suites still
  accepted them), and the remaining uses in `lib/`, `borg/`, the examples, the compiler tests and
  the book were rewritten. `grail build` now compiles only the standard-library modules a program
  reaches through `use` (plus `core`, which `Some`/`None` lower to) instead of every `lib/*.grl`.
  A bare `None` needs a type from context; `x == None` and `x != None` now take it from `x`.

- Fixed: the `i64` -> `u64` widening check emitted `jns`, which the AArch64 and RISC-V lowering
  does not implement (it emulates the zero and carry flags only), so programs relying on default
  `i64` semantics failed to compile for those targets. The sign is now tested with a shift and a
  zero test.

- Fixed: on macOS an exported `extern "C" fn` was defined without the Mach-O leading
  underscore while references to it had one, so taking a callback's address failed to link.
  `test-macos` now links the `dlopen` fixture (libSystem loader imports, a Grail callback) for
  both macOS targets.

- DWARF variable types: `--debug` on Linux x86-64 now gives every parameter and local a
  `DW_AT_type` base type (signed/unsigned integers of their width, `f64`/`f32`, `bool`, `char`;
  strings, records and other owned values as named 8-byte handles), so gdb prints
  `count = -3`, `ratio = 2.5`, `flag = true`; `llvm-dwarfdump --verify` reports no errors.

- Dynamic loading on AArch64 and RISC-V 64 Linux: the host-TLS bridge (switching the thread
  pointer between Grail's worker record and glibc's TCB around foreign calls and callbacks) now
  covers `tpidr_el0` and `tp`, written directly instead of through `arch_prctl`. With a glibc
  sysroot (`GRAIL_SYSROOT_AARCH64`, `GRAIL_SYSROOT_RISCV64`) dynamically linked cross programs
  link against the target loader and run under qemu `-L`; `tests/ffi/dlopen.grl` executes on
  all three Linux targets. Foreign calls on AArch64/RISC-V previously ran with Grail's worker
  record installed where glibc expects its TCB.
- `lib/sha256.grl`: FIPS 180-4 SHA-256 over byte views, incremental (`sha256::new()`,
  `update`, `finish` -> 32 bytes) with one-shot `digest` and lowercase `hex`/`hex_digest`; the
  PicoSHA2 replacement for Abundance content identities. Checked against the NIST vectors
  (including one million `a`), `sha256sum` on generated inputs around the 55/56/63/64/65-byte
  padding boundaries, and every split of the input between two `update` calls.
- `lib/json.grl`: strict RFC 8259 JSON for the bounded config adapter (replacing nlohmann/json).
  `json::parse`/`parse_with` return `json::Value |? json::Error` with an error kind and byte
  offset, never aborting on malformed input; integers that fit are exact `Int(i64)`, other
  numbers are correctly rounded `Float(f64)`; `\u` surrogate pairs decode to UTF-8 while lone
  surrogates, invalid UTF-8 and raw control characters are rejected; objects keep key order and
  reject duplicate keys unless `allow_duplicate_keys`; nesting is bounded by `max_depth`
  (default 128). `to_text`/`to_pretty` round-trip exactly (shortest float digits). Tested with
  311 inline JSONTestSuite-style accept/reject cases and 612 CPython-verified float conversions
  (`docs/design/language-readiness.md` section C1).

- Callbacks with float and narrow-integer parameters and float results: an exported
  `extern "C" fn` reads each parameter from where the platform C convention put it (SysV,
  AAPCS64 and RV64 pack integers and floats into separate register files; Win64 is positional,
  with the fifth and sixth words from the stack), widens f32, extends narrow integers itself,
  and returns floats in `xmm0`/`d0`/`fa0`. `tests/ffi/callback_floats.grl` runs on three Linux
  targets and Windows x64.

- Variadic C functions: `extern "C" fn f(fixed: T, ...)`. Extra arguments use the C default
  promotions; SysV sets `%al` to the vector-register count, Win64 passes variadic doubles in
  both the xmm and the integer register of their slot, RV64 passes them in integer registers.
  macOS arm64 (variadics on the stack) is refused for now. `tests/ffi/call_variadic.grl` runs on
  three Linux targets and Windows x64.
- COM methods with more than four arguments or floats: read the vtable slot as a typed `cfn`
  and call it with the full platform convention (`tests/ffi/call_com_slot.grl`, seven arguments
  with three on the stack, Linux and Windows).
- C records with `f32`/`f64` fields (by pointer), at C offsets and sizes (`D3D12_VIEWPORT`,
  `VkViewport` shapes). Records with float fields as by-value *results* are refused until the
  SSE/HFA classification exists.
- Fixed: assigning a narrow C-layout field (`p.a = 5` on an `i32`) stored eight bytes and
  clobbered the neighbouring fields; assignment and compound assignment now write only the
  field's width. Fixed: the optimizer could fold a constant into `movq $imm,%xmm0`, which does
  not assemble.

- Child process output capture: `sys_grail::pipe()`, `spawn_with(program, args, stdin, stdout,
  stderr)` (with `inherit()` for shared streams) and `read_to_end(file)`, over a new
  `grail_ffi_process_spawn_stdio`. Executed on Linux (`/bin/sh`) and Windows under Wine
  (`cmd.exe`). The Windows OS ABI returned an error at the end of an anonymous pipe
  (`ERROR_BROKEN_PIPE`); it now reports a zero-length read, the portable EOF contract.
- Windows ARM64 threads: the `CreateThread` start bridge `rt_win_thread_start` now exists on
  ARM64 too and is published by the entry point; thread creation previously failed there. Static
  checks only (no ARM64 Windows runner).

- C records returned by value from direct and `cfn` calls: up to 16 bytes in `rax:rdx`, `x0:x1`
  or `a0:a1` (Win64: 1/2/4/8 bytes in `rax`), larger ones through a hidden result pointer in
  `rdi`/`rcx`/`a0` (shifting the arguments) or `x8` on AAPCS64. `tests/ffi/call_records.grl`
  returns 8-, 16- and 24-byte records on x86-64, AArch64 and RISC-V Linux and Windows x86-64.
- Windows debug info: `--debug` on windows-x86_64 emits CodeView line tables (`.cv_file`,
  `.cv_func_id`, `.cv_loc`, `.cv_linetable`), and the Windows link adds `/DEBUG /PDB:`.
  `test-debug-lines` checks the PDB maps the source lines and that every function keeps its
  unwind entry (the SEH prologue matcher now skips debug labels and `.cv_` directives).

- Win64 callbacks: an exported `extern "C" fn` on Windows x86-64 is now a thunk under the C
  symbol that saves `rdi`, `rsi` and `xmm6`-`xmm15`, moves `rcx`/`rdx`/`r8`/`r9` (and stack
  arguments five and six) into the body's registers and calls the body. Callbacks previously read
  SysV registers, so a C caller's arguments were lost and its callee-saved registers clobbered.
  The f32 narrowing in extern calls no longer uses `xmm15` as scratch, which Win64 preserves.
- Stdlib wrappers on Windows: `lib/sys/grail_ffi.grl` binds `lib "grail_ffi"` (the Linux object or
  `grail_ffi.dll`); `tools/test-ffi-runtime-windows.mjs` builds the C OS ABI and shim into
  `grail_ffi.dll` with Zig's MinGW toolchain and runs the file, socket and process/thread tests
  under Wine (the process test spawns `cmd.exe`).
- Windows `io::Error` codes: the Windows host layer maps `GetLastError` to the errno values
  `io::Error` understands (ENOENT, EACCES, EEXIST, ENOTDIR, ENOTEMPTY, EINVAL, ENOMEM); unmapped
  codes surface as `Other(0x10000 + code)`. Opening any missing or unreadable file used to report
  ENOENT, and removing a non-empty directory or a file as a directory reported EISDIR.
- `vecs::fold` (consuming, any element type) and `any_num`/`all_num`/`count_num`/`position_num`.
  Generic predicates over borrowed elements wait for closure parameters that hold borrows.

- Windows dynamic loading: an `extern "C" lib "X"` declaration on a PE target now records
  `X SYMBOL`, and the Windows link step imports each symbol from `X.dll`, so `LoadLibraryA`,
  `GetProcAddress` and `FreeLibrary` link like any import. Calls through `cfn` values (on every
  target) now use the platform C convention, including floats, narrow integers, stack arguments
  and Win64; they previously used Grail's internal register order. A Wine-executed case resolves
  `lstrlenA` and `MulDiv` from kernel32 and checks `ERROR_MOD_NOT_FOUND` (126) for a missing DLL.

- D3D12 bindless and compute: the contract's root signature now carries the four unbounded
  tables (sampled images, storage images, samplers, storage buffers) over one shader-visible
  resource heap and one sampler heap; the thirteen fixed samplers fill slots 0..12. Added
  `gr_sampler_create`, sampled texture views, `gr_texture_write`, storage buffers (host-visible
  ones in a custom write-back heap the GPU can write), compute pipelines and dispatch, buffer
  barriers with tracked states, `gr_device_retire`/`gr_device_collect` and real bindless
  high-water marks. `grail_bindless.hlsli` declared both UAV tables in space 0, where an
  unbounded `u1` range overlaps `u3`; on D3D12 storage writes landed in the storage-image table.
  The tables now use `u0 space2` and `u0 space3`, with `[[vk::binding]]` keeping Vulkan's set 0,
  bindings 1 and 3 unchanged. Flip-model DXGI swapchains on an SDL3 window (acquire, present,
  resize) and Windows SDL3 loading through `LoadLibrary`, with the window's HWND/HINSTANCE from
  SDL properties, are added.

- Vulkan's thirteen fixed samplers did not match Abundance's definitions: the `*_WRAP` slots
  clamped, the `*_CLAMP_U_WRAP_V` slots never wrapped V, W was always clamped, and the MIN/MAX
  reduction slots filtered as ordinary samplers; `gr_sampler_create` also ignored MIN/MAX
  reduction. Both now use one table, `gr_fixed_sampler` (taken from `engine/core/bindless.cpp`),
  which D3D12 shares, and `samplerFilterMinmax` is enabled for the reduction slots.

- Vulkan pipelines now honour `gr_pipeline_desc.depth_compare`; it was ignored and every
  pipeline used GREATER_EQUAL. Zero still means the reverse-Z default, as on D3D12.

- D3D12 buffers, vertex input and depth: upload, readback and device buffers (host access to
  device memory is refused, as on Vulkan), vertex and index buffer binding, input layouts built
  from the vertex shader's reflected semantics and checked against the pipeline's attributes,
  depth textures, depth-stencil views, reverse-Z depth state and depth clears, and indexed draws.
  The smoke test now has 162 checks, including a depth-tested indexed triangle whose depth reads
  back exactly. The shader tool stored DXC's SPIR-V variable name (`in.var.COLOR0`) as the vertex
  semantic; it now stores the HLSL semantic and index (`COLOR`, 0), as the reflection contract
  says, which D3D12 input layouts need.

- D3D12 draws: DXIL shaders, graphics pipelines on the contract root signature (32 root
  constants at b0, frame constants as a root CBV at b0 space1), blend modes, topology, cull,
  wireframe, pipeline commit/stats, push constants, frame-constant slots and non-indexed draws.
  `make -C graphics d3d12-smoke` now runs on vkd3d-proton (the offline DXIL is shader model 6.6;
  Wine's built-in vkd3d supports 6.2) and checks a 64x64 draw of the offline `core/fullscreen` and
  `core/solid` shaders pixel by pixel against the shader's formula: 83 checks. Vertex input,
  depth, MSAA, compute/mesh pipelines and bindless tables still return `GR_ERROR_UNSUPPORTED`.

- Direct `extern "C"` calls are lowered per calling convention: SysV x86-64, Win64, AAPCS64
  (Linux, macOS and Windows ARM64) and RV64 LP64D. They now take and return `f32`/`f64` (an `f32`
  crosses as real binary32) and `i8`..`i32`/`u8`..`u32` (results re-extended; RV64 receives
  `u32` sign-extended), and pass arguments beyond the registers on the stack (up to 64 words;
  Win64 gets its 32-byte home area). Windows `extern "C"` calls previously used SysV registers;
  they now follow Win64 and run under Wine. RISC-V objects now use the `lp64d` hard-float ABI
  instead of `lp64`, which is what Linux C libraries use. `tests/ffi/call_abi.grl` runs on
  x86-64, AArch64 and RISC-V Linux and Windows x86-64. Callbacks and `cfn` calls keep the
  integer-only slice for now.

- Fixed a double `vkDestroySemaphore` at Vulkan device teardown: the compute queue borrows the
  device's graphics timeline but its teardown destroyed it too. The validation layer had reported
  `VUID-vkDestroySemaphore-semaphore-parameter` and two threading messages after the tests'
  error counters closed, so `vk-smoke`, `vk-surface` and `vk-cache` reported zero while teardown
  did not. All three are now silent through teardown.

- D3D12 backend, first slice (`graphics/src/grail_d3d12.c`): headless device with its reported
  feature level, one direct queue whose fence is the timeline gr fences observe, 2D render-target
  textures and views, command pools and lists (one allocator per list), barriers that refuse a
  source state disagreeing with the tracked one, clears, viewport/scissor, submit and texture
  readback. The device owns and releases all its objects. Every other entry point routes to an
  explicit `GR_ERROR_UNSUPPORTED`. `make -C graphics d3d12-smoke` builds the library for
  x86_64-windows with `zig cc` and runs 47 checks under Wine (vkd3d on the host GPU), including
  exact clear readbacks. Building without SDKs also exposed and fixed two latent gaps: Vulkan
  declarations in `grail_vk_common.h` outside `GRAIL_HAVE_VULKAN`, and eleven dispatcher entry
  points missing from the no-headers Vulkan stubs. The shader library can now index on Windows
  (`FindFirstFileA`) instead of reporting `GR_ERROR_UNSUPPORTED`.

- Added process and thread wrappers over the C ABI: `handle Process`/`handle Thread`,
  `spawn(program, arguments)` with a NUL-separated argv[1..] blob, blocking `wait` returning a
  40-byte `ProcessStatus` (kind/exit code/signal), `process_id`, `process_close`, and
  `thread_spawn(cfn(u64)->u64, user)`, consuming `thread_join`/`thread_detach`. Process stdio
  and environment are inherited; handles are affine by convention. The x86-64 test spawns
  `/bin/sh -c 'exit 7'`, checks the exit status and closes the process, then spawns a Grail
  C-ABI callback thread with user word 41 and joins the result 42; AArch64/RISC-V 64 assembly
  and unmangled calls are checked without execution.
  The FFI runtime runner no longer patches `raw_tp_set` out of a runtime copy: all wrapper tests
  now run on the real runtime through the compiler's host-TLS bridge.

- Dynamic loading on Linux x86-64: `dlopen`/`dlsym`/`dlclose` work through ordinary extern
  declarations, with `dlsym` declared once per signature and returning a callable `cfn`.
  Because the runtime's worker record and glibc's TCB share the FS base, the compiler records
  the loader's TLS base in `_start` before `rt_thread_init`, switches to it around every
  foreign call, and switches to Grail's base for the body of every exported callback. The new
  `tests/ffi/dlopen.grl` resolves two functions from a shared library and runs a callback that
  calls libc. Limits: main thread only, x86-64 Linux only, one `arch_prctl` per switch.

- Added Linux x86-64 DWARF `.debug_info` compile units and DIEs on top of the
  line table. `--debug` now emits a DWARF v4 compile unit naming the entry
  source and one subprogram DIE per function with name, linkage name,
  low/high pc, declaration file/line and an rbp frame base. Parameters and
  locals get formal-parameter/variable DIEs with declaration lines and
  `DW_OP_fbreg` stack locations; optimisation is skipped in debug builds so
  slots stay live, and validation replays do not leak discarded DIEs.
  `grail debug info BINARY` prints the unit through `llvm-dwarfdump` (readelf
  fallback). Type DIEs, location lists, breakpoints/attach/DAP and non-Linux
  debug sections remain follow-ups. The debug integration test now also checks
  subprogram ranges, parameter/local names and locations.
- Port Borg Agent's permission gates (`borg/`). `src/permission.grl` carries the three permission modes, the three approval decisions, and the rules a gate applies: the requested workspace root must sit under a canonical enrolled root, a path must be relative and free of traversal components, a symlink on the way is refused outright, and containment is component-wise so a `/w` root does not cover `/work`. The denial reasons are Borg's own strings, and an `allow_session` grant covers later calls of the same tool and scope while `allow_once` does not. The port now checks 921 reference lines over 200 documents, with `--anchors` verifying 74 copied snippets across thirteen source files.

- Windows COM interop: two new unsafe-runtime intrinsics, `raw_win_local(Symbol, args...)` for a
  direct Windows-ABI call to a symbol linked into the image (x86-64 `%rcx/%rdx/%r8/%r9`; ARM64
  `x0..x3`) and `raw_win_call(slot, args...)` for an indirect call through a loaded function
  pointer such as a COM vtable slot (x86-64 `call *%r11`, ARM64 `wininvoke` ->
  `ldr x16,[x9]; blr x16`). `CoInitializeEx`/`CoUninitialize` join the import table from
  `combase.dll`. Minimal C-ABI shims (`tests/com-shim-x64.s`, `tests/com-shim-arm64.s`) provide
  an `IUnknown` object; the executed x86-64 case proves AddRef/Release counts 2, 3, 2, 1 and 1, 0
  and the exact `E_POINTER` (2147500035) and `E_NOINTERFACE` (2147500034) HRESULTs, plus a
  successful `QueryInterface` returning the object pointer. The same program is checked
  statically for windows-aarch64. Single static object and one IID; no `CoCreateInstance`,
  marshalling or apartment tests.

- Added typed loopback TCP socket wrappers over the C ABI: `handle Socket`, a 56-byte `Address`
  record constructed only by `loopback(port)`, `tcp`, `bind`, `listen`, `accept`, `connect`,
  `send`, `recv`, `recv_bytes`, `socket_shutdown`, `socket_close`, `local_address`,
  `peer_address`, `local_port` and `peer_port`. `bind`/`connect` reject non-127.0.0.1
  addresses before the C call. The x86-64 test runs a listener/client/server ping-pong on an
  ephemeral loopback port and checks the non-loopback rejection; AArch64/RISC-V 64 assembly
  and unmangled socket calls are checked without execution.

- Added `lib/sys/grail_ffi.grl`, the first Grail-facing wrappers over the Linux OS ABI:
  explicit init/shutdown, file open/read/write/close/stat/size, monotonic and wall clocks,
  and environment get/set. The module uses FFI byte views, an opaque `File` handle and
  Grail-owned out-records, returns `T |? Error` with negative ABI statuses, and keeps file
  handles affine by convention (explicit single close, no auto-free). Added a hosted C
  adapter for the allocator and handle-return out-parameter, a repeatable
  `tools/test-ffi-runtime.mjs` runner, and `docs/design/grail-ffi-runtime.md` with the exact
  pointer/length/ownership rules. The x86-64 test links the Linux reference backend with
  libc and executes file/time/environment checks; AArch64 and RISC-V 64 are assembly/static
  checked only. It uses the merged v3 FFI compiler and `runtime.grl`/`os-linux.grl`, is not
  auto-loaded by the current stdlib, and changes no compiler sources (the runner generates a
  test-only runtime copy to preserve libc TLS).

- Persist and reload session state through the C OS ABI (`borg/`). `src/ffi/store.grl` is the first increment that performs real I/O: it frames a payload ("BGS1", little-endian length, payload), writes it to a same-directory temporary file, closes it, and renames over the destination so a crash mid-write cannot leave a partial file — the rule Borg documents for credentials. A short file, a foreign magic and a length that disagrees with the payload are refused by name rather than partially accepted. The rename is declared in the port against the same FFI object file because the wrapper does not expose it yet; nothing under `lib/` or `compiler/` changed. `just borg-store-test` builds the Linux backend, links the FFI test and runs it: three round-trips and five refusals, in a separate suite because it needs a C toolchain. `--anchors` now verifies 75 copied snippets across thirteen source files.

- Abundance RHI host: `abundance/tools/rhi_host.c` handles wire packets using the Vulkan
  backend. Its standalone GPU self-test clears an R8G8B8A8_UNORM target and reads back
  exactly 64, 128, 191, 255. The request/response file transport differs from the documented
  AF_UNIX topology; the Grail client exchange is not yet verified end to end.

- Abundance CPU port, RHI bridge framing: `abundance/src/rhi_bridge.grl` packs and unpacks the
  graphics foundation's `gr_wire_packet` exactly as `graphics/src/grail_wire.c` does — 40-byte
  header, magic/version/op/request/status/sequence/aux, payload, with the 1 MiB packet bound — so a
  host driving `grail_null.c` reads what a Grail program writes. Three packets and three refusals
  are gated byte-for-byte against the C framing: 30 exact values, suite total 313 across nine
  programs. Bounded and stated: the host half (null backend init, render target, one pass,
  readback) is the next increment; no device is created here.

- Abundance CPU port, asset-package increment: `abundance/src/asset_package.grl` carries the ABPKG1
  package header (id, payload hash, payload bytes, ascending dependency ids), package ids and
  payload hashes from the engine's `fnv1a64`, and the dependency DAG with duplicate, missing,
  self-dependency and cycle refusals plus a deterministic topological order that does not depend on
  input order. The reference gates ids and hashes against the engine and the DAG rules against a
  model, because Abundance has no C++ asset DAG (its dependency work is Python staging). 29 exact
  values; suite total 283 across eight programs. No payload bodies, GPU upload or renderer work.
- Added Linux x86-64 DWARF line tables. `grail build --debug` and the raw
  `grail --debug ...` compiler form emit `.file`/`.loc` directives that clang
  assembles into `.debug_line`; statement rows are line/column accurate, with a
  post-pass that re-asserts the location after literal `.popsection` switches.
  `grail debug lines BINARY` prints the table through `llvm-dwarfdump` (with a
  `readelf` fallback). `--debug` is rejected for non-Linux-x86-64 targets, and
  `.debug_info` variable DIEs / debugger attach remain follow-ups.
  `tools/test-debug-lines.mjs` verifies rows against source lines and the plain
  build's lack of a line table; CI adds a preflight-gated `debug-lines` job.
- Added non-executable target object release bundles for the implemented cross
  backends: `windows-x86_64` (COFF), `macos-aarch64` and `macos-x86_64`
  (Mach-O). `bun tools/ci.mjs objects --platform ...` compiles the compiler and
  a conformance program to relocatable objects, verifies COFF/Mach-O headers
  and symbols, and packages `objects/`, gzipped assembly,
  `share/grail/objects.json` provenance and `OBJECTS-BUILD-ONLY.txt` with a
  top-level `SHA256SUMS`. Manifests record `executable: false` and
  `runnable: false`, and verification rejects any bundle containing an
  executable. macOS gained required `cross-macos-aarch64`/`cross-macos-x86_64`
  static lanes; CI adds an object-bundle matrix and a macOS static-check job.
  Nothing is executed on macOS, and Windows release artifacts remain
  non-executable objects even though Windows test programs run under Wine.
- Reserve `VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC` in the Vulkan descriptor pool, matching
  set 1; the new SDL3 surface test’s validation layer had exposed the missing pool size.

- Windows x86-64 threads and waits: `raw_thread_clone` now calls a new
  `rt_win_thread_clone`/`rt_win_thread_main` pair in `compiler/os-windows.grl` that creates the
  thread with `CreateThread` through a compiler-emitted Win64 bridge (`rt_win_thread_start` keeps
  the private Grail convention by saving `%rdi/%rsi`, moving the thread parameter from `%rcx` and
  restoring them). A 15-slot registry maps the portable running word to the Win32 thread handle,
  so joins wait with `WaitForSingleObject` and only then release the stack; the unmap path reaps
  still-registered threads. Futex operations map to `WaitOnAddress` and
  `WakeByAddressSingle`/`WakeByAddressAll`, imported from `kernelbase.dll` (Wine exports them
  there, not from `kernel32.dll`). Two new cases run under Wine and as Linux ELF: a thread join
  and a producer/consumer wake. ARM64 thread creation remains unimplemented.

- Windows ARM64 frames now carry unwind data: the compiler describes each canonical prologue
  with armasm-style `.seh_proc`/`.seh_save_regp x29, 0`/`.seh_nop`/`.seh_set_fp`/`.seh_stackalloc`/
  `.seh_endprologue`/`.seh_endproc` directives, so the object has `.pdata` and `.xdata` and the
  image has an exception directory (240 records, 0x780 bytes for the hello image). Frame
  allocation uses a `framesub` pseudo-op (plain `sub sp,sp,x10` instead of checked arithmetic) so
  the recorded frame size is exactly the `.set` value. The records are the unpacked `.xdata` form
  on purpose: the packed encoding counts consecutive `x19..`/`d8..` saves and cannot express the
  lone `x29/x30` frame-pointer save Grail emits. Leaf functions need no record; drop thunks keep
  their conditional prologue and stay undescribed. The suite now checks records per function,
  frame sizes against the compiler's frame values, function lengths and the unpacked flag.

- macOS platform linkage beyond libSystem: `compileProgram` accepts `frameworks` and, with
  `$GRAIL_SDK`, links the SDK's real `-framework` stubs, otherwise writes `<Name>.framework` `.tbd`
  stubs from a caller-supplied export list (a framework name without either is rejected instead of
  being invented). `tools/macos.mjs` parses the linked image and verifies its `LC_LOAD_DYLIB`
  entries. `sign: true` requests an ad-hoc signature — `codesign --force --sign -` on macOS,
  `ld64.lld -adhoc_codesign` elsewhere — and `bun tools/macos.mjs inspect|verify BINARY` validates
  the SuperBlob, CodeDirectory, page hashes and cdhash statically; a tampered page fails
  verification. Tests add Foundation framework loading, unknown-framework rejection (driver and
  linker), and signature validation/tamper detection. Shared Mach-O libraries are also emitted:
  `assembleDylib` links `-dylib -install_name <name>` with an explicit `-exported_symbols_list`
  (a dylib without an install name or without exports is refused), and `tools/macos.mjs` reports
  `LC_ID_DYLIB` plus the export/import sets by parsing `LC_SYMTAB` directly. Tests link an
  executable against the dylib and require its install name in `LC_LOAD_DYLIB`, and reject a
  symbol outside the export list. `--export NAME` is a compiler flag: it marks exactly the
  definition with that declared name `.globl` at its own label and refuses a name that no function
  defines, so the driver no longer rewrites `.globl` into the assembly. Dylibs can advertise
  `@rpath/...` install names and consumers carry `LC_RPATH` (`rpaths` in `tools/macos.mjs`), with
  tests for both. Nothing here is execution evidence on Apple hardware.

- v3 C FFI increment 1: `extern "C"` foreign declarations and calls.
  `extern "C" [lib "INPUT"] [as "SYMBOL"] fn name(i64, u64) -> i64|u64|unit;` declares a
  linker-resolved C symbol; calls emit the C argument/result registers of the selected
  target (x86-64 SysV, AArch64 AAPCS64, RISC-V 64 LP64) and call the unmangled symbol.
  Foreign calls are rejected outside an explicit `unsafe { ... }` block, which remains a
  fully checked lexical region. Declarations carry their link inputs, deduplicated and
  emitted as `// grail-link: INPUT` lines that `tools/native.mjs` obeys. Narrower
  integers, floats, views, handles, records and callbacks are rejected with diagnostics
  rather than truncated or approximated. New `bun tools/test-ffi.mjs` (or `just
  test-ffi`) links a freestanding C shim and checks calls, the rename and `u64` results;
  rejection fixtures joined `tests/native-cases.json`. See `docs/ffi.md`.

- v3 C FFI increment 2: C byte/string views and opaque handles at `extern "C"` boundaries.
  A `&[u8]`/`&mut [u8]` parameter crosses as the C pair `(pointer, length)` with no copy and
  no allocation; `CStr` is a one-word NUL-terminated `const char *` produced by the checked,
  zero-copy `unsafe cstr(value)` cast; `handle Name;` declares a one-word opaque C token that
  safe code cannot construct, inspect, size or drop. Results may be `i64`/`u64`/`unit`/`CStr`/
  handle; a view is never a result. Arities are counted in C argument words (a view counts
  twice), and everything outside this slice is still rejected with a diagnostic. `tests/ffi/`
  gained a views/handles fixture and the shim gained string, byte, mutable-fill and handle
  functions; three more rejection fixtures joined `tests/native-cases.json`. See `docs/ffi.md`.

- v3 C FFI increment 3: `extern "C" record` with C layout and alignment. Fields use C's
  natural alignment, inter-field padding and tail padding, so `offsetof`/`sizeof` agree
  with the C compiler; field reads and writes use the exact field width (`i8`/`i16`/`i32`
  truncate on store and sign- or zero-extend on load, via portable byte-wise runtime
  helpers shared by all targets). A record parameter crosses as the address of its fields
  (`R *`); Grail keeps ownership of the allocation and frees it at scope end, while C must
  not free or retain it. Nested records, record results, pointer/float fields and by-value
  struct passing are rejected with diagnostics rather than approximated. Adds
  `tests/ffi/extern_records.grl` (C reads and writes Grail fields; `offsetof`/`sizeof`
  verified from C) and three rejection fixtures. See `docs/ffi.md`.

- v3 C FFI increment 4: C callbacks and function pointers. `extern "C" fn name(...) { ... }`
  defines a Grail function that C can call: it is emitted with the stated (unmangled) C
  symbol, `as "name"` renames it, and its signature must sit inside the C ABI slice.
  `cfn(P...) -> R` is the type of a C function pointer (one word, no environment, C
  calling convention); only `extern "C"` definitions produce such a value, so a closure or
  an ordinary Grail function is a type mismatch where C expects a callback, and a foreign
  declaration still cannot be used as a value. The generated code preserves the
  callee-saved registers it allocates, verified by a shim that clobbers `rbx`/`r12`-`r15`
  around the callback. `tests/ffi/callbacks.grl` covers a direct callback, a renamed one
  and the register-preservation case; two rejection fixtures cover a mismatched callback
  and `cfn` arity. Variadic callbacks and callback results are still rejected. See
  `docs/ffi.md`.

- Added executed Windows evidence for the C ABI without a Windows SDK:
  `tests/abi/wine_harness.c` is cross-built with Zig's MinGW-w64 target and run under Wine,
  covering file metadata follow/no-follow, hidden attributes, non-reparse readlink rejection,
  symlink readlink/realpath, regular-file non-blocking rejection and `localhost` DNS (47
  checks). Fixed Windows `fs_stat` to follow symlinks unless `GRAIL_STAT_NO_FOLLOW` is set by
  opening the path with `CreateFileW` and using `GetFileInformationByHandle`.
  `tests/abi/macos_metadata_dns_check.c` compiles the same metadata/reparse/DNS call sites for
  Apple ARM64 without execution. Added `tools/test-abi-wine.mjs` and `just abi-wine-test`.

- Abundance CPU port, executor increment: `abundance/src/job_executor.grl` runs the policy order
  through Grail's structured parallelism (`task_scope`/`spawn`/`join` over clone-created OS
  threads) in batches as wide as the worker count, with cancellation filtered before batching, a
  refusal for worker counts outside 1..4, and completion/checksum accounting. The job test now
  covers 47 exact values: 100 repetitions at 1, 2 and 4 workers each reproduce the same dispatch
  digest, completion count and checksum, and the dispatched order equals the policy oracle's.
  Suite total 254 exact values. Two port bugs fixed on the way: a four-id batch packed by
  multiplication overflowed u64 (bit packing now) and cancelled ids were only checked at the batch
  head (filtered up front now).

- Abundance CPU port, job-priority increment plus a container-ergonomics note: `abundance/src/job_policy.grl`
  carries `JobPriority::key()`/`from_key()` (class << 32 | f32 rank bits, with the engine's
  non-finite and negative clamps), `terrain_rank()` and the documented admission policy model; the
  reference links the engine's own symbols. Two arithmetic bugs found on the way are fixed and
  recorded: an unsigned exponent subtraction underflowed for every f32 value below 1.0 (the SIGABRT
  in the first cut) and the rank's level term is max(0, 32 - level). The committed job test now
  covers 30 exact values, including the model's execution order and counters.
  `docs/design/grail-container-ergonomics.md` records what the entity and checkpoint work cost:
  affine loops over owned aggregates, no reference to nested-vector elements, no in-place field
  writes through an index, reference rebinding at every call, and the syntax facts that each cost a
  compile iteration. Suite total 237 exact values.

- Abundance CPU port, entity-registry increment: `abundance/src/entity_table.grl` carries the
  entity registry's persisted state — dense id-ordered rows of id, type, owner, position, spawned
  clock and opaque payload, encoded as `ab::tx::PagedRows` writes it (u32 count then every row) —
  with the decode refusals for non-ascending keys, the codec's sequence and string caps and exact
  consumption. The reference builds a 290-row table through the real registry operations (out-of-
  order inserts, a rejected duplicate, ten erases, a mutate) and both sides reproduce 20 599 bytes
  with FNV 15354762378023838882 plus seven malformed-encoding verdicts. The suite now compares 207
  exact values (math 63, hashing 16, world 25, cache 46, checkpoint 39, entity 18). The in-memory
  page machine (256-row pages, split at 129, merge under 64, bulk fill 192) is documented rather
  than ported because it decides only page_count.
- Port Borg Agent's local-session ownership state (`borg/`). `src/session_state.grl` carries the
  owner record (`schema_version`, `pid`, `executable_identity`, optional `package_version` and
  `process_start_time`) through the JSON codec, the `dev:ino:len:mtime:mtime_nsec` executable
  identity, the `/proc/<pid>/stat` start-time parse, and the two decisions built on them: whether a
  recorded owner is still the same live process, and whether a stale owner may be retired. The
  rules are cited from `crates/borg-agent-runtime/src/local_control.rs:405-671` and reproduced
  exactly, including that a record which does not parse or carries an unknown schema counts as
  absent. Because `borg-agent-runtime` cannot be linked as a reference, `tests/parity/session.rs`
  carries those functions verbatim with citations, and `bun tools/borg-test.mjs --anchors` fails if
  the cited snippets disappear from the Borg checkout. The port now checks 603 reference lines over
  73 documents. Sockets, presence counting and process termination remain out of scope.

- Port Borg Agent's configuration loading (`borg/`). `src/toml.grl` parses and assembles the TOML
  subset Borg's configuration corpus actually uses — strings with escapes, integers in four bases,
  booleans, arrays, inline tables, `[table]` / `[a.b]` headers and comments — canonicalising keys
  into map order, materialising empty headers as empty tables, and rejecting a redefined header.
  Floats, dates, multi-line strings, arrays of tables and dotted inline keys are refused by name
  rather than approximated. `src/config.grl` loads `agent.toml` into effective settings with the
  defaults `crates/borg-cli` compiles in (`impl Default for CapabilityConfig`, `UsageCountConfig`,
  `PromptConfig`, `UpdateConfig`), and reports a wrong-typed key or negative count as an error at
  its path instead of falling back, and capability values are the effective ones: the dependent
  features are intersected the way `apply_dependency_intersection` does (`contract.rs:1403`). Two
  new reference suites compare against the `toml` 1.1.4 crate — the version Borg builds with —
  walking the same value model in the same order; the port now checks 483 reference lines over 50
  documents across JSON, protocol headers, TOML and configuration. Network, IPC and UI remain out of
  scope.

- Port Borg Agent's JSON substrate and runtime-protocol v1 envelope headers (`borg/`). `src/json.grl`
  parses and writes JSON with the exact semantics `crates/borg-*` rely on, measured against
  `serde_json` 1.0.151 with `arbitrary_precision`: numbers keep their decimal text (`1e+5`,
  `-0` -> `0`, 30-digit integers unrounded), objects canonicalise into `BTreeMap` key order with
  last-wins duplicates, strings use the minimal escape set, encoding is strict, and nesting stops at
  serde_json's 127-container limit. `src/wire.grl` validates the v1 header rule and reports the
  failing path and layer. `tools/borg-test.mjs` diffs both suites against committed references that
  `--regenerate` rebuilds from serde_json itself, so the port is checked against Borg's JSON rather
  than a restatement of it (187 reference lines over 31 documents). Command, event and snapshot
  bodies, and every network, IPC and UI concern, remain out of scope.

- Add `docs/platform-status.md`, an explicit matrix of executed, cross-built and scaffolded targets, so Windows PE output and macOS ABI headers are not mistaken for runtime support.
- Added an LSP MVP (`tools/lsp.mjs`): JSON-RPC over stdio with
  initialize/shutdown, didOpen/didChange/didClose and
  `textDocument/publishDiagnostics`. Diagnostics come from the compiler's
  existing `grail check FILE` output (`file:line:column: message`), mapped to
  UTF-16 LSP ranges with version and generation guards; the server never
  fabricates a language diagnostic and reports a missing compiler with
  `window/showMessage`. A real stdio test covers initialize/shutdown, an
  unknown request, a valid document, an invalid document and a didChange
  repair. CI runs the protocol tests in `tooling` and the compiler-backed
  session in a preflight-gated `lsp` job. Workspace checks, hover, definition,
  formatting, completion and pull diagnostics remain future work.
- Cross-platform tooling now treats `windows-x86_64` as a real **build-only**
  lane: `tools/ci.mjs build/test/package` cross-compiles the compiler to a
  PE32+ console image, verifies COFF objects, imports and image headers, and
  packages a zip whose manifest and `WINDOWS-BUILD-ONLY.txt` state that the
  Windows runtime is not implemented and the image must not be executed. The
  support matrix now distinguishes `supported`, `build-only` and `planned`,
  and every platform/lane reports `runnable` explicitly. CI also runs the
  runtime ABI contract suite (`tools/abi-test.mjs`) and the graphics C/shader
  suites, and the Windows x86-64 cross job is a required release gate for
  build/static checks. Windows AArch64 and macOS remain planned.
- Abundance CPU port, landscape-digest increment: `abundance/src/landscape_digest.grl` carries
  `terrain::landscape_world_content_digest` — FNV-1a from the standard offset basis over every byte
  the engine's landscape writer emits, plus the byte count — and the world envelope's `ABWLA001`
  branch is now exercised end to end. The reference builds a real landscape authority the way
  Abundance's own `tests/world_landscape_tests.cpp` does, writes its 721 840-byte serialisation and
  prints both the digest and `World::content_hash()`; the Grail side recomputes the digest from
  those bytes and reproduces the world hash that binds it. The suite now compares 104 exact values
  (math 63, hashing 16, world envelope and landscape digest 25).
- Abundance CPU port, world-hash increment: `abundance/src/world_hash.grl` carries the
  `World::content_hash` envelope — generator identity, configuration, twenty raster layers, drainage
  DAG, geology/province/biomes, material masks, provinces, caves, sites, regions, corridors and
  landform records — with the C++'s uneven count prefixes and eight-byte float widening preserved.
  `abundance/tests/parity/world.cpp` generates a real world with Abundance's own generator, dumps
  its inputs and prints `world.content_hash()`, so the Grail side reproduces a value `ABWCACH5`
  caches and `ABCP2` checkpoints bind, not a transcription of it. The suite now compares 99 exact
  values (math 63, hashing 16, world envelope 20); the terrain landscape-digest branch is recorded
  as the one unported branch.
- Abundance CPU port, hashing increment: `abundance/src/hash.grl` carries `fnv1a64` (with the
  seeded continuation form), the frozen world/checkpoint starting constant from
  `World::content_hash`, and its little-endian `absorb_byte`/`absorb_u64` accumulator. The reference
  is Abundance's own `tx/codec.hpp` plus a verbatim replay of `world.cpp`'s absorb loop, and all 16
  values match; the suite now compares 79 values across math and hashing. Standard-library SipHash
  is asserted to disagree so it cannot be substituted for an id or checkpoint hash.
- Abundance CPU port, first increment: `abundance/src/math.grl` carries the engine's CPU math
  contract (Vec3/Vec4/DVec3/Mat4, row-major multiply and transform, cofactor inverse, `look_dir`,
  reverse-Z infinite projection, camera-relative origin split). `just abundance-test` compiles the
  Grail module and diffs 63 bit patterns against a reference generated by compiling Abundance's own
  `engine/core/math.hpp`/`math.cpp`; every value matches. Documentation is in `abundance/README.md`.
- New design document `docs/design/abundance-port.md`: inventory of the Abundance portable core, own engine, Unreal host and shaders, their CPU/RHI boundary, the FFI/ABI requirements a Grail host would have to meet, and a staged port plan. Documentation only; no compiler or library behaviour changed.
- Graphics foundation (`graphics/`): a versioned C ABI for the render hardware interface and
  the shader pipeline, aligned with the Vulkan engine in Abundance. `grail_abi.h` defines
  64-bit tagged handles whose stale use is detected rather than dereferenced, status codes,
  capability bits and `{size, next}` descriptors. `grail_window.h` covers the SDL3 window,
  event drain and input; `grail_rhi.h` the device, queue timelines, resources, dynamic-rendering
  command buffers, deferred destruction and swapchain; `grail_bindless.h` the single set-0
  table and set-1 frame constants together with the Vulkan/D3D12/Metal mapping; `grail_shader.h`
  an offline reflection blob format, pipeline descriptors and permutation keys; per-backend
  headers state the Vulkan 1.3 feature floor, the D3D12 root signature and the Metal argument
  buffer requirements. `grail_wire.h` carries the same POD structures over a socket for a
  process that cannot link the RHI.

  The null backend implements every entry point and validates arguments, recording order and
  handle liveness without a GPU; `make -C graphics test` runs 219 checks with only a C
  compiler. Three HLSL stages compile offline with DXC 1.9.2609 and pass
  `spirv-val --target-env vulkan1.3`. Two binding facts are pinned by compilation rather than
  assumed: `register(xN, spaceM)` maps to Vulkan `DescriptorSet M`/`Binding N`, and push
  constants must use `[[vk::push_constant]]` because a plain `cbuffer` at `b0` would become a
  descriptor colliding with the sampled-image table. The offline shader tool and the real
  backends are not yet written; a Grail program cannot call any of this until the language has
  an FFI and non-`libc`-free linkage (`graphics/docs/first-renderer-port.md`).
- Cross-platform build/test/distribution foundation: a seven-platform CI matrix
  (Linux x86-64/AArch64/RISC-V64, Windows x86-64/AArch64, macOS AArch64/x86-64),
  host/SDK/QEMU detection, deterministic `tar.gz`/`zip` packaging with
  `SHA256SUMS` and provenance, POSIX/PowerShell installers, and secret-safe
  signing/notarization hooks. Linux lanes build and test; Windows/macOS lanes are
  explicit distribution scaffolding because the compiler still emits Linux ELF
  only. Tooling is documented in `docs/tooling/cross-platform-ci.md`.
- Added statically verified first-layer Windows and macOS backends for the OS ABI, using
  pinned Win32 and Darwin declarations so both compile for their targets without platform SDK
  headers. Implemented init/capabilities/error detail, clocks and sleep, environment
  get/set/unset/snapshot iteration, current directory and executable path, and file basics
  (open/read/write/seek/truncate/sync/close, pipes, mkdir/remove/rename; Windows also stat,
  macOS also non-blocking mode, readlink and realpath). Every unimplemented function is still
  an explicit `GRAIL_E_UNSUPPORTED` stub and the capability word advertises only the first
  layer. Added a shared environment store with host tests and separate `GRAIL_CAP_FILE_METADATA`,
  `GRAIL_CAP_FILE_NONBLOCKING` and `GRAIL_CAP_SYMLINKS` signals.
  `bun tools/abi-test.mjs` compiles each backend for `x86_64`/`aarch64` Windows and
  `arm64`/`x86_64` macOS and verifies all 95 public symbols with `llvm-nm`. These backends have
  not been executed on Windows or macOS; metadata, directory iteration, local time offsets,
  processes, sockets, threads and dynamic libraries remain fail-closed there.
- The Linux reference backend now implements the child-process contract with
  fork/execve/wait4: explicit argv/environment blocks, working directory, stdin/stdout/stderr
  wiring, PATH search, exec-error reporting through an error pipe, blocking and timed waits,
  SIGTERM/SIGKILL termination, process id and single-close handles. It also implements the
  first TCP/UDP socket subset: IPv4/IPv6 create/bind/listen/accept4/connect/send/recv,
  send_to/recv_from, shutdown, address queries, non-blocking mode, the documented socket
  options and blocking `getaddrinfo`, with negative-errno mapping and capability bits. Tests
  cover argv/environment/cwd/stdio, exit status, PATH search, timeout/terminate/kill, loopback
  TCP and UDP, options and DNS; the full Linux behaviour test is now 344 checks with zero
  tracked allocation bytes. Windows/macOS remain fail-closed. C-to-Graal callbacks remain a
  later FFI increment and allocator/thread callbacks stay backend-side.
- Added the child-process and socket/DNS contracts with explicit ownership, error and
  platform-search rules, plus fail-closed Windows and macOS backend skeletons. The Linux
  reference backend reports both domains as unsupported and clears their capability bits;
  a skeleton conformance test verifies that init fails closed, capabilities stay zero and
  representative entry points return `GRAIL_E_UNSUPPORTED`. Documented the full Win32/Winsock
  and libSystem/Mach mapping in `runtime/abi/README.md` and the safe Grail surface in
  `docs/design/runtime-api.md`.
- Added a hosted Linux reference backend for the OS ABI (an ABI oracle, not a Grail build
  path): startup/environment seeding and iteration, monotonic/realtime/CPU clocks and sleep,
  file open/read/write/seek/stat/sync/close, directory iteration, pipes, mkdir/remove/rename,
  current directory and executable paths, pthread threads (spawn/join/detach), mutexes,
  condition variables and `dlopen`/`dlsym`. Processes and sockets remain explicitly
  unsupported with clear capability bits. The end-to-end test verifies 165 checks and zero
  tracked allocation bytes at shutdown.
- Added the resource-domain headers for files/directories/pipes, environment iterators,
  native threads/mutexes/condition variables and dynamic libraries, plus a generation-checked
  handle table that rejects stale, double-closed and cross-domain handles. Contract tests
  cover 1000 handle allocations, reuse, foreign-table rejection and destruction; all headers
  parse for the five ABI targets.
- Added the lexical path contract (`include/grail/grail_path.h`) with one implementation
  for POSIX and Windows rules: absolute/relative detection, join, parent, file name,
  extension and normalization. Both rule sets are exercised on Linux, including drive-relative
  `C:` paths, UNC anchors and canonical `/` output.
- Added the cross-platform OS ABI contract under `include/grail/`: 64-bit scalar and pointer
  calling rules, opaque linear handles, version negotiation, allocator/startup records,
  portable error codes with raw OS detail, and strict UTF-8/UTF-16 helpers. Portable
  implementation and C tests cover version checks, every error mapping (errno, Win32, Mach),
  and Unicode rejection/round-trip cases. Linux, AArch64, RISC-V 64, Win64 and Apple ARM64
  header parsing is checked. Nothing is linked into Grail builds; `compiler/native.grl` and
  `runtime.grl` are unchanged.
  only. Tooling is documented in `docs/tooling/cross-platform-ci.md`; the
  LSP/debugger/profiler integration plan is in
  `docs/tooling/lsp-debugger-profiler.md`.
- Windows x86-64 programs now run: the runtime gained an OS layer
  (`compiler/os-windows.grl`) behind the existing operation IDs, and a new `raw_win32(Symbol, ...)`
  intrinsic emits Win64 calls with shadow space, register arguments and stack arguments. Console
  output, integer/float formatting, file write/read, exit codes and command-line arguments
  (via `GetCommandLineA`) work under Wine; allocation uses `VirtualAlloc` and the thread pointer
  reads TEB+0x28. The Linux syscall boundary moved to `compiler/os-linux.grl` so exactly one OS
  layer is compiled per target; `bun tools/windows.mjs check` executes eight PE cases under Wine
  when available, and the CLI resolves the OS layer next to the runtime (it still refuses to link
  PE images itself, pointing at the Windows tool). Threads, sockets, directory listing,
  `mremap` and `.pdata` unwinding remain unimplemented.
- New `windows-x86_64` target emits COFF-compatible x86-64 assembly for PE32+ console images:
  MSVC `.def` function records replace ELF symbol types, a `grail_entry` PE entry point replaces
  `_start`, process exit is an `ExitProcess` import and the allocation intrinsic maps to
  `VirtualAlloc` with TEB-based thread storage. `tools/windows.mjs` writes COFF short-import
  objects into `kernel32.lib` and links with `lld-link`; `bun tools/windows.mjs check` inspects
  the assembly, the COFF object and the PE image. The Windows runtime, `GetCommandLineA` argv
  recovery, worker threads and `.pdata`/unwind data are not implemented, so PE programs compile
  and link but must not be executed yet. Command-line option errors now print a diagnostic and
  exit 1 instead of aborting without output.
- macOS targets `macos-x86_64` and `macos-aarch64` emit Mach-O objects and executables: underscored
  C symbols, `.build_version`, `__TEXT,__const` literals, `__DATA,__bss` state, AArch64
  `@PAGE`/`@PAGEOFF` addressing and a `_main` entry that takes `argc`/`argv`/`envp` in the Apple C
  argument registers and exits through libSystem `_exit`. `compiler/darwin.grl` is the Mach-O
  platform module (`unsafe module runtime`, selected instead of `os-linux.grl`) and owns the
  libSystem boundary: file/console I/O, mmap and a `mremap` emulation, poll, pipe, mkdir/unlink,
  directory records, clock, sleep, yield, process control, plus Darwin flag-bit, `struct dirent`
  and `errno` translation. The runtime calls its `rt_call` bridge directly, so the compiler emits
  no Darwin-only symbols. Link with
  `ld64.lld -platform_version macos 11.0 11.0 -lSystem -e _main`; `bun tools/test-macos.mjs` checks
  the objects and executables statically. Threads, the async reactor and sockets report `ENOSYS` on
  Darwin, and no macOS runtime behaviour is verified without Apple hardware. Invalid `--target`
  values are now reported instead of aborting silently before any source is loaded.

- Native fixtures, inline regression programs and book examples now use typed references and
  explicit byte views under `--default-u64 --typed-refs`; user-mode cases retain `i64` defaults.
  Ownership/lifetime rejection fixtures use the modern dialect so they still test their intended
  safety checks; intentionally removed-syntax tests retain their invalid inputs. Closure capture
  discovery recognizes `&mut` expressions correctly, and typed borrows of captures retain their
  checked read-only storage frame.

- Compiler and standard-library source now uses typed `&value` / `&mut value` references,
  explicit `view` / `view_mut` byte views, and `&a [u8]` / `&a mut [u8]` signatures.
  `--typed-refs` separates the internal reference dialect from numeric defaults, which remain
  `u64` internally and `i64` for user modules. The normal regression corpus uses typed-reference
  mode; removed syntax is retained only as intentional rejection input. All checked-in bootstraps were refreshed
  and self-host byte-identically. Deferred
  generic and closure bodies restore their defining module's numeric and reference modes.

- Concise type syntax: `T[]` vectors, `u8[]` byte buffers, `T?` optional values and
  `[K: V]` maps. The `num` spelling is removed; user modules default to `i64`, while lengths,
  indices and byte counts are explicit `u64`. `Option`, `Result`, `Pair`, tuple syntax,
  `ref`, `ref_mut`, and the public map/option storage names are not exposed.
- Structural results use `S |? F`: success and failure alternatives are normalized
  separately, bare values convert implicitly, matching is exhaustive by type, and generic
  instantiation rejects overlapping or duplicate members. Ordinary `A | B` unions are
  unordered and carry no success/failure meaning. `?` and result-`!` apply only to `|?`.
- Prelude `Some(value)` and context-inferred `None` construct `T?`; typed patterns use
  `data: T` or a bare `T`, and nominal enum variant patterns remain available. Type aliases
  such as `type LoadError = IoError | ParseError` are supported.
- Function and method references use fresh input lifetimes. An elided output uses the borrowed
  receiver or the sole distinct input lifetime; distinct groups use free names such as `&a` and
  `&b` without a lifetime parameter list. Ambiguous outputs are rejected.
- `use module::Name;` imports a type or interface member. `use order::Ord;` resolves bounds
  and impls through the canonical `order::Ord` path instead of creating a local phantom.
- Read-only shared-reference parameters auto-borrow owned arguments at resolved call sites,
  including literals and owned views. `&mut` arguments remain explicit.
- The old `&mut a T` lifetime order is rejected in user modules; write `&a mut T`.
- The public `borrow`/`borrow_mut` builtins and `read<a>`/`mut<a>` view types are removed in user
  modules. Use `&value`/`&mut value` and `&[u8]`/`&mut [u8]`; compiler and standard-library
  source now use the same reference syntax.
- User-mode loops consume their iterable. Owned vectors move elements into the loop, enabling
  `for part in name.split(' ')` and named non-scalar consumption; loop-owned elements and the
  hidden container are cleaned on normal exit, break and return.
- Maps expose method-first operations: `len`, `contains`, `insert`, `get`, `get_mut`, `remove`
  and `entry`. Lookup methods borrow the key; `insert` consumes it and returns the previous value.
  `entry` returns a named `Entry<a, K, V>` view with a shared key and exclusive value. The free
  `hashmap::map_*` helpers are internal implementation details.
- Map expressions are concise: `[K: V]()`, `[K: V]::with_seed(s0, s1)`, `[k: v]`, and
  context-only `[:]`. `map[key]` is a required place that aborts on a missing key; assignment
  upserts; compound assignment updates an existing key; `get`/`entry` remain optional. Indexed
  assignment currently accepts named or field receivers, not call-result receivers.
- User modules reject `usize`, `core::some` and `core::none`; use `u64`, `Some(value)` and `None`.
- Checked-in x86-64, AArch64 and RISC-V64 bootstraps were refreshed from the v2 compiler and
  independently self-host byte-identically; the published-bootstrap suites pass on x86-64.
- Nominal concurrency types are capitalized: `Atomic<T>`, `Mutex<T>`, `Scope<C>`, `Task<R>`
  and `CancelToken`, with `Atomic::new` / `Mutex::new` constructors.
- Type syntax is now postfix and concise: `T[]` is a vector (`vec<T>` is gone), `u8[]` is the
  byte buffer (`bytes` is gone), and `T[...]` / `T[]` are the element and empty literals. A type
  may be parenthesized when its literal needs one, e.g. `(fn(num)->num)[f]`. The byte-buffer
  literal rejects elements above 255. Compiler, standard library, book, examples, tests, docs and
  the checked-in bootstrap have all been migrated; `grail fmt` understands the new spelling.
- `grail fmt` breaks long lines the way rustfmt does: a match arm moves its body after `=>`,
  binary operator chains break before each operator, postfix chains put one `.method()` per
  line, and bracket lists put one item per line. Record literals expanded this way also take a
  trailing comma, which the language accepts there (call arguments, parameter lists and generic
  arguments reject one, so they stay comma-free). The formatter is still token-level and
  idempotent; formatted sources compile to byte-identical assembly.
- Faster generated code: inline `push` fast path (growth only calls the runtime, large buffers grow in
  place with `mremap`, fresh memory is not re-zeroed), inline sized-integer arithmetic, comparisons
  and division, bounds checks dropped in `for i in v.len()` loops that cannot change `v`, and
  inlining of small leaf functions. A 5M-element sieve runs in 83 ms (was 207 ms), an `i32` loop in
  0.17 s (was 4.7 s).
- `bytes` and `string` store one byte per element instead of one word; the compiler's own peak memory
  for self-compilation drops from 1.5 GB to 0.18 GB.
- `mut` literal bindings take the type of their first sized use anywhere in the function
  (`mut count = 0; count += 1; show(count)` with `show(level: u8)`); the function is recompiled with
  that type. Conflicting uses are rejected.
- Equality on structs, enums and vectors containing `char` works.
- Indexed assignment: `v[i] = x`, `v[i] += x` and `s.items[i] = x` on vectors (the old element is
  dropped) and `buf[i] = b` on bytes; the right-hand side is evaluated first.
- `f32` closures and function values accept float literal arguments; exponent-only float literals
  (`1e9`, `2E-3`) are accepted.
- Optimized code generation: a per-function optimizer (`compiler/optimize.grl`) forwards stack
  slots through registers, removes dead stores and moves, keeps hot variables in callee-saved
  registers, fuses compare-and-branch sequences, turns division by powers of two into shifts and
  inlines bounds-checked element access. On x86-64 a Collatz loop runs in 213 ms instead of 620 ms
  (Rust -O: 85 ms), a 5M-element sieve in 207 ms instead of 689 ms (Rust -O: 33 ms), and the
  compiler builds itself in 15 s instead of 27 s. All three targets share it; output stays byte-identical on self-compilation.
- `borrow(...)`/`borrow_mut(...)` accept temporaries (`borrow(make())`, `borrow(v.len())`,
  `borrow(Point { x: 1, y: 2 })`); the value lives until the end of the enclosing block.
- In `match borrow(x)`, the borrow ends at the last use of the payload references, so an arm may
  then modify `x`.
- Unsuffixed literal bindings infer their type from later use: `n := 5; takes_u8(n)` works, and
  `mut sum = 0; sum += x_i32;` makes `sum` an `i32`. Float literal bindings adopt `f32` the same way.
- New `f32` type (`1.5f32`, contextual literals, `f32(x)`, arithmetic rounded to binary32, shortest
  round-trip printing identical to Rust) and `char` type (Unicode scalar values, `'é'`, `'\u{1F600}'`,
  `chars()`, `push_char`, `char(n)`, `u32(c)`, comparisons, `match`, classification and case
  methods). ASCII literals like `'a'` stay byte values unless a `char` context adopts them.

- References to `bytes`/`string` coerce to views (`read<a>`) in calls, like `&String` to `&str`.
- `parallel_map` accepts closures; realistic sample programs (CSV report, inventory CLI, parallel primes) join the test suite.
- Text operators read through references (`words[0] == "GET"`); clearer error for borrowing a temporary.
- Recursive data types (`enum Tree { Leaf, Node(Branch) }` with `Branch` holding `Tree`) are supported.
- `borrow(v[i])`/`borrow_mut(s.items[i])` borrow vector elements; calculator and binary-tree sample programs.
- `to_upper`/`to_lower` map Latin-1, Latin Extended-A, Greek and Cyrillic letters; word-frequency sample program.
- JSON parser/printer and HTTP server/client sample programs join the test suite.

- Add tuples (`(num, bytes)` types, `(a, b)` values, `t.0` access, `(q, r) := f();` destructuring,
  Debug-style printing), `match` on integers/bytes/bools with literal, range (`0..10`), binding and
  guard (`n if n > 3`) patterns, `_` default arms for enum matches, typed bindings
  (`mut total: i32 = 0;`), `for p in borrow(v)` over non-scalar elements, closures inside generic
  functions, dot-call syntax for implemented interface methods, hex/binary/octal literals with `_`
  separators, `f64` constants, and contextual literal typing for returns, assignments and vector
  literals.
- Formatting: width/fill/alignment specs (`{:>8}`, `{:*^9}`, `{:05}`, `{:8.2}`), Rust-Debug-style
  printing of vectors and tuples. Diagnostics show the source line with a caret; missing input
  files are reported. `grail check` type-checks without building.
- Libraries: `math` (exp, ln, log2, log10, sin, cos, tan, atan, atan2, pow, round, ... within 1 ulp
  of Rust's std except pow), insertion-ordered `hashmap` with `key_at`/`value_at` iteration,
  `order::Ord` with a stable generic `vecs::sort`, Unicode `strings::chars`/`push_char`,
  `replace`/`repeat`, `env::args`/`env::var`, `process::exit`, and typed `io::Error` results from
  `fs` (`read_text`, `create_dir`, `remove_file`, `remove_dir`, `list_dir`).
- Text: `==`/`<` comparisons and `+` concatenation for strings, bytes and views; built-in
  `trim`, `split`, `contains`, `starts_with`, `ends_with`, `replace`, `repeat`, `to_upper`,
  `to_lower`, `is_empty`. Vectors: `insert`, `remove`, `swap`, `reverse`, `truncate`, `clear`,
  `contains`. Borrowing a method result now gives a clear error. Book: Working with text,
  Collections, Tuples and patterns chapters.
- Structural `==`/`!=` for structs, tuples and enums (including `Option`/`Result`).

- Add `f64`: correctly rounded literals, IEEE arithmetic and comparisons in hardware on x86-64,
  ARM64 and RV64 (RISC-V now assembles for `rv64imafd`), checked conversions, `sqrt`/`abs`/`floor`/
  `is_nan`, and shortest round-trip printing identical to Rust's `{}` (checked on 408 values), and `{:.N}` fixed
  precision with exact half-to-even rounding. Compound assignment works on all integer types and f64.
  Add `Option`/`Result` methods (`is_some`, `unwrap_or`, `map`, `ok_or`, `is_ok`, `ok`, ...).

- Add inherent methods (`impl Type { ... }`, including generic `impl<T> Stack<T>`), method calls on
  variables, fields, references and temporaries, `Type::function` associated functions, enum
  methods with `match` through references (payloads bound as references), `show()` for printing
  user types, formatted `print`/`println("{} {}", a, b)` and `format(...)`, `if let`, `while let`,
  `else if`, `loop`, `for i in a..b`, module `const` values, byte character literals (`'a'`),
  struct field shorthand, and the `vecs`/`strings` libraries. Book: Methods and Printing chapters.

- Add sized integers (`u8`..`u32`, `i8`..`i64`) with literal suffixes, contextual literals,
  checked/wrapping/bit conversions and signed arithmetic; `bool` with `&&`/`||` (short-circuit) and
  `!`; the operators `>`, `<=`, `>=`, `|`, `<<`, `>>`; and capturing closures `|x: T| -> R body` of
  type `Fn(T) -> R` that copy or move their captures. Diagnostics now report `file:line:column`.
- Add `for x in v` over scalar vectors and byte sequences, TCP sockets on the colourless reactor
  (`host::tcp_listen/accept/connect`), recoverable file errors (`lib/fs.grl`: `fs::read`/`fs::write`
  return `Result`), `?` across Result types with the same error type, and lex `x!==y` as unwrap
  then `==`.

- Add the `grail` command-line tool in the compiler binary: `build`, `run`, `test`, `fmt
  [--check]`, `new`, `add` (git dependencies pinned in `grail.lock`) and `fetch`, plus
  `just install`. Add a comment-preserving, idempotent rustfmt-style formatter whose output
  compiles to byte-identical assembly. Existing compiler invocation is unchanged.

- Add structured task scopes (`task_scope`, `spawn`, `join`, `cancel_token`) and colourless
  suspension: tasks are stackful green threads on a worker pool with an epoll reactor; pipe I/O
  and sleeps suspend only the calling task, blocking file/process calls move to offload threads,
  and cancellation wakes waiting tasks. Handles cannot outlive their scope; dropping one never
  blocks. Processes now exit with exit_group. Verified on x86-64, ARM64 and RV64.

- Add real multi-threaded structured parallelism: `parallel_map(items, context, f)` runs on
  clone-based worker threads with dynamic work claiming and joins all workers before returning;
  Send/Share/borrow rules are checked. Add futex-based `mutex<T>` with lock-scoped `lock_with`
  access whose loans cannot escape, keyed SipHash-2-4 `hash` interfaces, a checked
  `hashmap::Map` and a sharded `concurrent_map::Map`. Verified on x86-64, ARM64 and RV64,
  including a barrier proving simultaneous execution and contention tests. Closures, cancellation
  and colourless suspension remain unimplemented.

- Add explicit user-defined interfaces, concrete implementations, checked generic bounds and
  static method dispatch, including module-qualified calls and method values. Check ownership
  and lifetime contracts; reject overlapping/orphan implementations and unsafe-runtime exposure.
  Generic interfaces, associated types, blanket implementations and dynamic dispatch remain absent.

- Add typed capture-free function values (`fn(T)->U`), generic callbacks, returned function
  values, indirect calls and explicit generic function items (`identity<num>`). Preserve
  callable lifetime/return-origin contracts; capturing closures remain in progress.
- Add checked structural `T:Send+Share` bounds and opaque `atomic<num>` with sequentially
  consistent operations, explicit valid load/store orderings and modular fetch arithmetic.
  Atomic receiver loans prevent argument evaluation from moving or replacing their owner.
  ARM64 uses exclusive operations/barriers; RISC-V now explicitly requires RV64IMA / LP64.
- Serialize runtime allocation and prepare executable paths before fork, keeping allocations
  and locks out of the child. Runtime file descriptors are close-on-exec. These are concurrency
  prerequisites, not a claim that worker tasks or colourless I/O are implemented.

- Audit all 32 Rust/Grail book pairs: remove unnecessary entry-module headers, use current
  collection literals, pair separate module files in both languages, align fail-fast I/O behavior,
  exercise Unicode argv byte lengths, and clarify ownership, truth-value and arithmetic differences.
  Rust verification now explicitly enables overflow checks and abort-on-panic; supporting modules
  require a checked counterpart instead of displaying an unpaired Grail-only snippet.

- Make the Grail-written compiler the sole language implementation: remove the Rust seed and
  unchecked C compiler/runtime/bootstrap, migrate maintained examples/library sources and 149
  language regression cases, and replace duplicate compiler tests/builds with seed-free tooling.
- Add direct ARM64 and RISC-V 64 Linux assembly lowering alongside x86-64, native syscall/ABI
  handling, target-default self-hosting, executable cross tests and verified compressed bootstraps.
  Add explicit `--target` selection and `--overflow=checked|wrap`; wrapping opts out of user
  arithmetic checks only, retaining runtime allocation/arithmetic, bounds and ownership guards.
- Extend the book runner to native/cross Linux targets without a Rust seed or C backend. CPU
  support does not imply macOS or Windows support; those operating systems are not implemented.

- Unify collection expressions: add `bytes[...]` / `vec<T>[...]` literals and postfix `.push`,
  `.pop`, `.len`, `.copy`, `.text` and string `.append`; use `[i]`, `&v[i]` and `&mut v[i]`
  for vector access as well as byte indexing. Remove old free collection helpers. Add reserved
  `true` / `false` truth literals and bare uppercase generic parameters (`identity<T>`, `replace<a,T>`),
  retaining checked ownership and universal generic-body validation. Method-statement argument
  temporaries end at the full statement. Migrate the book and compilers.

- Unify mutable declarations and borrowing around `mut`: replace `var` with `mut`, and byte-view
  `read(x)` / `mut(x)` with `&x` / `&mut x`. Replace `at` and `slice` calls with byte indexing
  `x[i]` and half-open `x[start:end]`, including omitted bounds. Indexing automatically borrows
  byte storage readonly and preserves borrow, evaluation-order and bounds checks. Migrate the
  maintained compilers, examples, tests and book; remove old builtin routes and regenerate bootstraps.

- Complete Rust comparisons for all 32 book examples, including control flow, modules, arguments,
  files and commands. Require comparison coverage and verify independent Rust arguments, fixtures
  and file outputs in isolated scratch directories.

- Make ordinary `num` addition, subtraction, multiplication and powers (including compound
  assignments) abort on overflow/underflow in every build profile across native, C and LLVM.
  Add explicit `wrapping_add`, `wrapping_sub`, `wrapping_mul` and `wrapping_pow` operations;
  migrate modular hashes and syscall error handling, update the book and regenerate both bootstraps.

- Replace `let` with immutable `:=` declarations and require `mut` for owned-storage mutation
  and mutable borrowing. Fixed explicit mutable capabilities may still write their referents.
  Migrate the maintained Grail compilers, source fixtures and book; regenerate both bootstraps.
- Add unsigned division, wrapping right-associative `**`, and numeric compound assignments
  `+=`, `-=`, `*=`, `/=`, `%=` and `**=` across native, C and LLVM lowering. Keep `^` as XOR;
  guard zero divisors and retain target capabilities through right-hand-side evaluation.
- Update the book to 32 checked Grail examples and 26 Rust comparisons. Default to light mode
  and globally visible Rust, remember explicit reader choices, remove decorative labels, and
  fix the comparison control wrapping across the header corner. Use plain truthy assertions.

- Add a quiet named `main`, optional unit result/final return and optional entry-file module,
  plus `print`/`println` with checked call-local borrowing and numeric output. Numeric main results
  set process status rather than being printed. Preserve the live numeric bootstrap test protocol;
  verify seed/native parity, owner reuse after printing and implicit-return cleanup.
- Add Grail by Example: 20 chapters, 32 verified Grail examples and 26 collapsible Rust comparisons,
  with aligned code/output workspaces, offline search, copy buttons, themes and mobile navigation.
  `just book` builds and opens the static book; companion recipes verify examples and tooling.

- Add invariant captured-storage assignment/replacement, captured vector updates and caller-side
  guard propagation, including generic `replace<T>`. Retain opaque local frame witnesses and
  attach new captures to their real storage owners. Ignore retired access-capability history
  after reassignment while preserving live-loan checks and branch restoration. Opaque external
  writes lacking a recoverable invariant contract remain conservatively rejected.

- Add native generic functions with inferred/explicit type arguments, cross-module specialization,
  regular recursion, and lifted capture lifetimes. Validate unused templates and keep opaque `T`
  affine even in numeric specializations; reject unsupported operations rather than exploiting
  the concrete instantiation.

- Add native generic records/enums with explicit and inferred constructor arguments, nested and
  borrowed type substitution, nominal argument checking, and specialized recursive destruction.
  Keep constructor and call-argument captures live during later argument/field evaluation,
  including nested calls.

- Connect native source-level loan/lifetime enforcement: reject live-borrow moves/growth/writes,
  escaping locals and captures, lifetime laundering, suspended unique carriers and malformed
  aggregate/reference operations. Retain concrete lifetime guards across opaque calls and copies;
  end loans at lexical last uses without confusing shadows, field names or loop iterations.
- Add positive seed/native borrow conformance and adversarial rejection cases, including opaque
  interior-reference returns and descriptor-copy provenance. Native stages reproduce exactly and
  normal exits require zero live allocations.
- Return large allocation arenas to the OS immediately; verify unmapping with `mincore` in the
  Grail runtime audit. Validate UTF-8 text construction/appending in the Grail runtime.

- Preserve native lifetime arguments and reference mutability; add type-shape checks and a
  Grail ownership graph with field-sensitive moves, loan authority and conservative joins.
  Wire move/initialization checks into source compilation, rejecting moved/uninitialized values,
  conditional moves and repeated consumption on backedges/continue, without replacing a prior
  artifact on rejection.
- Generate guarded recursive cleanup for native owned values, including partial fields, vectors,
  enum matches, returns, propagation and loop exits. Transfer ownership explicitly on moves and
  close consumed host-call descriptors. Require zero live allocations at normal program exit;
  native self-compilation and cleanup fixtures pass that check and reproduce their output.

- Replace native runtime support with `compiler/runtime.grl`: allocator/free lists, byte and
  sequence operations, file I/O, PATH search, process execution and numeric printing are Grail.
  Generated `_start` and narrow raw-memory/syscall intrinsics produce a static `as`/`ld` build,
  without C support objects, libc or a handwritten assembly runtime. Restrict raw intrinsics to
  an explicit unsafe runtime module. Verify native self-reproduction, binary I/O/command status,
  allocator reuse and balanced runtime allocations. Preserve the older C bootstrap only as an
  independent cross-check.

- Add a Grail-written Linux x86-64 backend (`compiler/native.grl`) emitting assembly directly,
  with System V calls, stack-slot locals, unsigned arithmetic, control flow, aggregates, typed
  references and the existing runtime ABI. Deliver reproducible `compiler/bootstrap/native.s`;
  native stages 2/3 are byte-identical. Verify both bootstrap routes, existing C artifact replay,
  differential programs and native abort paths. Runtime support is compiled separately from C;
  ownership checking, freeing and optimization remain unfinished. See `compiler/NATIVE.md`.

- Reach bootstrap v0: `compiler/grailc.grl`, a Grail-written compiler to C, is built by the seed
  and reproduces itself byte for byte (stage 2 = stage 3). Commit the stage-2 output as
  `compiler/bootstrap/grailc.c` with its runtime `compiler/grail_rt.c`, and check both plus
  seed-equivalent behaviour on examples in `bootstrap_native`. `grailc` does not check ownership.
- Fix seed liveness across `break`/`continue`: values read after a loop are no longer pruned when
  later body statements reassign them. Checker errors now include the function and register.

- Add generic owned `vec<T>` with push/pop/get and `std/collections.grl`; a trusted `host` module
  (argc/arg, read_file, write_file, print, command) for compiler drivers; and the first Grail-written
  compiler module, `compiler/lexer.grl`, returning borrowed tokens.

- Join conditional owned bindings/fields with definite-use checking and guarded native cleanup.
  Keep untouched fields usable, support consume-then-break exits, and reject repeated consumption.
  Checked IR/template bundles advance to schema 3; native O0/O2 ASan/UBSan paths are covered.
- Preserve all possible old captures when an opaque mutable reference can select multiple cells;
  precise single-target replacement still releases old captures. Add alias regression and native checks.

- Join retained local/external capture sources across branches and loop fixed points instead of
  requiring identical metadata. Recheck later iterations, separate break exits from backedges,
  preserve while-condition effects on zero-body paths, and normalize only dead temporary ancestry.
  Keep stored lifetime/capability bounds and reuse unchanged indexes. Validate hidden Option-pop /
  mixed-exit modules, C/LLVM execution, destruction, independent Rust, frozen replay and costs.
  Conditional moves/partial initialization, general heap collections and self-hosting remain unfinished.

- Admit captured mutable referents with invariant lifetime witnesses, universally checked generic
  storage operations and signature-derived opaque capture writeback. Preserve old/incoming sources,
  distinguish unique transfer from short reborrow, filter nested typed targets, and retire internal
  captures without losing external loans. Remove the temporary plain-kind machinery; use canonical
  IR/template bundle schema 2 with checked ascriptions. Close a reproduced stale external-cell proof
  across loop edges; general changing-state joins remain required. Validate hidden-source mutable
  cursors, generic Option pop/Result cleanup, mixed backends, independent Rust, allocator/sanitizer
  traces, frozen replay and measured costs. General heap collections and self-hosting remain unfinished.

- Support readonly typed references to captured values: distinguish dereferenced stored-source roots
  from outer frames, derive outlives constraints from written inputs and copy shared descriptors
  without extending unique-field reborrows. Check nested return bounds, preserve captures under
  live frame loans, emit proper nested const pointers and execute descriptor loads in C/LLVM.
  Retain hidden-source cleanup, independent Rust, frozen replay and cursor-token costs. Mutable
  capture witnesses/invariance/writeback, real general containers and self-hosting remain required.

- Add typed storage references for lifetime-free referents: explicit place borrows, indirect scalar
  loads, generic/core replacement, owned descriptor/record mutation and C/numeric LLVM lowering.
  Keep addressed scalar storage alive, enforce indexed field/storage exclusion and preserve owned
  relocation/recursive drop flags. Expose reference kind requirements in universal signature/body
  checking, uniformly refresh opaque mutable cell metadata and test source-hidden mixed-profile
  execution/free traces. Keep borrowed loop-entry values live across nested expression blocks,
  fixing a backedge rejection exposed by the mutable-state scanner. Captured-reference
  invariance/witnesses/writeback, general containers,
  remaining joins and full bootstrap/self-hosting are explicitly unfinished, not passed gates.

- Implement universally checked affine generic function bodies and static native specialization,
  inferred/explicit calls, eager snapshots and statement-end expression cleanup. Ship real Grail
  core Option/Result/Pair helpers, recursive calls, canonical rechecked IR/private helper closures,
  lifetime-erased layout-sensitive instance keys and bounded memoization. Bind IR in artifact schema
  2 / module schema 5, separately pin transitive generic implementations and reject stale/malformed
  consumers while preserving prior executables. Retain mixed-backend/independent Rust/cleanup and
  frozen-compiler checks plus token-workload costs. Typed-reference invariance/writeback, arbitrary-T
  heap collections, ownership joins, the real seed port and self-compilation remain unfinished.

- Implement checked `break`/`continue` for counted/while loops, including blocks, nested loops and
  matches. Close local loans and recursively drop local owners before jumping; preserve entry
  resources/scalar definedness and emit explicit C/LLVM targets/latches. Test source-hidden calls,
  unique-parent reactivation, complete release traces, condition-evaluation counts, mixed native
  profiles and a frozen 1,600-case replay. The existing conservative entry ownership invariant
  remains; general conditional ownership joins and full v0/self-hosting are not claimed complete.

- Add the actual `clang-release` native driver profile (`-O2`) while preserving default `clang`
  (`-O0`) and TinyCC. Check source-hidden generic/owned programs, relocation and byte-reproducible
  objects/executables, mixed-profile ABIs, runtime aborts, malformed UTF-8 and concurrent artifact
  publication. Retain real-driver scanner build/runtime costs and independent checksums; full
  executable recipe manifests, hermetic toolchain packaging and stage-2/stage-3 remain unfinished.

- Implement public generic record/enum value layouts and real type-only modules, including a
  `core` library with `Result<T,E>`, `Option<T>` and `Pair<T,U>`. Substitute nested type/lifetime
  arguments without rebinding inserted lifetimes; preserve ownership, origins and error propagation.
  Replace the name-only layout walk with concrete instance ordering; erase lifetime values from
  native instance keys, not modes/shapes. Bound producer/consumer codecs (module 4 / function 6),
  reject old artifacts without compatibility branches, and validate source-hidden native composition,
  recursive cleanup, mixed clang/TinyCC ABIs, invalidation, independent Rust results and costs.
  Generic functions, general typed references/containers and self-hosting remain unfinished.

- Retain a generic-lowering comparison across native development/release profiles with real
  source-token/owned-node workloads, instance counts, independent checksums and lifetime controls.
  Select an initial static-specialization implementation while preserving evidence for shared code;
  document eager snapshots, invariance, outer-loan limits and opaque mutable writeback requirements.
  This is preimplementation evidence, not delivered Grail generics or general typed references.

- Remove cumulative scalar/type-map cloning from the checker: share a monotonic function-local
  type ledger, retain scalar definedness in a compact bitmap and prune only dead scalar values.
  Correct match/if live-in definitions without changing loan/owner cleanup. Frozen-compiler
  differential checks retain identical acceptance/C/interfaces; three-run 1,000-site medians improve
  from 406 ms to 4.2 ms (branches) and 1.69 s to 12 ms (`?`), without an ABI/schema change.

- Implement postfix `?` for Result/Option-shaped enum propagation by lowering to independently
  checked match/return operations. Preserve success payloads, transfer matching errors/None and
  clean remaining owners on failure, including earlier call arguments and loop conditions. Test
  hidden-module composition, mixed native backends, complete release traces, side-effect retention
  and Rust controls; no rollback, implicit error conversion, or additional exception runtime.

- Implement tagged enums, exhaustive consuming match, unit values/interfaces and postfix `!`
  unwrap-or-abort for Ok/Err and Some/None shapes. Transfer only the selected payload; recursively
  destroy active owned leaves without reading inactive union data. Validate borrowed token/owned
  error APIs, recoverable u64 parsing, modern Rust controls, allocation/free behavior, variant-layout
  invalidation and clang/TinyCC ABIs in both directions. Use module schema 3 / function schema 5;
  previous artifacts rebuild. Generic payload parameters, richer patterns and `?` remain unfinished.

- Check early returns through branches/blocks/loops, emit path-local recursive cleanup before each
  return, and preserve only continuing ownership states at joins. Equal partial-move states can join;
  unmatched continuing states still diagnose. Validate C/TinyCC objects with hidden-source record
  calls, allocator balance/free order, and primitive LLVM terminators; retain modern Rust controls
  and seed checking-cost measurements. Record destruction does not access captured descriptors.
- Choose postfix `!` for Result/Option unwrap-or-abort and reserve `?` for propagation; syntax is
  documented but awaits the actual enum/Result implementation, not an error-only parser stub.

- Establish the Grail research workspace and living architectural design record.
- Record `.grl` as the agreed source-file extension.
- Add an initial source-backed comparison, provisional semantic core, syntax sketches,
  and falsifiable experiments. No compiler implementation or verified Grail programs yet.

- Add a source-backed memory-model competition; keep persistent external borrowing and access syntax
  open, assess lexical capability contexts, and make zero-copy APIs/diagnostics explicit design gates.

- Record targeted V lessons and caveats for ownership, ergonomics and fast-build architecture.

- Add isolated executable ownership probes, zero-copy representation measurements, and a synthetic
  generic-compilation experiment with raw data and source/toolchain provenance.
- Correct Hylo research to distinguish the former compiler from `hylo-new`, and qualify Goose
  specialization claims using observed root-class reuse. No Grail compiler implemented.

- Add a bounded typed-IR origin/capture inference experiment, imported contract composition, isolated
  client checking and adversarial tests. Contracts are not independently proof-certified.

- Stress-test origin/capture contracts against separate finite dependency and allocation-epoch models.
- Measure generic forwarding, source-set growth and root-indexed client lookup; document unsupported
  ownership/effect features and the trust limit of schema-valid but dishonest contracts.

- Record assessment of the external Opus design review, checked prior-art updates, and unresolved
  public-contract and scoped-exclusivity choices without treating peer recommendations as decisions.

- Add isolated Quint effect/cancellation experiments and distinguish sampled counterexamples from
  verification; record version-matched source provenance and design lessons.

- Record evidence-backed Haskell successes/costs, retention and inference lessons; distinguish
  community pain reports from causal adoption/performance claims.
- Add Swift/OxCaml/Mojo ownership findings and inspected Quint Connect adapter boundaries.

- Assess the external rooted-value proposal without merging it; add six isolated Rust probes for
  cache-reset and callable/thread-sharing distinctions, and identify mutation/cleanup contract gaps.

- Add a bounded pre/post dependency-state experiment for generic append, clear, replacement, old-value
  returns and disjoint-place updates, with independent concrete comparisons and body-hidden clients.
- State the restricted preservation obligation and expose the remaining forged-artifact trust gap;
  no full memory-model, allocation-reuse or runtime-performance claim follows.

- Exhaustively explore finite error-cleanup models with separate user handles and scope-owned work;
  expose premature buffer release and incorrect all-on-one-acknowledgment policies.
- Record status-specific liburing cancellation guarantees and distinguish storage safety, resource
  discipline, cleanup effects and bounded progress. No actual device/runtime verification claimed.

- Add eighteen isolated Rust/Yoke/self_cell probes for Bundle projection, variance, owned ASTs,
  inline-owner stabilization, external dependencies and dependent-before-owner destruction.
- Distinguish scoped covariant field projection from whole invariant-container escape; document
  candidate Bundle rules and explicit allocation choices without adopting a language primitive.

- Distinguish owner lifetimes, carrier loans, authority transfer and temporary reborrows with fifteen
  isolated Rust probes and bounded interval/cell permission comparisons.
- Record minimal construction/permission proof obligations and Aeneas/Hylo precedent; do not infer
  that extra public lifetime syntax, a runtime loan graph or a full checker is required or implemented.

- Test delayed call activation against nested argument effects, early dependency snapshots,
  materialized storage views and copied-view aliasing, with five Rust reference probes.
- Document stable-place premises and unresolved selector/address/bounds-check timing; no frontend
  implementation, general safety proof or bug in the older restricted IR is claimed.

- Add a pinned, isolated Lean preservation core for pure shared-data dependency state, public-bound
  composition and conditional tracked-root validity, with checked counterexamples and axiom reports.
- Consolidate distinct shape/support/authority/activation/cleanup obligations; explicitly exclude
  earlier artifact certification, physical ownership/alias safety and full-language verification.

- Prove symbolic pre-source substitution commutes with the restricted core analysis and preserves
  public bounds under arbitrary overlapping/empty source images; check the one-entry-snapshot boundary.
- Record separate-module proof provenance and standard quotient-soundness dependencies; do not claim
  physical alias safety, structured generic-route correctness or a certified artifact pipeline.

- Add eight checked structured-route targets for suffix-preserving opaque payload forwarding,
  root substitution and dependency-subtree replacement; extend the existing runner to three modules.
- Keep shape-substitution validation, Python implementation correspondence and physical disjointness
  explicit open premises rather than inferring them from dependency-path separation.

- Prove successful dependency-shape projections survive substitution and same-T prefixes have
  compatible descendants; connect that premise to structured forwarding in a restricted model.
- Check counterexamples for newly revealed opaque paths and different-variable incompatibility;
  keep full source typing, parser/unifier correctness and mutable referent state outside the claim.

- Add eleven isolated Rust referent-state probes and complete finite exploration of five single-cell
  policies, including retained-old-value and temporary-source controls.
- Distinguish storage lifetime, current contents and writeback; record two precise ghost-state styles
  and Aeneas precedent without claiming a general mutable-reference checker or runtime graph requirement.

- Add seven pinned Rust generic/resource controls for ownership forwarding, skipped/destructor
  effects and scoped work; retain an expected bounded stall separately from completed executions.
- Record public-source-matched scope accounting and distinguish root captures, logical loans,
  destructor effects and ambient work obligations without adopting safe forget or Rust's runtime ABI.

- Test target coverage beyond lifetime validity with five Rust cases and 2,140 finite transfer/write
  combinations; distinguish conservative weak updates from unsupported strong may-target updates.
- Add six conditional coverage/post-bound Lean targets with explicit logical dependencies; retain
  target-provenance, producer checking and full ownership/erasure composition as separate obligations.

- Prove may/must interval refinement polarity and test 7,380 interval pairs plus a toy stale-cache
  acceptance when coverage guarantees are omitted from dependencies; no production compiler cache claimed.
- Keep body-contract truthfulness, memory-interface invalidation and value/code proof dependencies
  separate; make the transfer smoke check report the actual shared proof-corpus target count.

- Start a dependency-free Rust typed-IR seed with explicit signature regions, affine views,
  carrier reborrows, guarded C/LLVM lowering and body-hidden interface tests. The first scan-based
  checker is a measured baseline, not the final algorithm or a complete language implementation.

- Replace repeated live-value scans with indexed origin/parent-loan checks in the Rust seed;
  preserve owner/authority checks across carrier moves and shared-view ending.
- Add reproducible paired checker, native backend and module-edit measurements with an independent
  checksum oracle, raw CPU/RSS/commands and explicit limits. Retain TinyCC as a measured development
  candidate, without claiming full-language performance, soundness or self-hosting.

- Freeze bootstrap-v0 decisions and add the first `.grl` source-to-native path: borrowed-token
  parsing, explicit signature regions, inferred local loan endings, counted loops, numeric branches,
  guarded byte slices/writes, imported interfaces and clang/TinyCC source builds.
- Add a two-module zero-copy decimal-token parser and source/native safety checks, including
  hidden producer source, wrong-region/local escapes, live-child write conflicts and abort guards.
  Heap containers, general generics, Result and self-hosting remain unimplemented.

- Add owned heap byte vectors, explicit deep copying, geometric growth and owned parameter/return
  transfer in the C backend. Reject growth/movement while borrowed and insert reverse lexical owner
  cleanup separately from last-use loan ending. Bump seed interfaces to schema 2.
- Validate heap cleanup and reverse drop order with independent allocator wrappers, including loops,
  clones and returned owners. LLVM comparison explicitly rejects unsupported heap layouts.

- Audit stable and pinned modern Rust (2026-10-29 nightly) with Polonius/next-solver flag isolation:
  conditional reborrows and get-or-insert now pass; stored-referent replacement/restoration still
  reject in the tested forms. Correct the comparison baseline without claiming a soundness proof.

- Add owned UTF-8 strings, validated literals/escapes, checked text copying and append, while
  rejecting raw byte mutation and growth under live views. Bump seed interfaces to schema 3.
- Differentially validate text construction on 26 byte sequences through clang/TinyCC, including
  malformed encodings, and exercise owned string calls/returns across a hidden-source boundary.

- Allow readonly byte-view descriptors to be read, moved or ended while derived readonly views
  live, without releasing their data owners or exclusive ancestors. Add paired positive/negative
  source checks for lexer-style retained slices.

- Add while loops to source, checked IR and C/LLVM lowering. Re-evaluate conditions, close their
  temporary owner/loan scope on both outgoing edges, and preserve loop-carried resource obligations.
- Validate zero-iteration execution, mutable counters, condition allocations and retained-view
  growth rejection with native and allocator-audited cases.

- Add lexical shadowing and standalone source blocks with reverse lexical cleanup. Keep old storage
  identities and outer-owner lifetimes distinct from names, restore names on scope exit, preserve
  explicit unconditional moves/drops, and reject duplicate parameters and use after scope/consumption.
  Validate C/LLVM behavior, live-loan rejection and allocator-audited shadowed-owner cleanup.

- Fix source call evaluation to copy/move each user-function argument left-to-right before evaluating
  the next. Reject later use of an already moved owner/view, retain builtin borrowing rules, and
  preserve explicit precomputed values/reborrows. No interface-schema or runtime-borrow-check change.

- Review pinned Blu/Lust frontend and ownership implementations; retain 15 modern-Rust/Lust
  acceptance pairs and seven equal native executions for aggregate/region gates. Record the useful
  field/variance/drop-liveness distinctions, remaining Grail work and Lust's older NLL restrictions
  without treating external subset/performance claims as Grail guarantees.

- Add private source-module helpers, forward calls and self/mutual recursion. Collect signatures
  before independent body checks, keep only used callee headers per body, and emit private native
  linkage in C/LLVM. Validate hidden-source clients, repeated helper names across modules, invalid
  unused helpers and allocator-audited owner transfer. The first function is still the sole export.

- Add explicit module identities, multiple `pub fn` exports, qualified calls and flat checked modules.
  Replace the source artifact protocol with canonical module schema 1 (signature-3 payloads); retire
  nested helper-module storage and rebuild old source artifacts. Validate transitive dependency
  surface hashes before linking, reject cycles/stale callers, and keep body-only rebuilds compatible.
  Verify C/LLVM/TinyCC execution and borrowed export contracts. Artifact-byte authentication,
  concurrent publication safety, public type definitions and full bootstrap remain unfinished.

- Publish immutable, manifest-verified native module generations behind atomic pointers; link captured
  generation objects instead of replaceable convenience files and atomically install successful binaries.
  Preserve prior outputs on native failure, retain metadata-only checking, and require old flat native
  providers to rebuild. Test concurrent publication, byte corruption and retained-version linking.
- Fix TinyCC reproducibility by compiling stable relative source names inside isolated work directories;
  repeated and relocated object generations/executables now match without ELF postprocessing.

- Add field-sensitive by-value nominal records with owned and captured-reference fields, nested
  partial moves, explicit byte-field borrows and recursive remaining-field cleanup. Share validated
  layouts; count empty nodes in expansion bounds; expire captures independently of default drop.
  Export reachable layout definitions in module schema 2/signature payload 4 and invalidate stale
  layout-only clients. General typed references, generic containers, enums/Result/joins remain open.
- Distinguish lifetime may-roots from valid-reference authority during reborrow. Validate disjoint
  returned mutable fields sharing a lifetime, duplicate-borrow rejection, and storage/capture returns.
- Omit the pinned TinyCC's invalid asynchronous frame tables for Grail's abort-only profile; retain
  relocation evidence and verify both mixed-backend large-record ABI directions and allocator balance.
