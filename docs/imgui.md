# Dear ImGui, called from Grail

Abundance's editor is an immediate-mode UI, and the layer it needs is Dear ImGui. Grail now calls it
in process: `abundance/src/imgui.grl` holds the context, the frame, `ImGuiIO` and the draw data,
`abundance/src/imgui_widgets.grl` the widgets, and `abundance/src/imgui_platform.grl` the SDL3 and
Vulkan backends. This page states what that covers, how the layout of every struct is verified, and
what still needs a device.

## Why there is a C boundary, and where it is

Dear ImGui is C++: `ImGui::Begin` is a namespaced overload, `Button` takes `const ImVec2&`, and every
struct is a C++ struct with members as well as fields. Grail's FFI calls C symbols with C layouts, so
*something* has to be the boundary, and the only question is where to put it. It is
`abundance/tools/imgui_shim.h` - plain C functions with scalar arguments, and a plain C `struct` for
every struct that crosses:

| File | What it is |
| --- | --- |
| `abundance/tools/imgui_shim.h` | the records and the C entry points. The single definition of what crosses |
| `abundance/tools/imgui_shim.cpp` | one ImGui call per function, and the offsets asserted at compile time |
| `abundance/tools/imgui_shim_platform.cpp` | the SDL3 and Vulkan backends, and the translation of `GrVulkanInitInfo` into `ImGui_ImplVulkan_InitInfo` |
| `abundance/tools/imgui_layout.c` | prints `sizeof`/`offsetof` of every record, compiled as C |
| `abundance/tools/imgui_layout.cpp` | prints the same fields of the real ImGui structs, compiled as C++ |
| `abundance/tools/build-imgui.mjs` | fetches, compiles, links, and diffs the two tables |

The shim keeps three rules, and they are what make this a binding rather than a second implementation:

- **a shim function is one ImGui entry point.** `gr_imgui_begin(name, flags)` calls
  `ImGui::Begin(name, NULL, flags)` and returns its `bool` in a `uint8_t` (C++ `bool` is one byte, and
  the upper bits are architecturally undefined, so the low byte is what C defines). No logic lives
  here that ImGui could disagree with;
- **an `ImVec2` is passed as two floats.** ImGui takes them by reference, so a record would need
  `byval` classification for no benefit;
- **an out-parameter is a record pointer.** Grail declares `&mut Record`, which is the address of the
  record's own fields, so C writes in place and Grail reads the typed fields afterwards.

Two shared libraries, not one:

- `abundance/third_party/imgui/libgrail_imgui.so` - Dear ImGui and the core shim. It needs the C and
  C++ runtimes and nothing else, so **a headless widget program links no loader and no device**;
- `abundance/third_party/imgui/libgrail_imgui_platform.so` - the SDL3 and Vulkan backends, which carry
  their own `DT_NEEDED` for `libSDL3` and `libvulkan`. Only a program that asks for a real frame links
  it.

Both are build products over a pinned checkout (`.work/deps/imgui`, Dear ImGui 1.93.0, commit
`c1aaac6`, the version `engine/third_party/imgui/imgui.h` vendors). `bun abundance/tools/build-imgui.mjs`
builds them and prints the record table; `bun tools/abundance-test.mjs` builds them on first use.

## The records, and how their layout is verified

No struct is laid out by hand, and no number in this page was guessed. There are four independent
checks, and a mistake has to survive all four:

1. **The record is the struct.** `GrIo` is the prefix of `ImGuiIO` through `MousePos`, field for field
   and type for type, so reading it is one `memcpy` and its offsets *are* ImGuiIO's. `imgui_shim.cpp`
   asserts this at compile time - one `offsetof` per field, 71 of them, plus `sizeof(GrIo) ==
   offsetof(ImGuiIO, MouseDown)` and a width check per field - so a version bump that moves or widens a
   field is a build error naming the field, not a wrong number at run time. `GrDrawData` and
   `GrDrawVert` are asserted the same way, up to `sizeof` equality.
2. **A C compiler prints the table.** `bun abundance/tools/build-imgui.mjs --table` compiles
   `imgui_layout.c` (C) and `imgui_layout.cpp` (C++) and diffs the two: the same labels, from two
   independent transcriptions, must print the same offsets.
3. **The library refuses to build otherwise.** Step 2 runs from the build script, so the `.so` a
   program links is one whose table agreed.
4. **A run checks it again.** `imgui_layout_probe.grl` calls `layout_round_trip`: C writes known values
   through the C offsets of the 21 fields the module exposes, Grail reads them back by field name, then
   C reads them back at its own offsets. The count of disagreements must be 0. Two things go wrong
   silently in a binding - a field at the wrong offset, and a flag with the wrong value - so the same
   probe compares all 27 restated flag constants against the values Dear ImGui compiled
   (`gr_imgui_constants`).

The table, as printed on this machine (x86-64, Dear ImGui 1.93.0):

| Record | Size | Offsets |
| --- | --- | --- |
| `Io` | 240 | `config_flags` 0, `backend_flags` 4, `display_size` 8, `display_framebuffer_scale` 16, `delta_time` 24, `ini_saving_rate` 28, `ini_filename` 32, `log_filename` 40, `user_data` 48, `fonts` 56, `font_default` 64, `font_allow_user_scaling` 72, then 32 config bytes through `config_color_edit_flags` 84 ... `backend_platform_name` 144, `backend_renderer_name` 152, `backend_platform_user_data` 160, `backend_renderer_user_data` 168, `backend_language_user_data` 176, `want_capture_mouse` 184, `want_capture_keyboard` 185, `want_text_input` 186, `want_set_mouse_pos` 187, `want_save_ini_settings` 188, `nav_active` 189, `nav_visible` 190, `framerate` 192, `metrics_render_vertices` 196, `metrics_render_indices` 200, `metrics_render_windows` 204, `metrics_active_windows` 208, `mouse_delta` 212, `ctx` 224, `mouse_pos` 232 |
| `DrawData` | 80 | `valid` 0, `frame_count` 4, `total_idx_count` 8, `total_vtx_count` 12, `cmd_lists` 16, `display_pos` 32, `display_size` 40, `framebuffer_scale` 48, `owner_viewport` 56, `textures` 64, `cmd_lists_count` 72 |
| `DrawVert` | 20 | `pos` 0, `uv` 8, `col` 16 |
| `DrawCmd` | 72 | `clip_rect` 0, `tex_ref_data` 16, `tex_ref_id` 24, `vtx_offset` 32, `idx_offset` 36, `elem_count` 40, `user_callback` 48, `user_callback_data` 56, `user_callback_data_size` 64, `user_callback_data_offset` 68 |
| `Vec2` | 8 | `x` 0, `y` 4 |
| `GrVulkanInitInfo` | 104 | `api_version` 0, `instance` 8, `physical_device` 16, `device` 24, `queue_family` 32, `queue` 40, `descriptor_pool` 48, `descriptor_pool_size` 56, `min_image_count` 60, `image_count` 64, `pipeline_cache` 72, `render_pass` 80, `subpass` 88, `msaa_samples` 92, `use_dynamic_rendering` 96, `color_format` 100 |

`Io` stops at `MousePos` because `bool MouseDown[5]` follows it and a record has no array field, so 240
is the largest prefix that is one `memcpy`. `DrawCmd` reads five fields rather than being the struct
(`ImTextureRef` and the callback words are copied field by field), which is why its own size is not
compared.

## The widget surface

`abundance_imgui_widgets` is one Grail function per ImGui entry point. Labels take `&[u8]`, so a string
literal, a `string` and a `u8[]` all pass without a conversion at the call site.

| Grail | Dear ImGui |
| --- | --- |
| `begin(name, flags)`, `begin_window(name)`, `end()` | `Begin`, `End` |
| `text(value)` | `TextUnformatted` (ImGui's `Text` is variadic, which a C declaration cannot express) |
| `button(label)`, `button_sized(label, w, h)`, `button_indexed(index, label)` | `Button`, with the index pushed as an ID |
| `input_u64(label, &mut ScalarU64)` | `InputScalar(…, ImGuiDataType_U64, …)` - ImGui has no unsigned-input widget; this is the honest equivalent, and `scalar(n)` makes the value |
| `same_line()`, `same_line_at(offset, spacing)` | `SameLine` |
| `begin_child(id, w, h)`, `begin_child_flags(...)`, `end_child()` | `BeginChild`, `EndChild` |
| `begin_table(id, columns, flags)`, `begin_table_sized(...)`, `table_next_row()`, `table_next_row_sized(flags, h)`, `table_next_column()`, `end_table()` | `BeginTable`, `TableNextRow`, `TableNextColumn`, `EndTable` |
| `push_id(id)`, `push_id_int(value)`, `pop_id()`, `id_of(id)`, `item_id()` | `PushID`, `PopID`, `GetID`, `GetItemID` |
| `item_rect_min()`, `item_rect_max()` | `GetItemRectMin`, `GetItemRectMax` |
| `frame_begin(w, h, dt)`, `frame_render()`, `frame_end()` | `NewFrame` (after `io.DisplaySize`/`DeltaTime`), `Render`, `EndFrame` |
| `create_context()`, `destroy_context()`, `style_dark()`, `style_set(rounding, alpha)`, `ini_disabled()` | `CreateContext`, `DestroyContext`, `StyleColorsDark`, `GetStyle()`, `io.IniFilename = NULL` |
| `mouse_pos(x, y)`, `mouse_button(button, down)` | `io.AddMousePosEvent`, `io.AddMouseButtonEvent` |

### Identity is the part a hand-rolled layer gets wrong

ImGui identifies an item by a hash of (its ID stack, its label), so two widgets with the same label in
the same scope are *the same item*: the second one's state is the first one's. That is why a loop has
to push something distinguishing, and why the widget layer exposes ImGui's own ID stack rather than a
copy of it:

- `push_id`/`push_id_int`/`pop_id` are `PushID`/`PopID`, so `id_of` afterwards is what ImGui would
  compute;
- `button_indexed(index, label)` is the push/pop pair for "the same widget in a loop", so the pop
  cannot be forgotten;
- `id_of` and `item_id` answer 0 when there is no current window, because ImGui's `GetID` dereferences
  the current window and would take the process with it. `imgui_test.grl` asserts that 0.

`imgui_test.grl` prints `id.base`, `id.pushed`, `id.restored` and `id.pushed_int`, and the reference
prints the same four from `ImGui::GetID`: the pushed ID differs, the pop restores it, and two
same-labelled buttons in different ID scopes get different item ids.

## The headless proof

ImGui builds its draw data on the CPU, so a frame is testable without a display or a device. What a
headless run has to supply is only what a renderer backend would: `io.BackendFlags |= RendererHasTextures`
(`abundance_imgui::backend_flags_engine_renderer`), or `NewFrame` asserts that nobody can take the font
atlas. Everything else - widgets, IDs, layout, clipping, text - is the same code path a GPU frame
takes.

`bun tools/abundance-test.mjs` runs the binding twice:

- **`imgui_test.grl`, diffed against `abundance/tests/parity/imgui.cpp`.** The reference is the same
  frames and the same widget set through ImGui's own C++ API, compiled against the same pinned
  checkout with the same flags, so the comparison is byte-identical over 472 lines - every vertex,
  every triangle, every command, every id. On this machine, for the widget set in that file:

  | Assertion | Value |
  | --- | --- |
  | frame 0 (a window with no size yet) | `cmd_lists 0`, `total_vtx 0`, `total_idx 0` |
  | frame 1 (laid out) | `cmd_lists 2`, `total_vtx 310`, `total_idx 501` |
  | the settled frame | `cmd_lists 2`, `total_vtx 310`, `total_idx 501` |
  | draw list 0 | 274 vertices, 447 indices, 2 commands |
  | draw list 1 | 36 vertices, 54 indices, 1 command |
  | `io.metrics_render_vertices` vs `draw.total_vtx` | 310 = 310 |
  | `input.value` through `InputScalar` | 1000 (nothing typed; the record came back as it went in) |
  | `id.pushed != id.base`, `id.restored == id.base` | 1, 1 |
  | a click on the button's own rectangle | 0 on hover, 0 on press, 1 on release, 0 after the mouse leaves |

  Those counts are not a fixture: they are what the two programs printed, and the suite fails if either
  changes. The triangle list itself is in the reference file (`list.tri i a b c`, 501 indices as 167
  triangles), which is also where a change in ImGui's tessellation shows up as a diff.

- **`imgui_layout_probe.grl`, a verdict probe like the RHI ones.** It reports
  `imgui.layout.round_trip 0`, `imgui.constants.mismatched 0` and `imgui.status ok`.

`bun abundance/tools/build-imgui.mjs` prints the record table and checks it against Dear ImGui;
`--table` prints it without rebuilding anything.

## A real frame

`abundance/src/imgui_platform.grl` is the device half, and `abundance/tests/imgui_frame_probe.grl` is
the frame that proves it: an SDL3 window, a Vulkan instance and device, a surface and swapchain, the
clear render pass `abundance_rhi_render` creates, and ImGui's own Vulkan backend recording into the
command buffer inside that pass. It links `libgrail_imgui_platform.so`, whose own `DT_NEEDED` carries
`libSDL3` and `libvulkan`, so the headless programs never load either.

The two init calls are upstream and unmodified:

| Grail | Dear ImGui |
| --- | --- |
| `sdl3_init_for_vulkan(window)` | `ImGui_ImplSDL3_InitForVulkan` |
| `vulkan_init(init_info(...))` | `ImGui_ImplVulkan_Init` |
| `sdl3_new_frame()`, `vulkan_new_frame()` | `ImGui_ImplSDL3_NewFrame`, `ImGui_ImplVulkan_NewFrame` |
| `vulkan_render_draw_data(command_buffer)` | `ImGui_ImplVulkan_RenderDrawData` |
| `sdl3_shutdown()`, `vulkan_shutdown()` | `ImGui_ImplSDL3_Shutdown`, `ImGui_ImplVulkan_Shutdown` |

`ImGui_ImplVulkan_InitInfo` cannot cross as itself (an `ImVector`, a
`VkPipelineRenderingCreateInfoKHR` and two `VkShaderModuleCreateInfo` by value, and a function
pointer), so `VulkanInitInfo` carries the fields a host has - instance, physical device, device,
queue family, queue, render pass, subpass, sample count, image counts, a descriptor-pool *size*
instead of a pool - and `imgui_shim_platform.cpp` translates it and zeroes the rest. Its 104-byte
layout is printed by `imgui_layout.c`, and `vulkan_init_layout_ok()` round-trips the scalar fields
through the C offsets before the backend is initialised, so a moved field is a number in the report
rather than a mis-signalled device.

What the probe prints on this machine (RX 7900 GRE, RADV, X11):

```
imgui.frame.backend.platform imgui_impl_sdl3 (3.4.18; 3.4.18) (x11)
imgui.frame.backend.renderer imgui_impl_vulkan
imgui.frame.io.backend_flags 30
imgui.frame 0 image 0 of 4 lists 0 vtx 0 idx 0 presented VK_SUCCESS
imgui.frame 1 image 1 of 4 lists 1 vtx 202 idx 327 presented VK_SUCCESS
imgui.frame 2 image 2 of 4 lists 1 vtx 208 idx 348 presented VK_SUCCESS
imgui.pixels 2 pixels 230400 clear 207492 drawn 22908 digest 17759077537127530277
imgui.frame.settled previous 17759077537127530277 last 17759077537127530277 identical 1
imgui.frame.result frames 5 of 5 drawn 91632
imgui.frame.status ok
```

`io.BackendFlags 30` is what the two backends set for themselves: `RendererHasVtxOffset` (8),
`RendererHasTextures` (16), and from SDL, `HasMouseCursors` (2) and `HasSetMousePos` (4). The first
frame draws nothing for the same reason the headless test's first frame is empty. Every later frame
draws 208 vertices and 348 indices - a different widget set from the headless test, which is why the
counts differ - and 22908 of 230400 pixels on the presented image are not the clear colour. The
probe reads that image back (the swapchain is created with `TRANSFER_SRC` when the surface allows it)
and compares the last two frames' digests, so "a frame reached the image" is a statement about
pixels, not about a return code.

Outcomes are the RHI probes': `imgui.frame.status ok` / `skipped <reason>` / `failed`, exit 0 for the
first two. A machine with no display server, no Vulkan driver, or a driver that cannot back a Vulkan
window is skipped, with the platform's own words.

## What still needs something else

- **SDL's event pump.** The RHI has no event loop yet (`docs/rhi.md`), so `ImGui_ImplSDL3_ProcessEvent`
  is not bound: there is nothing to feed it. Until it lands, a host drives ImGui with
  `mouse_pos`/`mouse_button` - which is what `imgui_test.grl` uses for its click - or hooks the
  backend's own `ProcessEvent` once the pump exists.
- **Text input.** `input_u64` covers the number case the editor's inspector needs. A text field needs
  ImGui to hold a pointer to a caller-owned buffer across frames; the buffer's capacity must be fixed
  before the first frame, which wants a resize-callback shim and a fixed-capacity buffer type. That
  is the next increment, not a limitation of the FFI.
- **Fonts beyond the default.** The atlas is ImGui's default ProggyClean; a custom font needs an
  `ImFontConfig` (a C++ struct with an embedded array) behind a shim call of its own.
- **Resize.** The swapchain is created once and destroyed at the end, as in the RHI increment: a
  resize needs the `oldSwapchain` path, `ImGui_ImplVulkan_SetMinImageCount` and a rebuilt framebuffer
  set.

## Limits, stated

- **`Io` is a prefix, and it is read-only.** It is one `memcpy` of the 240 bytes through `MousePos`;
  `bool MouseDown[5]` follows and a record has no array field. Writing *to* ImGuiIO goes through named
  calls (`frame_begin` for `DisplaySize`/`DeltaTime`, `add_backend_flags`, `style_set`,
  `ini_filename`) rather than a write-back of the record, because a write-back would also copy pointer
  fields and ImGui's own queue state.
- **A label allocates.** `nul` copies the label into a fresh NUL-terminated `u8[]` per call; ImGui
  copies what it retains, so the bytes only have to outlive the call. It is the one cost this layer
  adds, and it is the first thing to cache if label traffic ever shows up in a profile.
- **The version is pinned, and the pin is checked.** A newer Dear ImGui either compiles (because the
  offsets still agree) or fails with the field's name.
