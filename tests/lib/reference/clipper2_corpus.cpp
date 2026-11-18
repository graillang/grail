// Reference corpus for tests/lib/clipper2_test.grl: the vendored Clipper2 2.0.1 (ThirdParty/clipper2,
// compiled unmodified, exactly the translation units clipper2_*_ue.cpp include) runs every case and
// writes the output vertex for vertex. Real caller geometry comes from the engine's own
// water_geometry.cpp (buffered river centrelines, raster cell unions), and the tile-clip case
// mirrors water_volume_split.cpp's ClipperD(8) Intersection/EvenOdd/PolyTreeD call.
// Build and run with tests/lib/reference/build-corpus.sh.
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <functional>
#include <string>
#include <vector>

#include "clipper2/clipper.h"

#include "abundance/water_geometry.hpp"

using namespace Clipper2Lib;

static const char* g_out = ".";
static std::vector<std::string> g_names;

static std::string path_of(const char* name, const char* suffix) {
    std::string p(g_out);
    p += "/";
    p += name;
    p += suffix;
    return p;
}

// ---- serializer helpers ----

static void write_i64_paths(const char* name, const std::vector<Path64>& paths) {
    std::string o = path_of(name, ".out");
    FILE* f = fopen(o.c_str(), "w");
    fprintf(f, "%zu\n", paths.size());
    for (const auto& p : paths) {
        fprintf(f, "%zu", p.size());
        for (const auto& pt : p) fprintf(f, " %lld %lld", (long long)pt.x, (long long)pt.y);
        fprintf(f, "\n");
    }
    fclose(f);
}

static void write_d_paths(const char* name, const std::vector<PathD>& paths, int error) {
    std::string o = path_of(name, ".out");
    FILE* f = fopen(o.c_str(), "w");
    fprintf(f, "%d %zu\n", error, paths.size());
    for (const auto& p : paths) {
        fprintf(f, "%zu", p.size());
        for (const auto& pt : p) {
            unsigned long long xb, yb;
            memcpy(&xb, &pt.x, 8);
            memcpy(&yb, &pt.y, 8);
            fprintf(f, " %016llx %016llx", xb, yb);
        }
        fprintf(f, "\n");
    }
    fclose(f);
}

static void write_i64_tree(const char* name, const PolyTree64& tree) {
    std::string o = path_of(name, ".out");
    FILE* f = fopen(o.c_str(), "w");
    // Flatten in depth-first child order (the tree's own traversal).
    std::vector<const PolyPath64*> nodes;
    std::vector<std::pair<int, int>> parents;
    std::function<void(const PolyPath64*, int)> walk = [&](const PolyPath64* node, int parent_index) {
        for (size_t c = 0; c < node->Count(); ++c) {
            const PolyPath64* child = node->Child(c);
            int idx = (int)nodes.size();
            nodes.push_back(child);
            parents.push_back({parent_index, (int)child->Level()});
            walk(child, idx);
        }
    };
    walk(&tree, -1);
    fprintf(f, "%zu\n", nodes.size());
    for (size_t i = 0; i < nodes.size(); ++i) {
        const auto& p = nodes[i]->Polygon();
        fprintf(f, "%d %d %zu", parents[i].first, parents[i].second, p.size());
        for (const auto& pt : p) fprintf(f, " %lld %lld", (long long)pt.x, (long long)pt.y);
        fprintf(f, "\n");
    }
    fclose(f);
}

static void write_d_tree(const char* name, const PolyTreeD& tree, int error) {
    std::string o = path_of(name, ".out");
    FILE* f = fopen(o.c_str(), "w");
    std::vector<const PolyPathD*> nodes;
    std::vector<std::pair<int, int>> parents;
    std::function<void(const PolyPathD*, int)> walk = [&](const PolyPathD* node, int parent_index) {
        for (size_t c = 0; c < node->Count(); ++c) {
            const PolyPathD* child = node->Child(c);
            int idx = (int)nodes.size();
            nodes.push_back(child);
            parents.push_back({parent_index, (int)child->Level()});
            walk(child, idx);
        }
    };
    walk(&tree, -1);
    fprintf(f, "%d %zu\n", error, nodes.size());
    for (size_t i = 0; i < nodes.size(); ++i) {
        const auto& p = nodes[i]->Polygon();
        fprintf(f, "%d %d %zu", parents[i].first, parents[i].second, p.size());
        for (const auto& pt : p) {
            unsigned long long xb, yb;
            memcpy(&xb, &pt.x, 8);
            memcpy(&yb, &pt.y, 8);
            fprintf(f, " %016llx %016llx", xb, yb);
        }
        fprintf(f, "\n");
    }
    fclose(f);
}

// ---- input writer: op fill precision nsub subpaths nclip clippaths ----
// (op 1..4 = Intersection/Union/Difference/Xor; fill 0..3 = EvenOdd/NonZero/Positive/Negative)

static void write_input64(const char* name, ClipType op, FillRule fill,
                          const std::vector<Path64>& sub, const std::vector<Path64>& clip) {
    std::string in = path_of(name, ".in");
    FILE* f = fopen(in.c_str(), "w");
    fprintf(f, "%d %d 0\n", (int)op, (int)fill);
    fprintf(f, "%zu\n", sub.size());
    for (const auto& p : sub) {
        fprintf(f, "%zu", p.size());
        for (const auto& pt : p) fprintf(f, " %lld %lld", (long long)pt.x, (long long)pt.y);
        fprintf(f, "\n");
    }
    fprintf(f, "%zu\n", clip.size());
    for (const auto& p : clip) {
        fprintf(f, "%zu", p.size());
        for (const auto& pt : p) fprintf(f, " %lld %lld", (long long)pt.x, (long long)pt.y);
        fprintf(f, "\n");
    }
    fclose(f);
}

static void write_input_d(const char* name, ClipType op, FillRule fill, int precision,
                          const std::vector<PathD>& sub, const std::vector<PathD>& clip) {
    std::string in = path_of(name, ".in");
    FILE* f = fopen(in.c_str(), "w");
    fprintf(f, "%d %d %d\n", (int)op, (int)fill, precision);
    fprintf(f, "%zu\n", sub.size());
    for (const auto& p : sub) {
        fprintf(f, "%zu", p.size());
        for (const auto& pt : p) fprintf(f, " %.17g %.17g", pt.x, pt.y);
        fprintf(f, "\n");
    }
    fprintf(f, "%zu\n", clip.size());
    for (const auto& p : clip) {
        fprintf(f, "%zu", p.size());
        for (const auto& pt : p) fprintf(f, " %.17g %.17g", pt.x, pt.y);
        fprintf(f, "\n");
    }
    fclose(f);
}

// ---- geometry helpers ----

static Path64 rect64(int64_t x0, int64_t y0, int64_t x1, int64_t y1) {
    return Path64{{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}};
}

static PathD rectd(double x0, double y0, double x1, double y1) {
    return PathD{{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}};
}

static std::vector<PathD> to_paths_d(const std::vector<ab::WaterGeometryRegion>& regions) {
    std::vector<PathD> paths;
    for (const auto& region : regions) {
        PathD outer;
        for (const auto& p : region.outer) outer.push_back({p.x_m, p.y_m});
        paths.push_back(outer);
        for (const auto& hole : region.holes) {
            PathD h;
            for (const auto& p : hole) h.push_back({p.x_m, p.y_m});
            paths.push_back(h);
        }
    }
    return paths;
}

static void mark(const char* kind, const char* name) { g_names.push_back(std::string(kind) + " " + name); }

static void emit_bool64(const char* name, ClipType op, FillRule fill,
                        const std::vector<Path64>& sub, const std::vector<Path64>& clip) {
    write_input64(name, op, fill, sub, clip);
    write_i64_paths(name, BooleanOp(op, fill, sub, clip));
    mark("bool64", name);
}

static void emit_tree64(const char* name, ClipType op, FillRule fill,
                        const std::vector<Path64>& sub, const std::vector<Path64>& clip) {
    write_input64(name, op, fill, sub, clip);
    PolyTree64 tree;
    BooleanOp(op, fill, sub, clip, tree);
    write_i64_tree(name, tree);
    mark("tree64", name);
}

static void emit_boold(const char* name, ClipType op, FillRule fill, int precision,
                       const std::vector<PathD>& sub, const std::vector<PathD>& clip) {
    write_input_d(name, op, fill, precision, sub, clip);
    int error_code = 0;
    int clamped = precision;
    try {
        CheckPrecisionRange(clamped, error_code);
    } catch (const Clipper2Exception&) {
        // With exceptions enabled DoError throws before the non-fatal error_code is observed.
        error_code = precision_error_i;
    }
    std::vector<PathD> paths;
    if (error_code == 0) {
        try {
            ClipperD clipper(precision);
            clipper.AddSubject(sub);
            clipper.AddClip(clip);
            clipper.Execute(op, fill, paths);
            error_code = clipper.ErrorCode();
        } catch (const Clipper2Exception&) {
            error_code = range_error_i;
            paths.clear();
        }
    }
    write_d_paths(name, paths, error_code);
    mark("boold", name);
}

static void emit_treed(const char* name, ClipType op, FillRule fill, int precision,
                       const std::vector<PathD>& sub, const std::vector<PathD>& clip) {
    write_input_d(name, op, fill, precision, sub, clip);
    int error_code = 0;
    int clamped = precision;
    try {
        CheckPrecisionRange(clamped, error_code);
    } catch (const Clipper2Exception&) {
        error_code = precision_error_i;
    }
    PolyTreeD tree;
    if (error_code == 0) {
        try {
            ClipperD clipper(precision);
            clipper.AddSubject(sub);
            clipper.AddClip(clip);
            clipper.Execute(op, fill, tree);
            error_code = clipper.ErrorCode();
        } catch (const Clipper2Exception&) {
            error_code = range_error_i;
            tree.Clear();
        }
    }
    write_d_tree(name, tree, error_code);
    mark("treed", name);
}

int main(int argc, char** argv) {
    g_out = argc > 1 ? argv[1] : ".";
    const char* abundance = argc > 2 ? argv[2] : "/home/shulgin/abundance";

    // ---- synthetic int64 booleans ----
    std::vector<Path64> two_squares{rect64(0, 0, 10, 10), rect64(5, 5, 15, 15)};
    emit_bool64("union-squares", ClipType::Union, FillRule::EvenOdd, two_squares, {});
    emit_bool64("union-squares-nz", ClipType::Union, FillRule::NonZero, two_squares, {});
    emit_bool64("intersect-squares", ClipType::Intersection, FillRule::EvenOdd,
                {rect64(0, 0, 10, 10)}, {rect64(5, 5, 15, 15)});
    emit_bool64("difference-squares", ClipType::Difference, FillRule::EvenOdd,
                {rect64(0, 0, 10, 10)}, {rect64(5, 5, 15, 15)});
    emit_bool64("xor-squares", ClipType::Xor, FillRule::EvenOdd,
                {rect64(0, 0, 10, 10)}, {rect64(5, 5, 15, 15)});
    // Touching at a corner / sharing an edge / collinear edges.
    emit_bool64("corner-touch", ClipType::Union, FillRule::EvenOdd,
                {rect64(0, 0, 10, 10), rect64(10, 10, 20, 20)}, {});
    emit_bool64("edge-touch", ClipType::Union, FillRule::EvenOdd,
                {rect64(0, 0, 10, 10), rect64(10, 0, 20, 10)}, {});
    emit_bool64("collinear-merge", ClipType::Union, FillRule::NonZero,
                {rect64(0, 0, 10, 10), rect64(10, 2, 20, 8)}, {});
    // Duplicate vertices and a spike (out-and-back).
    emit_bool64("duplicate-vertices", ClipType::Union, FillRule::NonZero,
                {Path64{{0, 0}, {0, 0}, {10, 0}, {10, 0}, {10, 10}, {0, 10}}}, {});
    emit_bool64("spike", ClipType::Union, FillRule::NonZero,
                {Path64{{0, 0}, {10, 0}, {10, 10}, {20, 10}, {10, 10}, {0, 10}}}, {});
    // Staircase (lots of horizontals).
    {
        Path64 stair;
        for (int i = 0; i < 6; ++i) {
            stair.push_back({i * 4, i * 4});
            stair.push_back({i * 4 + 4, i * 4});
            stair.push_back({i * 4 + 4, i * 4 + 4});
        }
        stair.push_back({24, 0});
        emit_bool64("staircase", ClipType::Union, FillRule::NonZero, {stair}, {});
    }
    // Self-intersecting subject (bowtie) through the union path.
    emit_bool64("bowtie-union", ClipType::Union, FillRule::NonZero,
                {Path64{{0, 0}, {10, 10}, {10, 0}, {0, 10}}}, {});
    // One clockwise, one counter-clockwise square (winding under NonZero).
    emit_bool64("winding-opposite", ClipType::Union, FillRule::NonZero,
                {rect64(0, 0, 10, 10), Path64{{12, 0}, {12, 10}, {22, 10}, {22, 0}}}, {});
    // Positive/negative fill rules.
    emit_bool64("positive-fill", ClipType::Union, FillRule::Positive,
                {rect64(0, 0, 10, 10), Path64{{20, 0}, {20, 10}, {30, 10}, {30, 0}}}, {});
    emit_bool64("negative-fill", ClipType::Union, FillRule::Negative,
                {rect64(0, 0, 10, 10), Path64{{20, 0}, {20, 10}, {30, 10}, {30, 0}}}, {});
    // Degenerate inputs: fewer than three points are dropped, empty clip is fine.
    emit_bool64("degenerate-paths", ClipType::Union, FillRule::NonZero,
                {Path64{{0, 0}, {5, 5}}, Path64{{2, 2}}, Path64{}, rect64(0, 0, 4, 4)}, {});
    // Nested holes via difference.
    emit_bool64("nested-difference", ClipType::Difference, FillRule::EvenOdd,
                {rect64(0, 0, 40, 40)}, {rect64(5, 5, 35, 35), rect64(10, 10, 30, 30)});
    // Many-cell raster union (the shape union_water_raster_cells feeds Clipper2).
    {
        std::vector<Path64> cells;
        for (int64_t y = 0; y < 12; ++y)
            for (int64_t x = 0; x < 12; ++x) {
                if ((x + y) % 7 == 0) continue;
                cells.push_back(rect64(x, y, x + 1, y + 1));
            }
        emit_tree64("cell-union-tree", ClipType::Union, FillRule::NonZero, cells, {});
    }
    // ---- real caller geometry: river buffers and cell unions from water_geometry.cpp ----
    {
        std::vector<ab::WaterGeometryPoint> centreline = {
            {0.0, 0.0}, {40.0, 5.0}, {85.0, 2.0}, {130.0, -18.0}, {175.0, -22.0},
            {220.0, 4.0}, {260.0, 30.0}, {300.0, 38.0}, {340.0, 12.0}, {380.0, -8.0},
        };
        auto regions = ab::buffer_waterway_centerline(centreline, 2.5, 0.20);
        auto paths = to_paths_d(regions);
        // Millimetre grid: the same 10^3 scaling the caller's InflatePaths uses.
        emit_treed("river-buffer-tree", ClipType::Union, FillRule::NonZero, 3, paths, {});
        emit_boold("river-buffer-paths", ClipType::Union, FillRule::NonZero, 3, paths, {});
    }
    {
        std::vector<std::uint32_t> cells;
        auto add_rect = [&](std::uint32_t x0, std::uint32_t y0, std::uint32_t x1, std::uint32_t y1) {
            for (std::uint32_t y = y0; y < y1; ++y)
                for (std::uint32_t x = x0; x < x1; ++x) cells.push_back(y * 64 + x);
        };
        add_rect(4, 4, 20, 14);
        add_rect(8, 6, 16, 12);
        add_rect(30, 16, 36, 22);
        add_rect(32, 18, 34, 20);
        auto regions = ab::union_water_raster_cells(cells, 64, 2.5);
        auto paths = to_paths_d(regions);
        emit_treed("water-union-tree", ClipType::Union, FillRule::EvenOdd, 3, paths, {});
    }
    // ---- the tile clip of water_volume_split.cpp: ClipperD(8), Intersection, EvenOdd, PolyTreeD ----
    {
        std::vector<PathD> subject;
        PathD outer = rectd(0.5, 0.5, 100.5, 80.5);
        subject.push_back(outer);
        std::vector<PathD> clip{rectd(10.0, 10.0, 60.0, 60.0)};
        write_input_d("tile-clip", ClipType::Intersection, FillRule::EvenOdd, 8, subject, clip);
        ClipperD clipper(8);
        clipper.AddSubject(subject);
        clipper.AddClip(clip);
        PolyTreeD tree;
        bool ok = clipper.Execute(ClipType::Intersection, FillRule::EvenOdd, tree);
        (void)ok;
        write_d_tree("tile-clip", tree, clipper.ErrorCode());
        mark("treed", "tile-clip");
    }
    // ---- precision and failure paths ----
    std::vector<PathD> frac{rectd(0.25, 0.125, 10.75, 10.625), rectd(5.5, 5.5, 15.25, 15.75)};
    emit_boold("fractional-prec3", ClipType::Union, FillRule::NonZero, 3, frac, {});
    emit_treed("fractional-prec3-tree", ClipType::Union, FillRule::NonZero, 3, frac, {});
    emit_boold("fractional-prec8", ClipType::Intersection, FillRule::EvenOdd, 8,
               {frac[0]}, {frac[1]});
    emit_boold("precision-out-of-range", ClipType::Union, FillRule::NonZero, 12, frac, {});
    // Out-of-range D coordinates: the C++ throws range_error when exceptions are enabled.
    {
        std::vector<PathD> huge{PathD{{0.0, 0.0}, {1e19, 0.0}, {1e19, 1e19}, {0.0, 1e19}}};
        emit_boold("range-error", ClipType::Union, FillRule::NonZero, 3, huge, {});
    }
    // ---- PointInPolygon and area ----
    {
        Path64 ring = rect64(0, 0, 10, 10);
        std::vector<Point64> probes{{5, 5}, {0, 5}, {10, 10}, {-1, 5}, {11, 5}, {0, 0}, {5, 10}, {12, 12}};
        std::string name = "pip-square";
        std::string in = path_of(name.c_str(), ".in");
        FILE* f = fopen(in.c_str(), "w");
        fprintf(f, "%zu", ring.size());
        for (const auto& pt : ring) fprintf(f, " %lld %lld", (long long)pt.x, (long long)pt.y);
        fprintf(f, "\n%zu\n", probes.size());
        for (const auto& pt : probes) fprintf(f, "%lld %lld\n", (long long)pt.x, (long long)pt.y);
        fclose(f);
        std::string o = path_of(name.c_str(), ".out");
        f = fopen(o.c_str(), "w");
        for (const auto& pt : probes) {
            auto r = PointInPolygon(pt, ring);
            fprintf(f, "%d\n", r == PointInPolygonResult::IsOn ? 0 : (r == PointInPolygonResult::IsInside ? 1 : 2));
        }
        fclose(f);
        mark("pip", name.c_str());
    }
    {
        std::vector<Path64> polys{rect64(0, 0, 10, 10), Path64{{0, 0}, {0, 10}, {10, 10}, {10, 0}},
                                  Path64{{0, 0}, {10, 10}, {10, 0}, {0, 10}}, Path64{{0, 0}, {5, 5}}};
        std::string name = "area";
        std::string in = path_of(name.c_str(), ".in");
        FILE* f = fopen(in.c_str(), "w");
        fprintf(f, "%zu\n", polys.size());
        for (const auto& p : polys) {
            fprintf(f, "%zu", p.size());
            for (const auto& pt : p) fprintf(f, " %lld %lld", (long long)pt.x, (long long)pt.y);
            fprintf(f, "\n");
        }
        fclose(f);
        std::string o = path_of(name.c_str(), ".out");
        f = fopen(o.c_str(), "w");
        for (const auto& p : polys) {
            double a = Area(p);
            unsigned long long ab;
            memcpy(&ab, &a, 8);
            fprintf(f, "%016llx %d\n", ab, IsPositive(p) ? 1 : 0);
        }
        fclose(f);
        mark("area", name.c_str());
    }
    (void)abundance;
    {
        std::string m = path_of("manifest", ".txt");
        FILE* f = fopen(m.c_str(), "w");
        for (const auto& n : g_names) fprintf(f, "%s\n", n.c_str());
        fclose(f);
    }
    return 0;
}
