// Compile speed against Go, Zig and Rust (docs/design/compile-speed.md, "Against other languages").
// The same programs in each language - hello world and the scaling trio of tools/compile-bench.mjs
// (N copies of a record, its constructor and a 15-line loop function, and a main calling each) at
// N = 1000 and 4000 - timed four ways:
//   check, cold     grail check | cargo check | go build -o /dev/null (Go has no check: `go vet`
//                   runs analyses, not the type checker's verdict, so the check is a build whose
//                   output is thrown away) | zig build-exe -fno-emit-bin
//   check, edited   the same after one function body changed (one constant in work{N/2})
//   build, cold     grail build (the build store) | cargo build (the dev profile) | go build |
//                   zig build-exe -O Debug
//   build, edited   the same after the one-body edit
// "Cold" is a project's first build on a machine whose toolchain caches are warm: every cold run has
// new source text (a seed in main) and empty project caches (a new target/ for cargo, a new Grail
// build store filled only with what a hello-world build put there - the runtime, platform and core
// objects, which a toolchain ships precompiled in the other languages), while Go keeps its compiled
// standard library in GOCACHE and Zig its compiler_rt in its global cache. "Edited" reuses what the
// cold build left: cargo's incremental state, Grail's store, Go's and Zig's caches.
// The figure is CPU seconds (user + sys of the tool and every process it waited for), best of N;
// wall seconds are in the JSON (.work/compile-rivals.json). Ratios are Grail over the fastest rival.
//   bun tools/compile-rivals.mjs [--runs N] [--sizes 1000,4000] [--compiler PATH | --branch REF]
//   --compiler names the Grail compiler, --branch REF builds REF's release compiler
//   (tools/rivals/common.mjs); default GRAIL_COMPILER, else this tree's release compiler (`bun
//   tools/native.mjs release`), the one a user runs, as `compile-bench --release` measures.
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { root } from './platforms.mjs';
import { scalingProgram } from './compile-bench.mjs';
import { compilerOptions, grailCompiler, loadavg, measurer, ratio, run, toolchains, versions } from './rivals/common.mjs';

const argv = process.argv.slice(2);
const chosen = compilerOptions(argv);
const option = (name, fallback) => { const at = argv.indexOf(name); return at < 0 ? fallback : argv[at + 1]; };
const runs = Number(option('--runs', 3));
const sizes = option('--sizes', '1000,4000').split(',').map(Number);
const work = join(root, '.work/compile-rivals');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const measure = measurer(root, work);
const measuredGrail = !chosen.compiler && !chosen.branch && process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER)
  ? grailCompiler(root, { compiler: process.env.GRAIL_COMPILER })
  : grailCompiler(root, { ...chosen, release: true });
const grail = measuredGrail.compiler;

// ---- the programs. Each takes a seed (main's starting total) so every cold run is new text.
const grailProgram = (n, seed) => scalingProgram(n).replace('    mut t = 0;\n', `    mut t = ${seed};\n`);
const grailHello = seed => `fn main() {\n    println("hello, world ${seed}");\n}\n`;

function rustProgram(n, seed) {
  const parts = [];
  for (let i = 0; i < n; i++) parts.push(`struct Rec${i} {
    a: u64,
    b: u64,
    name: String,
}
fn mk${i}(a: u64, b: u64) -> Rec${i} {
    Rec${i} { a: a, b: b, name: "r${i}".to_string() }
}
fn work${i}(v: &[u64], k: u64) -> u64 {
    let mut total: u64 = 0;
    for i in 0..v.len() {
        let x = v[i];
        if x % 2 == 0 {
            total = total.wrapping_add(x * k % 1000);
        } else {
            total = total.wrapping_add(x % 7);
        }
    }
    let r = mk${i}(total, k);
    let mut out = r.a % 100000;
    while out > 1000 {
        out = out / 3;
    }
    out + r.b + r.name.len() as u64
}
`);
  parts.push(`fn main() {\n    let v: Vec<u64> = vec![1, 2, 3, 4];\n    let mut t: u64 = ${seed};\n`);
  for (let i = 0; i < n; i++) parts.push(`    t = t.wrapping_add(work${i}(&v, ${i}));\n`);
  parts.push('    println!("{}", t);\n}\n');
  return parts.join('');
}
const rustHello = seed => `fn main() {\n    println!("hello, world ${seed}");\n}\n`;

function goProgram(n, seed) {
  const parts = ['package main\n\nimport "fmt"\n\n'];
  for (let i = 0; i < n; i++) parts.push(`type Rec${i} struct {
	a    uint64
	b    uint64
	name string
}

func mk${i}(a uint64, b uint64) Rec${i} {
	return Rec${i}{a: a, b: b, name: "r${i}"}
}

func work${i}(v []uint64, k uint64) uint64 {
	var total uint64
	for i := 0; i < len(v); i++ {
		x := v[i]
		if x%2 == 0 {
			total += x * k % 1000
		} else {
			total += x % 7
		}
	}
	r := mk${i}(total, k)
	out := r.a % 100000
	for out > 1000 {
		out = out / 3
	}
	return out + r.b + uint64(len(r.name))
}

`);
  parts.push(`func main() {\n\tv := []uint64{1, 2, 3, 4}\n\tvar t uint64 = ${seed}\n`);
  for (let i = 0; i < n; i++) parts.push(`\tt += work${i}(v, ${i})\n`);
  parts.push('\tfmt.Println(t)\n}\n');
  return parts.join('');
}
const goHello = seed => `package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("hello, world ${seed}")\n}\n`;

function zigProgram(n, seed) {
  const parts = ['const std = @import("std");\n\n'];
  for (let i = 0; i < n; i++) parts.push(`const Rec${i} = struct {
    a: u64,
    b: u64,
    name: []const u8,
};
fn mk${i}(a: u64, b: u64) Rec${i} {
    return Rec${i}{ .a = a, .b = b, .name = "r${i}" };
}
fn work${i}(v: []const u64, k: u64) u64 {
    var total: u64 = 0;
    for (0..v.len) |i| {
        const x = v[i];
        if (x % 2 == 0) {
            total +%= x * k % 1000;
        } else {
            total +%= x % 7;
        }
    }
    const r = mk${i}(total, k);
    var out = r.a % 100000;
    while (out > 1000) {
        out = out / 3;
    }
    return out + r.b + r.name.len;
}
`);
  parts.push(`pub fn main() !void {\n    const v = [_]u64{ 1, 2, 3, 4 };\n    var t: u64 = ${seed};\n`);
  for (let i = 0; i < n; i++) parts.push(`    t +%= work${i}(&v, ${i});\n`);
  parts.push('    try std.io.getStdOut().writer().print("{d}\\n", .{t});\n}\n');
  return parts.join('');
}
const zigHello = seed => `const std = @import("std");\n\npub fn main() !void {\n    try std.io.getStdOut().writer().print("hello, world ${seed}\\n", .{});\n}\n`;

// The one-body edit: the first `% 1000` in work{N/2} becomes `% 1001`; hello world's string changes.
function edit(text, n) {
  if (!n) return text.replace('hello, world', 'hello, edited');
  const at = text.search(new RegExp(`(fn|func) work${n >> 1}\\(`));
  const k = text.indexOf('% 1000', at);
  return text.slice(0, k) + '% 1001' + text.slice(k + 6);
}

const goCache = join(work, 'gocache'), zigCache = join(work, 'zigcache');
const baseEnv = { ...process.env, GOCACHE: goCache, GOFLAGS: '-mod=mod', ZIG_GLOBAL_CACHE_DIR: zigCache, CARGO_NET_OFFLINE: 'true', GRAIL_JOBS: process.env.GRAIL_JOBS };
if (!baseEnv.GRAIL_JOBS) delete baseEnv.GRAIL_JOBS;
const storeTemplate = join(work, 'grail-store-template');

// Each language: how to lay out a project, and the four commands.
const languages = {
  grail: {
    file: 'main.grl', program: grailProgram, hello: grailHello,
    fresh(dir) { if (existsSync(storeTemplate)) cpSync(storeTemplate, join(dir, 'store'), { recursive: true }); },
    env: dir => ({ GRAIL_CACHE_DIR: join(dir, 'store') }),
    check: ['__grail', 'check', 'main.grl'], build: ['__grail', 'build', 'main.grl'],
  },
  go: {
    file: 'main.go', program: goProgram, hello: goHello,
    fresh(dir) { writeFileSync(join(dir, 'go.mod'), 'module syn\n\ngo 1.23\n'); },
    env: () => ({}),
    check: ['go', 'build', '-o', '/dev/null', '.'], build: ['go', 'build', '-o', 'syn', '.'],
  },
  zig: {
    file: 'main.zig', program: zigProgram, hello: zigHello,
    fresh() {},
    env: dir => ({ ZIG_LOCAL_CACHE_DIR: join(dir, 'zig-cache') }),
    check: ['zig', 'build-exe', '-fno-emit-bin', 'main.zig'], build: ['zig', 'build-exe', '-O', 'Debug', 'main.zig'],
  },
  rust: {
    file: 'src/main.rs', program: rustProgram, hello: rustHello,
    fresh(dir) { mkdirSync(join(dir, 'src'), { recursive: true }); writeFileSync(join(dir, 'Cargo.toml'), '[package]\nname = "syn"\nversion = "0.1.0"\nedition = "2021"\n'); },
    env: () => ({}),
    check: ['cargo', 'check', '--offline', '-q'], build: ['cargo', 'build', '--offline', '-q'],
  },
};
// The built program, run after each build: every language must print the same number, and a build
// whose program prints something else fails the tool (the one way it fails; ratios never do).
languages.grail.exe = 'target/main'; languages.go.exe = 'syn'; languages.zig.exe = 'main'; languages.rust.exe = 'target/debug/syn';
// A language whose toolchain is absent is left out, and toolchains() says so.
const have = toolchains();
for (const lang of ['go', 'zig', 'rust']) if (!have[lang]) delete languages[lang];
const names = Object.keys(languages);
const headOf = { grail: 'Grail', go: 'Go', zig: 'Zig', rust: 'Rust' };
let failed = 0;

let serial = 0;
function project(lang, text) {
  const l = languages[lang];
  const dir = join(work, `${lang}-${serial++}`);
  mkdirSync(dir, { recursive: true });
  l.fresh(dir);
  writeFileSync(join(dir, l.file), text);
  return dir;
}
function timed(lang, which, dir) {
  const l = languages[lang];
  const argv = l[which].map(a => a === '__grail' ? grail : a);
  return measure(argv, { cwd: dir, env: { ...baseEnv, ...l.env(dir) } });
}

// Warm the toolchains' own caches once: Go's standard library, Zig's compiler_rt, Grail's runtime
// and core objects (kept as the template every cold Grail store starts from).
for (const lang of names) {
  const dir = project(lang, languages[lang].hello('warm'));
  if (lang === 'grail') { mkdirSync(storeTemplate, { recursive: true }); run([grail, 'build', 'main.grl'], { cwd: dir, env: { ...baseEnv, GRAIL_CACHE_DIR: storeTemplate } }); continue; }
  run(languages[lang].build, { cwd: dir, env: { ...baseEnv, ...languages[lang].env(dir) } });
  rmSync(dir, { recursive: true, force: true });
}

const load = [loadavg()];
const rows = [];
const results = {};
for (const n of [0, ...sizes]) {
  const label = n ? `syn${n}` : 'hello';
  for (const which of ['check', 'build']) {
    const cold = {}, edited = {};
    for (const lang of names) {
      cold[lang] = { cpu: Infinity, wall: Infinity }; edited[lang] = { cpu: Infinity, wall: Infinity };
    }
    for (let r = 0; r < runs; r++) {
      // One seed per round, the same in every language (so every program prints the same number),
      // new in every round (so every cold run is new text).
      const seed = 1000 + serial;
      const printed = {};
      for (const lang of names) {
        const l = languages[lang];
        const text = n ? l.program(n, seed) : l.hello(seed);
        const dir = project(lang, text);
        const a = timed(lang, which, dir);
        const output = () => which === 'build' ? run([join(dir, l.exe)], { cwd: dir }).stdout.trim() : null;
        const coldOut = output();
        writeFileSync(join(dir, l.file), edit(text, n));
        const b = timed(lang, which, dir);
        if (which === 'build') printed[lang] = [coldOut, output()];
        for (const [slot, m] of [[cold, a], [edited, b]]) {
          slot[lang].cpu = Math.min(slot[lang].cpu, m.cpu);
          slot[lang].wall = Math.min(slot[lang].wall, m.wall);
        }
        rmSync(dir, { recursive: true, force: true });
      }
      const differ = names.filter(x => JSON.stringify(printed[x]) !== JSON.stringify(printed.grail));
      if (which === 'build' && differ.length) {
        failed++;
        console.log(`OUTPUT DIFFERS (${label}, round ${r}): ${names.map(x => `${x} ${JSON.stringify(printed[x])}`).join('; ')}`);
      }
    }
    rows.push([`${label} ${which}, cold`, cold], [`${label} ${which}, edited`, edited]);
    results[`${label} ${which} cold`] = cold;
    results[`${label} ${which} edited`] = edited;
    const show = ([name, figures]) => {
      const rivals = Math.min(...names.filter(x => x !== 'grail').map(x => figures[x].cpu));
      console.log(`${name.padEnd(24)} ${names.map(x => `${figures[x].cpu.toFixed(3)} (${figures[x].wall.toFixed(2)})`.padStart(16)).join(' ')}   ${ratio(figures.grail.cpu, rivals).padStart(8)}`);
    };
    if (rows.length === 2) console.log(`compile-rivals: CPU s (wall s), best of ${runs}; ratio = Grail CPU / fastest rival's CPU\n${'program, step'.padEnd(24)} ${names.map(x => headOf[x].padStart(16)).join(' ')}   Grail/best`);
    show(rows[rows.length - 2]); show(rows[rows.length - 1]);
  }
}
load.push(loadavg());
const v = versions();
console.log(`grail: ${grail}, commit ${measuredGrail.commit}\nload average ${load[0]} at start, ${load[1]} at end; ${Object.values(v).join('; ')}`);
writeFileSync(join(root, '.work/compile-rivals.json'), JSON.stringify({ runs, sizes, load, versions: v, grail, commit: measuredGrail.commit, results, at: new Date().toISOString() }, null, 2) + '\n');
// One line the gate's summary picks up: Grail over the fastest rival, the large program's four steps.
const big = `syn${sizes[sizes.length - 1]}`;
console.log(`compile-rivals (${measuredGrail.commit}): Grail/fastest ${['check cold', 'check edited', 'build cold', 'build edited'].map(step => { const f = results[`${big} ${step}`]; return `${big} ${step} ${ratio(f.grail.cpu, Math.min(...names.filter(x => x !== 'grail').map(x => f[x].cpu)))}`; }).join(', ')}`);
if (failed) process.exit(1);
