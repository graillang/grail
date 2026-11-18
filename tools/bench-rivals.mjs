// Run time against other languages (docs/design/runtime-parity.md, "Against other languages").
// Every bench/NAME.grl with a C twin also has C++, Rust, Go and Zig twins in bench/rivals/ (same
// algorithm, same output, idiomatic, not hand-vectorised). Each is built the way its users build:
//   Grail-native  the native backend, overflow checked            (the development build)
//   Grail-LLVM    --backend=llvm, clang -O2, --overflow=wrap      (the release build)
//   C -O2         clang -O2 -ffp-contract=off [+ the twin's bench-cflags line]
//   C++ -O2       clang++ -std=c++20 -O2 -ffp-contract=off [+ the twin's bench-cflags line; -pthread
//                 when it includes <thread>], from bench/rivals/NAME.cpp when there is one: a
//                 program without a C++ twin has no C++ figure, and the charts say so
//   Rust release  rustc --edition 2021 -C opt-level=3   (= cargo --release: opt-level 3, no debug
//                 assertions, no overflow checks; one crate, so codegen units do not matter)
//   Go            go build                              (Go has one build; -gcflags='-N -l' is a
//                 debugger's build, not what Go users ship or test with, so it is not used)
//   Zig RF        zig build-exe -O ReleaseFast -mcpu=baseline
//   Rust dev      rustc --edition 2021 -C opt-level=0 -g (= cargo's dev profile: debug assertions and
//                 overflow checks on)
//   Zig Debug     zig build-exe -O Debug -mcpu=baseline
// Every column targets baseline x86-64 (SSE2), as clang, rustc, Go (GOAMD64=v1) and Grail do by
// default; Zig defaults to the host CPU, so it is told not to. A second block builds C, Rust, Go and
// Zig for this CPU (clang -march=native, rustc -C target-cpu=native, GOAMD64=v3, zig -mcpu=native)
// and sets Grail-LLVM, still baseline, against the best of them: what the native-CPU option is worth.
// Every program's output is checked against C's (floats to 12 significant digits). The figure is
// CPU time (user + sys from getrusage, every thread), best of N runs interleaved round by round, so
// a loaded host is not what is measured; instructions are recorded beside it in the JSON.
// Each Grail column is also given as a ratio to the best competitor of its bar: Grail-LLVM against
// the fastest of C, C++, Rust release, Go and Zig ReleaseFast; Grail-native against the fastest of Go,
// Rust dev and Zig Debug.
//   bun tools/bench-rivals.mjs [--runs N] [--metric cpu|instructions] [--compiler PATH | --branch REF] [NAME...]
//   --compiler names the Grail compiler; --branch REF builds REF's (tools/rivals/common.mjs) and
//   takes the runtime and libraries from REF's tree, the programs from this one, so the twins stay
//   the same. Default: GRAIL_COMPILER, else this tree's. The tables name the commit measured. ffi_call is this tree's
//   when it has bench/ffi_call.grl; otherwise it is measured when
//   GRAIL_SCHED_TREE names a checkout of a branch that has bench/ffi_call.grl (with its compiler
//   built, `bun tools/native.mjs build` there, or named by GRAIL_SCHED_COMPILER); its figure is the
//   program's own per-call time.
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync, cpSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { root } from './platforms.mjs';
import { compileProgram } from './native.mjs';
import { compilerOptions, grailCompiler, jsonOption, loadavg, measurer, ratio, run, toolchains, versions, writeResults } from './rivals/common.mjs';

const argv = process.argv.slice(2);
const option = (name, fallback) => { const at = argv.indexOf(name); if (at < 0) return fallback; const v = argv[at + 1]; argv.splice(at, 2); return v; };
// Best of 7 by default: on a shared machine a best of 3 still let one quiet round decide a figure.
const runs = Number(option('--runs', 7));
const chosen = compilerOptions(argv);
const jsonPath = jsonOption(argv);
const metric = option('--metric', 'cpu'); // cpu | instructions | wall
// --workers 1,4,8: a parallel program is run once per count, with every runtime told that many
// threads (GRAIL_WORKERS, RAYON_NUM_THREADS, OMP_NUM_THREADS, GOMAXPROCS, ZIG_THREADS, CPP_THREADS); its rows are
// `NAME xW`. Wall time is the figure such a run is about (--metric wall).
const workerCounts = option('--workers', '').split(',').filter(Boolean).map(Number);
const threadEnv = w => w ? { GRAIL_WORKERS: String(w), RAYON_NUM_THREADS: String(w), OMP_NUM_THREADS: String(w), GOMAXPROCS: String(w), ZIG_THREADS: String(w), CPP_THREADS: String(w) } : {};
const work = join(root, '.work/bench-rivals');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const env = { ...process.env, GOCACHE: join(work, 'gocache'), ZIG_GLOBAL_CACHE_DIR: join(work, 'zigcache'), ZIG_LOCAL_CACHE_DIR: join(work, 'zigcache') };
const measure = measurer(root, work);
const measuredGrail = grailCompiler(root, chosen);
const grailOf = dir => {
  if (dir === root) return measuredGrail.compiler;
  if (dir !== root && process.env.GRAIL_SCHED_COMPILER && existsSync(process.env.GRAIL_SCHED_COMPILER)) return resolve(process.env.GRAIL_SCHED_COMPILER);
  return run(['bun', join(dir, 'tools/native.mjs'), 'build'], { cwd: dir }).stdout.trim().split('\n').pop();
};
const grail = grailOf(root);
const schedTree = process.env.GRAIL_SCHED_TREE ? resolve(process.env.GRAIL_SCHED_TREE) : null;

// A column whose toolchain is absent is dropped (toolchains() prints which): the C twin is the
// reference every output is checked against, so clang is required.
const have = toolchains();
if (!have.c) throw new Error('clang is required: the C twin is what every output is checked against');
const language = { cpp: 'cpp', 'rust-release': 'rust', 'rust-dev': 'rust', 'rust-native': 'rust', go: 'go', 'go-v3': 'go', 'zig-fast': 'zig', 'zig-debug': 'zig', 'zig-native': 'zig' };
const present = c => !language[c] || have[language[c]];
const headOf = { 'grail-native': 'Grail-native', 'grail-llvm': 'Grail-LLVM', c: 'C -O2', cpp: 'C++ -O2', 'rust-release': 'Rust rel', go: 'Go', 'zig-fast': 'Zig RF', 'rust-dev': 'Rust dev', 'zig-debug': 'Zig Debug', 'c-native': 'C native', 'rust-native': 'Rust native', 'go-v3': 'Go v3', 'zig-native': 'Zig native' };
const columns = ['grail-native', 'grail-llvm', 'c', 'cpp', 'rust-release', 'go', 'zig-fast', 'rust-dev', 'zig-debug'].filter(present);
const heads = columns.map(c => headOf[c]);
const releaseRivals = ['c', 'cpp', 'rust-release', 'go', 'zig-fast'].filter(present), devRivals = ['go', 'rust-dev', 'zig-debug'].filter(present);
const nativeColumns = ['c-native', 'rust-native', 'go-v3', 'zig-native'].filter(present);
const nativeHeads = nativeColumns.map(c => headOf[c]);
const measured = [...columns, ...nativeColumns];

const names = argv.length ? argv
  : readdirSync(join(root, 'bench')).filter(f => f.endsWith('.grl')).map(f => f.slice(0, -4))
    .filter(name => existsSync(join(root, 'bench', `${name}.c`)) && (existsSync(join(root, 'bench/rivals', `${name}.rs`)) || existsSync(join(root, 'bench/rivals', `${name}-rs/Cargo.toml`)))).sort()
    // ffi_call is this tree's when it has one, else the scheduler tree's (GRAIL_SCHED_TREE).
    .concat(!existsSync(join(root, 'bench/ffi_call.grl')) && schedTree && existsSync(join(schedTree, 'bench/ffi_call.grl')) ? ['ffi_call'] : []);

function build(name) {
  const tree = name === 'ffi_call' && !existsSync(join(root, 'bench/ffi_call.grl')) ? schedTree : root;
  const dir = join(work, name);
  mkdirSync(dir, { recursive: true });
  const ctext = readFileSync(join(tree, 'bench', `${name}.c`), 'utf8');
  const cflags = (ctext.match(/^\/\/ bench-cflags: (.*)$/m)?.[1] ?? '').split(' ').filter(Boolean);
  const rivals = join(root, 'bench/rivals');
  const libc = name === 'ffi_call' ? ['-lc', '-fno-builtin'] : [];
  const compiler = tree === root ? grail : grailOf(tree);
  // The program from this tree (or the scheduler tree); its runtime and core from the measured
  // compiler's tree.
  const lib = tree === root ? measuredGrail.tree : tree;
  const grailInputs = [join(tree, 'bench', `${name}.grl`), join(lib, 'lib/core.grl')];
  // A program that says `use host` (ffi_call) or `use json` finds the module under the module root.
  const grailOptions = { runtime: join(lib, 'compiler/runtime.grl'), osRuntime: join(lib, 'compiler/os-linux.grl'), extra: ['--module-root', join(lib, 'lib')] };
  const exe = {};
  exe['grail-native'] = compileProgram(compiler, grailInputs, join(dir, 'native'), { ...grailOptions, backend: 'native', overflow: 'checked' });
  exe['grail-llvm'] = compileProgram(compiler, grailInputs, join(dir, 'llvm'), { ...grailOptions, backend: 'llvm', overflow: 'wrap' });
  run(['clang', '-O2', '-ffp-contract=off', ...cflags, join(tree, 'bench', `${name}.c`), '-o', exe.c = join(dir, 'c'), '-lm']);
  run(['clang', '-O2', '-march=native', '-ffp-contract=off', ...cflags, join(tree, 'bench', `${name}.c`), '-o', exe['c-native'] = join(dir, 'c-native'), '-lm']);
  // The C++ twin, when the program has one (bench/rivals/NAME.cpp); its own bench-cflags line, and
  // -pthread when it uses <thread>.
  const cpp = join(rivals, `${name}.cpp`);
  if (have.cpp && existsSync(cpp)) {
    const text = readFileSync(cpp, 'utf8');
    const flags = [...(text.match(/^\/\/ bench-cflags: (.*)$/m)?.[1] ?? '').split(' ').filter(Boolean), ...(/#include <thread>/.test(text) ? ['-pthread'] : [])];
    run(['clang++', '-std=c++20', '-O2', '-ffp-contract=off', ...[...new Set(flags)], cpp, '-o', exe.cpp = join(dir, 'cpp')]);
  }
  // A twin that needs a crate (json: serde_json) is a cargo project, bench/rivals/NAME-rs, built
  // from the offline registry with cargo's release and dev profiles; the rest are one file for rustc.
  const crate = join(rivals, `${name}-rs`);
  if (have.rust && existsSync(join(crate, 'Cargo.toml'))) {
    const cargo = (profile, target, flags = '') => {
      run(['cargo', 'build', '--offline', '-q', ...(profile === 'release' ? ['--release'] : [])], { cwd: crate, env: { ...env, CARGO_TARGET_DIR: join(dir, target), RUSTFLAGS: flags } });
      return join(dir, target, profile === 'release' ? 'release' : 'debug', name);
    };
    exe['rust-release'] = cargo('release', 'cargo-release');
    exe['rust-dev'] = cargo('dev', 'cargo-dev');
    exe['rust-native'] = cargo('release', 'cargo-native', '-C target-cpu=native');
  } else if (have.rust) {
    run(['rustc', '--edition', '2021', '-C', 'opt-level=3', '-C', 'target-cpu=native', join(rivals, `${name}.rs`), '-o', exe['rust-native'] = join(dir, 'rust-native')]);
    run(['rustc', '--edition', '2021', '-C', 'opt-level=3', join(rivals, `${name}.rs`), '-o', exe['rust-release'] = join(dir, 'rust-release')]);
    run(['rustc', '--edition', '2021', '-C', 'opt-level=0', '-g', join(rivals, `${name}.rs`), '-o', exe['rust-dev'] = join(dir, 'rust-dev')]);
  }
  // `go build FILE.go` builds one file as package main; cgo needs it in a directory of its own.
  if (have.go) {
    mkdirSync(join(dir, 'go'), { recursive: true });
    cpSync(join(rivals, `${name}.go`), join(dir, 'go', `${name}.go`));
    run(['go', 'build', '-o', exe.go = join(dir, 'go-bin'), `${name}.go`], { cwd: join(dir, 'go'), env: { ...env, GOAMD64: 'v1' } });
    run(['go', 'build', '-o', exe['go-v3'] = join(dir, 'go-v3'), `${name}.go`], { cwd: join(dir, 'go'), env: { ...env, GOAMD64: 'v3' } });
  }
  if (!have.zig) return exe;
  run(['zig', 'build-exe', '-O', 'ReleaseFast', '-mcpu=native', ...libc, join(rivals, `${name}.zig`), `-femit-bin=${exe['zig-native'] = join(dir, 'zig-native')}`], { cwd: dir, env });
  run(['zig', 'build-exe', '-O', 'ReleaseFast', '-mcpu=baseline', ...libc, join(rivals, `${name}.zig`), `-femit-bin=${exe['zig-fast'] = join(dir, 'zig-fast')}`], { cwd: dir, env });
  run(['zig', 'build-exe', '-O', 'Debug', '-mcpu=baseline', ...libc, join(rivals, `${name}.zig`), `-femit-bin=${exe['zig-debug'] = join(dir, 'zig-debug')}`], { cwd: dir, env });
  return exe;
}

// Integers are compared exactly; any other number to 12 significant digits (Grail and Rust print
// the shortest round-trip form, C %.17g, Go switches to an exponent above 1e21 or at %v's whim).
function numbers(text) {
  return text.trim().split(/\s+/).map(word => {
    if (/^-?\d+$/.test(word) && Math.abs(Number(word)) > 2 ** 53) return word;
    const n = Number(word);
    return Number.isFinite(n) ? n.toPrecision(12) : word;
  });
}
// ffi_call reports its own per-call time on stderr: the loop around the call is what it measures.
// Under --metric instructions it is counted like every other program (the whole program, both loops).
const selfReported = (name, r) => name === 'ffi_call' && metric !== 'instructions' ? Number(r.stderr.match(/^ffi_call (\d+) ps/m)[1]) / 1000 : undefined;

// The fastest of some columns' figures, leaving out a column with no figure for this program.
const fastest = (keys, figures) => Math.min(...keys.map(c => figures[c]).filter(v => v !== undefined));
const load = [loadavg()];
const results = {};
const fmt = (name, v) => v === undefined ? '-' : name === 'ffi_call' && metric !== 'instructions' ? `${v.toFixed(2)}ns` : metric === 'instructions' ? `${(v / 1e9).toFixed(2)}G` : `${v.toFixed(3)}`;
console.log(`Grail: ${measuredGrail.commit}${names.includes('ffi_call') && !existsSync(join(root, 'bench/ffi_call.grl')) ? '; ffi_call: the scheduler tree ' + schedTree : ''}`);
console.log(`bench-rivals: ${metric === 'instructions' ? 'user-space instructions (G)' : metric === 'wall' ? 'wall seconds' : 'CPU seconds (user+sys)'}, best of ${runs}${workerCounts.length ? `, at ${workerCounts.join(', ')} workers` : ''}; ffi_call: ns per call as the program reports it`);
console.log(`${'program'.padEnd(10)} ${heads.map(h => h.padStart(12)).join(' ')}   native/dev-best  LLVM/release-best`);
let failed = 0;
const rowNames = [];
const builds = {};
for (const [name, workers] of names.flatMap(n => workerCounts.length ? workerCounts.map(w => [n, w]) : [[n, 0]])) {
  const exe = builds[name] ??= build(name);
  const key = workers ? `${name} x${workers}` : name;
  rowNames.push(key);
  const best = {}, out = {}, instructions = {}, cpu = {};
  for (let i = 0; i < runs; i++) {
    for (const column of measured) {
      if (!exe[column]) continue; // a rival without a twin of this program (C++ has not every one)
      const r = measure([exe[column]], { env: { ...process.env, ...threadEnv(workers) } });
      const v = selfReported(name, r) ?? (metric === 'instructions' ? r.instructions : metric === 'wall' ? r.wall : r.cpu);
      best[column] = Math.min(best[column] ?? Infinity, v);
      instructions[column] = Math.min(instructions[column] ?? Infinity, r.instructions);
      cpu[column] = Math.min(cpu[column] ?? Infinity, r.cpu);
      out[column] = r.stdout;
    }
  }
  // A native-CPU build may print other digits where its language allows a fused multiply-add (Go
  // fuses x*y+z when GOAMD64 has FMA; its spec permits it): reported, not a failure.
  const differs = measured.filter(c => exe[c] && JSON.stringify(numbers(out[c])) !== JSON.stringify(numbers(out.c)));
  if (differs.some(c => columns.includes(c))) failed++;
  const dev = fastest(devRivals, best), rel = fastest(releaseRivals, best);
  results[key] = { best, instructions, cpu, out: out.c, workers, native_over_dev_best: best['grail-native'] / dev, llvm_over_release_best: best['grail-llvm'] / rel, differs };
  console.log(`${key.padEnd(10)} ${columns.map(c => fmt(name, best[c]).padStart(12)).join(' ')}   ${ratio(best['grail-native'], dev).padStart(15)}  ${ratio(best['grail-llvm'], rel).padStart(17)}${differs.length ? `   OUTPUT DIFFERS: ${differs.join(', ')}` : ''}`);
}
// References: C written another way, to say what a gap is made of. Each is timed like the table and
// set against its program's C twin and Grail's release build.
//   nbody_heap.c, matmul_heap.c  the C twin with its arrays malloc'd: Grail has no fixed-size array,
//                                so this is what Grail's data structure costs C (a language gap)
//   ffi_fnptr.c                  C calling labs through a function pointer it cannot see through:
//                                a C-to-C call that stays a call
const references = [['nbody_heap', 'nbody'], ['matmul_heap', 'matmul'], ['ffi_fnptr', 'ffi_call']].filter(([, of]) => results[of]);
if (references.length) console.log(`\nreferences (C -O2 written another way)        figure    C twin    Grail-LLVM   Grail-LLVM / it`);
for (const [ref, of] of references) {
  const exe = join(work, of, ref);
  run(['clang', '-O2', '-ffp-contract=off', join(root, 'bench/rivals', `${ref}.c`), '-o', exe, '-lm']);
  let best = Infinity, out = '';
  for (let i = 0; i < runs; i++) {
    const r = measure([exe]);
    out = r.stdout;
    best = Math.min(best, selfReported(of, r) ?? (metric === 'instructions' ? r.instructions : r.cpu));
  }
  const same = JSON.stringify(numbers(out)) === JSON.stringify(numbers(results[of].out));
  if (!same) failed++;
  results[of].references = { ...results[of].references, [ref]: best };
  console.log(`${ref.padEnd(44)} ${fmt(of, best).padStart(8)} ${fmt(of, results[of].best.c).padStart(9)} ${fmt(of, results[of].best['grail-llvm']).padStart(12)}   ${ratio(results[of].best['grail-llvm'], best).padStart(14)}${same ? '' : '   OUTPUT DIFFERS'}`);
}
if (nativeColumns.length) console.log(`\nthe same programs built for this CPU (Grail-LLVM is still baseline x86-64)\n${'program'.padEnd(10)} ${[...nativeHeads, 'Grail-LLVM'].map(h => h.padStart(12)).join(' ')}   LLVM/native-best`);
for (const name of nativeColumns.length ? rowNames : []) {
  const b = results[name].best;
  const nat = Math.min(...nativeColumns.map(c => b[c]));
  results[name].llvm_over_native_best = b['grail-llvm'] / nat;
  console.log(`${name.padEnd(10)} ${[...nativeColumns, 'grail-llvm'].map(c => fmt(name, b[c]).padStart(12)).join(' ')}   ${ratio(b['grail-llvm'], nat).padStart(16)}`);
}
// User-space instructions retired (perf_event_open, every thread), fewest of the runs: unlike time,
// not moved by the load. ffi_call's count is the whole program's, both loops included.
console.log(`\nuser-space instructions (G), the same builds\n${'program'.padEnd(10)} ${heads.map(h => h.padStart(12)).join(' ')}   native/dev-best  LLVM/release-best`);
for (const name of rowNames) {
  const n = results[name].instructions;
  const dev = fastest(devRivals, n), rel = fastest(releaseRivals, n);
  console.log(`${name.padEnd(10)} ${columns.map(c => (n[c] === undefined ? '-' : (n[c] / 1e9).toFixed(2)).padStart(12)).join(' ')}   ${ratio(n['grail-native'], dev).padStart(15)}  ${ratio(n['grail-llvm'], rel).padStart(17)}`);
}
load.push(loadavg());
const v = versions();
console.log(`load average ${load[0]} at start, ${load[1]} at end; ${Object.values(v).join('; ')}`);
writeFileSync(join(root, '.work/bench-rivals.json'), JSON.stringify({ grail: measuredGrail.commit, metric, runs, load, versions: v, results, at: new Date().toISOString() }, null, 2) + '\n');
if (jsonPath) {
  const counted = kind => kind === 'instructions' || (metric === 'instructions' && kind !== 'cpu');
  const walled = kind => metric === 'wall' && kind === 'time';
  const unitOf = (name, kind) => walled(kind) ? 's wall' : kind === 'cpu' ? (name === 'ffi_call' ? 's CPU (whole program)' : 's CPU') : counted(kind) ? (name === 'ffi_call' ? 'G instructions (whole program)' : 'G instructions') : name === 'ffi_call' ? 'ns per call' : 's CPU';
  // A build that printed another answer than C's is not charted: its time is a wrong program's
  // (a native-CPU rival's fused multiply-add digits are the one allowed difference, and are not in
  // `columns`). The table shows it as not measured and the run still fails.
  const wrong = (name, k) => columns.includes(k) && (results[name].differs ?? []).includes(k);
  const table = (id, title, keys, primary, threshold, chart, kind = 'time', note = undefined) => ({
    id, title, chart, threshold, primary, note, direction: 'lower',
    columns: keys.map(key => ({ key, label: headOf[key], grail: key.startsWith('grail') })),
    rows: rowNames.map(name => ({ name, unit: unitOf(name.split(' ')[0], kind), values: Object.fromEntries(keys.map(k => [k, wrong(name, k) || results[name].best[k] === undefined ? null : kind === 'cpu' ? results[name].cpu[k] : counted(kind) ? results[name].instructions[k] / 1e9 : results[name].best[k]])) })),
  });
  const figure = metric === 'wall' ? `Wall time of the whole program, best of ${runs}${workerCounts.length ? `, at ${workerCounts.join(', ')} workers` : ''}; a parallel run is about time, so this is the figure, and the load is beside it` : metric === 'instructions' ? `User-space instructions (perf_event_open, every thread), fewest of ${runs}; chosen over time because the host was loaded` : `CPU time (user + sys), best of ${runs}`;
  writeResults(jsonPath, {
    tool: 'bench-rivals', title: 'Run time against C, C++, Rust, Go and Zig', commit: measuredGrail.commit, versions: v, load,
    commands: [`bun tools/bench-rivals.mjs --runs ${runs}${chosen.branch ? ` --branch ${chosen.branch}` : ''}`, ...Object.entries({ 'Grail-native': 'native backend, --overflow=checked', 'Grail-LLVM': '--backend=llvm --overflow=wrap, clang -O2', 'C -O2': 'clang -O2 -ffp-contract=off', 'C++ -O2': 'clang++ -std=c++20 -O2 -ffp-contract=off', 'Rust rel': 'rustc --edition 2021 -C opt-level=3', Go: 'go build (GOAMD64=v1)', 'Zig RF': 'zig build-exe -O ReleaseFast -mcpu=baseline', 'Rust dev': 'rustc --edition 2021 -C opt-level=0 -g', 'Zig Debug': 'zig build-exe -O Debug -mcpu=baseline' }).map(([k, c]) => `${k}: ${c}`)],
    tables: [
      table('release', metric === 'instructions' ? 'Release builds: instructions executed' : 'Release builds: run time', ['grail-llvm', ...releaseRivals], 'grail-llvm', 1.05, true, 'time', `${figure}. The bar: parity with clang -O2, within noise (5 %).`),
      table('dev', metric === 'instructions' ? 'Development builds: instructions executed' : 'Development builds: run time', ['grail-native', ...devRivals], 'grail-native', 1, true, 'time', `${figure}. The bar: faster than Zig Debug, Rust's dev profile and Go.`),
      ...(metric === 'instructions' ? [table('cpu', 'CPU time, the same runs', columns, 'grail-llvm', 1.05, false, 'cpu', `CPU time (user + sys), best of ${runs}; inflated by the load.`)] : [table('instructions', 'User-space instructions', columns, 'grail-llvm', 1.05, false, 'instructions', 'perf_event_open, every thread; not moved by load.')]),
      ...(nativeColumns.length ? [table('native-cpu', 'Rivals built for this CPU (Grail still baseline x86-64)', ['grail-llvm', ...nativeColumns], 'grail-llvm', 1.05, false)] : []),
    ],
  });
}
// One line the gate's summary picks up: Grail-LLVM over the best release rival, per program.
console.log(`bench-rivals (${measuredGrail.commit}): LLVM/release-best ${rowNames.map(n => `${n} ${ratio(results[n].best['grail-llvm'], fastest(releaseRivals, results[n].best))}`).join(', ')}`);
if (failed) process.exit(1);
