# What blocks the first renderer port

The graphics foundation is written and tested, but **nothing can call it from a Grail
program yet**. That is not an implementation gap in this work; it is a property of the
language and toolchain as they stand. This document states each blocker with the evidence,
and what removing it would take, in the order it can be removed.

## 1. A Grail binary cannot link a C library

`tools/native.mjs` assembles one object and links exactly one input:

```js
command([process.env.GRAIL_LINKER ?? 'ld.lld', '-m', emulations[target], object, '-o', executable]);
```

No `-l`, no shared object, no dynamic loader. `compiler/NATIVE.md` states it directly: "An
assembler and linker encode instructions and produce static Linux ELF executables; no libc
is linked." So `libSDL3.so` and `libvulkan.so.1` cannot be linked into a Grail program, and
no amount of header work changes that.

**To remove:** a link step that accepts extra objects/libraries and a way to declare an
imported symbol. This is the single largest piece of work in the path.

## 2. The language has no FFI

There is no `extern`, no `foreign`, no `dlopen`/`dlsym` anywhere in `compiler/*.grl`
(`grep -rn '\bffi\b|foreign|dlopen|dlsym'` finds nothing relevant). The only external
interface is `rt_syscall`, whose operation ids are Grail's own stable numbers mapped to Linux
syscalls inside `compiler/runtime.grl`, and raw memory and syscalls are confined to
`unsafe module runtime`.

Combined with (1), a Grail program cannot call `gr_device_create()`: there is no mechanism to
name the symbol, no mechanism to link it, and no libc to load it.

**Consequence:** the C ABI in `graphics/include/grail/` is, today, a contract for a
**C/C++ host**, not for Grail. That is deliberate: it defines the target the language must
eventually be able to call, and it is the thing the harness needs whatever the calling
convention turns out to be.

## 3. Only Linux is a target

`tools/native.mjs` targets `x86_64`, `aarch64`, `riscv64` with `*-linux-gnu` triples and
`elf_x86_64`/`aarch64elf`/`elf64lriscv` emulations. There is no Windows or macOS target.

So even with an FFI, the D3D12 backend (Windows) and the Metal backend (macOS) could not be
driven by a Grail process, because a Grail process cannot exist on those systems. Those two
backends are reachable only through the out-of-process bridge described below, where the host
is a native process on the target OS.

## 4. There is no C data model

No struct layout or padding guarantee, no raw pointer type, no way to receive a
`const gr_device_caps *` or to hand a `uint8_t *` to foreign code. Grail has `view`/`view_mut`
byte views, but they are not pointers and cannot cross an FFI boundary as one.

**To remove:** a defined `repr(C)`-equivalent record layout and a pointer type usable in
`unsafe` code. Both are language design decisions, not graphics work.

## 5. The backends are not implemented

`GR_BACKEND_NULL` is complete and tested (219 checks). `gr_device_create` returns
`GR_ERROR_UNSUPPORTED` for Vulkan, D3D12 and Metal, so a caller cannot accidentally believe
it has a GPU.

**Vulkan is the first real backend to write**, and the order after it is D3D12, then Metal.
The Vulkan backend must satisfy `grail_backend_vulkan.h`: Vulkan 1.3, descriptor indexing with
update-after-bind and partially-bound, buffer device address, dynamic rendering,
`synchronization2`, timeline semaphores, scalar layout, 16- and 64-bit integer types. The
surface comes from SDL3 through `gr_vk_create_surface`.

This requirement is now **verified on this host** rather than assumed: `make -C graphics
vk-probe` reports an AMD Radeon RX 7900 GRE (RADV NAVI31, Mesa 26.2.6) at Vulkan 1.4.354 with
every required feature present and 256-byte push constants. See
[`vulkan-probe.md`](vulkan-probe.md). What is missing is the backend code, not the hardware.

## 6. The reflection extractor does not exist

The blob format, its reader and its validation are written and tested
(`graphics/src/grail_reflect.c`), and the shaders compile. But `graphics/tools/shader.mjs` —
the tool that runs DXC, parses the compiled SPIR-V's decorations into the blob, writes the
`.refl.json` form, computes the layout hash, enumerates permutations and drives the Metal
leg — is not written yet. Until it is, a pipeline cannot be described to a device, so even a
finished Vulkan backend could not create one.

This is the next piece of work, and it is pure build tooling with no language dependency.

## 7. Bulk data has no path from Grail

The wire protocol (`grail_wire.h`) carries control messages and commands, and puts bulk data
in a shared-memory region addressed by `(offset, length)`. Grail's runtime has **TCP IPv4
sockets** (`rt_tcp_socket`, `rt_syscall(41, 2, …)`) so the control channel is reachable
today, but there is **no `mmap`/`munmap`** in `compiler/runtime.grl`, so a shared region
cannot be created or mapped. Vertex and texture upload would have to be large socket
messages, which is workable for a first port and wrong for a renderer.

**To remove:** add `mmap`/`munmap` to the `unsafe module runtime` boundary (and, for a
portable `AF_UNIX` channel, a socket-family argument instead of the hardcoded
`AF_INET`). Both are small, contained runtime additions.

## The shortest path to a visible frame

Given the above, the order that produces a frame soonest is:

1. **`graphics/tools/shader.mjs`** — no language dependency; produces the bytecode and
   reflection a device needs. *(next)*
2. **A Vulkan backend** behind `gr_device_create` — a C host, no Grail involvement.
3. **A C host harness** that owns the window and the frame loop and exposes it over
   `grail_wire.h` — the renderer renders its first triangle with a native host and a Grail
   *client* that only sends commands, over TCP loopback, with uploads as socket messages.
4. **Language work** — an FFI, extra link inputs, a C data model and non-Linux targets. This
   is what turns the client into an in-process renderer, and it is the largest item.

Steps 1–3 need no compiler change and no edit to `compiler/native.grl`. Step 4 does.
