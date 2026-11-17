// Compile speed against Go, Zig and rustc (docs/design/compile-speed.md, "Against Go, Zig and rustc";
// the book's Performance chapter). The same programs in all four languages - hello world, the scaling
// trio of tools/compile-bench.mjs (N copies of a record, its constructor and a 15-line loop
// function, and a main calling each) at each --sizes, and the rival twins of bench/ - each measured
// five ways:
//   check cold      grail check | go vet (it type-checks, then runs its analyses; go build -o /dev/null
//                   is measured beside it) | zig build-exe -fno-emit-bin | cargo check
//   check edited    the same after one function body changed
//   build cold      grail build (the build store) | go build | zig build-exe -O Debug | cargo build
//   build edited    the same after the edit
//   build no-op     the same again with nothing changed
// "Cold" is a project's first build on a machine whose toolchain caches are warm: new source text
// (a seed) and empty project caches - a new target/ for cargo, a Grail store holding only what a
// hello-world build put there (the runtime, platform and core objects the other toolchains ship
// precompiled) - while Go keeps its standard library in GOCACHE and Zig its compiler_rt. The edit
// changes one constant in one function body of a generated program, and adds one statement to a
// twin's main.
// Two passes: every toolchain in one process (GRAIL_JOBS=1, GOMAXPROCS=1 -p=1, cargo -j1) for the
// user-space instructions of the tool and every process it started - the primary figure, which load
// does not move - and every toolchain at four jobs for wall time. Best of --runs (default 2).
// Ratios are Grail over the fastest of the others. It fails only when a generated program's output
// differs between the languages.
//   bun tools/compile-rivals.mjs [--runs N] [--sizes 1000,4000] [--twins a,b] [--compiler PATH | --branch REF] [--json PATH]
//   --compiler names the Grail compiler, --branch REF builds REF's release compiler
//   (tools/rivals/common.mjs); default GRAIL_COMPILER, else this tree's release compiler (`bun
//   tools/native.mjs release`), the one a user runs.
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { root } from './platforms.mjs';
import { scalingProgram } from './compile-bench.mjs';
import { compilerOptions, grailCompiler, jsonOption, loadavg, measurer, ratio, run, toolchains, versions, writeResults } from './rivals/common.mjs';

const argv = process.argv.slice(2);
const chosen = compilerOptions(argv);
const jsonPath = jsonOption(argv);
const option = (name, fallback) => { const at = argv.indexOf(name); return at < 0 ? fallback : argv[at + 1]; };
const runs = Number(option('--runs', 2));
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
const baseEnv = { ...process.env, GOCACHE: goCache, ZIG_GLOBAL_CACHE_DIR: zigCache, CARGO_NET_OFFLINE: 'true' };
const storeTemplate = join(work, 'grail-store-template');
// Two passes over everything. `single`: every toolchain in one process - GRAIL_JOBS=1, GOMAXPROCS=1
// with -p=1, cargo with one job (Zig's build-exe has no job flag; its count includes its threads) -
// for the instruction counts, the primary figure. `jobs4`: four jobs each, the load cap of this host,
// for wall time.
const passes = {
  single: { GRAIL_JOBS: '1', GOMAXPROCS: '1', GOFLAGS: '-mod=mod -p=1', CARGO_BUILD_JOBS: '1' },
  jobs4: { GRAIL_JOBS: '4', GOMAXPROCS: '4', GOFLAGS: '-mod=mod -p=4', CARGO_BUILD_JOBS: '4' },
};

// The rival twins (bench/NAME.grl and bench/rivals/NAME.{rs,go,zig}, or NAME-rs/ for a crate): real
// programs of a few hundred lines, beside the generated ones.
const twins = option('--twins', 'hashmap,bintrees,strings,json,dyncall,iterchain,ecs').split(',').filter(Boolean);
const twinText = (lang, name) => lang === 'grail' ? readFileSync(join(root, 'bench', `${name}.grl`), 'utf8')
  : lang === 'rust' ? readFileSync(existsSync(join(root, 'bench/rivals', `${name}-rs`)) ? join(root, 'bench/rivals', `${name}-rs/src/main.rs`) : join(root, 'bench/rivals', `${name}.rs`), 'utf8')
  : readFileSync(join(root, 'bench/rivals', `${name}.${lang}`), 'utf8');
// A twin's one-function edit: a statement added at the top of `main`.
const twinEdit = {
  grail: t => t.replace(/^fn main\([^)]*\)[^{]*\{/m, m => `${m}\n    edit_marker := 1;`),
  rust: t => t.replace(/^fn main\(\)[^{]*\{/m, m => `${m}\n    let _edit_marker = 1;`),
  go: t => t.replace(/^func main\(\) \{/m, m => `${m}\n\t_ = 1`),
  zig: t => t.replace(/^pub fn main\(\) !void \{/m, m => `${m}\n    _ = 1;`),
};

// Each language: how to lay out a project, and the commands.
const languages = {
  grail: {
    file: 'main.grl', comment: '//', program: grailProgram, hello: grailHello,
    fresh(dir) { if (existsSync(storeTemplate)) cpSync(storeTemplate, join(dir, 'store'), { recursive: true }); },
    env: dir => ({ GRAIL_CACHE_DIR: join(dir, 'store') }),
    check: ['__grail', 'check', 'main.grl'], build: ['__grail', 'build', 'main.grl'], exe: 'target/main',
  },
  go: {
    file: 'main.go', comment: '//', program: goProgram, hello: goHello,
    fresh(dir) { writeFileSync(join(dir, 'go.mod'), 'module syn\n\ngo 1.23\n'); },
    env: () => ({}),
    // `go vet` type-checks the package and then runs its analyses; `go build -o /dev/null` (the
    // compiler's verdict without the link) is measured beside it, in a table of its own.
    check: ['go', 'vet', '.'], checkBuild: ['go', 'build', '-o', '/dev/null', '.'], build: ['go', 'build', '-o', 'syn', '.'], exe: 'syn',
  },
  zig: {
    file: 'main.zig', comment: '//', program: zigProgram, hello: zigHello,
    fresh() {},
    env: dir => ({ ZIG_LOCAL_CACHE_DIR: join(dir, 'zig-cache') }),
    check: ['zig', 'build-exe', '-fno-emit-bin', 'main.zig'], build: ['zig', 'build-exe', '-O', 'Debug', 'main.zig'], exe: 'main',
  },
  rust: {
    file: 'src/main.rs', comment: '//', program: rustProgram, hello: rustHello,
    fresh(dir, text) {
      mkdirSync(join(dir, 'src'), { recursive: true });
      const deps = /serde_json/.test(text ?? '') ? '\n[dependencies]\nserde_json = "1"\n' : '';
      writeFileSync(join(dir, 'Cargo.toml'), `[package]\nname = "syn"\nversion = "0.1.0"\nedition = "2021"\n${deps}`);
    },
    env: () => ({}),
    check: ['cargo', 'check', '--offline', '-q'], build: ['cargo', 'build', '--offline', '-q'], exe: 'target/debug/syn',
  },
};
// A language whose toolchain is absent is left out, and toolchains() says so.
const have = toolchains();
for (const lang of ['go', 'zig', 'rust']) if (!have[lang]) delete languages[lang];
const names = Object.keys(languages);
const headOf = { grail: 'Grail', go: 'Go', zig: 'Zig', rust: 'Rust', 'go-build': 'Go (build to /dev/null)' };
let failed = 0;

let serial = 0;
function project(lang, text) {
  const l = languages[lang];
  const dir = join(work, `${lang}-${serial++}`);
  mkdirSync(dir, { recursive: true });
  l.fresh(dir, text);
  mkdirSync(dirname(join(dir, l.file)), { recursive: true });
  writeFileSync(join(dir, l.file), text);
  return dir;
}
function timed(lang, argv0, dir, passEnv) {
  const l = languages[lang];
  const argv = argv0.map(a => a === '__grail' ? grail : a);
  return measure(argv, { cwd: dir, env: { ...baseEnv, ...passEnv, ...l.env(dir) } });
}

// Warm the toolchains' own caches once: Go's standard library, Zig's compiler_rt, Grail's runtime
// and core objects (kept as the template every cold Grail store starts from), cargo's view of the
// offline registry.
for (const lang of names) {
  const dir = project(lang, languages[lang].hello('warm'));
  if (lang === 'grail') { mkdirSync(storeTemplate, { recursive: true }); run([grail, 'build', 'main.grl'], { cwd: dir, env: { ...baseEnv, GRAIL_CACHE_DIR: storeTemplate } }); continue; }
  run(languages[lang].build, { cwd: dir, env: { ...baseEnv, ...languages[lang].env(dir) } });
  rmSync(dir, { recursive: true, force: true });
}

// The programs: hello world, the scaling trio at each size, and the twins.
const programs = [
  { label: 'hello', text: (lang, seed) => languages[lang].hello(seed), edit: (lang, t) => edit(t, 0), check: true },
  ...sizes.map(n => ({ label: `syn${n}`, text: (lang, seed) => languages[lang].program(n, seed), edit: (lang, t) => edit(t, n), check: true })),
  // A twin's text is fixed, so a seed comment makes each cold build new text (Go's cache is keyed by
  // content); its output is checked by bench-rivals, not here.
  ...twins.map(name => ({ label: name, text: (lang, seed) => `${languages[lang].comment} seed ${seed}\n${twinText(lang, name)}`, edit: (lang, t) => twinEdit[lang](t), check: false })),
];
const steps = ['check cold', 'check edited', 'build cold', 'build edited', 'build no-op'];

const load = [loadavg()];
const results = {}; // `${label} ${step}` -> column -> { instructions, cpu, wall }
const keep = (label, step, col, pass, m) => {
  const f = ((results[`${label} ${step}`] ??= {})[col] ??= {});
  if (pass === 'single') { f.instructions = Math.min(f.instructions ?? Infinity, m.instructions / 1e9); f.cpu = Math.min(f.cpu ?? Infinity, m.cpu); }
  else f.wall = Math.min(f.wall ?? Infinity, m.wall);
};
for (const program of programs) {
  for (const [pass, passEnv] of Object.entries(passes)) {
    for (let r = 0; r < runs; r++) {
      const seed = 1000 + serial;
      const printed = {};
      for (const lang of names) {
        const l = languages[lang];
        const text = program.text(lang, seed);
        // check: cold, then after the edit
        let dir = project(lang, text);
        keep(program.label, 'check cold', lang, pass, timed(lang, l.check, dir, passEnv));
        writeFileSync(join(dir, l.file), program.edit(lang, text));
        keep(program.label, 'check edited', lang, pass, timed(lang, l.check, dir, passEnv));
        rmSync(dir, { recursive: true, force: true });
        if (l.checkBuild && pass === 'single') {
          dir = project(lang, `${l.comment} b\n${text}`);
          keep(program.label, 'check cold', 'go-build', pass, timed(lang, l.checkBuild, dir, passEnv));
          writeFileSync(join(dir, l.file), program.edit(lang, `${l.comment} b\n${text}`));
          keep(program.label, 'check edited', 'go-build', pass, timed(lang, l.checkBuild, dir, passEnv));
          rmSync(dir, { recursive: true, force: true });
        }
        // build: cold, after the edit, and again with nothing changed
        dir = project(lang, text);
        keep(program.label, 'build cold', lang, pass, timed(lang, l.build, dir, passEnv));
        const output = () => program.check ? run([join(dir, l.exe)], { cwd: dir }).stdout.trim() : null;
        const coldOut = output();
        writeFileSync(join(dir, l.file), program.edit(lang, text));
        keep(program.label, 'build edited', lang, pass, timed(lang, l.build, dir, passEnv));
        keep(program.label, 'build no-op', lang, pass, timed(lang, l.build, dir, passEnv));
        printed[lang] = [coldOut, output()];
        rmSync(dir, { recursive: true, force: true });
      }
      const differ = names.filter(x => JSON.stringify(printed[x]) !== JSON.stringify(printed.grail));
      if (program.check && differ.length) {
        failed++;
        console.log(`OUTPUT DIFFERS (${program.label}, ${pass}, round ${r}): ${names.map(x => `${x} ${JSON.stringify(printed[x])}`).join('; ')}`);
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
console.log(`compile-rivals: instructions in one process (G) and wall time at four jobs (s), best of ${runs}; ratio = Grail's instructions over the fewest of Go, Zig and Rust`);
console.log(`grail: ${grail}, commit ${measuredGrail.commit}\nload average ${load[0]} at start, ${load[1]} at end; ${Object.values(v).join('; ')}`);
writeFileSync(join(root, '.work/compile-rivals.json'), JSON.stringify({ runs, sizes, twins, load, versions: v, grail, commit: measuredGrail.commit, results, at: new Date().toISOString() }, null, 2) + '\n');
if (jsonPath) {
  const table = (id, title, field, chart, note, cols = names, keepRow = () => true) => ({
    id, title, chart, note, threshold: 1, primary: 'grail', direction: 'lower',
    columns: cols.map(key => ({ key, label: headOf[key], grail: key === 'grail' })),
    rows: rows.filter(([name]) => keepRow(name)).map(([name, figures]) => ({ name, unit: { cpu: 's CPU', wall: 's wall', instructions: 'G instructions' }[field], values: Object.fromEntries(cols.map(k => [k, figures[k]?.[field]])) })),
  });
  writeResults(jsonPath, {
    tool: 'compile-rivals', title: 'Compile speed against Go, Zig and rustc', commit: measuredGrail.commit, versions: v, load,
    commands: [`bun tools/compile-rivals.mjs --runs ${runs} --sizes ${sizes.join(',')} --twins ${twins.join(',')}`,
      'one process: GRAIL_JOBS=1, GOMAXPROCS=1 GOFLAGS=-p=1, CARGO_BUILD_JOBS=1; four jobs: the same at 4',
      ...names.map(n => `${headOf[n]}: check \`${languages[n].check.join(' ').replace('__grail', 'grail')}\`, build \`${languages[n].build.join(' ').replace('__grail', 'grail')}\``),
      'edit: the generated programs change one constant in one function body; a twin gets one statement added to main'],
    tables: [
      table('compile', 'Compile speed: instructions, in one process', 'instructions', true, `User-space instructions of the tool and every process it started, every toolchain in one process, fewest of ${runs}. The bar: the fastest of Go, Zig and rustc.`),
      table('compile-wall', 'Compile speed: wall time at four jobs', 'wall', true, `Wall time with four jobs for every toolchain (this host's cap), best of ${runs}; the load is beside it.`),
      table('compile-cpu', 'The same builds in one process, CPU time', 'cpu', false, `CPU time, best of ${runs}; inflated by the load.`),
      table('compile-go-check', "Go's two checks: go vet against a build whose output is thrown away", 'instructions', false, 'go vet type-checks and then runs its analyses; go build -o /dev/null is the compiler without the link.', ['grail', 'go', 'go-build'], name => name.includes('check')),
    ],
  });
}
// One line the gate's summary picks up: Grail over the fastest rival, the large program's steps.
const big = `syn${sizes[sizes.length - 1]}`;
console.log(`compile-rivals (${measuredGrail.commit}): Grail/fastest instructions ${steps.map(step => { const f = results[`${big} ${step}`]; return `${big} ${step} ${ratio(f.grail.instructions, Math.min(...names.filter(x => x !== 'grail').map(x => f[x].instructions)))}`; }).join(', ')}`);
if (failed) process.exit(1);
