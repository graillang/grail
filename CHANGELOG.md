# Changelog

## Unreleased

- Reserve `VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC` in the Vulkan descriptor pool, matching
  set 1; the new SDL3 surface test’s validation layer had exposed the missing pool size.

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
- Abundance CPU port, landscape-cache increment: ABWCACH9 caches now load end to end. The loader
  requires the legacy drainage receiver raster to be empty, reads the embedded landscape authority
  snapshot as a length-prefixed byte range, hashes it in place and binds it through the envelope's
  ABWLA001 branch. The 1.2 MB fixture cache reproduces the world hash
  `2326846152216773467` (digest `1339588465908555843`), the same value the fingerprint fixture
  produced, and three authority-length rejections are gated against the engine's wording. The suite
  now compares 150 exact values (math 63, hashing 16, world 25, cache 46). The lake-topology
  sidecar and ABCP2 remain out of scope.
- Abundance CPU port, cache-body increment: `world_cache::load` decodes the ABWCACH8 body — the 30
  alignment-padded rasters, drainage nodes, provinces, caves, sites, regions, corridors, the
  validation report and the landform block — rebuilds the world fingerprint and re-derives the
  content hash from the file. For the 523 KB fixture cache the re-derived hash equals the header's
  `13360685293024758287`, the value `load_world_cache` verifies. Thirteen malformed, version and
  body cases plus the alignment rule are gated against the engine's own wording, including the
  reminder that a corrupted pad byte still loads. The suite now compares 139 exact values
  (math 63, hashing 16, world 25, cache 35). Landscape caches, ABCP2 and the lake-topology sidecar
  remain out of scope.
- Abundance CPU port, cache-container increment: `abundance/src/world_cache.grl` reads the
  ABWCACH8/ABWCACH9 world cache the way `read_world_cache_summary` does (84-byte header, optional
  landscape-settings trailer, generator block, optional 48-byte identity trailer from the end of the
  file), reproduces the engine's rejection wording for nine malformed or version cases, and writes a
  summary file the engine accepts byte for byte. The fixture is a real 523 KB cache of the generated
  world; the count lines and the stored content hash match it. The suite now compares 124 exact
  values (math 63, hashing 16, world 25, cache 20). The cache body, `load_world_cache`'s decode and
  the ABCP2 save container remain out of scope.
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
- Added local-time offsets and the first TCP/UDP socket layer to the Windows and macOS
  backends. Windows uses `GetTimeZoneInformation`/`SystemTimeToTzSpecificLocalTime` and Winsock
  (`WSAStartup`, TCP/UDP IPv4 plus probed IPv6, bind/listen/accept/connect, send/recv,
  sendto/recvfrom, shutdown, addresses, non-blocking mode and options). macOS uses
  `localtime_r`/`tm_gmtoff` and BSD sockets with `SO_NOSIGPIPE` and the same operations.
  `GRAIL_CAP_LOCAL_TIME_OFFSET`, `GRAIL_CAP_SOCKETS`, `GRAIL_CAP_SOCKET_UDP` and
  `GRAIL_CAP_SOCKET_IPV6` are set where available. DNS remains fail-closed
  (`grail_os_net_resolve` is still UNSUPPORTED); Windows also still lacks non-blocking files
  and readlink/realpath, and macOS still lacks `file_stat`/`fs_stat`. All four cross targets
  compile with strict warnings and define all 95 public symbols. Pinned Win32/Darwin layouts now carry compile-time
  size assertions. Socket/time code is statically checked only, not executed on Windows or
  macOS.
- Added child-process support to the Windows and macOS backends. Windows uses `CreateProcessW`
  with a validated argv/environment, UTF-16 environment block, working directory, inheritable
  explicit/inherited/NUL standard handles, Win32 search path, wait/wait-timeout,
  terminate/kill and process ids. macOS uses `posix_spawn` with file actions for stdio and
  working directory, `NEW_GROUP` via `POSIX_SPAWN_SETPGROUP`, and `waitpid`/`kill` for status
  and termination. Both set `GRAIL_CAP_PROCESSES`. Remaining fail-closed domains are sockets
  and local-time offsets; Windows also lacks non-blocking files and readlink/realpath, and
  macOS still lacks `file_stat`/`fs_stat`. All four cross targets still compile with strict
  warnings and define all 95 public symbols. Process spawn is statically checked only, not
  executed on Windows or macOS.
- Added directory iteration, threads/mutex/condition variables and dynamic-library loading to
  the Windows and macOS C ABI backends. Windows uses
  `FindFirstFileW`/`FindNextFileW`, `CreateThread`/`WaitForSingleObject`, `SRWLOCK`/
  `CONDITION_VARIABLE` and `LoadLibraryExW`/`GetProcAddress` with `FormatMessageW` loader
  errors; macOS uses `opendir`/`readdir` with a pinned Darwin `struct dirent`, pthread
  threads/mutex/relative-time condition variables and `dlopen`/`dlsym`/`dlclose`. Both now
  create parent directories when requested. Capabilities add `DIRECTORIES`, `THREADS`,
  `SYNC_PRIMITIVES` and `DYNAMIC_LIBRARIES`. Remaining fail-closed domains are processes,
  sockets and local-time offsets; Windows also lacks non-blocking files and
  readlink/realpath, and macOS still lacks `file_stat`/`fs_stat`. All four cross targets still
  compile with strict warnings and define all 95 public symbols. These layers are statically
  checked only, not executed on Windows or macOS.
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
- New `windows-aarch64` target emits ARM64 PE/COFF: the AArch64 selector gains Windows pseudo-ops
  (`winimport`, `winexit`, `wintp`, `wintpset`, `winunsupported`) that expand into an indirect IAT
  call with the 64-byte Win64 ARM64 home space, the TEB-through-`x18` user pointer and traps for
  Linux-only intrinsics. Internal argument registers already map to `x0..x5`, so Win32 calls need
  no shuffling; import libraries are written with `Machine = 0xAA64`. Objects assemble as
  `COFF-ARM64` (`IMAGE_FILE_MACHINE_ARM64`) with `BRANCH26`/`PAGEBASE_REL21`/`PAGEOFFSET_12A/12L`
  relocations and link to PE32+ console images with `lld-link /machine:arm64`. Four programs are
  checked statically (no ARM64 Windows runner is available here); ARM64 has no `.pdata` unwind
  records yet, and the Linux x86-64/AArch64/RISC-V builds are checked alongside.
- PE/COFF frames now carry unwind data: a post-pass over the final Windows assembly reads the
  `.set .F<n>` frame sizes and emits `.seh_proc`/`.seh_pushreg`/`.seh_setframe`/`.seh_stackalloc`/
  `.seh_endprologue` for every function, so the object has `.xdata` and a `.pdata`
  RUNTIME_FUNCTION table that `lld-link` publishes as the exception directory (240 records for
  the hello image). There is no exception personality or `RaiseException` panic path yet, the
  `.D<ty>` drop thunks and the entry stub stay undescribed, and the ELF optimizer still does not
  recognize `.def` functions, so PE output is unoptimized.
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
