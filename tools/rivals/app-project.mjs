// Realistic 3-layer, 20-unit generic/trait/collection/optional project generator for
// tools/compile-rivals.mjs (`app2000`: 4 foundation + 8 domain + 8 service modules/packages/crates/
// TUs + main). Every language uses its idiomatic generics, interfaces/traits, Option/optional,
// map/vector containers and closures, and produces the exact same checksum both cold and after a
// mid-layer edit in `mid4`.

export function appDistribution(n) {
  // 4 foundation (base0..3), 8 domain (mid0..7), 8 service (top0..7) = 20 units.
  // Split N functions evenly across the 8 domain + 8 service units (16 units).
  const mid = Array.from({ length: 8 }, () => []);
  const top = Array.from({ length: 8 }, () => []);
  const half = Math.max(8, Math.floor(n / 2));
  for (let i = 0; i < half; i++) mid[i % 8].push(i);
  for (let i = 0; i < n - half; i++) top[i % 8].push(i);
  return { mid, top };
}

export function grailApp(n, seed) {
  const { mid, top } = appDistribution(n);
  const files = {};
  for (let b = 0; b < 4; b++) {
    files[`src/base${b}.grl`] = `module base${b};

pub interface Score${b} {
    fn score(&self) -> u64;
}

pub struct Pair${b}<A, B> {
    first: A,
    second: B,
}

pub fn make_pair${b}<A, B>(a: A, b: B) -> Pair${b}<A, B> {
    Pair${b} { first: a, second: b }
}

pub fn checked_step${b}(a: u64, b: u64) -> u64? {
    if (a + b) % 13 == 0 {
        return None;
    }
    Some((a * 3 + b + ${b + 1}) % 100000)
}

pub fn combine${b}<T: Score${b}>(x: &T, bias: u64) -> u64 {
    s := x.score();
    match checked_step${b}(s, bias) {
        Some(v) => v,
        None => s % 997,
    }
}
`;
  }
  for (let m = 0; m < 8; m++) {
    const b0 = m % 4, b1 = (m + 1) % 4;
    const parts = [`module mid${m};\nuse base${b0};\nuse base${b1};\nuse hashmap;\n\n`];
    for (const i of mid[m]) {
      parts.push(`pub struct Item${i} { id: u64, weight: u64 }\nimpl base${b0}::Score${b0} for Item${i} {\n    fn score(&self) -> u64 { (self.id * 7 + self.weight * 3) % 10000 }\n}\npub fn domain${i}(k: u64) -> u64 {\n    it := Item${i} { id: k + ${i}, weight: (k * 5 + ${i + 1}) % 1000 };\n    p := base${b1}::make_pair${b1}(it.id, it.weight);\n    mut acc = base${b0}::combine${b0}(&it, p.second);\n    if k % 3 == 0 {\n        mut tbl = [u64: u64]::with_seed(1, 2);\n        tbl[k] = acc;\n        tbl[k + 1] = p.first;\n        if let Some(v) = tbl.get(&k) { acc = acc + *v % 1000; }\n    }\n    acc + p.first % 97\n}\n\n`);
    }
    files[`src/mid${m}.grl`] = parts.join('');
  }
  for (let t = 0; t < 8; t++) {
    const m0 = t, m1 = (t + 1) % 8, b0 = t % 4;
    const parts = [`module top${t};\nuse base${b0};\nuse mid${m0};\nuse mid${m1};\n\n`];
    for (let idx = 0; idx < top[t].length; idx++) {
      const i = top[t][idx];
      const d0 = mid[m0][idx % mid[m0].length];
      const d1 = mid[m1][idx % mid[m1].length];
      parts.push(`pub fn service${i}(seed: u64) -> u64 {\n    a := mid${m0}::domain${d0}(seed + ${i});\n    b := mid${m1}::domain${d1}(seed + ${i + 1});\n    p := base${b0}::make_pair${b0}(a, b);\n    match base${b0}::checked_step${b0}(p.first, p.second) {\n        Some(v) => v + (a % 31),\n        None => (a + b) % 997,\n    }\n}\n\n`);
    }
    files[`src/top${t}.grl`] = parts.join('');
  }
  const main = [];
  for (let t = 0; t < 8; t++) main.push(`use top${t};\n`);
  main.push(`\nfn main() {\n    mut total: u64 = ${seed};\n`);
  for (let t = 0; t < 8; t++) {
    for (const i of top[t]) main.push(`    total = wrapping_add(total, top${t}::service${i}(${i + 1}));\n`);
  }
  main.push(`    println(total);\n}\n`);
  files['src/main.grl'] = main.join('');
  files['grail.toml'] = `[package]\nname = "syn"\nversion = "0.1.0"\n`;
  return { files, editFile: 'src/mid4.grl', editTarget: mid[4][0], multi: true, kind: 'app' };
}

export function rustApp(n, seed) {
  const { mid, top } = appDistribution(n);
  const files = {};
  const members = [];
  for (let b = 0; b < 4; b++) {
    members.push(`"crates/base${b}"`);
    files[`crates/base${b}/Cargo.toml`] = `[package]\nname = "base${b}"\nversion = "0.1.0"\nedition = "2021"\n`;
    files[`crates/base${b}/src/lib.rs`] = `pub trait Score${b} {
    fn score(&self) -> u64;
}

pub struct Pair${b}<A, B> {
    pub first: A,
    pub second: B,
}

pub fn make_pair${b}<A, B>(a: A, b: B) -> Pair${b}<A, B> {
    Pair${b} { first: a, second: b }
}

pub fn checked_step${b}(a: u64, b: u64) -> Option<u64> {
    if (a + b) % 13 == 0 {
        return None;
    }
    Some((a * 3 + b + ${b + 1}) % 100000)
}

pub fn combine${b}<T: Score${b}>(x: &T, bias: u64) -> u64 {
    let s = x.score();
    match checked_step${b}(s, bias) {
        Some(v) => v,
        None => s % 997,
    }
}
`;
  }
  for (let m = 0; m < 8; m++) {
    const b0 = m % 4, b1 = (m + 1) % 4;
    members.push(`"crates/mid${m}"`);
    files[`crates/mid${m}/Cargo.toml`] = `[package]\nname = "mid${m}"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\nbase${b0} = { path = "../base${b0}" }\nbase${b1} = { path = "../base${b1}" }\n`;
    const parts = [`use std::collections::HashMap;\nuse base${b0}::{Score${b0}, combine${b0}};\nuse base${b1}::make_pair${b1};\n\n`];
    for (const i of mid[m]) {
      parts.push(`pub struct Item${i} { pub id: u64, pub weight: u64 }\nimpl Score${b0} for Item${i} {\n    fn score(&self) -> u64 { (self.id * 7 + self.weight * 3) % 10000 }\n}\npub fn domain${i}(k: u64) -> u64 {\n    let it = Item${i} { id: k + ${i}, weight: (k * 5 + ${i + 1}) % 1000 };\n    let p = make_pair${b1}(it.id, it.weight);\n    let mut acc = combine${b0}(&it, p.second);\n    if k % 3 == 0 {\n        let mut tbl = HashMap::new();\n        tbl.insert(k, acc);\n        tbl.insert(k + 1, p.first);\n        if let Some(&v) = tbl.get(&k) {\n            acc = acc + v % 1000;\n        }\n    }\n    acc + p.first % 97\n}\n`);
    }
    files[`crates/mid${m}/src/lib.rs`] = parts.join('');
  }
  const topDeps = [];
  for (let t = 0; t < 8; t++) {
    const m0 = t, m1 = (t + 1) % 8, b0 = t % 4;
    members.push(`"crates/top${t}"`);
    topDeps.push(`top${t} = { path = "crates/top${t}" }`);
    files[`crates/top${t}/Cargo.toml`] = `[package]\nname = "top${t}"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\nbase${b0} = { path = "../base${b0}" }\nmid${m0} = { path = "../mid${m0}" }\nmid${m1} = { path = "../mid${m1}" }\n`;
    const parts = [`use base${b0}::{checked_step${b0}, make_pair${b0}};\n\n`];
    for (let idx = 0; idx < top[t].length; idx++) {
      const i = top[t][idx];
      const d0 = mid[m0][idx % mid[m0].length];
      const d1 = mid[m1][idx % mid[m1].length];
      parts.push(`pub fn service${i}(seed: u64) -> u64 {\n    let a = mid${m0}::domain${d0}(seed + ${i});\n    let b = mid${m1}::domain${d1}(seed + ${i + 1});\n    let p = make_pair${b0}(a, b);\n    match checked_step${b0}(p.first, p.second) {\n        Some(v) => v + (a % 31),\n        None => (a + b) % 997,\n    }\n}\n`);
    }
    files[`crates/top${t}/src/lib.rs`] = parts.join('');
  }
  const main = [`fn main() {\n    let mut total: u64 = ${seed};\n`];
  for (let t = 0; t < 8; t++) {
    for (const i of top[t]) main.push(`    total = total.wrapping_add(top${t}::service${i}(${i + 1}));\n`);
  }
  main.push(`    println!("{}", total);\n}\n`);
  files['src/main.rs'] = main.join('');
  files['Cargo.toml'] = `[workspace]\nmembers = [${members.join(', ')}]\n\n[package]\nname = "syn"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\n${topDeps.join('\n')}\n`;
  return { files, editFile: 'crates/mid4/src/lib.rs', editTarget: mid[4][0], multi: true, kind: 'app' };
}

export function goApp(n, seed) {
  const { mid, top } = appDistribution(n);
  const files = {};
  for (let b = 0; b < 4; b++) {
    files[`base${b}/base${b}.go`] = `package base${b}

type Score${b} interface {
	Score() uint64
}

type Pair${b}[A, B any] struct {
	First  A
	Second B
}

func MakePair${b}[A, B any](a A, b B) Pair${b}[A, B] {
	return Pair${b}[A, B]{First: a, Second: b}
}

func CheckedStep${b}(a, b uint64) (uint64, bool) {
	if (a+b)%13 == 0 {
		return 0, false
	}
	return (a*3 + b + ${b + 1}) % 100000, true
}

func Combine${b}[T Score${b}](x T, bias uint64) uint64 {
	s := x.Score()
	if v, ok := CheckedStep${b}(s, bias); ok {
		return v
	}
	return s % 997
}
`;
  }
  for (let m = 0; m < 8; m++) {
    const b0 = m % 4, b1 = (m + 1) % 4;
    const parts = [`package mid${m}\n\nimport (\n\t"syn/base${b0}"\n\t"syn/base${b1}"\n)\n\n`];
    for (const i of mid[m]) {
      parts.push(`type Item${i} struct { ID, Weight uint64 }\nfunc (x Item${i}) Score() uint64 { return (x.ID*7 + x.Weight*3) % 10000 }\nfunc Domain${i}(k uint64) uint64 {\n\tit := Item${i}{ID: k + ${i}, Weight: (k*5 + ${i + 1}) % 1000}\n\tp := base${b1}.MakePair${b1}(it.ID, it.Weight)\n\tacc := base${b0}.Combine${b0}(it, p.Second)\n\tif k%3 == 0 {\n\t\ttbl := make(map[uint64]uint64)\n\t\ttbl[k] = acc\n\t\ttbl[k+1] = p.First\n\t\tif v, ok := tbl[k]; ok {\n\t\t\tacc = acc + v%1000\n\t\t}\n\t}\n\treturn acc + p.First%97\n}\n\n`);
    }
    files[`mid${m}/mid${m}.go`] = parts.join('');
  }
  for (let t = 0; t < 8; t++) {
    const m0 = t, m1 = (t + 1) % 8, b0 = t % 4;
    const parts = [`package top${t}\n\nimport (\n\t"syn/base${b0}"\n\t"syn/mid${m0}"\n\t"syn/mid${m1}"\n)\n\n`];
    for (let idx = 0; idx < top[t].length; idx++) {
      const i = top[t][idx];
      const d0 = mid[m0][idx % mid[m0].length];
      const d1 = mid[m1][idx % mid[m1].length];
      parts.push(`func Service${i}(seed uint64) uint64 {\n\ta := mid${m0}.Domain${d0}(seed + ${i})\n\tb := mid${m1}.Domain${d1}(seed + ${i + 1})\n\tp := base${b0}.MakePair${b0}(a, b)\n\tif v, ok := base${b0}.CheckedStep${b0}(p.First, p.Second); ok {\n\t\treturn v + (a % 31)\n\t}\n\treturn (a + b) % 997\n}\n\n`);
    }
    files[`top${t}/top${t}.go`] = parts.join('');
  }
  const main = [`package main\n\nimport (\n\t"fmt"\n`];
  for (let t = 0; t < 8; t++) main.push(`\t"syn/top${t}"\n`);
  main.push(`)\n\nfunc main() {\n\tvar total uint64 = ${seed}\n`);
  for (let t = 0; t < 8; t++) {
    for (const i of top[t]) main.push(`\ttotal += top${t}.Service${i}(${i + 1})\n`);
  }
  main.push(`\tfmt.Println(total)\n}\n`);
  files['main.go'] = main.join('');
  return { files, editFile: 'mid4/mid4.go', editTarget: mid[4][0], multi: true, kind: 'app' };
}

export function zigApp(n, seed) {
  const { mid, top } = appDistribution(n);
  const files = {};
  for (let b = 0; b < 4; b++) {
    files[`base${b}.zig`] = `pub fn Pair${b}(comptime A: type, comptime B: type) type {
    return struct { first: A, second: B };
}

pub fn makePair${b}(comptime A: type, comptime B: type, a: A, b: B) Pair${b}(A, B) {
    return .{ .first = a, .second = b };
}

pub fn checkedStep${b}(a: u64, b: u64) ?u64 {
    if ((a + b) % 13 == 0) return null;
    return (a * 3 + b + ${b + 1}) % 100000;
}

pub fn combine${b}(x: anytype, bias: u64) u64 {
    const s = x.score();
    return checkedStep${b}(s, bias) orelse (s % 997);
}
`;
  }
  for (let m = 0; m < 8; m++) {
    const b0 = m % 4, b1 = (m + 1) % 4;
    const parts = [`const std = @import("std");\nconst base${b0} = @import("base${b0}.zig");\nconst base${b1} = @import("base${b1}.zig");\n\n`];
    for (const i of mid[m]) {
      parts.push(`pub const Item${i} = struct {\n    id: u64,\n    weight: u64,\n    pub fn score(self: Item${i}) u64 { return (self.id * 7 + self.weight * 3) % 10000; }\n};\npub fn domain${i}(k: u64) u64 {\n    const it = Item${i}{ .id = k + ${i}, .weight = (k * 5 + ${i + 1}) % 1000 };\n    const p = base${b1}.makePair${b1}(u64, u64, it.id, it.weight);\n    var acc = base${b0}.combine${b0}(it, p.second);\n    if (k % 3 == 0) {\n        var tbl = std.AutoHashMap(u64, u64).init(std.heap.page_allocator);\n        defer tbl.deinit();\n        tbl.put(k, acc) catch unreachable;\n        tbl.put(k + 1, p.first) catch unreachable;\n        if (tbl.get(k)) |v| acc += v % 1000;\n    }\n    return acc + p.first % 97;\n}\n`);
    }
    files[`mid${m}.zig`] = parts.join('');
  }
  for (let t = 0; t < 8; t++) {
    const m0 = t, m1 = (t + 1) % 8, b0 = t % 4;
    const parts = [`const base${b0} = @import("base${b0}.zig");\nconst mid${m0} = @import("mid${m0}.zig");\nconst mid${m1} = @import("mid${m1}.zig");\n\n`];
    for (let idx = 0; idx < top[t].length; idx++) {
      const i = top[t][idx];
      const d0 = mid[m0][idx % mid[m0].length];
      const d1 = mid[m1][idx % mid[m1].length];
      parts.push(`pub fn service${i}(seed: u64) u64 {\n    const a = mid${m0}.domain${d0}(seed + ${i});\n    const b = mid${m1}.domain${d1}(seed + ${i + 1});\n    const p = base${b0}.makePair${b0}(u64, u64, a, b);\n    if (base${b0}.checkedStep${b0}(p.first, p.second)) |v| return v + (a % 31);\n    return (a + b) % 997;\n}\n`);
    }
    files[`top${t}.zig`] = parts.join('');
  }
  const main = [`const std = @import("std");\n`];
  for (let t = 0; t < 8; t++) main.push(`const top${t} = @import("top${t}.zig");\n`);
  main.push(`\npub fn main() !void {\n    var total: u64 = ${seed};\n`);
  for (let t = 0; t < 8; t++) {
    for (const i of top[t]) main.push(`    total +%= top${t}.service${i}(${i + 1});\n`);
  }
  main.push(`    try std.io.getStdOut().writer().print("{d}\\n", .{total});\n}\n`);
  files['main.zig'] = main.join('');
  return { files, editFile: 'mid4.zig', editTarget: mid[4][0], multi: true, kind: 'app' };
}

export function cppApp(n, seed) {
  const { mid, top } = appDistribution(n);
  const files = {};
  const srcs = ['main.cpp'];
  for (let b = 0; b < 4; b++) {
    srcs.push(`base${b}.cpp`);
    files[`base${b}.hpp`] = `#pragma once
#include <cstdint>
#include <optional>

template<typename A, typename B>
struct Pair${b} { A first; B second; };

template<typename A, typename B>
inline Pair${b}<A, B> make_pair${b}(A a, B b) { return Pair${b}<A, B>{a, b}; }

std::optional<std::uint64_t> checked_step${b}(std::uint64_t a, std::uint64_t b);

template<typename T>
inline std::uint64_t combine${b}(const T& x, std::uint64_t bias) {
    std::uint64_t s = x.score();
    if (auto v = checked_step${b}(s, bias)) return *v;
    return s % 997;
}
`;
    files[`base${b}.cpp`] = `#include "base${b}.hpp"
std::optional<std::uint64_t> checked_step${b}(std::uint64_t a, std::uint64_t b) {
    if ((a + b) % 13 == 0) return std::nullopt;
    return (a * 3 + b + ${b + 1}) % 100000;
}
`;
  }
  for (let m = 0; m < 8; m++) {
    const b0 = m % 4, b1 = (m + 1) % 4;
    srcs.push(`mid${m}.cpp`);
    const hdr = [`#pragma once\n#include <cstdint>\n\n`];
    const parts = [`#include "mid${m}.hpp"\n#include "base${b0}.hpp"\n#include "base${b1}.hpp"\n#include <unordered_map>\n\n`];
    for (const i of mid[m]) {
      hdr.push(`std::uint64_t domain${i}(std::uint64_t k);\n`);
      parts.push(`struct Item${i} { std::uint64_t id, weight; std::uint64_t score() const { return (id * 7 + weight * 3) % 10000; } };\nstd::uint64_t domain${i}(std::uint64_t k) {\n    Item${i} it{k + ${i}, (k * 5 + ${i + 1}) % 1000};\n    auto p = make_pair${b1}(it.id, it.weight);\n    std::uint64_t acc = combine${b0}(it, p.second);\n    if (k % 3 == 0) {\n        std::unordered_map<std::uint64_t, std::uint64_t> tbl;\n        tbl[k] = acc;\n        tbl[k + 1] = p.first;\n        auto found = tbl.find(k);\n        if (found != tbl.end()) acc += found->second % 1000;\n    }\n    return acc + p.first % 97;\n}\n`);
    }
    files[`mid${m}.hpp`] = hdr.join('');
    files[`mid${m}.cpp`] = parts.join('');
  }
  for (let t = 0; t < 8; t++) {
    const m0 = t, m1 = (t + 1) % 8, b0 = t % 4;
    srcs.push(`top${t}.cpp`);
    const hdr = [`#pragma once\n#include <cstdint>\n\n`];
    const parts = [`#include "top${t}.hpp"\n#include "base${b0}.hpp"\n#include "mid${m0}.hpp"\n#include "mid${m1}.hpp"\n\n`];
    for (let idx = 0; idx < top[t].length; idx++) {
      const i = top[t][idx];
      const d0 = mid[m0][idx % mid[m0].length];
      const d1 = mid[m1][idx % mid[m1].length];
      hdr.push(`std::uint64_t service${i}(std::uint64_t seed);\n`);
      parts.push(`std::uint64_t service${i}(std::uint64_t seed) {\n    auto a = domain${d0}(seed + ${i});\n    auto b = domain${d1}(seed + ${i + 1});\n    auto p = make_pair${b0}(a, b);\n    if (auto v = checked_step${b0}(p.first, p.second)) return *v + (a % 31);\n    return (a + b) % 997;\n}\n`);
    }
    files[`top${t}.hpp`] = hdr.join('');
    files[`top${t}.cpp`] = parts.join('');
  }
  const main = [`#include <cstdint>\n#include <iostream>\n`];
  for (let t = 0; t < 8; t++) main.push(`#include "top${t}.hpp"\n`);
  main.push(`\nint main() {\n    std::uint64_t total = ${seed};\n`);
  for (let t = 0; t < 8; t++) {
    for (const i of top[t]) main.push(`    total += service${i}(${i + 1});\n`);
  }
  main.push(`    std::cout << total << "\\n";\n}\n`);
  files['main.cpp'] = main.join('');
  const objs = srcs.map(s => s.replace(/\.cpp$/, '.o')).join(' ');
  const chks = srcs.map(s => s.replace(/\.cpp$/, '.chk')).join(' ');
  files['Makefile'] = `CXX = clang++\nCXXFLAGS = -std=c++20 -O0 -g\nLDFLAGS = -fuse-ld=lld\nOBJS = ${objs}\nCHECKS = ${chks}\n\nmain: $(OBJS)\n\t$(CXX) $(LDFLAGS) -o main $(OBJS)\n\n%.o: %.cpp\n\t$(CXX) $(CXXFLAGS) -c $< -o $@\n\ncheck: $(CHECKS)\n\n%.chk: %.cpp\n\t$(CXX) -std=c++20 -fsyntax-only $< && touch $@\n`;
  return { files, editFile: 'mid4.cpp', editTarget: mid[4][0], multi: true, kind: 'app' };
}

export function cApp(n, seed) {
  const { mid, top } = appDistribution(n);
  const files = {};
  const srcs = ['main.c'];
  for (let b = 0; b < 4; b++) {
    srcs.push(`base${b}.c`);
    files[`base${b}.h`] = `#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct { uint64_t first, second; } pair${b}_t;
typedef struct { uint64_t k, v; bool used; } tbl_slot${b}_t;
static inline pair${b}_t make_pair${b}(uint64_t a, uint64_t b) { return (pair${b}_t){ a, b }; }
bool checked_step${b}(uint64_t a, uint64_t b, uint64_t *out);
uint64_t combine${b}(const void *x, uint64_t (*score_fn)(const void *), uint64_t bias);
`;
    files[`base${b}.c`] = `#include "base${b}.h"
bool checked_step${b}(uint64_t a, uint64_t b, uint64_t *out) {
    if ((a + b) % 13 == 0) return false;
    *out = (a * 3 + b + ${b + 1}) % 100000;
    return true;
}
uint64_t combine${b}(const void *x, uint64_t (*score_fn)(const void *), uint64_t bias) {
    uint64_t s = score_fn(x), v = 0;
    return checked_step${b}(s, bias, &v) ? v : (s % 997);
}
`;
  }
  for (let m = 0; m < 8; m++) {
    const b0 = m % 4, b1 = (m + 1) % 4;
    srcs.push(`mid${m}.c`);
    const hdr = [`#pragma once\n#include <stdint.h>\n\n`];
    const parts = [`#include "mid${m}.h"\n#include "base${b0}.h"\n#include "base${b1}.h"\n#include <string.h>\n\n`];
    for (const i of mid[m]) {
      hdr.push(`uint64_t domain${i}(uint64_t k);\n`);
      parts.push(`struct item${i} { uint64_t id, weight; };\nstatic uint64_t score_${i}(const void *p) { const struct item${i} *x = p; return (x->id * 7 + x->weight * 3) % 10000; }\nuint64_t domain${i}(uint64_t k) {\n    struct item${i} it = { k + ${i}, (k * 5 + ${i + 1}) % 1000 };\n    pair${b1}_t p = make_pair${b1}(it.id, it.weight);\n    uint64_t acc = combine${b0}(&it, score_${i}, p.second);\n    if (k % 3 == 0) {\n        tbl_slot${b0}_t tbl[8];\n        memset(tbl, 0, sizeof(tbl));\n        uint64_t h0 = k & 7;\n        tbl[h0] = (tbl_slot${b0}_t){ k, acc, true };\n        uint64_t h1 = (k + 1) & 7;\n        tbl[h1] = (tbl_slot${b0}_t){ k + 1, p.first, true };\n        if (tbl[h0].used && tbl[h0].k == k) acc += tbl[h0].v % 1000;\n    }\n    return acc + p.first % 97;\n}\n`);
    }
    files[`mid${m}.h`] = hdr.join('');
    files[`mid${m}.c`] = parts.join('');
  }
  for (let t = 0; t < 8; t++) {
    const m0 = t, m1 = (t + 1) % 8, b0 = t % 4;
    srcs.push(`top${t}.c`);
    const hdr = [`#pragma once\n#include <stdint.h>\n\n`];
    const parts = [`#include "top${t}.h"\n#include "base${b0}.h"\n#include "mid${m0}.h"\n#include "mid${m1}.h"\n\n`];
    for (let idx = 0; idx < top[t].length; idx++) {
      const i = top[t][idx];
      const d0 = mid[m0][idx % mid[m0].length];
      const d1 = mid[m1][idx % mid[m1].length];
      hdr.push(`uint64_t service${i}(uint64_t seed);\n`);
      parts.push(`uint64_t service${i}(uint64_t seed) {\n    uint64_t a = domain${d0}(seed + ${i});\n    uint64_t b = domain${d1}(seed + ${i + 1});\n    pair${b0}_t p = make_pair${b0}(a, b);\n    uint64_t v = 0;\n    if (checked_step${b0}(p.first, p.second, &v)) return v + (a % 31);\n    return (a + b) % 997;\n}\n`);
    }
    files[`top${t}.h`] = hdr.join('');
    files[`top${t}.c`] = parts.join('');
  }
  const main = [`#include <inttypes.h>\n#include <stdint.h>\n#include <stdio.h>\n`];
  for (let t = 0; t < 8; t++) main.push(`#include "top${t}.h"\n`);
  main.push(`\nint main(void) {\n    uint64_t total = ${seed};\n`);
  for (let t = 0; t < 8; t++) {
    for (const i of top[t]) main.push(`    total += service${i}(${i + 1});\n`);
  }
  main.push(`    printf("%" PRIu64 "\\n", total);\n    return 0;\n}\n`);
  files['main.c'] = main.join('');
  const objs = srcs.map(s => s.replace(/\.c$/, '.o')).join(' ');
  const chks = srcs.map(s => s.replace(/\.c$/, '.chk')).join(' ');
  files['Makefile'] = `CC = clang\nCFLAGS = -O0 -g\nLDFLAGS = -fuse-ld=lld\nOBJS = ${objs}\nCHECKS = ${chks}\n\nmain: $(OBJS)\n\t$(CC) $(LDFLAGS) -o main $(OBJS)\n\n%.o: %.c\n\t$(CC) $(CFLAGS) -c $< -o $@\n\ncheck: $(CHECKS)\n\n%.chk: %.c\n\t$(CC) -fsyntax-only $< && touch $@\n`;
  return { files, editFile: 'mid4.c', editTarget: mid[4][0], multi: true, kind: 'app' };
}

export function editApp(text, target) {
  const at = text.search(new RegExp(`(fn|func|uint64_t) [dD]omain${target}\\(`));
  if (at < 0) throw new Error(`editApp: domain${target} not found`);
  const k = text.indexOf('% 1000', at);
  if (k < 0) throw new Error(`editApp: % 1000 not found after domain${target}`);
  return text.slice(0, k) + '% 1001' + text.slice(k + 6);
}
