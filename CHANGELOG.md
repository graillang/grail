# Changelog

## Unreleased

- Added: debug info describes what values contain - DWARF on Linux and CodeView (a `.debug$T` type stream) on Windows. A Grail record is a pointer to a structure of its fields, a string/byte sequence/vector a pointer to its {data, len, cap} header with typed elements, a view {data, len}, a reference a pointer to its referent, and an extern "C" record its C layout - so `print **o` in gdb shows `{count = 7, ratio = 2.5, inner = ...}` and `print (*s)->data` the text.
- Added: compile-time evaluation, stage C1 (`docs/design/comptime.md`, book chapter *Compile time*). Module constants take constant expressions (`const MASK: u64 = PAGE - 1;`, or `MASK := PAGE - 1;` with the type inferred); `@if target.os == .windows { } else { }` compiles only the branch that holds, at module level or in a function, without type-checking the other; `@assert(cond, "message")` is a compile error with the message; `@expr` folds an operand; `size_of`/`align_of` give the target layout of scalars, handles and C records. Checked arithmetic: an overflow is a compile error.
- Fixed: a character the language does not use (such as `#`) made the compiler abort without a message; it is now an error at its position, and `#` says that comments start with `//`.
- Range facts (`--range-facts`) widen at loop heads with thresholds, so a loop of any trip count, and a loop that pushes, converges and can be proved; previously the fixpoint hit its 24-round cap and decided nothing.
- Added: an iterator protocol. A record with an inherent `fn next(self: &mut Self) -> T?` is iterable: `for x in it` takes the iterator, `for x in &mut it` lends it so the loop can stop early and a later loop carry on; `for x in &it` is refused by name. A plain `for` over a vector compiles exactly as before.
- Added: `lib/iter.grl`, lazy adapters over a closure-backed `Iter<T>` - `upto`, `of`, `map`, `filter`, `take`, `enumerate`, `zip` and `collect` - with a new book chapter, *Iteration*, and Rust comparisons.
- Fixed: a closure body that instantiates a generic (`Some(i)` inside `|| ...`) no longer leaves an undefined symbol at link time; closures and specialisations are emitted to a fixpoint.
- Added: `byval` records on Windows. Win64 passes a record of 1, 2, 4 or 8 bytes as one integer word in its positional slot and any other size by reference to a 16-byte-aligned caller copy; Windows ARM64 uses the AAPCS64 rules. Executed under Wine with the callback stack-argument, record-write and nested-float fixtures (`tests/windows-cases.json`).
- Added: a C function may return a record whose embedded records contain floats. Result classification (SysV eightbytes, AAPCS64 homogeneous aggregates, RV64 float+int pairs) now runs over the flattened field list instead of refusing the shape (`tests/ffi/nested_float_results.grl`, executed on x86-64, AArch64 and RISC-V).
- Added: a C callback may write into the struct C passes it: declare the parameter `p: &mut R` for an extern record `R`. The body works on a Grail-owned copy that every exit writes back into C's storage, so field writes, passing `p` on and whole-value replacement are all sound. A `cfn` type may declare `&mut R`, and a call through it passes the record's own address.
- Added: a C callback may take any number of parameters. Arguments past the registers are read from the caller's stack on SysV x86-64, AAPCS64, RV64 (which first spills extra floats into free integer registers) and Win64, instead of the parameter list being refused (`tests/ffi/callback_stack.grl`, executed on x86-64, AArch64 and RISC-V).
- Added: a C callback that arrives on a thread C created now runs instead of aborting. The outermost callback on such a thread adopts a record (its own TCB, no task state) for the duration of the call and releases it on return, so it can allocate, make foreign calls with its own errno, and be re-entered through C.
- Fixed: `cstr("literal\0")` no longer dangles after its statement - it points into static read-only storage, so a `CStr` kept in a binding or record field stays valid; a literal without a trailing NUL is a compile error rather than a runtime abort. `cstr(bytes)` now holds a loan on `bytes` for as long as the `CStr` is live, under the same rule as `cptr`.
- Foreign calls work on every runtime thread, not only the main one. The host TLS base is per
  thread now (record word 56, replacing the process-wide `rt_host_tls`/`rt_grail_tls`), and in a
  process that loaded libc the runtime creates its pool workers, green scheduler threads, reactor and
  offload threads through `pthread_create`, so each has a glibc TCB of its own: errno, `pthread_self`
  and the malloc tcache belong to the thread that uses them, and glibc knows the process is
  multithreaded. A callback finds its thread's record through `rt_tls_record`, an initial-exec TLS
  word; on a thread C created it aborts by name instead of sharing the main thread's record (adoption
  is next). Static programs are unchanged except that a foreign call on a thread without a TCB no
  longer switches the thread pointer. A dynamic link now always adds `-lc`. On x86-64 a foreign call
  costs one `arch_prctl` fewer (two instead of three). `tests/ffi/threads.grl` (`bun tools/test-ffi.mjs`)
  executes libc calls and errno from a pool worker and a green task and errno isolation between two
  threads on x86-64, and under qemu on AArch64 and RISC-V 64 with a glibc sysroot; the previous
  runtime fails it (shared errno 42/42).
- Fixed (soundness): a C pointer made by `cptr(&r)`, `cptr_mut(&mut r)` or `cptr(bytes)` is now a
  borrow of what it points at for as long as the pointer is live. Before, the borrow ended with the
  statement, so `p := cptr(&sub); sub = other;` compiled and left `p` dangling. The pointer holds the
  same loan a reference would, through bindings, copies, record fields (assigned or in a literal),
  values read back out of them, moves of the record holding it and closures that capture it. While
  it is live the storage cannot be assigned, modified, moved, dropped or re-borrowed, and a
  `cptr_mut` pointer is exclusive, so the storage cannot be read either. The pointer also cannot
  outlive the storage, so keeping it in an outer-scope record, writing it through a `&mut`
  parameter, returning it or returning a closure that holds it are all refused. A Grail call whose
  arguments carry a pointer is assumed to pass it to its result and its `&mut` arguments, so a
  helper cannot launder it. `cptr(&mut v)` is a read-only pointer and holds a shared borrow.
  Each refusal names the storage, the binding holding the pointer and the `cptr` that made it:
  `cannot assign to `sub` while a C pointer to it is live in `p` (made by cptr at line 5)`,
  `` `app` goes out of scope while a C pointer to it is live in `info` ``, `cannot return a C
  pointer to `app`: the pointer would outlive it`. A C call still borrows the pointer only for the
  call, and C must not keep it. Abundance's renderer (`abundance/src/rhi_*.grl`) and every FFI
  fixture compile unchanged. `CStr` from `cstr(...)` is not covered yet. See
  [docs/ffi.md](docs/ffi.md), "Pointer lifetimes", and the book's "Calling C" chapter.
- Fixed: a generic instantiated on both `f32` and `f64` no longer shares one specialisation - the structural type key now records float width, so the f64 call ran the f32 body before (found by the per-module work).
- Fixed: `&mut` of an `extern "C"` record held in a field of a plain record (`set_y(&mut bag.pair,
  7)`, or the same reference passed to C as an `R *`) silently lost the write: the place was wrapped
  in the proxy slot only an embedded C-layout field needs, so the callee wrote into the container's
  next word instead of the record. The proxy is now made only for a C-layout container;
  `tests/ffi/record_field_refs.grl` executes the shape with a Grail and a C callee on x86-64,
  AArch64 and RISC-V 64 (reproducer from [docs/rhi.md](docs/rhi.md)).
- The sequential stdlib callbacks take `FnMut` (readiness A12, first step): `vecs::map`, `fold`,
  `filter_nums`, `any_num`, `all_num`, `count_num`, `position_num`, `sort_by`, `sort_by_key`,
  `Option::map` and the second callback of `pool::join`, so a predicate or comparator that writes
  its captures - a counter behind a captured `&mut`, a toggle in its own environment - is accepted
  instead of refused with `FnMut, not Fn`. `Fn` closures and named `fn` values still widen to them.
  The `pool` callbacks that run on workers (`pool::map`, `run`, `for_chunks`, `chunks_mut`, `spawn`,
  `join`'s first) stay `Fn`, because every worker shares one closure. Native cases
  `vecs-fnmut-predicates-mutate-captures`, `closure-fnmut-sort-by-counts` (replaces
  `closure-fnmut-sort-by-rejected`), `vecs-fnmut-predicate-needs-exclusive-capture`,
  `pool-join-second-fnmut`, `pool-join-first-fnmut-rejected`.
- Fixed: an `Fn` closure passed for a generic `FnMut(T) -> U` parameter was a `type mismatch` when
  the call learned a type variable from that closure (`vecs::map(v, |x: u64| -> u64 x * 2)` learns
  `U` from it): the widening only ran once every variable was already bound. The closure's own
  signature is now widened to `FnMut` before inference (`widen_to_fnmut_formal` in
  `compiler/native.grl`); native case `closure-fn-widens-to-generic-fnmut`.
- Fixed: `--range-facts` (off by default) could remove a bounds check that a loop does exceed. The
  pass stopped its fixpoint after 24 rounds and recorded verdicts from whatever state it had, and
  without widening a loop counter's interval grows one step per round, so `while i < 100` over a
  30-element vector read past the end instead of aborting. A function whose fixpoint has not
  converged at the cap now gets no verdicts, and every access keeps its check; a loop that pushes,
  which never converged either, keeps its check too. `compiler/tests/range_long_trip.grl` and
  `range_push_loop.grl` pin both in `tools/test-facts.mjs`.
- Typed-IR range facts for the LLVM backend (F3), behind `--range-facts`: the lifter derives, from
  the word stream alone, that a slot holds an integer in `[lo, hi]` at a point, and uses it where
  the front end's bounds check lives. A *state* is one flat vector per block over the 14 registers, the frame slots
  and one length per sequence identity; the facts are established from literals, masks, truncations
  to a narrow type, arithmetic over facts already held, and comparisons already checked on the path
  -- including the 0/1 word the front end materialises every `while` guard into, whose operands the
  analysis follows back through the copies that carried them -- and they are dropped by a write to
  the location, by an address that escapes, by any call that may take an argument by reference, and
  by a narrowing that is not provably in range. Where a fact puts an accessor's index below the
  sequence's length, the accessor's body is emitted in place of the call with the bounds compare and
  its cold `rt_abort` removed, `align 8`/`align 4`/`align 1` by element width; `--verify-facts`
  re-inserts exactly that check (a cold abort if any index is out of range), and writes the verdicts
  into the module as `; range` comments. Nothing else changes: the word stream is byte-identical to
  the F1 branch's on all five benchmarks, and `optimize.grl`, `machine.grl` and the native backend
  are untouched. Measured with `tools/bench.mjs --rounds 9` against `typed-ir-f1`: **no benchmark
  moves** (0.519/0.571/1.076/0.169/0.224 s, the same as before within the spread) because **no check
  is removed on any of the five** -- their sequences are filled by counted push loops, whose trip
  count this pass does not summarise, and `nbody` hands its vectors to `energy(&p, ...)`, an escape
  the rules drop the fact on. What it does prove is a fixture's `v[i]` under a literal-length
  sequence and a `while i < 5` guard, identically through the native backend, LLVM, and LLVM with
  `--verify-facts`. It costs compile time (3.2 s -> 6.0 s end to end on `sieve`). See
  `docs/design/typed-ir.md`, "Implemented: the range fact (F3)", including the one rule that would
  make the benchmarks prove. Off by default: with the pass on, compile time is 3.2 s -> 5.5 s on
  `sieve` for no runtime gain yet, so default builds are unchanged (3.2 s / 3.3 s, F1's numbers) and
  `tools/test-facts.mjs` exercises the pass on a fixture instead.
- Fixed: LLVM builds no longer fail with `changed binding to STB_GLOBAL` - a kept-native function the emitter declared `.weak` (content-addressed drop helpers) keeps that binding instead of being re-declared `.globl`. The weak-name table is sized for every name, so programs with many drop helpers no longer hang the lowering.
- Fixed: `GRAIL_TEST_RESUME` keys pass markers by the compiler's content-hash directory rather than its file name, which is `grail` for every build, so a rebuilt compiler never inherits another build's passes.
- Measured what the validation in a Grail program costs, split by kind; the compiler is untouched.
  [tools/checks-budget.mjs](tools/checks-budget.mjs) classifies the abort arms in the emitted `.ll`
  by the predicate that guards them (bounds: the arms inside the sequence accessors; overflow: the
  arms `--overflow=wrap` does not emit; other: allocation, formatting and conversions), then times
  variants of that same `.ll` with one kind of arm deleted, paired with C `-O2` over nine rounds.
  On the five `tools/bench.mjs` programs, x86-64 `--backend=llvm`: the index/length check is 61% of
  `nbody`'s gap to C and 37% of `sort`'s, 72% of `matmul`'s and 41% of `sieve`'s, and worth nothing
  on `fnv`, which has no gap; the arithmetic checks are worth ~5% on `sieve` and 0 ms on the other
  four, so `nbody`'s "both operands are bounded by the integration step" proof would move nothing.
  `--overflow=wrap` is *not* a clean isolate -- it also drops the flag materialization the same
  machine's comparisons read, so `nbody` and `sieve` come out 3-4% slower with fewer checks -- and
  the report uses the branch-only variant for that share. Inlining the accessors in the check-free
  build is worth at most ~2%, so the residual 1.01-1.26x floor is not call overhead.
  [docs/design/typed-ir.md](docs/design/typed-ir.md) carries the tables, the explanation of what
  could not be attributed (the floor's split between the 24-byte header and the word-shaped scalars,
  `sieve`, `fnv`, and the 9-34% interaction term), and ranks the proofs a range fact would buy:
  the loop-guard/literal-length bounds proof first, `nbody` as its first instance.
- Documents: the claims this week's compiler work made false are gone, each checked against the
  compiler in this tree first. [docs/rhi.md](docs/rhi.md) said "there is no expression whose value is
  the address of an owned `extern \"C\"` record" and listed `cptr(&app)`, a record out-parameter and a
  `cnull()`-seeded handle field as refused - all three work now (the first two compile, the third is
  still `generic argument shape mismatch`), so the probe's own two `unavailable` lines are a port that
  has not been made rather than a language limit, and the refusal table now lists what is *still*
  refused: the address of a temporary, the same record twice in one expression, an out-parameter with
  no binding, and an out-parameter that is not a handle/`CPtr`/`CMutPtr`/extern record.
  [docs/platform-status.md](docs/platform-status.md) listed the same refusal and 18 executable FFI
  fixtures with 54 instances - [docs/ffi.md](docs/ffi.md) already said 19, and
  `bun tools/test-ffi.mjs x86_64` reports "19 linked and executed", so the counts are 19 fixtures and
  57 instances, and the FFI row now includes record addresses, `&mut R` out-parameters and arrays of
  handles. [book/chapters/cleanup-and-boundaries.md](book/chapters/cleanup-and-boundaries.md) listed
  taking a record's address as still refused and said the book cannot show C ABI tests because its
  examples link no C library - two of them now link a freestanding fixture in `book/ffi/`.
  [docs/testing.md](docs/testing.md) described `test-facts.mjs` and `--verify-facts` as the `f32` fact
  alone (F1 landed this week and the same suite covers its header facts) and omitted `split-test.mjs`
  from the gate and from the suite list.
  [docs/design/implementation-status.md](docs/design/implementation-status.md) still said `Send`/`Share`
  for closures was deferred, which a neighbouring row of the same file contradicted and the
  parallelism work replaced, and [docs/design/decisions-b2-b6.md](docs/design/decisions-b2-b6.md)
  recorded the same scope limit; both now point at the structural classification that reaches a
  closure's environment. [docs/design/parallelism.md](docs/design/parallelism.md) described in-place
  chunks in the future tense ("stage 2's `&mut [T]` chunks will produce") after measuring them, and
  now states the copy it removed with the numbers.
  [docs/design/llvm-backend.md](docs/design/llvm-backend.md)'s 660-case requirement names the corpus
  and its current count. Historical records of past runs (`755 cases`, `796 native cases`, `49
  examples` for a branch) are left as the records they are.
- Book: four new example pairs for the week's compiler work, each run by `bun tools/book.mjs check`
  against an equivalent Rust program. **`pool-chunks-mut`**: `parallel_for_chunks` over a ten-element
  vector in three chunks (4, 4, 2, the `ceil(n/chunks)` split) and then `pool::chunks_mut` at 5 and 5,
  against `chunks_mut(4)`/`chunks_mut(5)` under `thread::scope` - the same arithmetic split, the same
  ten numbers, and no element copied in either language. **`pool-job-handle`**: spawn, do other work,
  join; then two live handles joined in the reverse of their start order, against
  `std::thread::spawn`/`JoinHandle::join`. **`ffi-handle-array`**: a record of `handle` fields as the
  array C writes - `c_alloc_buffers(&mut buffers)` fills four slots, the record goes back to C as a
  parameter, a second array is seeded from handles already held, and the handle Grail reads out of the
  array compares equal to the one C hands back - against a Rust twin using `MaybeUninit`/`assume_init`
  on the same C file. **`ffi-uninitialised-record`** is the uninitialised-handle rule as an intentional
  rejection in both languages: reading a field of an `extern "C"` record before anything wrote it is
  `use of moved, borrowed or partially initialized value` in Grail and E0381 in Rust. The book is now
  59 Grail examples with 59 Rust twins. The concurrency and FFI chapters gain a *What this month added*
  section (in-place chunks and the measured difference against `pool::for_chunks`, the job handle and
  what its drop does, the capture classification; record pointers, records C fills, arrays of handles,
  and the borrowed callback record parameter that used to abort at exit). The modules chapter states
  the build cache flag (`grail build --cache`, `b1-cache`) and checked module interfaces
  (`b1-interfaces`) with **no** Rust comparison, and says why: they are build-driver flags, and Rust
  splits the same work between `rustc`'s incremental mode and Cargo, so a pair of programs would
  compare nothing. That section also says plainly that neither flag is in this tree yet, so the book
  does not claim to verify it.
- Dear ImGui, called from Grail: the immediate-mode UI layer the editor needs, over the FFI the
  previous increment landed. `abundance/src/imgui.grl` (new) is the context, the frame, `ImGuiIO` and
  the draw data; `abundance/src/imgui_widgets.grl` (new) the widgets and ImGui's ID stack. The C++
  boundary is `abundance/tools/imgui_shim.h`/`.cpp` - one ImGui entry point per function, and a plain
  C `struct` for every record that crosses - built with the pinned Dear ImGui 1.93.0 checkout into two
  shared libraries (`libgrail_imgui.so`, `libgrail_imgui_platform.so`) by
  `abundance/tools/build-imgui.mjs`, which also prints and diffs the record table. No struct is laid
  out by hand: `GrIo` is ImGuiIO's 240-byte prefix through `MousePos`, asserted field by field with
  `offsetof` at compile time, printed by a C program against a C++ program's own table, and checked
  again at run time by `imgui_layout_probe.grl` in both directions. `imgui_test.grl` (new) runs
  widgets, IDs, a table, a child, an `InputU64` (ImGui's `InputScalar` over `ImGuiDataType_U64`), a
  real click on a button's own rectangle, and then prints every vertex, every triangle and every draw
  command of a settled frame: 2 draw lists, 310 vertices, 501 indices, 167 triangles, byte-identical
  to the same frames through ImGui's own C++ API in `abundance/tests/parity/imgui.cpp`. That is 11
  reference programs now, and the ten ports are unchanged.
- Dear ImGui, the io fields as numbers: `imgui_layout_probe.grl` printed ImGuiIO's `DisplaySize`,
  `DeltaTime` and `Framerate` as the *bit pattern* of their binary64 widening (1280.0 came out as
  `4653344314980564992`), which was a correct read presented as an unreadable number. The probe now
  prints `imgui.io.display_size 1280 720`, `imgui.io.delta_time 0.015625` and `imgui.io.framerate 64`
  and asserts them by value - `display_size_is_1280x720`, `delta_time_is_1_over_64`,
  `delta_time_in_range`, `framerate_in_range` - and `imgui_frame_probe.grl` pins the same fields to the
  window SDL reports (`io.display_size_is_window_pixels`), so a float field arriving as a raw word
  fails on the first comparison instead of looking plausible. The parity reference keeps the encoding
  only where it is an exactness mechanism (vertex positions, uvs, clip rectangles) and now says so in
  the labels (`pos_bits`, `uv_bits`, `clip_bits`, `target.min_x_bits`); its io lines are 1280, 720, 1.
- Dear ImGui reaches the GPU: `abundance/src/imgui_platform.grl` (new) binds `ImGui_ImplSDL3_InitForVulkan`,
  `ImGui_ImplVulkan_Init`, both backends' `NewFrame`, `ImGui_ImplVulkan_RenderDrawData` and both
  shutdowns, in a second shared library (`libgrail_imgui_platform.so`) whose own dependencies are
  `libSDL3` and `libvulkan`, so no headless program loads either. `ImGui_ImplVulkan_InitInfo` crosses as
  `VulkanInitInfo` - the fields a host has - and the shim translates it into the real struct and zeroes
  the rest; the record's 104-byte layout is round-tripped through the C offsets before the backend is
  initialised. `imgui_frame_probe.grl` (new) runs the frame the editor needs end to end: SDL3 window,
  device, swapchain, the RHI's clear render pass, ImGui recording into the command buffer inside it,
  submit, present, and a readback of the presented image - 5 frames, 208 vertices and 348 indices per
  settled frame, 22908 of 230400 pixels not the clear colour, and the last two frames' images
  byte-identical. `imgui.status`/`imgui.frame.status` verdicts; a machine with no display server or
  driver skips with the platform's own words.
- RHI increment 4b, in four steps that each run before the next. The gate was the FFI's record
  pointer (`cptr(&record)`, record out-parameters, arrays of handles), so the whole Vulkan create-info
  graph is now records and pointers into them rather than byte layout:
  **1. device, queue, swapchain, images and views.** `abundance/src/rhi_device.grl` (new) creates the
  logical device with `pQueueCreateInfos` pointing at a `VkDeviceQueueCreateInfo` record whose
  `pQueuePriorities` points at a one-field record holding the `float`, and `ppEnabledExtensionNames`
  pointing at a record of `CStr` fields - the array itself - to enable `VK_KHR_swapchain`;
  `abundance/src/rhi_swapchain.grl` (new) creates the swapchain from the four decisions
  `abundance_rhi_surface` already makes (B8G8R8A8_SRGB, currentExtent, minImageCount+1, MAILBOX with
  FIFO fallback), takes its images through a record of handle fields (`vkGetSwapchainImagesKHR`
  writing them in place, four on this machine) and makes one 2D colour view per image. The surface's
  `supportedUsageFlags` decides whether a transfer source can be asked for; the report says
  `rhi.swapchain.readback supported` or names the missing bit. The probe's
  handle ledger is now per class - window, instance, surface, device, queue, swapchain, image, image
  view, and a total - with the queue closed by `vkDestroyDevice` and the images by
  `vkDestroySwapchainKHR`, so `rhi.handles.total created 14 destroyed 14 live 0` is a fact about this
  machine rather than an assumption.
  **2. a clear, a fence and a present loop.** `abundance/src/rhi_render.grl` (new) has the render pass
  (`pAttachments`/`pSubpasses`/`pDependencies`, each a record passed with `cptr(&record)`), one
  framebuffer per image view (`pAttachments` as a record of one `ImageView` field), a command pool and
  one command buffer, a clear colour as a `VkClearValue` record, `VkSubmitInfo`/`VkPresentInfoKHR` with
  their arrays of handles as one-field records, and the barriers that move the image from
  COLOR_ATTACHMENT_OPTIMAL to TRANSFER_SRC_OPTIMAL and PRESENT_SRC_KHR. The probe runs the
  acquire/submit/present loop for `GRAIL_RHI_FRAMES` frames (default 3), waiting on a
  fence each frame, and prints one `rhi.frame` line per frame plus
  `rhi.swapchain.result frames 3 of 3`. The pool carries
  VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT: one command buffer is re-recorded every frame, and
  beginning it again without that bit is undefined behaviour (it segfaults on RADV).
  **3. one triangle, drawn from the committed SPIR-V.** `abundance/src/rhi_pipeline.grl` (new) creates
  both shader modules from `abundance_rhi_shader_blob`'s bytes, and builds
  `VkGraphicsPipelineCreateInfo`'s nine pointers out of records: the two stages as a record of two
  `VkPipelineShaderStageCreateInfo`s (`pName` a `CStr` field), the vertex input from the layout the
  shader build extracted (locations 0/1/2, offsets 0/12/20, formats R32G32B32/R32G32/R32G32B32A32,
  stride 36 - checked to be contiguous and to sum to the stride), triangle list, a static viewport and
  scissor, fill, no culling, one sample, blending off, no depth and no dynamic state. The vertex data
  is a 108-byte record of three 36-byte vertices and is copied in with `vkCmdUpdateBuffer` from
  `cptr(&triangle)` - no staging buffer and no mapped memory - followed by a memory barrier to the
  vertex stage. The probe reads the entry point out of the SPIR-V's own `OpEntryPoint` and passes the
  bytes it found, so a renamed shader cannot leave a stale name behind.
  **4. the readback.** Every presented frame is copied out of the swapchain image
  (`vkCmdCopyImageToBuffer`, one `VkBufferImageCopy` region record, into a host-visible coherent
  buffer) after a COLOR_ATTACHMENT_OPTIMAL -> TRANSFER_SRC_OPTIMAL barrier, then barriered on to
  PRESENT_SRC_KHR, and after the fence the buffer is mapped, memcpy'd into Grail bytes and checked:
  626688 cleared pixels and 294912 covered ones out of 921600, none of any other colour, the covered
  count equal to the triangle's own area (0.32 x width x height), the corner (4,4) reading 0,0,0,255
  and the centre (640,270) reading 0,0,255,255 in B8G8R8A8 order, and the same FNV-1a digest for all
  three frames. "It presented" is not the evidence; the bytes are.
- FFI, found by increment 4b and recorded in `docs/rhi.md` ("What the FFI does not do safely"),
  both reproducible without Vulkan and neither worked around by laying bytes out by hand:
  **`&mut` of an extern record field of a plain record does not reach the field's storage.** A write
  through such a reference lands in the proxy slot, not in the container - `set_y(&mut bag.pair, 7)`
  leaves `bag.pair.y` at 0 and puts the 7 in the next field. A slot array written through such a
  reference is a record of null handles, which is how it was found: a null `VkFramebuffer` handle, and
  a segfault inside the driver. Direct field writes and passing the interior record by value are both
  correct; only the reference is wrong. **A `CStr` taken from a string literal must not outlive the
  statement that made it**: `cstr` is zero-copy and a literal's bytes are a temporary, so keeping the
  `CStr` in a binding and using it later reads freed memory - it read correctly often enough to be
  missed here, and the pipeline's entry-point names now come out of the SPIR-V into byte-sequence
  bindings instead. Both are `compiler/` bugs and `compiler/` is off limits in this increment, so they
  are reported rather than patched.
- Typed-IR range facts for the LLVM backend (F3), behind `--range-facts`: the lifter derives, from
  the word stream alone, that a slot holds an integer in `[lo, hi]` at a point, and uses it where
  the front end's bounds check lives. A *state* is one flat vector per block over the 14 registers, the frame slots
  and one length per sequence identity; the facts are established from literals, masks, truncations
  to a narrow type, arithmetic over facts already held, and comparisons already checked on the path
  -- including the 0/1 word the front end materialises every `while` guard into, whose operands the
  analysis follows back through the copies that carried them -- and they are dropped by a write to
  the location, by an address that escapes, by any call that may take an argument by reference, and
  by a narrowing that is not provably in range. Where a fact puts an accessor's index below the
  sequence's length, the accessor's body is emitted in place of the call with the bounds compare and
  its cold `rt_abort` removed, `align 8`/`align 4`/`align 1` by element width; `--verify-facts`
  re-inserts exactly that check (a cold abort if any index is out of range), and writes the verdicts
  into the module as `; range` comments. Nothing else changes: the word stream is byte-identical to
  the F1 branch's on all five benchmarks, and `optimize.grl`, `machine.grl` and the native backend
  are untouched. Measured with `tools/bench.mjs --rounds 9` against `typed-ir-f1`: **no benchmark
  moves** (0.519/0.571/1.076/0.169/0.224 s, the same as before within the spread) because **no check
  is removed on any of the five** -- their sequences are filled by counted push loops, whose trip
  count this pass does not summarise, and `nbody` hands its vectors to `energy(&p, ...)`, an escape
  the rules drop the fact on. What it does prove is a fixture's `v[i]` under a literal-length
  sequence and a `while i < 5` guard, identically through the native backend, LLVM, and LLVM with
  `--verify-facts`. It costs compile time (3.2 s -> 6.0 s end to end on `sieve`). See
  `docs/design/typed-ir.md`, "Implemented: the range fact (F3)", including the one rule that would
  make the benchmarks prove. Off by default: with the pass on, compile time is 3.2 s -> 5.5 s on
  `sieve` for no runtime gain yet, so default builds are unchanged (3.2 s / 3.3 s, F1's numbers) and
  `tools/test-facts.mjs` exercises the pass on a fixture instead.
- FFI: a C callback's extern-record parameter is borrowed, not owned. The parameter prologue marked
  every parameter as an owning binding, so the epilogue ran the record's drop glue on the address C
  handed over — freeing the caller's struct (or its stack) — and the process then aborted inside the
  runtime's free path at exit, after `main` had printed everything and returned 0. That is the abort
  the RHI work recorded in `docs/rhi.md`: the shape is "a record crosses an `extern "C"` call", and
  the two-declarations-of-one-symbol case that pinned it is now a case of its own. A callback's
  record parameter is the `const R *` the C caller owns, so `func`'s prologue registers it through
  `borrow_parameter` (a real place, no drop glue) instead of `own`, and the fields stay readable
  under the ordinary borrow rules. Verified by `ffi-record-callback-parameter` in
  `tests/native-cases.json` (20, and the process reaches its exit status) and by the same shape in
  `tests/ffi/record_pointers.grl` against a real C shim.

- FFI: the address of a Grail-owned `extern "C"` record is now a value, and C can fill a record in
  place. `unsafe cptr(&r)` is a `CPtr` and `cptr_mut(&mut r)` a `CMutPtr` holding the address of the
  record's own fields — the same pointer a record *parameter* already was — so a struct that points
  at another struct (`VkInstanceCreateInfo::pApplicationInfo`, `VkRenderPassCreateInfo::pAttachments`)
  is expressible without laying bytes out by hand; a field, a binding and a declaration parameter
  typed `const void *`/`void *` all take it. `p: &mut R` in a declaration is the C `R *` the callee
  writes, and the caller reads the typed fields afterwards
  (`vkGetPhysicalDeviceSurfaceCapabilitiesKHR`). An `extern "C"` record binding declared without an
  initializer gets `sizeof(struct)` zeroed bytes instead of nothing, so `&mut r` is a valid pointer
  and a callee that reads a field it does not overwrite reads 0 - but the binding still holds no
  *value*: reading a field (or moving the record) before a foreign call or an assignment wrote it is
  refused with `use of moved, borrowed or partially initialized value`, which is what keeps a zeroed
  handle from being read as one. With handle-typed fields filled by C through `&mut`, or seeded from
  handles the program already holds, `vkQueueSubmit`'s `pCommandBuffers` and `VkPresentInfoKHR`'s
  `pSwapchains` are expressible as arrays of handles. The borrow rules are the call-scoped ones
  `cptr` already had, with named failures for each hazard: `cptr needs a named record: the address of
  a temporary would not outlive the pointer`, `cptr takes the address of an extern "C" record; a
  Grail record has no C layout`, `the value handed to C as a writable pointer is already borrowed in
  this expression`, `the value handed to C as a read-only pointer is already mutably borrowed in this
  expression`, and `an extern C out-parameter needs a binding to write into; a temporary record would
  be discarded`. Also fixed, on the way: an embedded record's place (`o.inner`) is a proxy slot
  holding its interior address, so `&mut o.inner` no longer reads the first field as an address
  (it faulted on x86-64 and wrote through a stack slot on assignment); and a C callback's record
  parameter is now borrowed rather than owned, because the epilogue used to free C's struct, which
  aborted in the runtime's free path at exit after `main` had already printed everything. Verified
  by `tests/ffi/record_pointers.grl` against a real C shim on all three targets (including a handle
  Grail reads out of an array C filled comparing equal to the one C hands back), fourteen new cases
  in `tests/native-cases.json`, and a new book chapter (`Calling C`) whose Grail and Rust twins link
  one C file.

- `parallel_for_chunks` and a job handle: the two things the pool surface was missing, and the
  measured entry cost the owned-chunk shape paid is gone. `parallel_for_chunks(&mut data[a: b],
  chunks, f)` splits an exclusive slice into disjoint exclusive chunks and hands each job `&mut [T]`
  over its own elements, so no element is moved or copied: the same 3M-u64 CPU-bound pass measures
  94 ms through `pool::for_chunks` (which moves every element into its chunk) against 38 ms in place
  as one job, 63 ms against 11 ms as eight. The split is `size = ceil(n/chunks)`, chunk `k` being
  `[k*size, min(n, k*size+size))`, so disjointness and coverage are arithmetic rather than a checked
  property, and the runtime still asserts the chunk lengths sum to the element count. The element
  type goes through the same structural walk `parallel_map` uses, asking `transferable`: `&mut
  [File]` is refused exactly as `&[File]` is. A chunk callback cannot reach outside its chunk:
  the argument is an exclusive loan of the whole vector, so a capture that could alias that data - a
  move, a shared slice, a sub-range's slice - is a borrow error at the call site; a captured `&mut
  [T]` is refused by name (every worker calls one closure); and the slice a callback holds has its
  own length, so an index past it is a bounds abort. `parallel_spawn(f) -> Job<R>` with
  `parallel_join(h) -> R` is spawn-then-wait as two statements, on the runtime's existing submit and
  wait. `Job<R>` is a move-only type kind like `Task<R>`: the closure's environment moves into the
  job through a heap box the job drops on the worker that ran it, the result is owned and
  transferable, a callback that captured a borrow is refused (the handle's type records no such
  lifetime), a job may not return another handle, sharing a handle is denied, and the handle's drop
  *waits* - so dropping it instead of joining is a wait-and-discard, never a leak or a double free.
  Nothing reachable from a handle is frame memory and it has exactly one owner, which is why it may
  outlive the frame and cannot dangle. `lib/pool.grl` wraps all three as `chunks_mut`, `spawn` and
  `wait`. Native cases: `pool-chunks-mut-split` (uneven, one, zero, more chunks than elements, more
  chunks than workers, a sub-range, empty, nested chunking, f32/u32/bytes, all by content),
  `pool-chunks-mut-timing`, `pool-job-handle`, six chunk rejections, four job rejections, the
  out-of-chunk bounds abort, and the borrowed-closure refusal. No reseed is needed: the compiler's
  own sources do not call the new builtins.
- Separate compilation, stage 4 (first half): **a build cache**. `grail build --cache` reuses what a
  previous build produced, from a content-addressed store under `.work/cache/<target>/`. An unchanged
  program is not rebuilt at all, and an unchanged module is not reassembled: the store is keyed by what
  actually determines each output - a module's source digest, the digests of the interfaces it reads,
  the compiler's own digest, the target, the assembler's and the linker's identity, and the compiler's
  whole flag vector - and each entry is filed under the digest of its bytes, published by rename, and
  re-hashed before it is ever reused, so a corrupted or unreadable entry is a miss and never a wrong
  binary. `grail build --cache` reports one line - what hit, what missed by name, and what ran. The
  flag implies `--split`, so it is available where that is: the Linux x86-64 assembler path, without
  `--debug`. `grail build` also accepts `--overflow=wrap|checked`, which until now only the compiler
  driver itself could pass. Without `--cache` nothing about a build changes. `tools/cache-test.mjs`
  proves the six claims (a cached build is the uncached build byte for byte, a second build is a full
  hit and 12x faster, one module's edit misses that module and its importers and nothing else, a flag
  change misses everything, a tampered interface misses the importer, corruption rebuilds and repairs)
  and pins the one thing the module level cannot do yet: the emitter numbers its local labels over one
  stream, so an edit re-spells every module emitted after it and those modules reassemble.
- Separate compilation, stage 3: **generic bodies in interfaces**. A type-generic template's body
  now travels in its module's interface (`// grail-interface 2`): one quoted `line` row per source
  line under the template's `fn` line, so a changed statement is a changed line in a review diff.
  `grail ... --use DIR` builds a module against a directory of interfaces whose sources are not on
  the command line at all, and `--serve DIR` makes the module that *defines* a template emit the
  instantiations its importers asked for. A specialisation's symbol is now content-addressed -
  `f_<module>_<name>$<16 hex of the SHA-256 of module::name plus the canonical argument types>` -
  so the definition and the reference agree in every compilation order, and the body is emitted
  once, in the defining module's part, while importers reference it; each importer writes
  `DIR/<module>.sreq` naming what it references, and the defining module's build serves that list.
  The key is a *total structural* description of the type (`type_key`), not the interface's spelling
  and not an index: naming a type happens on every scope exit and every call, so it must never be
  able to fail a build, and it embeds no number this run chose - a proof carries its interface's
  name, an unknown store kind has its payload walked as a type, and one definition is emitted per
  key rather than per interned index. Drop helpers are content-addressed the same way and `.weak`
  for the same reason, closure bodies are named after the module that owns them rather than by an
  index in this run's closure table, and a request file carries the environment records its keys
  mention, so a generic instantiated on a capturing closure can be served by the module that defines
  it and two importers still share one body. Capability metadata keeps its force across an
  instantiation: a `T: Share` bound and a handle's audited `transfer`/`share` are read from the
  interface, so instantiating a template on a handle that is transferable but not shareable is
  refused by name (`type does not satisfy Share: handles::Lock is thread-affine (declared
  transferable, not shareable)`) whether the module came from source or from its interface. Also
  fixed: the interface manifest was never actually enforced (`iface_words` returned the whole file
  as one word), and `--verify` now covers carried bodies. `tools/interface-test.mjs` proves one
  emitted body across two importers, identical behaviour against the source build, the refusal by
  name, and that a template without a body is refused. What stage 3 does not do: a body is still replayed (re-parsed and re-checked) once per
  instantiation at the *caller*, because the checker is per-instantiation and there is no typed IR
  yet; only emission moved. A request line must be written in the interface format, so an
  instantiation on a type with no spelling is refused by name at that boundary (a type that cannot
  be spelled cannot appear in an exported signature either). A generic instantiation
  discovered while a defining module replays one of its own templates is filed in *its* request
  file, so a driver has to iterate to a fixpoint (stage 4).

- Separate compilation, stage 2: **checked module interfaces**. `grail check --interface DIR` writes
  one `DIR/<module>.iface` per module plus `DIR/interfaces.manifest`; `grail build --interface DIR`
  reads them instead of the modules' sources, and refuses by name when an interface is missing, when
  the source it was built from no longer hashes to the digest it records, or (with `--verify`) when
  it disagrees with the module. An interface carries what an importer needs to check a call -
  exported declarations with their parameter and return types, types with their full structure, and
  the audit results that must not be re-derived (`handle ... transfer= share=`, and a closure type's
  environment record) - and nothing a body would carry. Text, versioned, one declaration per line,
  sorted by name, with a digest over the file. `tools/interface-test.mjs` proves that a program built
  against interfaces behaves like the program built from source (corpus, and the compiler compiling
  itself), that stale and tampered interfaces are refused - an edited `transfer`/`share`/environment
  entry, a re-digested file, and a file whose manifest entry was rewritten - and that an interface
  leaks no body, no local name and no synthetic declaration. Bodies and generic templates still come from source: that
  is stage 3 (bodies in interfaces) and stage 4 (one object per module, and the cache).

- RHI increment 4a, the shader side: HLSL compiles offline to SPIR-V, the bytes are committed, and
  the one create info that carries them is expressible today. `abundance/tests/shaders/
  rhi_triangle.hlsl` is the source of truth (one vertex and one pixel stage);
  `bun abundance/tools/build-shaders.mjs` compiles it with `glslangValidator -D -V --target-env
  vulkan1.2 -S vert -e vs_main` (and `-S frag -e ps_main`), runs `spirv-val` on each module, extracts
  the `VertexIn` layout, cross-checks that extraction against the compiled stage's own `OpName` /
  `OpDecorate Location` / `OpTypeVector` decorations, and writes the `.spv` files, a manifest
  (`abundance/tests/shaders/shaders.json`: compiler version, exact flags, entry points, sizes,
  fnv1a64 hashes, layout, cross-check status) and `abundance/src/rhi_shader_blob.grl` (the bytes as
  constants plus the layout). All four artifacts are committed, so a clean checkout builds, tests and
  renders with no shader compiler installed; the generator is a maintenance tool, not a build step.
  `abundance/src/rhi_shader.grl` (new) holds the loader shape - `VkShaderModuleCreateInfo` as an
  `extern "C" record` (40 bytes; sType 0, pNext 8, flags 16, codeSize 24, pCode 32) whose `pCode` is
  the one pointer inside a Vulkan create info the FFI can already fill, `unsafe cptr(&bytes)` - plus
  a small SPIR-V decode (magic, version, generator, bound, schema, first `OpEntryPoint`) that checks
  a module the way a loader can without a driver. `abundance/tests/rhi_shader_probe.grl` (new) is
  the fourth probe and the only graphics check that links nothing at all: it runs under `env -i`,
  with no display, no ICD and no shader compiler, reconstructs the bytes from the generated
  constants, hashes them with Abundance's own `fnv1a64` and matches the recorded hash, decodes the
  header and entry points, builds the create info and checks `codeSize`, and validates the layout
  (declaration-order locations, contiguous offsets, stride equal to the sum). The suite runs it in
  the default set and also ties its printed hash to the manifest; the generator's own `--check` is
  two-tiered - everything that needs no toolchain always runs, and the recompile demands identical
  bytes only when this machine's glslang matches the version the manifest records, otherwise it
  prints `shader hash differs (glslang 11:16.6.0 recorded, <detected> present): not compared` and
  passes. Verified with `DISPLAY`/`WAYLAND_DISPLAY` unset, `VK_ICD_FILENAMES=/nonexistent` and
  `glslangValidator`/`spirv-val`/`spirv-dis` off `PATH`: `rhi_shader: ok`, the other three probes
  skip, `10 test program(s) passed, 4 RHI probe(s) run`. Handle accounting in the swapchain probe is
  now per class (`rhi.handles.window`, `.instance`, `.surface`, then `.total`), and a disagreement in
  any class or in the total fails the run, so increment 4b's device, swapchain, images, views,
  semaphores and fences arrive as classes rather than as one count they could hide in.
- RHI increment 3: `abundance/src/rhi_surface.grl` (new) creates a real `VkSurfaceKHR` from the
  SDL3 window and reads back what that surface accepts. The instance is now created with the
  platform's own extension set: `abundance_rhi_vulkan::instance_create_info_with(extensions, count)`
  fills `ppEnabledExtensionNames` from a `CPtr`, and `SDL_Vulkan_GetInstanceExtensions` returns
  exactly that shape — C's `const char *const *` — so the array is C's memory and Grail never has to
  build an array of strings (this host: 2 extensions for the `x11` driver, and the loader offers
  `VK_KHR_surface`, `VK_KHR_xlib_surface` and `VK_KHR_wayland_surface`, each named in the report).
  `SDL_Vulkan_CreateSurface` reaches the platform `vkCreate*SurfaceKHR` for whichever video driver
  served the window, so no platform extension is named in Grail. `VkSurfaceCapabilitiesKHR` is an
  `extern "C" record` (52 bytes of scalars, offsets checked with a C program against
  `offsetof`/`sizeof`) rather than a byte buffer, and the format and present-mode lists are
  fixed-capacity records of scalars — the record *is* the array, the count query and the seeded fill
  call are the idiom the physical device list already used. On top of that the module makes the four
  decisions a swapchain needs, each a stated rule instead of a constant: format (sRGB first, ties
  keeping the surface's order, `format_by application` when the surface reports no preference),
  present mode (MAILBOX, then FIFO, then FIFO_RELAXED, then IMMEDIATE), extent (`currentExtent`
  unless it is `UINT32_MAX`, otherwise the window's pixel size clamped into the surface's range) and
  image count (`minImageCount + 1`, clamped to a non-zero `maxImageCount`). The device is now chosen
  as the highest-ranked one that has a queue family which both runs graphics and presents to this
  surface (`vkGetPhysicalDeviceSurfaceSupportKHR`), not merely the fastest device on the machine.
  `abundance/tests/rhi_swapchain_probe.grl` (new, wired into `tools/abundance-test.mjs` as the third
  probe) prints the whole chain, takes the frame count as `argv[1]` (`GRAIL_RHI_FRAMES`, default 3),
  skips with `rhi.status skipped no-display` where there is no display server, and asserts its own
  handle balance (`rhi.handles created 3 destroyed 3 live 0`, a leak fails the run) because the
  validation layer is not installed on this host; where it is installed the suite forces it on
  through the loader (`VK_LOADER_LAYERS_ENABLE`/`VK_INSTANCE_LAYERS`) for a second run and fails on
  any validation message, after requiring the layer's manifest to name a real ELF shared object,
  since the loader skips a broken layer silently. What did *not* land is the swapchain itself and
  everything downstream of it — device, `VkSwapchainKHR`, image views, the render pass, the clear and
  the present — because all of them need an expression whose value is the address of an `extern "C"`
  record Grail owns, and the submit/present arrays are arrays of *handles*, which cannot even be
  seeded. The probe reports `rhi.swapchain.result frames 0 of 3` plus one `unavailable` line per
  blocked call rather than pretending; docs/rhi.md lists the calls and what each one needs.
- Borg's goal, plan and work list fold out of a journal, and `borg` serves them (`borg/src/aggregates.grl`,
  `borg/src/cli.grl`). Four new journal kinds join the five transcript ones, each with the journal's
  encoding — a tag, a little-endian length and a body of length-prefixed texts — and each refusing by
  name what it cannot represent: `goal_created` (6) carries a goal id, an objective and an optional
  token budget; `goal_updated` (7) a goal id and a status of `active`, `complete` or `blocked`
  (`ModelGoalStatus`, contract.rs:2337); `plan_projected` (8) a participant, a workspace revision and
  its items (`id`, `content`, a `pending`/`in_progress`/`blocked`/`awaiting_review`/`completed`
  status, and the port's own optional `work_id`); `work_projected` (9) a revision and its shared work
  items with their assignees and states. A status outside its enum is `unknown-goal-status` or
  `unknown-item-status` from the reader rather than a variant coerced to a neighbour. The fold is its
  own module with its own refusals: `goal-exists` (a second `goal_created`), `no-goal`, `goal-mismatch`
  (an update naming another goal), `goal-finished` (any update of a completed goal — the terminal
  rule), `unknown-work` (a plan item pointing at work the journal never carried), `duplicate-item` and
  `duplicate-work`; replay carries them with the event index and its own reason, so a diagnostic names
  the rule that stopped it. The one rule that does not refuse is the model's: a plan projection that is
  not newer than the one applied is dropped and counted (`plans_stale`), exactly as
  `session_store.rs:1178-1191` compares revisions, and the drop is decided before the items are
  examined. `borg_replay::State` now holds the goal, the plan and the work list, with the session
  fingerprint unchanged (a journal without aggregates keeps its checksum) and a second fingerprint over
  the aggregates only. `borg daemon` serves the transport while keeping the folded session between
  connections (`borg_daemon::serve_stateful`, `serve_one` untouched), stamps the sequence, event id and
  timestamp onto what a client sends — the daemon appends, so a command cannot write the cursor in two
  places — and answers with the reply frame *and* a new state frame (opcode 6) carrying the aggregates,
  whose statuses are re-read through the same functions on arrival. The client has `create-goal`,
  `update-goal`, `set-plan` (a work projection, then a plan that may name it), `list-work` and `attach`,
  each printing what came back off the socket rather than what it meant to send, and each refusing with
  the model's own names; `bad-argument` is the command line's own for a command it cannot read. The
  transport's unknown-tag fixture moved from tag 6 to tag 10 because 6 is now a real kind, and what it
  prints is unchanged. `borg/tests/aggregates_test.grl` covers every refusal, the stale plan drop, a
  plan taken over by another participant, a sequence gap, a cut stream, and for every fixture three
  properties — the same journal through the byte stream, twice-replay identity, and prefix-plus-apply —
  then runs a whole command session on 127.0.0.1 where each answer is compared with the daemon's own
  account of what it sent. The committed reference (`borg/tests/parity/ref/src/bin/aggregates.rs`)
  implements the kinds, the fold, the fingerprint and the command session independently, over its own
  socket.
- The Borg transport layer carries the typed event stream over TCP with the refusals the journal
  already has (`borg/src/frames.grl`, `borg/src/daemon.grl`, `borg/src/client.grl`). A frame is one
  encoded event — the journal's `u8 tag | u32 LE length | body` — so the wire and the journal are the
  same bytes by construction (`frame_of` is `encode_stream` over a one-event journal, `frames` is
  `encode_stream`), and a frame captured off the socket replays through the file reader. Tag `0`
  marks a control frame: `hello` (version, session), `hello_ok`, `hello_refused` (both versions as
  numbers), `reply` (the folded sequence/status/events plus any refusal) and `end` (the batch is
  complete). Refusals are named and numbered, and the reader's codes 20-24 pass through unchanged:
  `version-mismatch` 10, `session-mismatch` 11, `not-handshaken` 12, `frame-too-large` 13,
  `short-read` 14, `bad-control` 15, `bad-reply` 16, `replay-refused` 17, then `unknown-tag` 20,
  `truncated-event` 21, `length-overflow` 22, `bad-field` 23 and `trailing-bytes` 24. A cut stream
  fails the way the file reader fails, as a function rather than a claim: `journal_code(14)` is 21
  and `journal_code(13)` is 22, and the test prints both columns for the same bytes. A declared
  length is refused at the header before its body is waited for, and the ceiling is the journal's
  own `MAX_EVENT_BODY`, so an accepted frame is an event a journal file could hold. The daemon folds
  each event as it arrives with `borg_replay::apply` and answers a refusal with the index and the
  fold's own reason; the client returns that refusal instead of reporting success, and a peer that
  closes without answering is `short-read` rather than silence. Opening the listener is an explicit
  grant — `borg_daemon::listen` takes `authority::Authority` and calls `authority::listen`, and
  `borg_client::connect` calls `authority::connect` — so the grant decides who may listen and who may
  connect, while `accept`/`read_fd`/`write_fd` stay ambient: what the peer does after connecting is
  not covered. No authentication, encryption, reconnection or multiplexing, and the docs say so.
  `borg/tests/frames_test.grl` prints every frame in hex, decodes the capture whole and one byte at a
  time, hands it to the file path, builds all thirteen refusals from the bytes a peer would send, and
  runs a real loopback round trip per fixture (a clean fold, a frame that decodes and replays to a
  refusal, a foreign session, a version mismatch) plus a peer that stops inside a reply frame, and a process grant that opens neither a listener nor a
  connection; the
  daemon's account of its answer is compared with the line the client decoded from the socket. The
  committed reference (`borg/tests/parity/ref/src/bin/frames.rs`) implements the frame layout, the
  refusal classification and the fold independently, including its own socket, and the module is
  called `frames` because `borg/src/transport.grl` already holds the local-control channel's rules.
- Borg journals replay into the in-memory session state (`borg/src/replay.grl`). The module folds a
  decoded event stream with the rules of `SessionState::reduce`/`apply` (session_store.rs:906-959,
  1036-1041, 1320-1336) over the five transcript kinds `borg/src/events.grl` carries, and
  reconstructs exactly what those kinds write: the sequence cursor, when the session started, the
  activity clock, status and detail, the title with the rule that a generated title is final
  (session_store.rs:952), the first and latest prompt and the latest reply. It folds typed events
  rather than bytes, so it cannot disagree with the reader about what an event says, and
  `replay_stream` propagates the reader's refusal — a cut tail, an unknown tag — instead of folding
  the rows that arrived before the cut; a refused stream yields no state at all. An event that cannot
  apply is refused by name with the index that stopped the fold and never skipped or forced:
  `sequence` (not the expected `last + 1`), `session` (another session's `session_id`),
  `unknown-actor` and `unknown-message-status` (outside `EventActor`'s and `MessageStatus`'
  four variants), and `stream` (the reader's own code). The one rule that drops rather than refuses —
  a title event while the current title was generated — is the model's own rule, so replay counts
  the drop (`titles_frozen`) instead of rejecting a journal Borg writes. `borg_events` gains typed
  accessors (`title_value`, `status_value`, `actor_value`, `tokens_value`, ...) so a fold can tell an
  absent optional from a text that happens to be `-`, and `no_event()`. `borg/tests/replay_test.grl`
  covers a clean journal, the empty one (which replays to the default state, not an error),
  out-of-order, unknown actor, unknown message status, a foreign session, the sticky title, and a
  journal read back from the typed byte stream intact and cut short, then generates journals: a
  seeded xorshift makes six events per seed and each seed must replay to the same checksum twice and
  to the same checksum as `prefix + [last]` versus `replay(prefix)` plus a direct `apply` — refusals
  compared by index and reason, so both sides must fail identically. The committed reference
  (`borg/tests/parity/ref/src/bin/replay.rs`) is an independent implementation of the same rules and
  of the byte stream, and the suite compares fingerprints and FNV-1a checksums field by field.
  `docs/design/borg-agent-port.md` records what replay reconstructs, the refusal table, and what it
  cannot cover yet: a real journal also carries `PlanProjected`, `SubagentRegistered` and provider
  events, whose unknown tags the reader refuses, so replaying one fails by name rather than
  returning the subset it understood.
- Windows task scheduling is now the same as Linux: a task is green on Windows, not an OS thread.
  One scheduler thread runs the tasks cooperatively, a task runs until it yields or blocks, and
  suspension parks the task rather than the thread. The switch is a Win32 fiber
  (`CreateFiberEx`/`SwitchToFiber`/`DeleteFiber`/`ConvertThreadToFiber`, declared in
  `compiler/os-windows.grl`, since `raw_switch` is not lowered for the PE targets) and the run queue
  parks on the same address wait (`WaitOnAddress`/`WakeByAddressAll`) the Linux build uses for its
  idle word. Windows has no epoll/eventfd/timerfd, so the platform reports no reactor
  (`rt_os_reactor()` = 0) and the runtime parks tasks *inside* blocking host operations instead:
  `host::read_file`, `host::write_file`, `host::command`, `host::read_fd`, `host::write_fd` and
  `host::sleep_ms` run the blocking call on a helper thread (`rt_offload`) and suspend the task, so
  another task keeps running, exactly as the reactor does on Linux. What is now identical:
  `spawn`/`join`/`task_scope`/`parallel_map`, cancellation, scope-exit joining, the run-until-it-
  yields-or-blocks rule, and the blocking-operation handoff. What still differs: Linux works the
  queue with one scheduler thread per CPU (4-64) so two ready tasks can run at once, while Windows
  has one thread and therefore a FIFO, deterministic interleaving; task stack cost is 256 KiB of
  mapping on Linux and a 64 KiB-in-256 KiB fiber on Windows. The previous thread-per-task scheduler
  is kept as an explicit opt-in, `GRAIL_TASKS=thread`, on every platform: each task then owns an OS
  thread, a task that never yields still progresses, suspension blocks that thread, `rt_wait_fd`
  returns immediately and `rt_reactor_fence` is a no-op. It is the better shape for CPU-bound
  fan-out once a `Send`/`Sync` check exists; there is none yet, so it is not the default. A program
  ported from Linux keeps its task semantics and must only stop relying on global interleaving
  order. Verified by execution under Wine (`bun tools/windows.mjs check`):
  `tasks-scope-and-parallel-map`, `tasks-sleep-overlap`, and the new `tasks-interleave-at-yield`
  (deterministic FIFO interleaving at yields), `tasks-sleep-progress` (a parked sleeper does not
  stop another task), `tasks-read-file-offload` (`host::read_file` from a task offloads and another
  task runs) and `tasks-thread-mode` (the opt-in mode still runs). The same four programs are also
  executed as Linux ELF where their result is platform-independent.
- Transferable and shareable, derived and default-denied, and a real soundness hole closed. The
  parallel surface asked one question of a type and answered it with a structural walk; the walk is
  now the design note's two properties and it reaches a closure's captures. `transfer_capability(c,
  ty, shared, trail, depth)` keeps its role as the single derivation engine and `shared` selects
  which property is asked, so `transferable(T)` and `shareable(T)` come from one recursion and stay
  genuinely distinct (a movable-but-not-shareable decoder context is one and not the other). Rules by
  kind: scalars (now including `char`) are both; a record, enum or union is both when every field is;
  a vector is its element; a typed slice is its element and is shareable only read-only; `&T` is
  shareable when `T` is (so a `&File` is refused even though nothing can be written through it);
  `&mut T` transfers but is never shareable; `Mutex<T>` and `Task<R>` and `byval(R)` behave as the
  table in `docs/design/parallelism.md` says; `Scope<C>` is neither. **A foreign handle is neither
  unless its own declaration says otherwise** - `handle File: transferable;`, `handle
  PhysicalDevice: transferable, shareable;`, `handle Window;` - and `shareable` alone is an error
  because sharing implies moving. `sys_grail` audits `File`, `Socket` and `Process` transferable-only
  (owned OS resources with no wrapper-side state, but nothing serializes two users of one) and
  `Thread` as neither (disposal is the creating thread's bookkeeping, and the shim hands every handle
  out through a `_Thread_local` slot); `abundance/src/rhi_vulkan.grl` audits `Instance` as neither
  (created and destroyed on the display's thread, every child dead before it) and `PhysicalDevice` as
  both (it owns nothing and every operation is a query). The hole: a closure type carried only its
  signature, so `parallel_map` checked the item, the result and the context but never the callback,
  and `g := |x: u64, u: u64| -> u64 touch(&h, x)` compiled - a plain-data signature with a
  thread-affine capture that every worker could reach. The environment is now part of the closure's
  type (`Ty.env`, interned into the type key, so two closures with one signature and different
  captures are the different types they already were as layouts), the walk classifies every capture,
  and `parallel_map` also refuses an `FnMut` callback because every worker shares one closure object.
  Rejections name the field instead of the type: `cannot share closure capture `a`: a.file is
  thread-affine (a foreign handle with no audited classification)`, `cannot share parallel_map
  context: file is thread-affine`, `cannot transfer spawned result: thread-affine (a foreign handle
  with no audited classification)`. The parallel surface speaks `transferable`/`shareable`; the
  opt-in generic bounds keep their old `Send`/`Share` names, since renaming a user-visible bound is a
  separate language change. `CStr`, `CPtr`/`CMutPtr` and `CFn` stay denied. Pinned by 12 cases in
  `tests/native-cases.json` - two accepted (a closure capturing a record of plain data and a shared
  slice of numbers, and a transferable handle crossing as a spawned result) and ten rejected, each
  with the field in its diagnostic. A scoped job primitive calls `require_capability_named` for the
  values it moves and `require_parallel_closure` for the closure it accepts, `shared` = 1 when the
  environment is called by several workers. Classification must reach B1's interface files before
  separate compilation can check it; `docs/design/parallelism.md` records the table, the audit and
  that contract.
- Parallelism stage 1: a real bounded work-stealing job pool in the runtime, and `lib/pool.grl` as
  the safe surface over it. The pool is one process-wide singleton created by the first parallel
  call: N workers (default max(4, available CPUs) capped at 64, `GRAIL_POOL_WORKERS` overrides it),
  one bounded ring per worker plus a bounded injection ring for threads that are not workers, owner
  push/pop at the tail (LIFO) and thieves taking from the head (FIFO) with a rotating victim cursor,
  and idle workers parked in the kernel on one futex wake sequence read *before* each scan, so no
  wakeup is lost and nothing spins for work. A job owns its callback, one environment word, one
  argument word and the single word it returns; the worker publishes the result with a release store
  and the thread that waits for the job frees the record, so every allocation has one releasing
  thread. A waiting worker runs queued work itself, so nested parallelism cannot deadlock even on a
  one-worker pool. `parallel_map` is now a client of the pool - it submits a few contiguous owned
  ranges per worker and waits for every job - instead of creating and joining threads per call, and
  it asserts that the per-job item counts sum to the item count, so an item written twice or not at
  all aborts rather than returning a plausible wrong answer. `rt_offload` stays the blocking path;
  a blocking foreign call never runs on a pool worker. Safe surface: `pool::map(items, f)`,
  `pool::run(count, f)`, `pool::for_chunks(data, chunks, f)` (consume a vector, one contiguous owned
  chunk per job, results concatenated in chunk order) and `pool::join(a, b)`; results are always in
  input order, and the ownership rule "everything a job's closure touches it owns" is stated in the
  module. Once the structural classification landed, item, result, context and the closure's
  captured environment are all classified: a handle - bare, inside a record, or captured - is refused
  by name (`cannot share closure capture `h`: h.file is thread-affine ...`), as are an `FnMut`
  closure shared with workers, a `Task` handle, an exclusive borrow, a mutable slice and an
  unproven type parameter. `CStr`, `CPtr`, `CMutPtr` and `cfn` stay deliberately unclassified, so
  they are refused as unclassified foreign authority rather than silently allowed; a classification
  states that a value may move, never that the library behind it tolerates that, and `unsafe module`
  code can still build anything - the safe surface is as strong as the classification under it, not
  more.
  Measured on 24 reported cores, 3M CPU-bound elements, one job vs four: 27 ms → 8 ms (3.4x) at the
  default size, 28 → 12 ms (2.3x) at four workers, 27 → 28 ms (0.96x) at one. Six native cases:
  owned-chunk split equals the sequential answer, `map` order independent of completion order,
  uneven work without deadlock, nested parallelism on a one-worker pool, an aborting job that
  ends the process instead of hanging, and the speedup assertion (which skips honestly below four cores).
  The test harness gained an `env` field for the one-worker case.
- Fixed an interaction between the pool and the Windows green scheduler, found only when the two
  branches met: the pool cached its pointer in `raw_state()+88`, and the green scheduler's new
  task-mode cache then stored the resolved mode (1) there, so a program that ran a `task_scope`
  before its first `parallel_map` read 1 as the pool pointer and faulted at address 0x9 - correct
  output first, then SIGSEGV inside `rt_parallel_map` (`program-parallel-primes`), and the same page
  fault under Wine. The pool's words are now 3200/3208, taken from named accessors that appear in a
  single process-state table in `compiler/runtime.grl` (word, owner, accessor, claimant) instead of
  a comment nobody owns. The same review found a second borrowing of the same kind: the pool read
  "which worker am I" from thread-record word 48, which is free on Linux but is the Windows address
  wait's per-thread expected-value slot, so every Windows wait and the pool marker fought over it;
  a worker now publishes its thread record into its own worker block and `rt_pool_self` scans the
  worker array, touching no thread-record word on any platform. Pinned by `pool-from-green-task`
  (parallel work entered from a task scope and from spawned tasks), which fails with 139 against the
  merged-but-unfixed runtime.
- Book and status documents match the 2026-11-10 increments. The book (54 examples, each with its
  Rust comparison) adds strict bool conditions (`strict-condition`: an integer condition is refused
  in both languages), consuming loops over owned elements (`consume-owned`) and range loops in
  *Branches and loops*, and a *Calling C* section in *Cleanup and current boundaries* with the
  `byval` record marker (`byval-record`), the handle and out-parameter surface, and what the FFI
  still refuses. Claims that map iteration, owned-element consumption, `FnMut`, borrowed captures,
  `char`, the sampling profiler, `.debug_info` locals or the language server were missing or
  rejected are gone, and so are the comparison notes that said Grail comparisons produce a number
  rather than `bool`. [docs/design/language-readiness.md](docs/design/language-readiness.md) now
  reports B1 stage 1, B2, B6 and B7 as implemented, with the Windows `byval` refusal;
  [docs/platform-status.md](docs/platform-status.md) replaces the stale FFI, tooling and COM rows;
  [docs/ffi.md](docs/ffi.md) documents the `byval` marker instead of listing it as decided-but-absent;
  and [docs/design/decisions-b2-b6.md](docs/design/decisions-b2-b6.md) records what landed for B1,
  B2 and B7.
- Fixed: the `FnMut` entry below had a duplicated half-paragraph spliced into it.
- Borg journals replay into the in-memory session state (`borg/src/replay.grl`). The module folds a
  decoded event stream with the rules of `SessionState::reduce`/`apply` (session_store.rs:906-959,
  1036-1041, 1320-1336) over the five transcript kinds `borg/src/events.grl` carries, and
  reconstructs exactly what those kinds write: the sequence cursor, when the session started, the
  activity clock, status and detail, the title with the rule that a generated title is final
  (session_store.rs:952), the first and latest prompt and the latest reply. It folds typed events
  rather than bytes, so it cannot disagree with the reader about what an event says, and
  `replay_stream` propagates the reader's refusal — a cut tail, an unknown tag — instead of folding
  the rows that arrived before the cut; a refused stream yields no state at all. An event that cannot
  apply is refused by name with the index that stopped the fold and never skipped or forced:
  `sequence` (not the expected `last + 1`), `session` (another session's `session_id`),
  `unknown-actor` and `unknown-message-status` (outside `EventActor`'s and `MessageStatus`'
  four variants), and `stream` (the reader's own code). The one rule that drops rather than refuses —
  a title event while the current title was generated — is the model's own rule, so replay counts
  the drop (`titles_frozen`) instead of rejecting a journal Borg writes. `borg_events` gains typed
  accessors (`title_value`, `status_value`, `actor_value`, `tokens_value`, ...) so a fold can tell an
  absent optional from a text that happens to be `-`, and `no_event()`. `borg/tests/replay_test.grl`
  covers a clean journal, the empty one (which replays to the default state, not an error),
  out-of-order, unknown actor, unknown message status, a foreign session, the sticky title, and a
  journal read back from the typed byte stream intact and cut short, then generates journals: a
  seeded xorshift makes six events per seed and each seed must replay to the same checksum twice and
  to the same checksum as `prefix + [last]` versus `replay(prefix)` plus a direct `apply` — refusals
  compared by index and reason, so both sides must fail identically. The committed reference
  (`borg/tests/parity/ref/src/bin/replay.rs`) is an independent implementation of the same rules and
  of the byte stream, and the suite compares fingerprints and FNV-1a checksums field by field.
  `docs/design/borg-agent-port.md` records what replay reconstructs, the refusal table, and what it
  cannot cover yet: a real journal also carries `PlanProjected`, `SubagentRegistered` and provider
  events, whose unknown tags the reader refuses, so replaying one fails by name rather than
  returning the subset it understood.
- Explicit environments for spawned processes: `host::command_with(argv, env)` runs `argv` with
  `env` as the child's *whole* environment and returns the same status encoding `host::command`
  returns (0–255 exit code, 128+N for a signal, 256+errno when the child could not be started, and
  278 = 256+EINVAL for a vector or entry that cannot be used). Nothing is inherited: an empty vector
  means the child starts with no environment from us, and a malformed entry (no `=`, or an empty
  name) is refused before anything is spawned, because `execve` would otherwise start the child with
  no environment at all and `CreateProcess` rejects the block. Both vectors are consumed, like
  `host::command`. `host::environment()` reports this process's own environment as `NAME=VALUE`
  entries, which is the additive spelling made explicit — `env := host::environment();
  env.push("APP_MODE=batch".copy()); host::command_with(argv, env)`. The executable search stays in
  the parent against the parent's `PATH`, so an explicit environment does not stop `"sh"` from being
  found. The spawn moved out of the portable runtime into the platform modules: `rt_spawn_wait` is
  `fork`/`execve`/`wait4` in `compiler/os-linux.grl` and `compiler/darwin.grl`, and `CreateProcessA`
  with an explicit (sorted, double-NUL-terminated) environment block in `compiler/os-windows.grl`,
  which also makes `host::command` work on windows-x86_64 for the first time: a NULL block inherits,
  a non-NULL one replaces. The Windows argument vector is quoted back into the command line with the
  `CommandLineToArgvW` rules; the ARM64 PE target reports the call as unimplemented because the
  ARM64 Win32 call path passes seven register arguments and `CreateProcessA` needs ten. Tests: six
  native cases (`command-with-env-carries-its-entries`, `-empty-env-clears-everything`,
  `-built-from-the-inherited-one`, `command-without-env-still-inherits`, `-refuses-malformed-entry`,
  `-reports-a-signalled-child`) and four Windows cases executed under Wine (`command-with-env`,
  `-inherit-env`, `-empty-env`, `-argv-round-trip`) plus one static ARM64 build. A host builtin that
  `compiler/*.grl` itself calls needs a **two-step bootstrap**, because the checked-in seed *is* the
  compiler and carries the `host::` table of the commit it was recorded from: stage a compiler that
  knows the builtin and point `GRAIL_COMPILER` at it, then reseed with that same variable
  (`bun tools/bootstrap.mjs update all` — `bootstrap.mjs` uses `buildCompiler()`, which honours
  `GRAIL_COMPILER`), then confirm on a clean tree (`rm -rf .work && bun tools/native.mjs build` with
  no `GRAIL_COMPILER`). `bun tools/bootstrap.mjs verify x86_64` is the 20-second version of that
  check: it still reports "checked-in bootstrap is stale" when `GRAIL_COMPILER` is set, which is the
  case the suites cannot catch. Until the reseed lands, a plain build of this branch fails at the seed with
  `unknown function` for `host::environment`; `docs/testing.md` records the cycle next to the other
  reseed notes.
- `authority::spawn_with(&a, argv, env)` gates an explicit environment with the same `may_spawn`
  grant as `authority::spawn`: spawning with an environment of your choosing is still a spawn, so
  neither route becomes a way around the other, and a file grant is refused exactly as it is for a
  plain spawn. `authority::environment()` returns this process's own entries so a program compiled
  with `--deny-ambient-host` can build an additive environment without opting into `use host;`;
  reading your own environment stays ungated, because every grant already implies the process can
  see its own configuration. What the grant covers is unchanged and still narrow: it decides
  *whether* a child starts, not what program it runs, and the child's own environment reads are
  outside the model.
- `grail profile` no longer uses a rendezvous file: the arming request
  (`GRAIL_PROFILE="1 RATE CAPACITY SAMPLES"`) travels in the target's environment through
  `host::command_with`, the samples go to a private `mkdir`-claimed scratch directory under
  `TMPDIR`, and nothing is written to the target's working directory. A killed run can no longer
  leave a stale request behind, the target no longer needs a writable working directory, and
  concurrent profiles no longer collide on `.grail-profile/`. The runtime reads the variable at
  startup instead of a config file. A profiled program that spawns Grail children with the
  inherited environment now arms them too (they share one sample file); a child started with an
  explicit environment is not armed unless the request is copied into it. `tools/test-profile.mjs`
  now also asserts that the target still sees a variable the runner set, and that no
  `grail-profile-` scratch directory is left behind.
- Typed-IR F1, a sequence-header fact for the LLVM backend: the front end now records, beside the
  word stream, that a frame slot or a call's argument 0 holds a pointer to a 24-byte sequence header
  -- `{data, len, cap}` for a vector, `what` 2/3/4 with element width 8/4/1 -- and the LLVM lifter
  can consume it, so nothing in `.s`, `optimize.grl`, `machine.grl` or the native backend changes. A
  fact-carrying `call rt_slot` is lowered into an internal sibling of the accessor emitted from the
  same word-machine body with argument 0 typed `ptr nocapture nofree dereferenceable(24) align 8` and
  with `data`/`len` passed in, so the two header loads leave the body; the call site emits them once
  where the fact is established, at `align 8`, and passes them. `len` dies on
  push/pop/remove/insert/truncate/fill/clear and `data` on any growth or untyped write to the slot,
  enforced by invalidating the hoisted pair on any call that is given the header and is not a
  read-only accessor, and on any `leaq` of the slot; `cap` is never read, so a descriptor's
  uninitialised `+16` is unreachable from an F1 fact.
  `--verify-facts` now checks F1 too: non-null and eight-byte aligned, `cap >= len` through `+16`
  for a vector fact (the tripwire for a vector fact on a descriptor), and the element pointer inside
  `data .. data + len*width` for the wide accessors. `tools/test-facts.mjs` compiles a fixture with a
  deliberately wrong fact (`--f1-what=N`, a test aid) and shows the flag aborting in that check
  instead of printing a plausible number. Measured with `tools/bench.mjs --rounds 9`, F1 is
  **neutral, not a win**: `dereferenceable(24)` on the accessor's parameter is not re-derived for the
  inlined argument, so LLVM still will not speculate the header load out of a loop, and the lifter's
  own hoist is only sound where the establishing block dominates the call -- which the word machine's
  frame-spilled temporaries never make true on this corpus. Letting the call site re-read the fields
  when they are not established instead is measured at `nbody` 1.72x -> 1.89x, so that form is not in
  the tree. The fact and its verifier stay because a pointer type with an element width is the half
  that outlives this attempt. See `docs/design/typed-ir.md`, "Implemented: F1".
- B1 stage 1, per-module emission: `grail build --split` writes one assembly file per module
  (`OUT.NNN.module.s`) plus `OUT.parts`, assembles the parts concurrently and links them once,
  instead of one `.s` for the whole program. Emission is still a single pass — the optimizer inlines
  across modules and generic specialisations are emitted at the module that defines the generic — so
  the compiler records a `.grail_part <module>` marker where the module changes, the optimizer
  reports the offset each marker landed at (also after its inlining pass rewrites the stream), and
  the writer cuts the finished stream at those offsets. Splitting therefore copies nothing and the
  compile time is unchanged; what the parts cannot own goes to one synthetic `__start` part: the
  entry stub, `rt_state`, the TLS bases and `.note.GNU-stack`. String literals travel with the
  function that emits them (`.pushsection .rodata`/`.popsection` inside a module's own code), so
  there is no program-wide literal pool to duplicate or pool. Two things differ from the single-file
  build, both inherent to linking several objects: with `--split` a function another part calls is
  `.globl` (names, sizes and order unchanged; in the compiler's own build the symbol table is the
  same size and `sh_info` moves 2366 → 1139), and the linker inserts alignment padding between input
  sections (15 bytes across nine boundaries for the compiler, a few bytes for small programs). Code
  and data bytes do not change. A whole-program build is untouched: no `--split`, the same compiler,
  the same `.s`, byte for byte. Scope is the Linux x86-64 assembler path, without `--debug` and
  `--backend=llvm`; other targets keep the whole-program build because `machine::lower` rewrites the
  stream after the optimizer. `bun tools/split-test.mjs` (also `just test-split`, and a CI job)
  proves it on the book's `modules` example, a generic-heavy native corpus case and the compiler
  itself: the parts minus their `.text` prologue and the added `.globl` lines concatenate to the
  single assembly file byte for byte, the concatenated objects have the single object's `.text`
  length and match outside relocation fields, the linked programs have the same `.rodata`/`.data`/
  `.bss`, the same symbols and the same output, and `grail build --split` agrees with `grail build`.
  Measured on the compiler compiling itself (10 modules, 33 MB of assembly): compile 15.6–15.8 s →
  15.7–15.9 s, assemble 1.62–1.65 s → 0.99–1.02 s (−38 %), link 18–19 ms → 21–22 ms, total ~17.3 s →
  ~16.8 s. See `docs/design/separate-compilation.md`, "Stage 1 as built".
- RHI increment 2: `abundance/src/rhi_vulkan.grl` creates a real `VkInstance` and picks a real
  physical device. `vkCreateInstance` is called through the FFI's out-parameter form — `slot: &mut
  Instance` in the declaration, `&mut instance` at the call site — with `VkInstanceCreateInfo` as an
  `extern "C" record` holding the C layout (64 bytes; `sType` 0, `pNext` 8, `flags` 16,
  `pApplicationInfo` 24, the two counts and name arrays at 32/40/48/56), and `vkDestroyInstance` on
  every path that created one, the paths where a later call failed included. Physical devices are
  enumerated three ways through one symbol: a count query, a single handle slot (`&mut
  PhysicalDevice`, which is also the seed the array form needs) and a fixed-capacity record of
  handle fields, because a record *parameter* is the address of the record's fields and a handle
  cannot be read out of a byte buffer. `VkPhysicalDeviceProperties` (824 bytes) and
  `VkQueueFamilyProperties` (24 bytes each) are decoded at their C offsets, selection ranks device
  types (discrete, integrated, virtual, CPU) with an optional name filter, and the first
  graphics-capable queue family is chosen and printed. Two calls are deliberately not made:
  `VkApplicationInfo` cannot be passed and `vkCreateDevice` is not declared, because Grail has no
  expression whose value is the address of an owned `extern "C"` record, so a create-info cannot
  point at another struct (`pApplicationInfo`, `pQueueCreateInfos`, `ppEnabledExtensionNames`,
  `pNext`); `cptr` takes only byte sequences and views, and a `&mut` record is not an
  out-parameter slot. Both refusals are pinned as `ffi-reject-record-address` and
  `ffi-reject-record-out-param` in `tests/native-cases.json`, the probe says
  `unavailable extern-C-cannot-take-the-address-of-a-record` on its own output line, and
  `docs/rhi.md` states what that costs and what unblocks it. New program
  `abundance/tests/rhi_vulkan_probe.grl` replaces the Vulkan half of `rhi_device_probe.grl`, which
  now covers the SDL3 window alone; `tools/abundance-test.mjs` links one system library per probe,
  so the Vulkan probe runs on a machine with no display server while the window probe skips there.
- `FnMut`: a closure that mutates a captured value now works, with the rules B6 fixed in advance.
  The body is scanned for a store to a capture or to a place rooted at it (`n = ..`, `n += ..`,
  `s.field = ..`, `v[i] = ..`, `*r = ..`), a mutable borrow of it (`&mut n`) and method calls that
  may mutate their receiver; a closure with any such capture is `FnMut(...)` instead of `Fn(...)`.
  Only the written captures are mutable in the body, and the body's hidden environment parameter is
  `&mut Env`, so a store goes through an exclusive reference to the environment field and the
  existing loan checks apply. Calling an `FnMut` value needs a mutable binding (`mut f = |...|`),
  borrows the closure exclusively for the whole call and ends that borrow when the call returns: a
  second simultaneous call (`f(f(1))`) or a live shared borrow of the closure is rejected, and a
  `FnMut` closure used where `Fn` is required (the `Fn(...)` parameter type, a function value
  coerced to it, `vecs::sort_by` and the other stdlib callbacks) is rejected with a diagnostic that
  says why instead of being silently made exclusive. A closure that writes nothing stays `Fn` and is
  accepted where `FnMut` is expected, by value and as `&mut Fn(...)` for `&mut FnMut(...)`; `FnMut`
  is written in type position like `Fn`. A by-value `FnMut` parameter cannot be called, because
  parameters are not mutable storage — adapters take `&mut FnMut(...)`, and even then a callable
  reached through a reference parameter can be called once in straight-line code (the pre-existing
  `access has no live reference authority` limitation, which reproduces on `main` with `&Fn`).
  `compiler/native.grl`, fourteen cases in `tests/native-cases.json` (`closure-fnmut-counter`,
  `-disjoint-captures`, `-sequential-calls`, `-second-call-rejected`, `-shared-borrow-rejected`,
  `-not-fn-rejected`, `-sort-by-rejected`, `-vector-element`, `-captured-field`,
  `-needs-mut-binding`, `-through-exclusive-reference`, `-mixed-captures`,
  `closure-shared-capture-still-fn`, `closure-shared-borrow-of-fn-closure`) plus the two former
  read-only rejections now accepted as `closure-capture-mutation-fnmut` and
  `closure-capture-borrow-mut-fnmut`, the book example `fnmut`, and the B6 decision record.
- LLVM backend: typed-IR fact **F2**, "this word holds an `f32`". The front end now records, beside
  the word stream rather than in it, that a local's frame slot holds an `f32` and that a given
  `rt_f64_op` call computes on two `f32` operands with a given opcode; `compiler/llvm.grl` lowers an
  accepted slot to `alloca float` with `load float`/`store float` and one `fpext` to the binary64
  word the rest of the program expects, and an accepted call to `fadd`/`fsub`/`fmul`/`fdiv float`
  plus the single `fpext` that produces the result word. `matmul`'s inner loop becomes
  `movss`/`mulss`/`addss` with no `cvtss2sd`/`cvtsd2ss`, so the `f32` kernel stops being penalised
  for being unrolled; output is bit-identical (the standard `p2 >= 2*p1 + 2` argument, pinned by new
  cases that print each `f32` result as `f64`, i.e. its shortest round-trip decimal). The fact table
  never enters the stream: `optimize.grl`, `machine.grl` and the native backend are untouched, the
  native assembly is byte-identical, and a slot whose address is taken or that the body touches in
  any way other than one eight-byte word is dropped and keeps the word lowering. `--verify-facts`
  (off by default) emits `fpext(fptrunc(d)) == d` at every word a fact treats as an `f32` and writes
  the table into the module as `; fact` comments; `tools/test-facts.mjs` runs it.
  Measured on x86-64 with `tools/bench.mjs --rounds 9` (paired medians): `fnv`/`sieve`/`sort`/`nbody`
  unchanged, and `nbody` correctly gets no fact at all (its 38 float operations are `f64`). `matmul`
  does **not** get faster at default `-O2` on the measuring host: 0.220 s -> 0.214 s in the 9-round
  paired run, and 1.000 / 1.014 (after/before) over two 41-round paired A/B runs, i.e. within noise
  -- this LLVM already unrolls the kernel, and the second element of the unrolled pair hides the
  widened dependency chain. What F2 is worth is the design's own experiment: with every check branch
  deleted from the `.ll` (measurement only), `matmul` is 0.360 s / **1.95x** C before and 0.191 s /
  **1.05x** C after, so F2 is what turns "remove the bounds checks" from a 1.9x regression into C
  parity, which is F1's lever. Design and the full measured table: `docs/design/typed-ir.md`,
  *Implemented: F2*.
- FFI out-parameters: a C function can write a handle or bare pointer through a slot the caller owns,
  spelled as a mutable borrow in the declaration (`slot: &mut Instance`) and `&mut binding` at the
  call site. That is the Vulkan/D3D12/Metal create shape (`vkCreateInstance(..., VkInstance
  *pInstance)`), which no result register can express. The parameter is the C `H *`; the callee
  writes one word into the binding's own slot and Grail reads the binding afterwards. A handle or
  bare pointer binding declared without an initializer is now null instead of uninitialized, so the
  callee always reads a defined word and a binding that already holds a value seeds the next call.
  Only `handle`, `CPtr` and `CMutPtr` slots are out-parameters; a shared `&H`, any other `&mut T`, a
  C callback parameter and a `cfn` type's parameter are refused with their own diagnostic, and the
  slot is an ordinary mutable borrow, so one call cannot take it twice
  (`compiler/native.grl`, `docs/ffi.md`, `tests/ffi/out_params.grl`, and the `ffi-out-params` case
  that executes under Wine on Windows x86-64).
- FFI calls of more than six word arguments execute with the target's own limit: six integer argument
  registers on x86-64 and the outgoing stack after them, eight on AArch64 and RISC-V 64. Argument
  words past the register file are stack slots (up to 64 words, 2 KiB of outgoing area), so Vulkan
  entry points of seven to ten words are expressible. `tests/ffi/call_words.grl` executes seven,
  eight and nine word arguments with literal and computed values on x86-64, AArch64 and RISC-V 64, so
  a dropped or misplaced word changes the printed sum; with the old peephole argument-register model
  the same fixture returns 91 and 603 instead of 140 and 204 on AArch64 and RISC-V 64. The
  `ffi-call-words` case runs the same calls on Windows x86-64 under Wine.
- Fixed: an exported C callback with a seventh or eighth parameter read the sixth again. The callback
  prologue clamped at `%r9` instead of reading the seventh and eighth integer argument registers, so
  on AArch64 and RISC-V 64 the extra parameters arrived as copies of the sixth. It now reads the
  target's own argument registers, which `tests/ffi/callback_words.grl` executes on those two
  targets (1 + 2*2 + ... + 8*8 = 204, previously 181). x86-64 and Windows, whose callback prologue
  reads registers only, refuse a parameter list beyond six integer words by name instead of reading
  a register that holds something else.
- Opaque handles across modules, and identity comparison. A `handle` declared in one module is
  nameable in any module that imports it (`use sys_grail;` then `sys_grail::File`, or
  `use sys_grail::File;` then `File`), so another module can name it in a parameter, a result and a
  record field - `tests/handles/stream_def.grl` + `stream_user.grl` execute an `fopen`/`fileno`/
  `fclose` round trip through a field and back to C, which pins it. `==`/`!=` between two handles of
  the same type now compile to a word compare, the "compared by identity" rule `docs/ffi.md` already
  stated but which failed with `type mismatch`; a record field of handle type compares the same way.
  A handle used where it has no value names the rule instead of `type mismatch`: arithmetic and
  ordering say "a handle is a foreign token: pass it, store it in a field, or compare it with == / !=
  against a handle of the same type; it has no arithmetic, ordering or size", a value of another type
  where a handle is expected says it cannot be constructed or converted (only a foreign call produces
  one), and two different handle types say they do not mix. Handles stay one-word values the compiler
  never frees (`docs/ffi.md`), so binding one copies the word rather than moving it; that documented
  non-linearity is unchanged. `tests/native-cases.json` gains `cross-module-handle-signatures` and
  `handle-reject-arithmetic`.
- Fixed: `!` on a `None` inside an `extern "C"` callback died of SIGSEGV instead of reaching the
  checked abort (SIGABRT / exit 134, the B5 policy). The unwrap was right; the value never existed.
  A declaration (`absent: u64? := None`), an assignment and a `return` in an `unsafe module` all
  skipped `adopt_value`, which is the context *lowering* - `None`/`Some` construction, union
  injection, a function used as a closure - and not a check, so a raw module left `None` as an
  untyped `0` and `absent!` dereferenced a null payload. The three sites now run `adopt_value`
  regardless of raw mode; only `require_type` and the literal-typing tail (a raw module's literals
  stay untyped words) remain safe-mode. The `None` token span is also cleared when the token stream
  or `locals` is replaced, like the call-flex hint record, so a span from another file can never
  fabricate an option object. `tests/ffi/unwrap_none_callback.grl` (an `extern "C"` callback that C
  calls through the shim) asserts SIGABRT and the output printed before it; without the fix the same
  program dies of SIGSEGV.
- Fixed: a sized integer in an `unsafe module` (the runtime's raw mode) computed its arithmetic as
  an untyped unsigned word, so `x: i32 = 0; x = x - 1` aborted in checked mode instead of producing
  `-1`, and an `i64` comparison such as `status < 0` was an unsigned compare. Raw mode skips the
  *checks* for a stated integer type, not the type itself: the binary operator path, compound
  assignment and `compound_value` now pick `int_binary` whenever an operand's type is a sized
  integer (taking it from either operand), so subtraction, comparison, shifts, division and
  multiplication keep the stated signedness and width inside `unsafe module runtime`/`darwin` code.
  `tests/native-cases.json` `raw-module-sized-integer-arithmetic` pins `0 - 1` as `-1`, a signed
  comparison, `i8` 120 + 7 and an `i64` comparison, with an `extern "C"` declaration that carries a
  `cfn` parameter in the same module - the shape the report named, though the `cfn` itself was not
  the trigger: any `unsafe module` showed it.
- `grail profile [--rate N] [--out FILE] -- PROGRAM [ARGS]` samples a compiled Grail program and
  prints a per-function table (`samples`, `share`, `function`, `module`) plus `[unknown]` and
  `total` rows. The sampler is part of the program's runtime, not a wrapper around `perf`: on Linux
  x86-64 `compiler/runtime.grl` looks for a `.grail-profile/config` rendezvous file at startup,
  maps a 65536-entry address buffer and a 64 KiB alternate signal stack, installs a `SIGPROF`
  handler and starts `ITIMER_PROF` at `1/rate` of CPU time. The handler reads the interrupted `RIP`
  from the kernel `ucontext_t`, claims a slot with a CAS loop and stores one word - it never
  allocates, never takes the allocator lock and never enters the kernel, so it cannot deadlock
  against the runtime. Samples are written as `GRPROF2` plus the rate, capacity, count, dropped
  count, the `CLOCK_PROCESS_CPUTIME_ID` nanoseconds the samples cover and the raw addresses on
  normal exit, `host::exit` or a runtime abort. The report prints the measured CPU time and the
  effective rate (`samples / CPU seconds`) and says so when the request was not honoured, because
  the kernel accounts CPU time per tick and caps the effective rate near one kilohertz regardless of
  `--rate`. The command then
  parses the program's ELF `.symtab` (`SHT_SYMTAB` + linked `.strtab`, `STT_FUNC` ranges since the
  compiler emits no `st_size`) and binary-searches each address. Addresses outside every symbol are
  reported in an always-present `[unknown]` row rather than dropped, and the report states that a
  default build is `ET_EXEC` and needs no PIE adjustment (a relocated `ET_DYN` binary is reported as
  unmatched instead of guessed). No `perf`, `nm`, `addr2line` or debug section is used at any
  point; `.grail-profile/` is created and removed in the working directory because safe Grail code
  cannot set a child's environment. `tools/test-profile.mjs` (`just profile-test`, the CI `profiler`
  job, and a `bun tools/ci.mjs lint` check) profiles a known hot loop at a fixed rate and asserts
  the hot function is the first row with over half of the attributed samples, that the rows sum to
  the total, that a stripped copy lands entirely in `[unknown]`, and that `--out` matches stdout.
  `docs/tooling/profiler.md` documents the command, the columns and the limits: the sampled code
  cost (about 3.4 KiB of `x86-64` text in every program and one failing `openat` at startup when no
  profile was requested), leaf-only
  attribution, optimiser inlining, no line granularity, CPU-time rather than wall-clock sampling,
  no report when the program is killed, and Linux x86-64 only (other targets compile the hook but
  never arm it, and `grail profile` refuses to run there).

- Records can be passed to C **by value**: `v: byval R` in an `extern "C"` declaration (or a
  `cfn(...)` parameter list) passes the whole record the way C does, while a bare `R` keeps meaning
  the C `R *`. The classification reuses the record's C layout and is per target ABI: SysV x86-64
  classifies each eightbyte INTEGER or SSE (a mixed eightbyte is INTEGER, over 16 bytes is MEMORY on
  the caller's stack, and an exhausted register class sends the whole record to the stack); AAPCS64
  passes homogeneous float aggregates in `v0`-`v7`, other composites of 16 bytes or less in
  consecutive `x0`-`x7`, and larger records by reference to a caller copy; RISC-V 64 passes records
  over 2xXLEN by reference, and at or below it either one register per field (one or two fields with
  at least one float) or one integer register per eightbyte. `byval` is refused with a diagnostic on
  the Windows ABIs (MSVC struct rules, no Windows FFI execution path here), on anything that is not
  an `extern "C"` record, and in an `extern "C" fn` definition (C calling Grail with a by-value
  record), rather than approximated. `tests/ffi/byval_records.grl` with `tests/ffi/byval_shim.c`
  executes 4-, 8-, 16- and 24-byte records, mixed int/float fields, an ImVec2-shaped float pair, an
  embedded array, a byval argument after six integer arguments, a byval record sharing the stack area
  with a following scalar and a `cfn` call on x86-64, AArch64 and RISC-V 64 (the latter two under
  qemu); `docs/ffi.md` gains the syntax, the per-ABI rule table and the refusal cases.
- A C-layout record argument to a `cfn` call is now borrowed, not moved, exactly as a direct extern
  call treats it: the callee receives a pointer to (or a copy of) the record's fields and Grail keeps
  ownership, so the value is still usable after the call.

- Fixed: `tools/test-ffi.mjs` listed the `pointers` fixture by repeating keys inside the
  `nested_records` entry, so `nested_records` never ran. Both fixtures are entries of their own and
  both pass.
- Borg session state persists a typed event stream instead of an opaque payload
  (`borg/src/ffi/store.grl`, `borg/src/events.grl`). The frame still opens with the `BGS` magic and
  now carries the version digit `2`, a little-endian payload length and a sequence of tagged events;
  a `1` file is refused as `unsupported-version` rather than decoded as events. Each event is a
  one-byte tag, a 32-bit body length and explicitly typed fields: little-endian numbers,
  length-prefixed text, 0/1 booleans, presence-tagged optional values and length-counted text lists.
  An unknown tag, an event cut short, a body length past the 256 KiB per-event ceiling, a boolean or
  presence byte that is neither 0 nor 1, and bytes past an event's last field are each refused by
  name, and a refused stream yields no events. Every declared length is checked against the bytes
  actually present, and the payload is capped at 1 MiB before the file is read, so no
  attacker-controlled length becomes an allocation. The same-directory temp file and rename are
  unchanged, and the write is still not fsynced. `just borg-store-test` covers the empty stream, one
  event of every variant, ordering, and every refusal (`borg/tests/ffi/store_test.grl`).
- `lib/sys/grail_ffi.grl` re-binds the `&mut [u8]` argument of `read`, `env_get` and `recv` to a
  mutable local before the C call. The ownership checker requires a mutable binding for storage a
  call writes through, and a parameter binding cannot be `mut`, so forwarding the reference straight
  through no longer compiled: the FFI wrapper, and every test that links it, failed to build.
- The seven owner decisions left open in `docs/design/language-readiness.md` section B are settled
  and recorded in `docs/design/decisions-b2-b6.md`: B1 (separate compilation with checked module
  interfaces) and B7 (records passed by value, spelling `v: byval R`) are accepted and in progress;
  B2 keeps ambient `host::` for v1 as a recorded deviation with the conditions that force a change;
  B3 makes a foreign call block the executing thread with no green-task integration; B4 keeps
  thread-per-blocking-call on Windows and names IOCP as future work with a sketch; B5 fixes abort as
  "never unwinds, nothing unwinds across the C boundary"; B6 records that closures capture
  references and views under region checking and defers `FnMut` with six fixed rules. Section B of
  the readiness audit now marks every row decided with a one-line summary and a link, so the work
  can proceed without re-arguing the choices.
- Documentation corrections found while writing those decisions: `implementation-status.md` reported
  the user FFI boundary as missing (it is implemented and executed on six targets) and borrowing
  closure captures as missing (they exist; only `FnMut` is deferred); `concurrency-v1.md` claimed
  blocking foreign calls are isolated (only `host::read_file`, `host::write_file` and
  `host::command` are offloaded, from a green task); `windows-backend.md` and B4 now state that a
  green-task spawn aborts on Windows because the scheduler treats a missing `epoll` as fatal, which
  a task-scope program reproducing it confirms (exit 134 under Wine, no output, against `42` and
  exit 0 on Linux); `borg-agent-port.md` blockers 1 and 3 are annotated as resolved before that
  record; README lost a duplicated Windows paragraph and no longer reports Windows threads as
  missing; `runtime-api.md` keeps its OS-wrapper plan but records that its premise - the compiler
  not yet accepting `extern "C"` declarations - has changed. No compiler or runtime code changed.
- Strict-bool is now the language's rule, not an opt-in survey: a `bool` and an integer no longer mix,
  and every `if`/`while` condition must be a `bool`. `if n` is written `if n != 0`, `(a < b) + (c < d)`
  is `a < b || c < d`, `flag & (x == 0)` is `flag != 0 && x == 0`, and `f(x) == 0` on a predicate is
  `!f(x)`. The compiler's own sources were migrated first (`docs/design/strict-bool-migration.md`):
  `--strict-bool-report` over them went 1595 -> 1409 (predicates that return `bool` instead of a 0/1
  `u64`) -> 405 (operators) -> 0 (conditions).
  - `--strict-bool` is gone: the rule is enforced whenever the compiler type-checks a program (it stays
    off in `unsafe module` sources, as before), and a violation is a compile error.
  - `--strict-bool-report` remains as the survey mode: it prints `file:line:column: message` for every
    violation, keeps compiling and exits 0.
  - `--strict-bool-fix` and its `FIX ...` records are deleted; the `tools/strict-bool-fix.py` they were
    meant for never existed.
  - Migrated with it: the test corpus and the examples (`tests/native-cases.json`, `compiler/tests`,
    `compiler/examples`, `book/examples`, `examples/loops/cleanup.grl`), where `if flag` became
    `if flag != 0` and the fixture that asserted bool arithmetic now spells the conversion with
    `u64(1 == 1) + u64(2 == 2)`.
- The RHI starts in Grail. `abundance/src/rhi_sdl3.grl` and `abundance/src/rhi_vulkan.grl` bind the
  system SDL3 and Vulkan loaders through `extern \"C\"` declarations, and
  `abundance/tests/rhi_device_probe.grl` exercises them against this machine: `SDL_GetVersion`,
  `SDL_Init(SDL_INIT_VIDEO)`, `SDL_GetCurrentVideoDriver`, a hidden `SDL_WINDOW_VULKAN` window with
  `SDL_GetWindowSize`/`SDL_GetWindowSizeInPixels` and `SDL_DestroyWindow`, then
  `vkEnumerateInstanceVersion` and the loader's instance extensions and layers, decoded at their C
  offsets out of `VkExtensionProperties`/`VkLayerProperties` byte buffers. `tools/abundance-test.mjs`
  runs the probe after the parity suite under the same exclusive GPU lock `graphics/Makefile` takes,
  and skips it when no `libSDL3.so`/`libvulkan.so` can be linked; the ten parity programs are
  unchanged and still byte-identical, because the two FFI modules are linked only by the probe.
  `VkInstance` creation is blocked by an FFI limit, not by a driver: `handle` and `CPtr` values enter
  Grail only as a foreign call's *result*, so `vkCreateInstance`'s `VkInstance *` out-parameter has no
  spelling. The new `ffi-reject-handle-out-slot` and `ffi-reject-handle-null-seed` native cases pin
  the two refusals, and `docs/rhi.md` states what the increment covers, what it does not, and the
  next three.
- **Authority/capability model for OS access (decision B2).** `lib/authority.grl` makes OS access
  an explicit value: `authority::open_read(root)`, `open_write(root)`, `open(root)`, `process()`
  and `sockets()` create an owned `Authority`, and `authority::read_file`, `write_file`, `spawn`,
  `connect`, `listen`, `port` and `close` enforce it. Path containment is lexical and
  component-wise after normalising `.`, `..` and duplicate separators (both `/` and `\`), so
  `/database` is not under `/data` and `/data/../etc/passwd` is `Denied`; the operation opens the
  same resolved path the check approved. `authority::Error` keeps an OS error (`not found`)
  distinct from a denial. The new compiler switch `--deny-ambient-host` rejects any `host::`
  reference in a module whose `use` lines do not name `host`, covering calls, function values and
  constants; `use host;` is the module-level opt-in (Grail has no attribute syntax), and ambient
  `host::` remains the default without the switch. `grail build`, `grail check` and `grail test`
  forward the flag. The switch does not cover `extern "C"` declarations, compiler builtins or
  descriptor values, and containment does not resolve symlinks (see `docs/authority.md`). New
  `bun tools/test-authority.mjs` (74 checks: 57 containment cases, a gated read/write/spawn/socket
  round trip, and the switch), wired into `just test-authority` and the full linux-x86_64 CI lane.
  Book: a "Capabilities instead of ambient access" section and the `authority` example with its
  Rust comparison.
- The compiler no longer dies of SIGABRT on a stale call-flex hint record. `hint_use` remembers the
  token span and `locals` index of a committed literal binding whose type a later use may fix, but the
  record outlived the file that made it: token spans are indices into one file's token stream, so a
  record from one file could match an unrelated argument in the next, and the `locals` index it
  carried could reach past that function's locals. On the Borg module set that aborted the compiler
  with no diagnostic and no output. The record is now cleared wherever the token stream or `locals` is
  replaced (file load, function, closure body), and a stale index is reported as a
  `file:line:column` internal-error diagnostic instead of faulting the process.
  `compiler/tests/hint_scope_record.grl` + `hint_scope_stale.grl` (case `literal-hint-scope`)
  reproduce the abort in two eight-line files; the triggering program is valid, so the `.copy()` and
  `.text()` call sites that exposed it are unchanged.
- Two cross-lane defects found while wiring the release pipeline: `bun tools/ci.mjs build
  --platform windows-x86_64` no longer passes `compiler/os-linux.grl` alongside the
  `compiler/os-windows.grl` that `tools/windows.mjs` appends, which made the PE/COFF build fail with
  a duplicate `rt_syscall`; and the Mach-O object check reads `llvm-nm --extern-only` so the
  compiler object's local symbols no longer overflow the command buffer. Windows x86-64 and both
  macOS object lanes build again.
- Release pipeline for `v*` tags (`.github/workflows/release.yml`, `tools/release.mjs`,
  `docs/releases.md`). Every supported target builds from the checked-in bootstrap seed with no
  development compiler (`GRAIL_COMPILER` is refused) and no network beyond the runner toolchain;
  the workflow publishes one GitHub release per tag with the per-target artifacts, a `SHA256SUMS`
  file, `release.json` provenance and a generated `RELEASE-README.md`. Linux x86-64, AArch64 and
  RISC-V 64 ship real ELF compiler executables; windows-x86_64 ships a cross-built PE32+ compiler
  image and COFF object bundle that are static-checked but not runnable on Windows yet; macOS
  ships static-checked Mach-O object bundles only; windows-aarch64 remains planned and is not
  published. `tools/ci.mjs build`/`package` gained `--stage0 PATH` for a seed-built stage0, and
  `bun tools/ci.mjs lint` now checks the release workflow against the platform matrix.
- A language server for Grail, **written in Grail** (`tools/lsp/main.grl`, launched by
  `bun tools/lsp.mjs`, also `just lsp`), replacing the JavaScript MVP that lived in
  `tools/lsp.mjs`/`tools/lsp.test.mjs` (both removed). It speaks JSON-RPC 2.0 over stdio with
  `Content-Length` framing and implements `initialize`/`initialized`, `shutdown`/`exit`,
  full-text `didOpen`/`didChange`/`didClose`, and `textDocument/publishDiagnostics` from the
  existing compiler: the buffer is written to a scratch file, `grail check` runs on it in its
  own directory, and the compiler's `file:line:column: message` diagnostics are published as
  UTF-16 ranges (severity Error, `source: grail`, `code: compiler`) and cleared with `[]` when
  the buffer checks clean or is closed. `textDocument/definition` answers from the same file
  for a function declaration, a local `NAME :=`/`mut NAME` binding, a `for` binding and a
  function parameter, using `compiler/lexer.grl` in process. Malformed input is answered with
  the JSON-RPC error that describes it — `-32700` for framing and JSON, `-32601` for unknown
  methods, `-32002` before `initialize`, `-32600` after `shutdown`, `-32602` for definition
  params — and never terminates the server; a frame that carried no usable `Content-Length`
  is discarded and the reader resynchronises on the next header line. `initialize` advertises
  only `textDocumentSync` and `definitionProvider`: no hover, completion, rename, formatting,
  references, symbols or pull diagnostics. `bun tools/lsp-test.mjs` (55 checks, hermetic: it
  builds the compiler and the server from the tree) drives a real stdio session, is wired
  into `just lsp-test`, `bun tools/ci.mjs lint` and the CI `lsp` lane, and the server is
  documented in `docs/tooling/lsp.md`.

- Decision B4 (Windows I/O readiness): the green-task reactor is epoll-only, so on Windows
  (`rt_threaded()`) a task is now an OS thread instead of aborting on a failed `epoll_create`:
  `spawn` creates the thread, `join`/scope exit wait on the task's finished word and reap it,
  suspension parks the task's own thread on its park word with `WaitOnAddress`, `host::sleep_ms`
  sleeps that thread and `rt_wait_fd` returns immediately (thread-per-blocking-call). `rt_sched`
  never creates a reactor there, so `spawn`, `task_scope` and `parallel_map` work; a blocking foreign
  call blocks only its own task. `WaitOnAddress`'s expected value moved from one shared scratch word
  to the calling thread's record, because two task threads can now wait on different values at once.
  Windows cases `tasks-scope-and-parallel-map` and `tasks-sleep-overlap` execute under Wine and on
  Linux. Not implemented: IOCP, overlapped I/O, and an ARM64 thread bridge.
- Decision B3 (suspension and blocking contract): a foreign call blocks the executing task thread.
  The runtime's own blocking operations hand the call to a dedicated OS thread and suspend the task
  (`rt_blocking_call`, now the single entry point for `host::read_file`, `host::write_file` and
  `host::command`), so no worker is lost; `host::pipe` and `host::sleep_ms` suspend on the reactor.
  An `extern "C"`/`cfn` call is not wrapped by the compiler, so it runs on the worker and blocks it,
  and a wrapper that knows it blocks declares that with `rt_blocking_enter`, which makes the runtime
  warn once per process on stderr. Native cases `blocking-foreign-call-occupies-worker` (two tasks,
  one blocking in libc `usleep`: the other keeps running and the warning appears exactly once) and
  `blocking-foreign-call-handoff-is-silent` (the same call through the handoff: silent) pin the
  contract; `docs/ffi.md` states it for users.
- Decision B5 (abort/unwind policy): abort never unwinds, and nothing may unwind across the C
  boundary. `rt_abort` is the only abort entry point and now ends in a platform `rt_hard_exit`:
  `exit_group` on Linux, `TerminateProcess` on Windows, `_exit` on macOS. Two defects are fixed.
  A Windows abort used `ExitProcess`, which runs DLL detach handlers and C++ static destructors; and
  on x86-64 Linux the fallback was `exit(2)`, which ends only the calling thread, so an abort inside
  a green task whose SIGABRT was caught by a foreign handler left the process waiting forever. Both
  now end the whole process with no foreign cleanup. Tested from inside a Grail callback that C
  called (glibc `qsort`) and from a green task: `tests/abort/` plus native cases
  `abort-in-c-callback-*`, `abort-in-green-task-ends-process`, `abort-unwrap-none`, with a control
  case proving C does return into Grail normally. The rule and its one-line rationale are stated in
  `docs/ffi.md` ("Abort and unwinding across the boundary").
- `docs/design/llvm-backend.md` stage 2c: the five benchmarks re-measured with paired medians, seven
  further lowering and driver levers recorded as measured-and-rejected (three-region alias metadata,
  loop pragmas on the latch, `-funroll-loops`, inline thresholds, an unroll threshold with its
  compile-time cost), the cause of `matmul`'s "removing the checks is slower" anomaly corrected to
  the `f32` accumulator widening to a `binary64` phi when the loop unrolls, and the two pieces of
  type information that block the remaining gap named precisely (`F1` a typed pointer to a sequence
  header; `F2` a word that holds an `f32`), each with the lever it unblocks and what that lever is
  worth. No lowering change: nothing tested paid for itself.
- `tools/bench.mjs --rounds N` interleaves the C and Grail binaries round by round and reports the
  median of N runs each with the observed spread, because a shared machine drifts within a single
  run: the default best-of-three favours whichever side happens to run first when the host is busy.
  The default (best-of-three) is unchanged.
- Merge the three design reviews from branch `claude/brave-heisenberg-0h3ska` as documents only
  (`docs/design/first-principles-architecture.md`, `architecture-reassessment.md`,
  `complexity-reassessment.md`, 2,746 lines). Their edits to README and to the research-phase
  decision log were not taken: those files describe the compiler as it is today, and the reviews
  were written against the earlier research-phase text.
- The runtime's narrow-vector routines (`f32[]`, `u32[]` and `i32[]` push, fill, indexing, copy,
  insert, remove, swap, reverse, truncate, contains and compare) read and write their 4-byte elements
  with the `raw_load32`/`raw_store32` intrinsics, one access each, instead of composing each from four
  byte loads and stores; behaviour and output are unchanged. The bootstrap seeds are refreshed so a
  fresh clone builds this runtime without a development compiler, and the seed manifest carries the
  new source and artifact digests.
- Strict-bool phase 1 (`docs/design/strict-bool-migration.md`): the compiler's own predicate helpers
  return `bool` instead of a 0/1 `u64`, so a caller's `if f(x)` stops reading as an integer test and
  `f(x) == 0` reads as `!f(x)`. Internal only; no language change. The six helpers that carry a real
  status code (`compile_mode`, the `*_command` handlers, `frame_split`) keep `u64`.
  - `lexer`: `whitespace`, `punctuation`.
  - `ownership`: `ancestor`, `loan_ancestor`, `can_cleanup`, and `overlaps`, whose body was the sum of
    two `ancestor` calls and is now `||`.
  - `optimize`: `same`, `movelike`, `arith`, `slot_read`, `slot_written`, `reg_fact_valid`,
    `dead_after`, `promotable_use`. Sums of predicates used as a truth value became `||`.
  - `fmt`: `is`, `keyword`, `binary`, `prefix_position`, `unary`, `space`, `opener`, `closer`,
    `opens`, `shuts`, `breakable`, `trailing_ok`, `arm_break`, `chain_dot`, `chain_break`,
    `list_break`, `op_break`. The space flag still lands in the numeric `f.lspace`, so that one
    assignment converts explicitly.
  - `cli`: `eq`, `starts`, `ends`, `contains_name`, `is_macho`, `is_command`. The command handlers
    that carry the process exit status are untouched.
  - `llvm`: `eq`, `starts`, `ends`, `occurs_at`, `has`, `member`, `is_local_label`, `legacy_base`,
    `is_xmm`, `set_has`, `callee_saved`. `frame_split` stays u64: it is stored in the lowering
    state's `split` field.
  - `machine`: `eq`, `starts`, `small_reg`, `atomic_instruction`, `c_abi`. The register-width codes
    `rw`/`sw` stay numeric (0, 1 or 2), so the two `eq` results that initialize them are read through
    an `if`.
  - `native`: `same` (the hottest helper, 437 call sites) first, because most other predicates are
    written in terms of it. Its `same(a) + same(b)` sums become `||`; `mode`, `permitted` and the
    `imm()` argument stay numeric and convert explicitly.
  - `native`, type and span predicates: `span_is`, `span_has`, `needs_drop`, `intersects`,
    `is_local_slot`, `concrete_type`, `ffi_record_has_nested`, `is_text`, `is_float`, `is_char`,
    `literal_target`, `is_bool`, `scalar`, `integer`, `adopt_literal`, `capture_borrow`,
    `contains_text`, `has_bonds`, `numbers_equal`, `satisfies_interface`, `callable_contract`,
    `token_starts_type`, `starts_with`, `flex_read`, `element_index_ahead`, `simple_index_ahead`,
    `slice_ahead`, `typed_binding_ahead_at`.
  - `native`, unions, maps and FFI: `is_ordinary_union`, `is_result_union`, `is_at`, `is_keyword`,
    `ffi_direct_type`, `impl_has_for`, `stdlib_module`, `ffi_record_has_float`,
    `ffi_record_has_float_deep`, `typed_binding_ahead`, `format_arg`, `ref_to_text`,
    `is_option_storage`, `closure_free_name`, `char_method`, `subword`, `is_map_type`,
    `proven_index`. `format_arg`'s `numeric` flag becomes bool; the mask it feeds converts
    explicitly.
  - `native`: `is` (the current-token check, 88 call sites, 70 of them `while`/`if`
    `is(...) == 0`). `is_enum` and a constant's `value` are stored in u64 fields, and `imm()`
    takes the bool constant's value, so those three convert explicitly.
  - `native`: `eat`, `is_union`, `lifetime_candidate`, `borrow_place_ahead`,
    `type_literal_ahead`, `map_assignment_ahead`, `statement_builtin`, plus `type_keyword` and
    `simple_type_head`. 35 `eat(...) == 0` guards become `!eat(...)`; the values that feed u64
    parameters or fields (`public`, `negative`, `hneg`, `raw`, `write`, `mutable`) convert
    explicitly. `is_f32` and `is_comparison` stay u64 — see below.
- Maps iterate with `for key, value in &map`, in insertion order, and `for key, value in &mut map` binds the
  same shared key with an exclusive value (`value := map.value_at_mut(i)`), so values update in place. The loop
  holds one reference to the map throughout: inserting into it inside the body is rejected, a shared loop cannot
  write to a value, and `for key, value in map` is refused with a pointer to `&map`. The compiler cannot see a
  map's private layout, so the sugar lowers to `len`/`key_at`/`value_at`/`entry_at` over positions.
- `Map::key_at`, `Map::value_at`, `Map::value_at_mut` and `Map::entry_at`, and `hashmap::entry_at`, which returns
  the `Entry` view of a position: the positional accessors had free functions only, so the written-out loop had
  no method form.
- Book: the collections chapter documents map iteration, with a side-by-side Rust comparison (a `BTreeMap`,
  because insert order is Grail's order and std's `HashMap` has none).
- `&mut r` on a `mut` binding holding a shared reference borrows the binding's own slot
  (`&mut &T`), so a callee can replace which referent the binding names:
  `previous := replace(&mut current, &second)` with `current = &first` compiles (it was rejected with
  "mutable reborrow of shared reference"). The new reference grants no write access to the old
  referent, the old referent stays frozen for as long as a value still names it, and `&mut r.f` /
  `&mut r[i]` still borrow through the referent and stay rejected. A mutable-reference binding keeps
  reborrowing its referent. Book example `writeback` and its Rust comparison use the natural form
  again.
- Record patterns in `match`: `match p { Point { x, y: other, .. } => { ... } }` takes a record apart
  by field. A record arm matches every value, so it is the only pattern (an explicit `_` may follow
  and is never taken); `..` ignores the rest. Fields bind by copy for plain scalars, by move when the
  whole record is moved, and as shared or exclusive references through `match &p` and `match &mut p`.
  An unknown field and a field left out without `..` are reported by name, and a record arm may not
  be followed by any pattern but `_`. The book's records chapter documents the form with a
  `record-patterns` example.
- Abundance port: the cluster builder builds canonical voxel meshes (`Source::canonical_voxel`). Cluster attributes
  carry the raw RGBA8 grade/excavated grade channel, the quantization grid refines itself (AUTO) until every canonical
  position and every open or non-manifold boundary survives the position codec and the decode remap, and the encoded
  positions of a shared metadata class are locked. Previously refused.
- Abundance port: the cluster builder trims alpha contours (`Options::alpha_trim_levels`, `alpha_trim_budget`). A masked
  material carries its full-resolution alpha as an image (`AlphaSource::Bytes`) or a pixel provider
  (`AlphaSource::Sample`); four-state per-triangle opacity classes produce the per-cluster alpha-test bits and remove
  fully transparent triangles; unclassifiable cutout triangles are split 1:4 at shared edge midpoints, fully
  transparent children dropped and T-junctions repaired, so the kept leaf cards follow their alpha shape. The C++
  source validation for those paths is ported too (finite attributes, measured position encoding error, masked alpha
  rules, one alpha source per material). Previously refused.
- Abundance port parity: `abundance/tests/parity/abgeo.cpp` now also builds a canonical voxel chunk and a leaf card
  with image alpha and pixel-provider alpha; the Grail builder matches all 681 reference lines byte for byte (was 489).
- `bun tools/abundance-test.mjs --regenerate`: a reference may name the source program it shares (`cache` is
  `world.cpp` run with different argv), so the `abgeo` and other references that need a source of their own no longer
  fail on a missing `<name>.cpp`. References that link Abundance's world build tree still need that tree's headers.

- A closure may capture a reference or view (`&T`, `&[T]`, `&[u8]`, `&mut T`): the pointer moves into
  the closure and its loan moves with it, so a comparator can read a key that lives outside the value
  it is given (`groups := &b.groups; vecs::sort_by(&mut order, |x, y| ... groups[*x] ...)`). The closure
  type records the captured lifetime, so a closure that borrows cannot be returned out of the
  function or stored where the borrow does not reach; a struct or enum that merely holds a borrow is
  still rejected. Returning a value that carries a live loan is now rejected whatever its type says.
  The Abundance cluster builder sorts pages with such a comparator again instead of precomputing keys
  into a vector (`vecs::sort_by_key`); output unchanged.
- Sequence element access is cheaper: the runtime's accessors (`rt_slot`, `rt_at`, the byte and
  4-byte variants, `rt_push`, `rt_len`, the slice/view helpers) compose addresses with
  `wrapping_add`/`wrapping_mul`, so the compiler stops emitting overflow guards for the length field
  and the element address on every access. Bounds checks are unchanged and still abort on any
  out-of-range index, including indexes whose byte offset would wrap. Against C `-O2` on x86-64,
  `--backend=llvm`: nbody 2.3x -> 1.7x, sort 1.4x -> 1.3x. The native backend reads the same stream,
  so the guards disappear there too. Design notes: `docs/design/llvm-backend.md`, stage 2b.
- LLVM backend, stage 2b measurement (`docs/design/llvm-backend.md`): after stage 2a the benchmarks
  are within 1.0-1.2x of C except `nbody` (2.4x) and `sort` (1.5x), and in those two the remaining
  cost is the per-element validity/bounds/address checks the front end emits (44% and 21% of run
  time, measured by rebuilding the lowered IR with the check branches deleted). LLVM cannot hoist
  them out of the loops: the word stream carries no type or alias information, so the descriptor's
  length and data loads cannot be merged across an element store, and LLVM will not speculate a
  load through `inttoptr`. Alias scopes, TBAA, alignment metadata, `nounwind`, branch weights, loop
  unroll pragmas and `-O3` were measured and rejected; the only lever that moves them is aggressive
  unrolling (a compile-policy decision: `nbody` 21% faster, `sort` 6%, at five times the code).
  Closing the gap needs the typed front-end IR of stage 3. `fnv`, `sieve` and `matmul` are at their
  floor.
- A program's own `Task`, `Mutex`, `Atomic`, `Scope` or `CancelToken` type shadows the built-in generic of that name
  (`Task[...]` was a parse error). A slice compares with `==` against a vector of the same element type.
- Book: duplicate chapters merged (numbers, bytes and text, records and vectors, views and slices); every example uses
  current syntax (`data[:]`/`&data` instead of `view(data)`, direct writes through references, `bool` instead of
  `u64` flags); new side-by-side examples for typed slices and stable sorting with a closure; stale "preview" notes
  replaced by an accurate list of what is not implemented yet.
- A block that does not start with `{` (such as a brace-less `match` arm) is reported as
  "expected { to start a block"; the compiler used to crash on an arithmetic underflow.
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
