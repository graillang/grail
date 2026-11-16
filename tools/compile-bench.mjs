// Compile-speed benchmark (docs/design/compile-speed.md). Times the compiler, not the programs it
// builds: `grail check` on a synthetic program at three sizes (the scaling trio), hello world
// `build` and `check`, the compiler compiling itself, and a generic-heavy program. Each figure is
// the best of three runs, because the host is usually shared. Results go to
// .work/compile-bench.json and a table to stdout. A report, not a threshold: nothing here fails on
// a slow number, only on a compile that does not succeed.
//   bun tools/compile-bench.mjs           full: N=250/1000/4000, hello, self-compile, generics
//   bun tools/compile-bench.mjs --quick   routine: N=250/1000 and hello
//   GRAIL_COMPILER selects the compiler (default: build the tree's)
//   GRAIL_BENCH_RUNS overrides the number of runs per figure (default 3)
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { buildCompiler, buildReleaseCompiler, compilerSources, root } from './native.mjs';

// The scaling program: N copies of {record, constructor, 15-line loop fn} and a main calling each.
// Linear work per copy, so a compiler whose time grows faster than N is doing something per pair.
export function scalingProgram(n) {
  const parts = [];
  for (let i = 0; i < n; i++) {
    parts.push(`struct Rec${i} {
    a: u64,
    b: u64,
    name: string
}
fn mk${i}(a: u64, b: u64) -> Rec${i} {
    return Rec${i} { a: a, b: b, name: "r${i}" };
}
fn work${i}(v: &u64[], k: u64) -> u64 {
    mut total = 0;
    for i in v.len() {
        x := v[i];
        if x % 2 == 0 {
            total = wrapping_add(total, x * k % 1000);
        } else {
            total = wrapping_add(total, x % 7);
        }
    }
    r := mk${i}(total, k);
    mut out = r.a % 100000;
    while out > 1000 {
        out = out / 3;
    }
    return out + r.b + r.name.len();
}
`);
  }
  parts.push('fn main() {\n    v := u64[1, 2, 3, 4];\n    mut t = 0;\n');
  for (let i = 0; i < n; i++) parts.push(`    t = wrapping_add(t, work${i}(&v, ${i}));\n`);
  parts.push('    println(t);\n}\n');
  return parts.join('');
}

// Many generic functions, each instantiated at many types: instantiation and its lookups.
export function genericProgram(functions = 100, types = 20) {
  const parts = [];
  for (let k = 0; k < types; k++) parts.push(`struct P${k} {\n    v: u64\n}\n`);
  for (let j = 0; j < functions; j++) {
    parts.push(`fn g${j}<T>(x: T, n: u64) -> T {
    mut i = 0;
    mut acc = 0;
    while i < n {
        acc = wrapping_add(acc, i * ${j + 1});
        i += 1;
    }
    if acc == 7 {
        println(acc);
    }
    return x;
}
`);
  }
  parts.push('fn main() {\n    mut t = 0;\n');
  for (let j = 0; j < functions; j++) {
    for (let k = 0; k < types; k++) parts.push(`    t = wrapping_add(t, g${j}(P${k} { v: ${k} }, 3).v);\n`);
  }
  parts.push('    println(t);\n}\n');
  return parts.join('');
}

const hello = 'fn main() {\n    println("hello, world");\n}\n';

function timed(argv, cwd) {
  const start = process.hrtime.bigint();
  const result = spawnSync(argv[0], argv.slice(1), { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout: 1_800_000 });
  const seconds = Number(process.hrtime.bigint() - start) / 1e9;
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${argv.join(' ')} failed (${result.signal ?? result.status})\n${result.stdout}${result.stderr}`);
  return seconds;
}

function best(argv, cwd, runs) {
  let time = Infinity;
  for (let i = 0; i < runs; i++) time = Math.min(time, timed(argv, cwd));
  return Math.round(time * 1000) / 1000;
}

if (import.meta.main ?? process.argv[1] === new URL(import.meta.url).pathname) {
  const quick = process.argv.includes('--quick');
  const runs = Number(process.env.GRAIL_BENCH_RUNS ?? 3);
  // `--release` measures the compiler as it ships (tools/native.mjs, buildReleaseCompiler): the same
  // sources through the LLVM backend. Without it the natively built compiler is measured - the one
  // the tests run - or the one GRAIL_COMPILER names, which is how the gate passes its own.
  const release = process.argv.includes('--release');
  const compiler = release
    ? buildReleaseCompiler({ log: line => console.error(line) })
    : process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER) ? resolve(process.env.GRAIL_COMPILER) : buildCompiler();
  const work = join(root, '.work/compile-bench');
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  const results = { compiler, build: release ? 'release' : 'native', mode: quick ? 'quick' : 'full', runs, best_of: runs, scaling: {}, at: new Date().toISOString() };
  const report = (name, seconds, lines) => console.log(`${name.padEnd(28)} ${seconds.toFixed(3).padStart(9)} s${lines ? `  (${lines} lines)` : ''}`);

  for (const n of quick ? [250, 1000] : [250, 1000, 4000]) {
    const file = join(work, `syn${n}.grl`);
    const text = scalingProgram(n);
    writeFileSync(file, text);
    const seconds = best([compiler, 'check', file], work, runs);
    results.scaling[n] = { seconds, lines: text.split('\n').length - 1 };
    report(`check syn${n}`, seconds, results.scaling[n].lines);
  }
  const s = results.scaling;
  results.exponent_250_1000 = Math.round(Math.log(s[1000].seconds / s[250].seconds) / Math.log(4) * 100) / 100;
  if (s[4000]) {
    results.ratio_4000_1000 = Math.round(s[4000].seconds / s[1000].seconds * 100) / 100;
    results.exponent = Math.round(Math.log(s[4000].seconds / s[1000].seconds) / Math.log(4) * 100) / 100;
  }

  const helloFile = join(work, 'hello.grl');
  writeFileSync(helloFile, hello);
  results.hello_check = best([compiler, 'check', helloFile], work, runs);
  report('check hello', results.hello_check);
  // `build` goes through the build store by default (stage 2). Three figures, each in a store of
  // its own so nothing outside this run is measured: a first build that finds the store empty, a
  // rebuild after an edit, and the first build of *another* project, which is what the shared
  // runtime and standard-library objects are for. `--no-cache` is the whole-program build.
  const store = join(work, 'store');
  const stored = { ...process.env, GRAIL_CACHE_DIR: store };
  const timedIn = (argv, cwd) => {
    const start = process.hrtime.bigint();
    const result = spawnSync(argv[0], argv.slice(1), { cwd, encoding: 'utf8', env: stored, timeout: 1_800_000 });
    if (result.status !== 0) throw new Error(`${argv.join(' ')} failed\n${result.stdout}${result.stderr}`);
    return Number(process.hrtime.bigint() - start) / 1e9;
  };
  let cold = Infinity, edit = Infinity, other = Infinity;
  for (let i = 0; i < runs; i++) {
    rmSync(store, { recursive: true, force: true });
    const a = join(work, 'project-a'), b = join(work, 'project-b');
    for (const d of [a, b]) { rmSync(d, { recursive: true, force: true }); mkdirSync(d, { recursive: true }); }
    writeFileSync(join(a, 'hello.grl'), hello);
    cold = Math.min(cold, timedIn([compiler, 'build', 'hello.grl'], a));
    writeFileSync(join(a, 'hello.grl'), hello.replace('hello, world', `hello, edit ${i}`));
    edit = Math.min(edit, timedIn([compiler, 'build', 'hello.grl'], a));
    writeFileSync(join(b, 'hello.grl'), hello.replace('hello, world', `another project ${i}`));
    other = Math.min(other, timedIn([compiler, 'build', 'hello.grl'], b));
  }
  const round = t => Math.round(t * 1000) / 1000;
  results.hello_build_empty_store = round(cold);
  results.hello_build_after_edit = round(edit);
  results.hello_build_new_project = round(other);
  report('build hello, empty store', results.hello_build_empty_store);
  report('build hello, after an edit', results.hello_build_after_edit);
  report('build hello, new project', results.hello_build_new_project);
  results.hello_build = best([compiler, 'build', helloFile, '--no-cache'], work, runs);
  report('build hello --no-cache', results.hello_build);

  if (!quick) {
    const genericFile = join(work, 'generic.grl');
    const text = genericProgram();
    writeFileSync(genericFile, text);
    results.generic_check = best([compiler, 'check', genericFile], work, runs);
    report('check generic (100x20)', results.generic_check, text.split('\n').length - 1);
    // The compiler compiling its own sources to assembly, as tools/test-selfhost.mjs does.
    results.self_compile = best([compiler, join(work, 'self.s'), ...compilerSources], root, runs);
    report('self-compile', results.self_compile);
  }
  if (results.exponent !== undefined) console.log(`scaling exponent log(t4000/t1000)/log 4 = ${results.exponent} (t4000/t1000 = ${results.ratio_4000_1000})`);
  console.log(`scaling exponent log(t1000/t250)/log 4 = ${results.exponent_250_1000}   (best of ${runs})`);
  writeFileSync(join(root, release ? '.work/compile-bench-release.json' : '.work/compile-bench.json'), JSON.stringify(results, null, 2) + '\n');
  console.log(`compile-bench${release ? ' (release compiler)' : ''}: check hello ${results.hello_check} s, build hello after an edit ${results.hello_build_after_edit} s, t1000 ${s[1000].seconds} s${results.ratio_4000_1000 ? `, t4000/t1000 ${results.ratio_4000_1000}` : ''}${results.self_compile ? `, self-compile ${results.self_compile} s` : ''}`);
}
