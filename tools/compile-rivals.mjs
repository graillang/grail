// Compile speed against C, C++, Go, Zig and rustc (docs/design/compile-speed.md, "Against Go, Zig
// and rustc"; the book's Performance chapter).
//
// Two kinds of programs in all six languages:
//   1. Scaling projects (`syn1000`, `syn4000` at --sizes): N copies of a record, its constructor
//      and a 15-line loop function split across 20 modules / packages / translation units (plus a
//      main calling each), so every toolchain gets realistic parallel compilation and incremental
//      module/package/TU rebuilds on a one-function edit (Go caches untouched packages, make
//      recompiles only the edited C/C++ translation unit, cargo uses incremental CGUs, Grail uses
//      its function/module store).
//   2. Small single-file programs (`hello` and the rival twins of bench/) for startup/small-file
//      reference; the overview geometric mean counts only the multi-module scaling projects.
//
// Each program is measured four ways:
//   check cold      grail check | make check (clang -fsyntax-only) | make check (clang++ -fsyntax-only)
//                   | go vet ./... (go build -o /dev/null . is measured beside it)
//                   | zig build-exe -fno-emit-bin | cargo check
//   check edited    the same after one function body in module m10 (or main for twins) changed
//   build cold      grail build | make (clang -O0 -g, lld) | make (clang++ -std=c++20 -O0 -g, lld)
//                   | go build | zig build-exe -O Debug | cargo build
//   build edited    the same after the edit
//
// Two passes: every toolchain in one process (GRAIL_JOBS=1, GOMAXPROCS=1 -p=1, make -j1, cargo -j1)
// for user-space instructions (the primary figure, which load does not move), and four jobs each
// for wall time. Best of --runs (default 2).
//   bun tools/compile-rivals.mjs [--runs N] [--sizes 1000,4000] [--twins a,b] [--compiler PATH | --branch REF] [--json PATH]
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, utimesSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { root } from './platforms.mjs';
import { compilerOptions, grailCompiler, jsonOption, loadavg, measurer, ratio, run, toolchains, versions, writeResults } from './rivals/common.mjs';

const argv = process.argv.slice(2);
const chosen = compilerOptions(argv);
const jsonPath = jsonOption(argv);
const option = (name, fallback) => { const at = argv.indexOf(name); return at < 0 ? fallback : argv[at + 1]; };
const runs = Number(option('--runs', 2));
const sizes = option('--sizes', '1000,4000').split(',').filter(Boolean).map(Number);
const MODULES = 20;
const work = join(root, '.work/compile-rivals');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const measure = measurer(root, work);
const measuredGrail = !chosen.compiler && !chosen.branch && process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER)
  ? grailCompiler(root, { compiler: process.env.GRAIL_COMPILER })
  : grailCompiler(root, { ...chosen, release: true });
const grail = measuredGrail.compiler;

// ---- multi-module project generators: return { files: { relPath: content }, editFile, multi: true }
// Split N functions across M = 20 modules (m0..m19); the edit changes `% 1000` -> `% 1001` in one
// function of module m10 (the midpoint), leaving the other 19 modules untouched.
function chunksOf(n) {
  const m = Math.min(MODULES, Math.max(1, n));
  const out = Array.from({ length: m }, () => []);
  for (let i = 0; i < n; i++) out[i % m].push(i);
  return out;
}

function grailScaling(n, seed) {
  const chunks = chunksOf(n);
  const files = {};
  for (let p = 0; p < chunks.length; p++) {
    const parts = [`module m${p};\n\n`];
    for (const i of chunks[p]) {
      parts.push(`struct Rec${i} {\n    a: u64,\n    b: u64,\n    name: string,\n}\n\nfn mk${i}(a: u64, b: u64) -> Rec${i} {\n    Rec${i} { a: a, b: b, name: "r${i}" }\n}\n\npub fn work${i}(v: &u64[], k: u64) -> u64 {\n    mut total = 0;\n    for i in v.len() {\n        x := v[i];\n        if x % 2 == 0 {\n            total = total + x * k % 1000;\n        } else {\n            total = total + x % 7;\n        }\n    }\n    r := mk${i}(total, k);\n    mut out = r.a % 100000;\n    while out > 1000 {\n        out = out / 3;\n    }\n    out + r.b + r.name.len()\n}\n\n`);
    }
    files[`src/m${p}.grl`] = parts.join('');
  }
  const main = [];
  for (let p = 0; p < chunks.length; p++) main.push(`use m${p};\n`);
  main.push(`\nfn main() {\n    v := u64[1, 2, 3, 4];\n    mut t = ${seed};\n`);
  for (let p = 0; p < chunks.length; p++) {
    for (const i of chunks[p]) main.push(`    t = t + m${p}::work${i}(&v, ${i});\n`);
  }
  main.push('    println(t);\n}\n');
  files['src/main.grl'] = main.join('');
  files['grail.toml'] = `[package]\nname = "syn"\nversion = "0.1.0"\n`;
  const midMod = chunks.length >> 1;
  return { files, editFile: `src/m${midMod}.grl`, editTarget: chunks[midMod][0], multi: true };
}

function rustScaling(n, seed) {
  const chunks = chunksOf(n);
  const files = {};
  const members = [];
  const deps = [];
  for (let p = 0; p < chunks.length; p++) {
    members.push(`"crates/m${p}"`);
    deps.push(`m${p} = { path = "crates/m${p}" }`);
    files[`crates/m${p}/Cargo.toml`] = `[package]\nname = "m${p}"\nversion = "0.1.0"\nedition = "2021"\n`;
    const parts = [];
    for (const i of chunks[p]) {
      parts.push(`struct Rec${i} {\n    a: u64,\n    b: u64,\n    name: String,\n}\nfn mk${i}(a: u64, b: u64) -> Rec${i} {\n    Rec${i} { a: a, b: b, name: "r${i}".to_string() }\n}\npub fn work${i}(v: &[u64], k: u64) -> u64 {\n    let mut total: u64 = 0;\n    for i in 0..v.len() {\n        let x = v[i];\n        if x % 2 == 0 {\n            total = total.wrapping_add(x * k % 1000);\n        } else {\n            total = total.wrapping_add(x % 7);\n        }\n    }\n    let r = mk${i}(total, k);\n    let mut out = r.a % 100000;\n    while out > 1000 {\n        out = out / 3;\n    }\n    out + r.b + r.name.len() as u64\n}\n`);
    }
    files[`crates/m${p}/src/lib.rs`] = parts.join("");
  }
  const main = [`fn main() {\n    let v: Vec<u64> = vec![1, 2, 3, 4];\n    let mut t: u64 = ${seed};\n`];
  for (let p = 0; p < chunks.length; p++) {
    for (const i of chunks[p]) main.push(`    t = t.wrapping_add(m${p}::work${i}(&v, ${i}));\n`);
  }
  main.push(`    println!("{}", t);\n}\n`);
  files["src/main.rs"] = main.join("");
  files["Cargo.toml"] = `[workspace]\nmembers = [${members.join(", ")}]\n\n[package]\nname = "syn"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\n${deps.join("\n")}\n`;
  const midMod = chunks.length >> 1;
  return { files, editFile: `crates/m${midMod}/src/lib.rs`, editTarget: chunks[midMod][0], multi: true };
}

function goScaling(n, seed) {
  const chunks = chunksOf(n);
  const files = {};
  for (let p = 0; p < chunks.length; p++) {
    const parts = [`package m${p}\n\n`];
    for (const i of chunks[p]) {
      parts.push(`type Rec${i} struct {\n\ta    uint64\n\tb    uint64\n\tname string\n}\n\nfunc mk${i}(a uint64, b uint64) Rec${i} {\n\treturn Rec${i}{a: a, b: b, name: "r${i}"}\n}\n\nfunc Work${i}(v []uint64, k uint64) uint64 {\n\tvar total uint64\n\tfor i := 0; i < len(v); i++ {\n\t\tx := v[i]\n\t\tif x%2 == 0 {\n\t\t\ttotal += x * k % 1000\n\t\t} else {\n\t\t\ttotal += x % 7\n\t\t}\n\t}\n\tr := mk${i}(total, k)\n\tout := r.a % 100000\n\tfor out > 1000 {\n\t\tout = out / 3\n\t}\n\treturn out + r.b + uint64(len(r.name))\n}\n\n`);
    }
    files[`m${p}/m${p}.go`] = parts.join('');
  }
  const main = ['package main\n\nimport (\n\t"fmt"\n'];
  for (let p = 0; p < chunks.length; p++) main.push(`\t"syn/m${p}"\n`);
  main.push(`)\n\nfunc main() {\n\tv := []uint64{1, 2, 3, 4}\n\tvar t uint64 = ${seed}\n`);
  for (let p = 0; p < chunks.length; p++) {
    for (const i of chunks[p]) main.push(`\tt += m${p}.Work${i}(v, ${i})\n`);
  }
  main.push('\tfmt.Println(t)\n}\n');
  files['main.go'] = main.join('');
  const midMod = chunks.length >> 1;
  return { files, editFile: `m${midMod}/m${midMod}.go`, editTarget: chunks[midMod][0], multi: true };
}

function zigScaling(n, seed) {
  const chunks = chunksOf(n);
  const files = {};
  for (let p = 0; p < chunks.length; p++) {
    const parts = [];
    for (const i of chunks[p]) {
      parts.push(`const Rec${i} = struct {\n    a: u64,\n    b: u64,\n    name: []const u8,\n};\nfn mk${i}(a: u64, b: u64) Rec${i} {\n    return Rec${i}{ .a = a, .b = b, .name = "r${i}" };\n}\npub fn work${i}(v: []const u64, k: u64) u64 {\n    var total: u64 = 0;\n    for (0..v.len) |i| {\n        const x = v[i];\n        if (x % 2 == 0) {\n            total +%= x * k % 1000;\n        } else {\n            total +%= x % 7;\n        }\n    }\n    const r = mk${i}(total, k);\n    var out = r.a % 100000;\n    while (out > 1000) {\n        out = out / 3;\n    }\n    return out + r.b + r.name.len;\n}\n`);
    }
    files[`m${p}.zig`] = parts.join('');
  }
  const main = ['const std = @import("std");\n'];
  for (let p = 0; p < chunks.length; p++) main.push(`const m${p} = @import("m${p}.zig");\n`);
  main.push(`\npub fn main() !void {\n    const v = [_]u64{ 1, 2, 3, 4 };\n    var t: u64 = ${seed};\n`);
  for (let p = 0; p < chunks.length; p++) {
    for (const i of chunks[p]) main.push(`    t +%= m${p}.work${i}(&v, ${i});\n`);
  }
  main.push('    try std.io.getStdOut().writer().print("{d}\\n", .{t});\n}\n');
  files['main.zig'] = main.join('');
  const midMod = chunks.length >> 1;
  return { files, editFile: `m${midMod}.zig`, editTarget: chunks[midMod][0], multi: true };
}

function cScaling(n, seed) {
  const chunks = chunksOf(n);
  const files = {};
  const srcs = ['main.c'];
  for (let p = 0; p < chunks.length; p++) {
    srcs.push(`m${p}.c`);
    const hdr = ['#pragma once\n#include <stddef.h>\n#include <stdint.h>\n\n'];
    const parts = [`#include "m${p}.h"\n#include <string.h>\n\n`];
    for (const i of chunks[p]) {
      hdr.push(`uint64_t work${i}(const uint64_t *v, size_t len, uint64_t k);\n`);
      parts.push(`struct rec${i} {\n    uint64_t a;\n    uint64_t b;\n    const char *name;\n};\n\nstatic struct rec${i} mk${i}(uint64_t a, uint64_t b) {\n    return (struct rec${i}){ .a = a, .b = b, .name = "r${i}" };\n}\n\nuint64_t work${i}(const uint64_t *v, size_t len, uint64_t k) {\n    uint64_t total = 0;\n    for (size_t i = 0; i < len; i++) {\n        uint64_t x = v[i];\n        if (x % 2 == 0) {\n            total += x * k % 1000;\n        } else {\n            total += x % 7;\n        }\n    }\n    struct rec${i} r = mk${i}(total, k);\n    uint64_t out = r.a % 100000;\n    while (out > 1000) {\n        out = out / 3;\n    }\n    return out + r.b + strlen(r.name);\n}\n\n`);
    }
    files[`m${p}.h`] = hdr.join('');
    files[`m${p}.c`] = parts.join('');
  }
  const main = ['#include <inttypes.h>\n#include <stddef.h>\n#include <stdint.h>\n#include <stdio.h>\n'];
  for (let p = 0; p < chunks.length; p++) main.push(`#include "m${p}.h"\n`);
  main.push(`\nint main(void) {\n    const uint64_t v[] = { 1, 2, 3, 4 };\n    uint64_t t = ${seed};\n`);
  for (let p = 0; p < chunks.length; p++) {
    for (const i of chunks[p]) main.push(`    t += work${i}(v, 4, ${i});\n`);
  }
  main.push('    printf("%" PRIu64 "\\n", t);\n    return 0;\n}\n');
  files['main.c'] = main.join('');
  const objs = srcs.map(s => s.replace(/\.c$/, '.o')).join(' ');
  const chks = srcs.map(s => s.replace(/\.c$/, '.chk')).join(' ');
  files['Makefile'] = `CC = clang\nCFLAGS = -O0 -g\nLDFLAGS = -fuse-ld=lld\nOBJS = ${objs}\nCHECKS = ${chks}\n\nmain: $(OBJS)\n\t$(CC) $(LDFLAGS) -o main $(OBJS)\n\n%.o: %.c\n\t$(CC) $(CFLAGS) -c $< -o $@\n\ncheck: $(CHECKS)\n\n%.chk: %.c\n\t$(CC) -fsyntax-only $< && touch $@\n`;
  const midMod = chunks.length >> 1;
  return { files, editFile: `m${midMod}.c`, editTarget: chunks[midMod][0], multi: true };
}

function cppScaling(n, seed) {
  const chunks = chunksOf(n);
  const files = {};
  const srcs = ['main.cpp'];
  for (let p = 0; p < chunks.length; p++) {
    srcs.push(`m${p}.cpp`);
    const hdr = ['#pragma once\n#include <cstdint>\n#include <vector>\n\n'];
    const parts = [`#include "m${p}.hpp"\n#include <string>\n\n`];
    for (const i of chunks[p]) {
      hdr.push(`std::uint64_t work${i}(const std::vector<std::uint64_t>& v, std::uint64_t k);\n`);
      parts.push(`struct Rec${i} {\n    std::uint64_t a;\n    std::uint64_t b;\n    std::string name;\n};\n\nstatic Rec${i} mk${i}(std::uint64_t a, std::uint64_t b) {\n    return Rec${i}{a, b, "r${i}"};\n}\n\nstd::uint64_t work${i}(const std::vector<std::uint64_t>& v, std::uint64_t k) {\n    std::uint64_t total = 0;\n    for (std::size_t i = 0; i < v.size(); i++) {\n        std::uint64_t x = v[i];\n        if (x % 2 == 0) {\n            total += x * k % 1000;\n        } else {\n            total += x % 7;\n        }\n    }\n    Rec${i} r = mk${i}(total, k);\n    std::uint64_t out = r.a % 100000;\n    while (out > 1000) {\n        out = out / 3;\n    }\n    return out + r.b + r.name.size();\n}\n\n`);
    }
    files[`m${p}.hpp`] = hdr.join('');
    files[`m${p}.cpp`] = parts.join('');
  }
  const main = ['#include <cstdint>\n#include <iostream>\n#include <vector>\n'];
  for (let p = 0; p < chunks.length; p++) main.push(`#include "m${p}.hpp"\n`);
  main.push(`\nint main() {\n    const std::vector<std::uint64_t> v{1, 2, 3, 4};\n    std::uint64_t t = ${seed};\n`);
  for (let p = 0; p < chunks.length; p++) {
    for (const i of chunks[p]) main.push(`    t += work${i}(v, ${i});\n`);
  }
  main.push('    std::cout << t << "\\n";\n}\n');
  files['main.cpp'] = main.join('');
  const objs = srcs.map(s => s.replace(/\.cpp$/, '.o')).join(' ');
  const chks = srcs.map(s => s.replace(/\.cpp$/, '.chk')).join(' ');
  files['Makefile'] = `CXX = clang++\nCXXFLAGS = -std=c++20 -O0 -g\nLDFLAGS = -fuse-ld=lld\nOBJS = ${objs}\nCHECKS = ${chks}\n\nmain: $(OBJS)\n\t$(CXX) $(LDFLAGS) -o main $(OBJS)\n\n%.o: %.cpp\n\t$(CXX) $(CXXFLAGS) -c $< -o $@\n\ncheck: $(CHECKS)\n\n%.chk: %.cpp\n\t$(CXX) -std=c++20 -fsyntax-only $< && touch $@\n`;
  const midMod = chunks.length >> 1;
  return { files, editFile: `m${midMod}.cpp`, editTarget: chunks[midMod][0], multi: true };
}

const grailHello = seed => `fn main() {\n    println("hello, world ${seed}");\n}\n`;
const rustHello = seed => `fn main() {\n    println!("hello, world ${seed}");\n}\n`;
const goHello = seed => `package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("hello, world ${seed}")\n}\n`;
const zigHello = seed => `const std = @import("std");\n\npub fn main() !void {\n    try std.io.getStdOut().writer().print("hello, world ${seed}\\n", .{});\n}\n`;
const cHello = seed => `#include <stdio.h>\n\nint main(void) {\n    printf("hello, world ${seed}\\n");\n    return 0;\n}\n`;
const cppHello = seed => `#include <iostream>\n\nint main() {\n    std::cout << "hello, world ${seed}\\n";\n}\n`;

// The one-body edit: the first `% 1000` in work{target} becomes `% 1001`; hello world's string changes.
function editScaling(text, target) {
  const at = text.search(new RegExp(`(fn|func|uint64_t) [wW]ork${target}\\(`));
  if (at < 0) throw new Error(`editScaling: work${target} not found`);
  const k = text.indexOf('% 1000', at);
  if (k < 0) throw new Error(`editScaling: % 1000 not found after work${target}`);
  return text.slice(0, k) + '% 1001' + text.slice(k + 6);
}

const goCache = join(work, 'gocache'), zigCache = join(work, 'zigcache');
const baseEnv = { ...process.env, GOCACHE: goCache, ZIG_GLOBAL_CACHE_DIR: zigCache, CARGO_NET_OFFLINE: 'true' };
const storeTemplate = join(work, 'grail-store-template');
let templateFrom = '';
const passes = {
  single: { jobs: 1, env: { GRAIL_JOBS: '1', GOMAXPROCS: '1', GOFLAGS: '-mod=mod -p=1', CARGO_BUILD_JOBS: '1' } },
  jobs4: { jobs: 4, env: { GRAIL_JOBS: '4', GOMAXPROCS: '4', GOFLAGS: '-mod=mod -p=4', CARGO_BUILD_JOBS: '4' } },
};

const twins = option('--twins', 'hashmap,bintrees,strings,json,dyncall,iterchain,ecs').split(',').filter(Boolean);
const twinText = (lang, name) => lang === 'grail' ? readFileSync(join(root, 'bench', `${name}.grl`), 'utf8')
  : lang === 'c' ? readFileSync(join(root, 'bench', `${name}.c`), 'utf8')
  : lang === 'rust' ? readFileSync(existsSync(join(root, 'bench/rivals', `${name}-rs`)) ? join(root, 'bench/rivals', `${name}-rs/src/main.rs`) : join(root, 'bench/rivals', `${name}.rs`), 'utf8')
  : readFileSync(join(root, 'bench/rivals', `${name}.${lang}`), 'utf8');
const twinEdit = {
  grail: t => t.replace(/^fn main\([^)]*\)[^{]*\{/m, m => `${m}\n    edit_marker := 1;`),
  rust: t => t.replace(/^fn main\(\)[^{]*\{/m, m => `${m}\n    let _edit_marker = 1;`),
  go: t => t.replace(/^func main\(\) \{/m, m => `${m}\n\t_ = 1`),
  zig: t => t.replace(/^pub fn main\(\) !void \{/m, m => `${m}\n    _ = 1;`),
  c: t => t.replace(/^int main\(void\) \{/m, m => `${m}\n    (void)1;`),
  cpp: t => t.replace(/^int main\(\) \{/m, m => `${m}\n    (void)1;`),
};

const languages = {
  grail: {
    file: 'main.grl', comment: '//', scaling: grailScaling, hello: grailHello,
    fresh(dir) { if (existsSync(storeTemplate)) cpSync(storeTemplate, join(dir, 'store'), { recursive: true }); },
    env: dir => ({ GRAIL_CACHE_DIR: join(dir, 'store') }),
    check: (multi) => multi ? ['__grail', 'check'] : ['__grail', 'check', 'main.grl'],
    build: (multi) => multi ? ['__grail', 'build'] : ['__grail', 'build', 'main.grl'],
    exe: (multi) => multi ? 'target/syn' : 'target/main',
  },
  go: {
    file: 'main.go', comment: '//', scaling: goScaling, hello: goHello,
    fresh(dir) { writeFileSync(join(dir, 'go.mod'), 'module syn\n\ngo 1.23\n'); },
    env: () => ({}),
    check: (multi) => ['go', 'vet', multi ? './...' : '.'],
    checkBuild: () => ['go', 'build', '-o', '/dev/null', '.'],
    build: () => ['go', 'build', '-o', 'syn', '.'],
    exe: 'syn',
  },
  zig: {
    file: 'main.zig', comment: '//', scaling: zigScaling, hello: zigHello,
    env: dir => ({ ZIG_LOCAL_CACHE_DIR: join(dir, 'zig-cache') }),
    fresh() {},
    check: () => ['zig', 'build-exe', '-fno-emit-bin', 'main.zig'],
    build: () => ['zig', 'build-exe', '-O', 'Debug', 'main.zig'],
    exe: 'main',
  },
  c: {
    file: 'main.c', comment: '//', scaling: cScaling, hello: cHello,
    fresh(dir, spec) {
      if (!spec.multi) writeFileSync(join(dir, 'Makefile'), 'CC = clang\nCFLAGS = -O0 -g\nLDFLAGS = -fuse-ld=lld\n\nmain: main.c\n\t$(CC) $(CFLAGS) $(LDFLAGS) -o main main.c\n');
    },
    env: () => ({}),
    check: (multi, jobs) => multi ? ['make', '-s', `-j${jobs}`, 'check'] : ['clang', '-fsyntax-only', 'main.c'],
    build: (multi, jobs) => multi ? ['make', '-s', `-j${jobs}`] : ['make', '-s'],
    exe: 'main',
  },
  cpp: {
    file: 'main.cpp', comment: '//', scaling: cppScaling, hello: cppHello,
    fresh(dir, spec) {
      if (!spec.multi) writeFileSync(join(dir, 'Makefile'), 'CXX = clang++\nCXXFLAGS = -std=c++20 -O0 -g\nLDFLAGS = -fuse-ld=lld\n\nmain: main.cpp\n\t$(CXX) $(CXXFLAGS) $(LDFLAGS) -o main main.cpp\n');
    },
    env: () => ({}),
    check: (multi, jobs) => multi ? ['make', '-s', `-j${jobs}`, 'check'] : ['clang++', '-std=c++20', '-fsyntax-only', 'main.cpp'],
    build: (multi, jobs) => multi ? ['make', '-s', `-j${jobs}`] : ['make', '-s'],
    exe: 'main',
  },
  rust: {
    file: 'src/main.rs', comment: '//', scaling: rustScaling, hello: rustHello,
    fresh(dir, spec) {
      mkdirSync(join(dir, 'src'), { recursive: true });
      const text = Object.values(spec.files).join('\n');
      const deps = /serde_json/.test(text) ? '\n[dependencies]\nserde_json = "1"\n' : '';
      if (!spec.multi) writeFileSync(join(dir, 'Cargo.toml'), `[package]\nname = "syn"\nversion = "0.1.0"\nedition = "2021"\n${deps}`);
    },
    env: () => ({}),
    check: () => ['cargo', 'check', '--offline', '-q'],
    build: () => ['cargo', 'build', '--offline', '-q'],
    exe: 'target/debug/syn',
  },
};
const have = toolchains();
for (const lang of ['c', 'cpp', 'go', 'zig', 'rust']) if (!have[lang] || ((lang === 'c' || lang === 'cpp') && spawnSync('make', ['--version']).status !== 0)) delete languages[lang];
const names = Object.keys(languages);
const headOf = { grail: 'Grail', c: 'C', cpp: 'C++', go: 'Go', zig: 'Zig', rust: 'Rust', 'go-build': 'Go (build to /dev/null)' };
let failed = 0;

let serial = 0;
function materialize(lang, spec) {
  const l = languages[lang];
  const dir = join(work, `${lang}-${serial++}`);
  mkdirSync(dir, { recursive: true });
  l.fresh(dir, spec);
  for (const [rel, content] of Object.entries(spec.files)) {
    const full = join(dir, rel);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, content);
  }
  return dir;
}
function applyEdit(dir, rel, content) {
  const full = join(dir, rel);
  writeFileSync(full, content);
  // Advance mtime slightly so make always sees the edit even on filesystems with coarse timestamps.
  const future = new Date(Date.now() + 2000);
  utimesSync(full, future, future);
}
function timed(lang, argv0, dir, pass) {
  const l = languages[lang];
  const argv = argv0.map(a => a === '__grail' ? grail : a);
  return measure(argv, { cwd: dir, env: { ...baseEnv, ...pass.env, ...l.env(dir) } });
}

// Warm the toolchains' own caches once.
for (const lang of names) {
  const spec = { files: { [languages[lang].file]: languages[lang].hello('warm') }, editFile: languages[lang].file, multi: false };
  const dir = materialize(lang, spec);
  if (lang === 'grail') {
    mkdirSync(storeTemplate, { recursive: true });
    const env = { ...baseEnv, GRAIL_CACHE_DIR: storeTemplate };
    const warm = spawnSync(grail, ['cache', 'warm'], { cwd: dir, env, encoding: 'utf8' });
    templateFrom = warm.status === 0 ? 'grail cache warm (every standard module)' : 'a hello-world build';
    run([grail, 'build', 'main.grl'], { cwd: dir, env });
    continue;
  }
  run(languages[lang].check(false, 1), { cwd: dir, env: { ...baseEnv, ...languages[lang].env(dir) } });
  run(languages[lang].build(false, 1), { cwd: dir, env: { ...baseEnv, ...languages[lang].env(dir) } });
  rmSync(dir, { recursive: true, force: true });
}

const programs = [
  {
    label: 'hello', check: true,
    spec: (lang, seed) => ({ files: { [languages[lang].file]: languages[lang].hello(seed) }, editFile: languages[lang].file, multi: false }),
    edit: (_lang, spec) => spec.files[spec.editFile].replace('hello, world', 'hello, edited'),
  },
  ...sizes.map(n => ({
    label: `syn${n}`, check: true,
    spec: (lang, seed) => languages[lang].scaling(n, seed),
    edit: (_lang, spec) => editScaling(spec.files[spec.editFile], spec.editTarget),
  })),
  ...twins.map(name => ({
    label: name, check: false,
    spec: (lang, seed) => ({ files: { [languages[lang].file]: `${languages[lang].comment} seed ${seed}\n${twinText(lang, name)}` }, editFile: languages[lang].file, multi: false }),
    edit: (lang, spec) => {
      const t = spec.files[spec.editFile];
      const e = twinEdit[lang](t);
      if (e === t) throw new Error(`the twin edit found no main in ${name} (${lang})`);
      return e;
    },
  })),
];
const steps = ['check cold', 'check edited', 'build cold', 'build edited'];

const load = [loadavg()];
const results = {};
const keep = (label, step, col, passName, m) => {
  const f = ((results[`${label} ${step}`] ??= {})[col] ??= {});
  if (passName === 'single') { f.instructions = Math.min(f.instructions ?? Infinity, m.instructions / 1e9); f.cpu = Math.min(f.cpu ?? Infinity, m.cpu); }
  else f.wall = Math.min(f.wall ?? Infinity, m.wall);
};
for (const program of programs) {
  for (const [passName, pass] of Object.entries(passes)) {
    for (let r = 0; r < runs; r++) {
      const seed = 1000 + serial;
      const printed = {};
      for (const lang of names) {
        const l = languages[lang];
        const spec = program.spec(lang, seed);
        const edited = program.edit(lang, spec);
        // check: cold, then after the edit
        let dir = materialize(lang, spec);
        keep(program.label, 'check cold', lang, passName, timed(lang, l.check(spec.multi, pass.jobs), dir, pass));
        applyEdit(dir, spec.editFile, edited);
        keep(program.label, 'check edited', lang, passName, timed(lang, l.check(spec.multi, pass.jobs), dir, pass));
        rmSync(dir, { recursive: true, force: true });
        if (l.checkBuild && passName === 'single') {
          const specB = { ...spec, files: { ...spec.files, [spec.editFile]: `${l.comment} b\n${spec.files[spec.editFile]}` } };
          dir = materialize(lang, specB);
          keep(program.label, 'check cold', 'go-build', passName, timed(lang, l.checkBuild(specB.multi, pass.jobs), dir, pass));
          applyEdit(dir, specB.editFile, `${l.comment} b\n${edited}`);
          keep(program.label, 'check edited', 'go-build', passName, timed(lang, l.checkBuild(specB.multi, pass.jobs), dir, pass));
          rmSync(dir, { recursive: true, force: true });
        }
        // build: cold, then after the edit
        dir = materialize(lang, spec);
        keep(program.label, 'build cold', lang, passName, timed(lang, l.build(spec.multi, pass.jobs), dir, pass));
        const exePath = typeof l.exe === 'function' ? l.exe(spec.multi) : l.exe;
        const output = () => program.check ? run([join(dir, exePath)], { cwd: dir }).stdout.trim() : null;
        const coldOut = output();
        applyEdit(dir, spec.editFile, edited);
        keep(program.label, 'build edited', lang, passName, timed(lang, l.build(spec.multi, pass.jobs), dir, pass));
        printed[lang] = [coldOut, output()];
        rmSync(dir, { recursive: true, force: true });
      }
      const differ = names.filter(x => JSON.stringify(printed[x]) !== JSON.stringify(printed.grail));
      if (program.check && differ.length) {
        failed++;
        console.log(`OUTPUT DIFFERS (${program.label}, ${passName}, round ${r}): ${names.map(x => `${x} ${JSON.stringify(printed[x])}`).join('; ')}`);
      }
    }
  }
  for (const step of steps) {
    const f = results[`${program.label} ${step}`];
    const best = Math.min(...names.filter(x => x !== 'grail').map(x => f[x].instructions));
    console.log(`${`${program.label} ${step}`.padEnd(26)} ${names.map(x => `${f[x].instructions.toFixed(2)}G ${f[x].wall.toFixed(2)}s`.padStart(16)).join(' ')}   ${ratio(f.grail.instructions, best).padStart(8)}`);
  }
}
const rows = programs.flatMap(p => steps.map(step => [`${p.label} ${step}`, results[`${p.label} ${step}`]]));
load.push(loadavg());
const v = versions();
console.log(`compile-rivals: instructions in one process (G) and wall time at four jobs (s), best of ${runs}; ratio = Grail's instructions over the fewest of the others`);
console.log(`grail: ${grail}, commit ${measuredGrail.commit}\nload average ${load[0]} at start, ${load[1]} at end; ${Object.values(v).join('; ')}`);
writeFileSync(join(root, '.work/compile-rivals.json'), JSON.stringify({ runs, sizes, twins, modules: MODULES, load, versions: v, grail, commit: measuredGrail.commit, results, at: new Date().toISOString() }, null, 2) + '\n');
if (jsonPath) {
  const table = (id, title, field, chart, note, cols = names, keepRow = () => true) => ({
    id, title, chart, note, threshold: 1, primary: 'grail', direction: 'lower',
    columns: cols.map(key => ({ key, label: headOf[key], grail: key === 'grail' })),
    rows: rows.filter(([name]) => keepRow(name)).map(([name, figures]) => ({ name, unit: { cpu: 's CPU', wall: 's wall', instructions: 'G instructions' }[field], values: Object.fromEntries(cols.map(k => [k, figures[k]?.[field]])) })),
  });
  writeResults(jsonPath, {
    tool: 'compile-rivals', title: 'Compile speed against C, C++, Go, Zig and rustc', commit: measuredGrail.commit, versions: v, load,
    commands: [`bun tools/compile-rivals.mjs --runs ${runs} --sizes ${sizes.join(',')} --twins ${twins.join(',')}`,
      `syn1000 and syn4000 are split across ${MODULES} Grail modules / Go packages / Rust crates / C and C++ translation units so every toolchain gets parallel compilation and incremental module/package/TU edits`,
      `Grail's store before each cold run: ${templateFrom}; Go's GOCACHE holds its standard library, Zig's cache its compiler_rt, and cargo uses the offline registry, so the standard library is warm for every toolchain`,
      'one process: GRAIL_JOBS=1, GOMAXPROCS=1 GOFLAGS=-p=1, make -j1, CARGO_BUILD_JOBS=1; four jobs: the same at 4',
      'Grail: check `grail check`, build `grail build` (grail.toml project with 20 modules under src/)',
      'C/C++: multi-TU Makefile (`clang -O0 -g -fuse-ld=lld`, `clang++ -std=c++20 -O0 -g -fuse-ld=lld`); check runs `-fsyntax-only` per changed TU',
      'Go: check `go vet ./...`, build `go build -o syn .` (20 packages under module `syn`)',
      'Zig: check `zig build-exe -fno-emit-bin main.zig`, build `zig build-exe -O Debug main.zig` (20 imported modules)',
      'Rust: check `cargo check --offline -q`, build `cargo build --offline -q` (20-crate Cargo workspace)',
      'edit: one constant in one function body inside module m10 changes; a twin gets one statement added to main'],
    tables: [
      table('compile', 'Compile speed: instructions, in one process', 'instructions', true, `User-space instructions of the tool and every process it started, every toolchain in one process, fewest of ${runs}. syn1000 and syn4000 are split across ${MODULES} modules/packages/TUs. The bar: the fastest of the others.`),
      table('compile-wall', 'Compile speed: wall time at four jobs', 'wall', true, `Wall time with four jobs for every toolchain (this host's cap), best of ${runs}; the load is beside it.`),
      table('compile-cpu', 'The same builds in one process, CPU time', 'cpu', false, `CPU time, best of ${runs}; inflated by the load.`),
      table('compile-go-check', "Go's two checks: go vet against a build whose output is thrown away", 'instructions', false, 'go vet type-checks and then runs its analyses; go build -o /dev/null is the compiler without the link.', ['grail', 'go', 'go-build'], name => name.includes('check')),
    ],
  });
}
if (failed) process.exit(1);
