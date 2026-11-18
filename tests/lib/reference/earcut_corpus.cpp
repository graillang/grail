// Reference corpus for tests/lib/earcut_test.grl: mapbox earcut.hpp, as vendored by Abundance
// (ThirdParty/earcut, the only triangulator the water-geometry callers use), triangulates every
// case's rings and prints the index list it produced. The expected files are vertex-for-vertex
// earcut output: the triangle index sequence in the exact order the library emits it.
// Real-caller polygons come from the engine's own water_geometry.cpp (buffer_waterway_centerline
// and union_water_raster_cells outputs fed through the same triangulate_water_region adapter),
// compiled unmodified beside the vendored headers.
// Build and run it with tests/lib/reference/build-corpus.sh, which names the include paths.
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

// <cstdint> must precede the vendored earcut.hpp, whose default template argument relies on it;
// the engine callers (water_geometry.cpp) include it first the same way.
#include "mapbox/earcut.hpp"

#include "abundance/water_geometry.hpp"

using Ring = std::vector<std::array<double, 2>>;
using Polygon = std::vector<Ring>;

std::vector<std::string> g_case_names;

const char* out_dir = nullptr;  // set in main

std::string path_of(const char* name, const char* suffix) {
    std::string p(out_dir ? out_dir : ".");
    p += "/";
    p += name;
    p += suffix;
    return p;
}

void write_case(const char* name, const Polygon& rings) {
    g_case_names.push_back(name);
    // .in: ring count, then per ring a vertex count and the coordinates with 17 significant
    // digits (exactly round-trippable through a correctly rounded parser).
    std::string in = path_of(name, ".in");
    FILE* f = fopen(in.c_str(), "w");
    fprintf(f, "%zu\n", rings.size());
    for (const Ring& ring : rings) {
        fprintf(f, "%zu\n", ring.size());
        for (const auto& p : ring) fprintf(f, "%.17g %.17g\n", p[0], p[1]);
    }
    fclose(f);

    // .out: the exact index sequence earcut produced for these rings.
    const std::vector<std::uint32_t> indices = mapbox::earcut<std::uint32_t>(rings);
    std::string o = path_of(name, ".out");
    f = fopen(o.c_str(), "w");
    fprintf(f, "%zu\n", indices.size());
    for (std::uint32_t index : indices) fprintf(f, "%u\n", index);
    fclose(f);
}

Polygon from_region(const ab::WaterGeometryRegion& region) {
    Polygon rings;
    Ring outer;
    for (const auto& p : region.outer) outer.push_back({p.x_m, p.y_m});
    rings.push_back(outer);
    for (const auto& hole : region.holes) {
        Ring h;
        for (const auto& p : hole) h.push_back({p.x_m, p.y_m});
        rings.push_back(h);
    }
    return rings;
}

Ring ring_from_list(const std::vector<std::array<double, 2>>& pts) {
    Ring r;
    for (const auto& p : pts) r.push_back(p);
    return r;
}

int main(int argc, char** argv) {
    const char* out = argc > 2 ? argv[2] : ".";
    out_dir = out;

    // ---- real caller-produced polygons ----
    {
        // A meandering river centreline buffered by the engine's own Clipper2 round-join path.
        std::vector<ab::WaterGeometryPoint> centreline = {
            {0.0, 0.0}, {40.0, 5.0}, {85.0, 2.0}, {130.0, -18.0}, {175.0, -22.0},
            {220.0, 4.0}, {260.0, 30.0}, {300.0, 38.0}, {340.0, 12.0}, {380.0, -8.0},
        };
        auto regions = ab::buffer_waterway_centerline(centreline, 2.5, 0.20);
        int n = 0;
        for (const auto& region : regions) {
            char name[64];
            snprintf(name, sizeof(name), "river-buffer-%d", n++);
            write_case(name, from_region(region));
        }
    }
    {
        // A tight hairpin bend: joins overlap, the buffer union splits it.
        std::vector<ab::WaterGeometryPoint> hairpin = {
            {0.0, 0.0}, {60.0, 0.0}, {80.0, 8.0}, {80.0, 40.0}, {55.0, 52.0},
        };
        auto regions = ab::buffer_waterway_centerline(hairpin, 6.0, 0.25);
        int n = 0;
        for (const auto& region : regions) {
            char name[64];
            snprintf(name, sizeof(name), "hairpin-buffer-%d", n++);
            write_case(name, from_region(region));
        }
    }
    {
        // Raster cell unions with real holes: an island ring inside a lake ring.
        std::vector<std::uint32_t> cells;
        auto add_rect = [&](std::uint32_t x0, std::uint32_t y0, std::uint32_t x1, std::uint32_t y1) {
            for (std::uint32_t y = y0; y < y1; ++y)
                for (std::uint32_t x = x0; x < x1; ++x) cells.push_back(y * 64 + x);
        };
        add_rect(4, 4, 20, 14);      // main lake
        add_rect(8, 6, 16, 12);      // island (hole) overlapping the lake
        add_rect(30, 16, 36, 22);    // second body
        add_rect(32, 18, 34, 20);    // hole in the second body
        auto regions = ab::union_water_raster_cells(cells, 64, 2.5);
        int n = 0;
        for (const auto& region : regions) {
            char name[64];
            snprintf(name, sizeof(name), "cell-union-%d", n++);
            write_case(name, from_region(region));
        }
    }

    // ---- synthetic geometry ----
    // Plain square, counter-clockwise.
    write_case("square", Polygon{ring_from_list({{0, 0}, {10, 0}, {10, 10}, {0, 10}})});
    // Same square, clockwise (earcut normalises winding itself).
    write_case("square-cw", Polygon{ring_from_list({{0, 0}, {0, 10}, {10, 10}, {10, 0}})});
    // Square with one square hole.
    write_case("square-hole", Polygon{
        ring_from_list({{0, 0}, {12, 0}, {12, 12}, {0, 12}}),
        ring_from_list({{3, 3}, {9, 3}, {9, 9}, {3, 9}}),
    });
    // Square with two holes, one of them triangular and concave.
    write_case("square-two-holes", Polygon{
        ring_from_list({{0, 0}, {20, 0}, {20, 20}, {0, 20}}),
        ring_from_list({{2, 2}, {8, 2}, {8, 8}, {2, 8}}),
        ring_from_list({{12, 2}, {18, 2}, {15, 9}}),
    });
    // Hole touching the outer ring at a vertex.
    write_case("hole-touch-vertex", Polygon{
        ring_from_list({{0, 0}, {10, 0}, {10, 10}, {0, 10}}),
        ring_from_list({{5, 5}, {10, 5}, {5, 8}}),
    });
    // Hole with an edge collinear/overlapping the outer edge.
    write_case("hole-touch-edge", Polygon{
        ring_from_list({{0, 0}, {10, 0}, {10, 10}, {0, 10}}),
        ring_from_list({{2, 0}, {8, 0}, {8, 4}, {2, 4}}),
    });
    // Concave comb: many reflex vertices.
    {
        Ring comb;
        for (int i = 0; i <= 10; ++i) {
            comb.push_back({double(i), i % 2 ? 1.0 : 9.0});
            if (i < 10) comb.push_back({double(i) + 0.5, i % 2 ? 1.0 : 9.0});
        }
        comb.push_back({10, 10});
        comb.push_back({0, 10});
        write_case("comb", Polygon{comb});
    }
    // Star polygon: alternating outer/inner radii around the centre.
    {
        Ring s;
        for (int i = 0; i < 10; ++i) {
            double ang = (i * 36.0) * 3.141592653589793 / 180.0;
            double r = i % 2 ? 4.0 : 11.0;
            s.push_back({10.0 + r * cos(ang), 10.0 + r * sin(ang)});
        }
        write_case("star", Polygon{s});
    }
    // Collinear points along edges (filterPoints path).
    write_case("collinear", Polygon{ring_from_list({
        {0, 0}, {2, 0}, {4, 0}, {6, 0}, {6, 2}, {6, 4}, {6, 6}, {4, 6}, {2, 6}, {0, 6}, {0, 4}, {0, 2},
    })});
    // Duplicate consecutive points.
    write_case("duplicates", Polygon{ring_from_list({
        {0, 0}, {0, 0}, {8, 0}, {8, 0}, {8, 8}, {0, 8}, {0, 8},
    })});
    // Bowtie: self-crossing quadrilateral.
    write_case("bowtie", Polygon{ring_from_list({{0, 0}, {10, 10}, {10, 0}, {0, 10}})});
    // Winding with a full extra turn (w=2): a ring whose edges overlap.
    write_case("overlap-turn", Polygon{ring_from_list({
        {0, 0}, {6, 0}, {6, 6}, {3, 6}, {3, 3}, {9, 3}, {9, 9}, {0, 9},
    })});
    // Degenerate: fewer than 3 vertices in every ring.
    write_case("degenerate-two", Polygon{ring_from_list({{0, 0}, {5, 5}})});
    // Degenerate: a single vertex.
    write_case("degenerate-one", Polygon{ring_from_list({{2, 2}})});
    // Degenerate: zero vertices.
    write_case("degenerate-empty", Polygon{ring_from_list({})});
    // Degenerate: completely collinear ring.
    write_case("degenerate-collinear", Polygon{ring_from_list({{0, 0}, {2, 2}, {4, 4}, {6, 6}})});
    // Hole with no points, outer fine.
    write_case("empty-hole", Polygon{
        ring_from_list({{0, 0}, {10, 0}, {10, 10}, {0, 10}}),
        ring_from_list({}),
    });
    // Hole entirely outside the outer ring.
    write_case("hole-outside", Polygon{
        ring_from_list({{0, 0}, {10, 0}, {10, 10}, {0, 10}}),
        ring_from_list({{20, 20}, {26, 20}, {26, 26}, {20, 26}}),
    });
    // Hole crossing the outer edge.
    write_case("hole-crossing", Polygon{
        ring_from_list({{0, 0}, {10, 0}, {10, 10}, {0, 10}}),
        ring_from_list({{5, 5}, {15, 5}, {15, 8}, {5, 8}}),
    });
    // Two identical holes.
    write_case("hole-duplicate", Polygon{
        ring_from_list({{0, 0}, {20, 0}, {20, 20}, {0, 20}}),
        ring_from_list({{4, 4}, {8, 4}, {8, 8}, {4, 8}}),
        ring_from_list({{4, 4}, {8, 4}, {8, 8}, {4, 8}}),
    });
    // Hole inside another hole (nested, in one polygon listing).
    write_case("nested-holes", Polygon{
        ring_from_list({{0, 0}, {30, 0}, {30, 30}, {0, 30}}),
        ring_from_list({{3, 3}, {27, 3}, {27, 27}, {3, 27}}),
        ring_from_list({{8, 8}, {22, 8}, {22, 22}, {8, 22}}),
    });
    // Exactly at the z-order threshold (80): hashing off.
    {
        Ring oct;
        for (int i = 0; i < 80; ++i) {
            double a = 2.0 * 3.141592653589793 * i / 80.0;
            oct.push_back({50.0 + 30.0 * cos(a), 50.0 + 30.0 * sin(a)});
        }
        write_case("circle-80", Polygon{oct});
    }
    // Just past the z-order threshold: hashing on, isEarHashed path.
    {
        Ring oct;
        for (int i = 0; i < 81; ++i) {
            double a = 2.0 * 3.141592653589793 * i / 81.0;
            oct.push_back({50.0 + 30.0 * cos(a), 50.0 + 30.0 * sin(a)});
        }
        write_case("circle-81", Polygon{oct});
    }
    // A big hashed case with holes.
    {
        Ring oct;
        for (int i = 0; i < 200; ++i) {
            double a = 2.0 * 3.141592653589793 * i / 200.0;
            oct.push_back({100.0 + 80.0 * cos(a), 100.0 + 80.0 * sin(a)});
        }
        Ring hole1;
        for (int i = 0; i < 60; ++i) {
            double a = 2.0 * 3.141592653589793 * i / 60.0;
            hole1.push_back({70.0 + 20.0 * cos(a), 100.0 + 20.0 * sin(a)});
        }
        Ring hole2;
        for (int i = 0; i < 40; ++i) {
            double a = 2.0 * 3.141592653589793 * i / 40.0;
            hole2.push_back({130.0 + 12.0 * cos(a), 100.0 + 12.0 * sin(a)});
        }
        write_case("circle-holes", Polygon{oct, hole1, hole2});
    }
    // Negative coordinates and tiny extents (z-order integer mapping).
    write_case("negative-tiny", Polygon{
        ring_from_list({{-0.5, -0.25}, {0.5, -0.25}, {0.5, 0.25}, {-0.5, 0.25}}),
    });
    // Fractional coordinates with exact .5 midpoints.
    write_case("fractional", Polygon{ring_from_list({
        {0.5, 0.5}, {10.5, 0.5}, {10.5, 10.5}, {5.5, 4.5}, {0.5, 10.5},
    })});
    {
        std::string m = path_of("manifest", ".txt");
        FILE* f = fopen(m.c_str(), "w");
        for (const auto& n : g_case_names) fprintf(f, "%s\n", n.c_str());
        fclose(f);
    }
    return 0;
}
