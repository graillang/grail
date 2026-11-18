# msdfgen, called from Grail

Abundance draws its UI text from multi-channel signed distance fields made by msdfgen v1.12
(engine/ui/DESIGN.md), and msdfgen is one of the C++ libraries the port keeps rather than rewrites
(docs/design/abundance-port.md, R8). Grail now calls it in process: `abundance/src/msdfgen.grl` holds
the font, the glyph shape and the MSDF bitmap. This page states what crosses, how it is verified, and
what the parity program proves.

## What the engine uses, and therefore what crosses

The engine has exactly one msdfgen call site, `rasterise_glyph` in `engine/ui/canvas_builder.cpp`, and
the binding is that function's calls - nothing more:

| Engine (canvas_builder.cpp) | Shim entry point |
| --- | --- |
| `initializeFreetype()` / `deinitializeFreetype()` (:229, :260) | `gr_msdf_initialize` / `gr_msdf_deinitialize` |
| `loadFont(ft, path)` / `destroyFont(f)` (:231, :259) | `gr_msdf_load_font` / `gr_msdf_destroy_font` |
| `loadGlyph(shape, font, GlyphIndex(id), FONT_SCALING_EM_NORMALIZED)` and the empty-contour check (:87) | `gr_msdf_load_glyph` |
| `shape.normalize()` (:88) | `gr_msdf_shape_normalize` |
| `edgeColoringSimple(shape, 3.0, id)` (:91) | `gr_msdf_shape_edge_coloring` |
| `shape.getBounds()` (:93) | `gr_msdf_shape_bounds` |
| `Bitmap<float, 3>{w, h}` + `generateMSDF(bitmap, shape, Projection({s, s}, {tx, ty}), Range(r))` (:98-100) | `gr_msdf_generate_msdf` |
| `bitmap(x, y)` (:103) | `gr_msdf_bitmap_texel`, and `gr_msdf_bitmap_copy` for the whole field |

The glyph layout - the tier scale (16/32/64 texels per em), the 4-texel pad, the bitmap size
`ceil(extent * scale + 8)`, the projection's translation and the 6-texel range - is the call site's
arithmetic and stays on the Grail side as plain numbers; the shim decides none of it. The generator
configuration crosses explicitly (`GeneratorConfig`), and `default_config()` reads the library's own
defaults (edge-priority error correction, distance check at edges, msdfgen's two ratios) rather than
restating them. The engine's 512-texel cap is enforced in the shim, as are non-finite or non-positive
scales and ranges: each is a refusal, not an allocation.

## The records

| Record | Size | Fields (offset) |
| --- | --- | --- |
| `Texel` | 12 | r 0, g 4, b 8 |
| `Bounds` | 32 | left 0, bottom 8, right 16, top 24 |
| `GeneratorConfig` | 32 | error_correction_mode 0, distance_check_mode 4, min_deviation_ratio 8, min_improve_ratio 16, overlap_support 24 |
| `Constants` | 72 | version 0/4, error modes 8-20, check modes 24-32, scaling modes 36-44, default modes 48/52, ratios 56/64 |
| `Font`, `Shape`, `Bitmap` | 8 | pointer 0 |

`bun abundance/tools/build-msdfgen.mjs --table` prints the C side. The check is
`abundance/tests/msdfgen_layout_probe.grl`, in both directions: C seeds every record through its
offsets, Grail reads each field by name; Grail writes the other half by name, C reads it at its
offsets. `msdfgen.layout.round_trip` must be 0.

The handles are one-word records rather than opaque tokens so a refused load is visible: it leaves the
pointer NULL, and every destroy clears it. Grail moves an `extern "C"` record passed by value (to C it
is a `const R*`), so the readers take `&Font`/`&Shape`/`&Bitmap` and hand C a fresh one-word record
built from the pointer; the handle stays usable.

## The build

`abundance/tools/build-msdfgen.mjs` fetches the v1.12 release archive (SHA-256 pinned). The engine's
vendored `engine/third_party/msdfgen` is that release byte for byte - `diff -r` over `core/`, `ext/`
and `msdfgen.h` is empty - so the C++ under test is the C++ the engine ships. It compiles the 24 units
the engine's `abe_ui_msdf` library compiles (`core/*.cpp` and `ext/import-font.cpp`) with the engine's
definitions and flags from its own compile database (`MSDFGEN_USE_CPP11=1`, the two `PUBLIC` macros
empty, `-O3 -std=c++20 -UNDEBUG`, which keeps msdfgen's asserts on as the engine does), plus `-fPIC`,
into one `libmsdfgen.a`. The shim links that archive and the system FreeType into
`abundance/third_party/msdfgen/libgrail_msdfgen.so`; the parity reference links the same archive.

## The headless proof

`abundance/tests/msdfgen_test.grl` and `abundance/tests/parity/msdfgen.cpp` rasterise the same pinned
glyphs from the committed Titillium Web Regular (the engine's first design face, SIL OFL, licence beside
it in `abundance/tests/parity/msdfgen/fonts/`): '.', 'A' at 16 texels/em, 'g' and 'Q' at 32, 'W' at 64.
Each prints its glyph id, tier, contour count, outline bounds (f64 bits), bitmap size and an FNV-1a
digest of every texel's bytes; the '.' prints its whole 10x10 field as f32 bit patterns; 'A' is
rasterised again with the edge-colouring seed moved by one (a different field, a different digest);
and the two ways `loadGlyph` answers nothing - a glyph the font lacks, the space's empty outline -
are both checked. All **143** lines match.

The engine's RGBA quantisation (`lround(clamp(v, 0, 1) * 255)`) is not part of the comparison: it is
the call site's, and the raw floats are a strictly stronger check.

## Limits

- **Same build, same machine.** The parity compares one `libmsdfgen.a` against itself through two
  routes; FreeType is the system's. A different FreeType can outline a glyph differently, so a
  reference regenerated on another host may differ - that is a font-stack change, and the diff names it.
- **One face.** The fixture is Titillium Web Regular; the other design faces and the Noto fallbacks are
  the same code path with different outlines.
- **Not bound:** single-channel SDF, PSDF and MTSDF generation, SVG import, shape descriptions, and the
  save/export helpers - the engine calls none of them.
- **Shaping is not here.** HarfBuzz chooses the glyph ids (`canvas_builder.cpp`); this binding takes
  an id and returns its field.
