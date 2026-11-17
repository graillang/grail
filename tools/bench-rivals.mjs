// Run time against other languages (docs/design/runtime-parity.md, "Against other languages").
// Every bench/NAME.grl with a C twin also has Rust, Go and Zig twins in bench/rivals/ (same
// algorithm, same output, idiomatic, not hand-vectorised). Each is built the way its users build:
//   Grail-native  the native backend, overflow checked            (the development build)
//   Grail-LLVM    --backend=llvm, clang -O2, --overflow=wrap      (the release build)
//   C -O2         clang -O2 -ffp-contract=off [+ the twin's bench-cflags line]
//   Rust release  rustc --edition 2021 -C opt-level=3   (= cargo --release: opt-level 3, no debug
//                 assertions, no overflow checks; one crate, so codegen units do not matter)
//   Go            go build                              (Go has one build; -gcflags='-N -l' is a
//                 debugger's build, not what Go users ship or test with, so it is not used)
//   Zig RF        zig build-exe -O ReleaseFast
//   Rust dev      rustc --edition 2021 -C opt-level=0 -g (= cargo's dev profile: debug assertions and
//                 overflow checks on)
//   Zig Debug     zig build-exe -O Debug
// Every program's output is checked against C's (floats to 12 significant digits). The figure is
// CPU time (user + sys from getrusage, every thread), best of N runs interleaved round by round, so
// a loaded host is not what is measured; instructions are recorded beside it in the JSON.
// Each Grail column is also given as a ratio to the best competitor of its bar: Grail-LLVM against
// the fastest of C, Rust release, Go and Zig ReleaseFast; Grail-native against the fastest of Go,
// Rust dev and Zig Debug.
//   bun tools/bench-rivals.mjs [--runs N] [--metric cpu|instructions] [NAME...]
//   GRAIL_COMPILER selects the compiler (default: build the tree's). ffi_call is measured when
//   GRAIL_SCHED_TREE names a checkout of a branch that has bench/ffi_call.grl (with its compiler
//   built, `bun tools/native.mjs build` there, or named by GRAIL_SCHED_COMPILER); its figure is the
//   program's own per-call time.
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync, cpSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { root } from './platforms.mjs';
import { compileProgram } from './native.mjs';
import { loadavg, measurer, ratio, run, versions } from './rivals/common.mjs';

const argv = process.argv.slice(2);
const option = (name, fallback) => { const at = argv.indexOf(name); if (at < 0) return fallback; const v = argv[at + 1]; argv.splice(at, 2); return v; };
const runs = Number(option('--runs', 3));
const metric = option('--metric', 'cpu');
const work = join(root, '.work/bench-rivals');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const env = { ...process.env, GOCACHE: join(work, 'gocache'), ZIG_GLOBAL_CACHE_DIR: join(work, 'zigcache'), ZIG_LOCAL_CACHE_DIR: join(work, 'zigcache') };
const measure = measurer(root, work);
const grailOf = dir => {
  if (dir === root && process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER)) return resolve(process.env.GRAIL_COMPILER);
  if (dir !== root && process.env.GRAIL_SCHED_COMPILER && existsSync(process.env.GRAIL_SCHED_COMPILER)) return resolve(process.env.GRAIL_SCHED_COMPILER);
  return run(['bun', join(dir, 'tools/native.mjs'), 'build'], { cwd: dir }).stdout.trim().split('\n').pop();
};
const grail = grailOf(root);
const schedTree = process.env.GRAIL_SCHED_TREE ? resolve(process.env.GRAIL_SCHED_TREE) : null;

const columns = ['grail-native', 'grail-llvm', 'c', 'rust-release', 'go', 'zig-fast', 'rust-dev', 'zig-debug'];
const heads = ['Grail-native', 'Grail-LLVM', 'C -O2', 'Rust rel', 'Go', 'Zig RF', 'Rust dev', 'Zig Debug'];
const releaseRivals = ['c', 'rust-release', 'go', 'zig-fast'], devRivals = ['go', 'rust-dev', 'zig-debug'];

const names = argv.length ? argv
  : readdirSync(join(root, 'bench')).filter(f => f.endsWith('.grl')).map(f => f.slice(0, -4))
    .filter(name => existsSync(join(root, 'bench', `${name}.c`)) && existsSync(join(root, 'bench/rivals', `${name}.rs`))).sort()
    .concat(schedTree && existsSync(join(schedTree, 'bench/ffi_call.grl')) ? ['ffi_call'] : []);

function build(name) {
  const tree = name === 'ffi_call' ? schedTree : root;
  const dir = join(work, name);
  mkdirSync(dir, { recursive: true });
  const ctext = readFileSync(join(tree, 'bench', `${name}.c`), 'utf8');
  const cflags = (ctext.match(/^\/\/ bench-cflags: (.*)$/m)?.[1] ?? '').split(' ').filter(Boolean);
  const rivals = join(root, 'bench/rivals');
  const libc = name === 'ffi_call' ? ['-lc', '-fno-builtin'] : [];
  const compiler = tree === root ? grail : grailOf(tree);
  const grailInputs = [join(tree, 'bench', `${name}.grl`), join(tree, 'lib/core.grl')];
  // ffi_call says `use host`: the compiler proper finds a module only under a module root.
  const grailOptions = { runtime: join(tree, 'compiler/runtime.grl'), osRuntime: join(tree, 'compiler/os-linux.grl'), extra: tree === root ? [] : ['--module-root', join(tree, 'lib')] };
  const exe = {};
  exe['grail-native'] = compileProgram(compiler, grailInputs, join(dir, 'native'), { ...grailOptions, backend: 'native', overflow: 'checked' });
  exe['grail-llvm'] = compileProgram(compiler, grailInputs, join(dir, 'llvm'), { ...grailOptions, backend: 'llvm', overflow: 'wrap' });
  run(['clang', '-O2', '-ffp-contract=off', ...cflags, join(tree, 'bench', `${name}.c`), '-o', exe.c = join(dir, 'c'), '-lm']);
  run(['rustc', '--edition', '2021', '-C', 'opt-level=3', join(rivals, `${name}.rs`), '-o', exe['rust-release'] = join(dir, 'rust-release')]);
  run(['rustc', '--edition', '2021', '-C', 'opt-level=0', '-g', join(rivals, `${name}.rs`), '-o', exe['rust-dev'] = join(dir, 'rust-dev')]);
  // `go build FILE.go` builds one file as package main; cgo needs it in a directory of its own.
  mkdirSync(join(dir, 'go'), { recursive: true });
  cpSync(join(rivals, `${name}.go`), join(dir, 'go', `${name}.go`));
  run(['go', 'build', '-o', exe.go = join(dir, 'go-bin'), `${name}.go`], { cwd: join(dir, 'go'), env });
  run(['zig', 'build-exe', '-O', 'ReleaseFast', ...libc, join(rivals, `${name}.zig`), `-femit-bin=${exe['zig-fast'] = join(dir, 'zig-fast')}`], { cwd: dir, env });
  run(['zig', 'build-exe', '-O', 'Debug', ...libc, join(rivals, `${name}.zig`), `-femit-bin=${exe['zig-debug'] = join(dir, 'zig-debug')}`], { cwd: dir, env });
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
const selfReported = (name, r) => name === 'ffi_call' ? Number(r.stderr.match(/^ffi_call (\d+) ps/m)[1]) / 1000 : undefined;

const load = [loadavg()];
const results = {};
const fmt = (name, v) => v === undefined ? '-' : name === 'ffi_call' ? `${v.toFixed(2)}ns` : metric === 'instructions' ? `${(v / 1e9).toFixed(2)}G` : `${v.toFixed(3)}`;
console.log(`bench-rivals: ${metric === 'instructions' ? 'user-space instructions (G)' : 'CPU seconds (user+sys)'}, best of ${runs}; ffi_call: ns per call as the program reports it`);
console.log(`${'program'.padEnd(10)} ${heads.map(h => h.padStart(12)).join(' ')}   native/dev-best  LLVM/release-best`);
let failed = 0;
for (const name of names) {
  const exe = build(name);
  const best = {}, out = {};
  for (let i = 0; i < runs; i++) {
    for (const column of columns) {
      const r = measure([exe[column]]);
      const v = selfReported(name, r) ?? (metric === 'instructions' ? r.instructions : r.cpu);
      best[column] = Math.min(best[column] ?? Infinity, v);
      out[column] = r.stdout;
    }
  }
  const differs = columns.filter(c => JSON.stringify(numbers(out[c])) !== JSON.stringify(numbers(out.c)));
  if (differs.length) failed++;
  const dev = Math.min(...devRivals.map(c => best[c])), rel = Math.min(...releaseRivals.map(c => best[c]));
  results[name] = { best, native_over_dev_best: best['grail-native'] / dev, llvm_over_release_best: best['grail-llvm'] / rel, differs };
  console.log(`${name.padEnd(10)} ${columns.map(c => fmt(name, best[c]).padStart(12)).join(' ')}   ${ratio(best['grail-native'], dev).padStart(15)}  ${ratio(best['grail-llvm'], rel).padStart(17)}${differs.length ? `   OUTPUT DIFFERS: ${differs.join(', ')}` : ''}`);
}
load.push(loadavg());
const v = versions();
console.log(`load average ${load[0]} at start, ${load[1]} at end; ${Object.values(v).join('; ')}`);
writeFileSync(join(root, '.work/bench-rivals.json'), JSON.stringify({ metric, runs, load, versions: v, results, at: new Date().toISOString() }, null, 2) + '\n');
if (failed) process.exit(1);
