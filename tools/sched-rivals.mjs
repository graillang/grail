// The scheduler against Rust's rayon and C++'s oneTBB (docs/design/runtime-parity.md, "Against
// other languages"). Grail's side is bench/sched.grl and bench/frame.grl from a tree that has them
// (the scheduler branch, gaps12-sched: GRAIL_SCHED_TREE names a checkout, default this tree); the
// rivals are bench/rivals/sched-rayon (cargo build --release, rayon from the offline registry) and
// bench/rivals/sched_tbb.cpp (g++ -O2 -std=c++20 -ltbb). All print `name value unit` lines of the
// same meaning. Grail is built two ways: `grail build --no-cache` (the native backend, what
// tools/bench-sched.mjs runs) and the LLVM backend with --overflow=wrap (the release build).
// Each program runs R rounds; a figure is the median over rounds, with the range in the JSON. These
// are wall-clock figures measured inside the programs - a join's cost and a frame's latency are
// times, not CPU totals - so on a loaded host read the median, never one run. The CPU seconds of
// each whole run (getrusage) are reported beside them.
// A column runs the release build with GRAIL_WORKERS set to the CPU count, the rivals' default.
//   bun tools/sched-rivals.mjs [--rounds R] [--compiler PATH | --branch REF]   (default 9 rounds)     GRAIL_SCHED_TREE, GRAIL_SCHED_COMPILER as above
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { cpus } from 'node:os';
import { join, resolve } from 'node:path';
import { root } from './platforms.mjs';
import { compilerOptions, grailCompiler, jsonOption, loadavg, measurer, ratio, run, toolchains, versions, writeResults } from './rivals/common.mjs';

const at = process.argv.indexOf('--rounds');
const rounds = at > 0 ? Number(process.argv[at + 1]) : 9;
// --compiler PATH / --branch REF as in the other rivals tools; otherwise GRAIL_SCHED_TREE and
// GRAIL_SCHED_COMPILER below (a branch whose seed and this tree's compiler both fail to build it).
const chosen = compilerOptions(process.argv);
const jsonPath = jsonOption(process.argv);
const picked = chosen.compiler || chosen.branch ? grailCompiler(root, chosen) : null;
const tree = picked ? picked.tree : resolve(process.env.GRAIL_SCHED_TREE ?? root);
// A tree without the scheduler benchmarks (the scheduler branch not merged yet) has nothing to
// compare: say so and succeed, so the gate leg is a note rather than a failure.
if (!existsSync(join(tree, 'bench/sched.grl')) || !existsSync(join(tree, 'bench/frame.grl'))) {
  console.log(`note: ${tree} has no bench/sched.grl and bench/frame.grl, so there is no scheduler to compare (GRAIL_SCHED_TREE or --branch names a tree that has them)`);
  process.exit(0);
}
const have = toolchains();
const work = join(root, '.work/sched-rivals');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const measure = measurer(root, work);

// ---- build
// GRAIL_SCHED_COMPILER names that tree's compiler; else it is built there, bootstrapped by
// GRAIL_COMPILER when set (a branch's checked-in seed may be older than its sources).
const grail = picked ? picked.compiler : process.env.GRAIL_SCHED_COMPILER && existsSync(process.env.GRAIL_SCHED_COMPILER) ? resolve(process.env.GRAIL_SCHED_COMPILER)
  : run(['bun', join(tree, 'tools/native.mjs'), 'build'], { cwd: tree }).stdout.trim().split('\n').pop();
const { compileProgram } = await import(join(tree, 'tools/native.mjs'));
const exe = { 'grail-native': {}, 'grail-llvm': {} };
for (const name of ['sched', 'frame']) {
  const native = join(work, `${name}-native`);
  run([grail, 'build', join(tree, 'bench', `${name}.grl`), '-o', native, '--no-cache'], { cwd: work });
  exe['grail-native'][name] = [native];
  exe['grail-llvm'][name] = [compileProgram(grail, [join(tree, 'bench', `${name}.grl`)], join(work, `${name}-llvm`), { backend: 'llvm', overflow: 'wrap', runtime: join(tree, 'compiler/runtime.grl'), osRuntime: join(tree, 'compiler/os-linux.grl'), extra: ['--module-root', join(tree, 'lib')] })];
}
// rayon comes from cargo's offline registry: a machine that has cargo but never fetched rayon
// skips it with a note, as one without cargo does.
if (have.rust) {
  const built = spawnSync('cargo', ['build', '--release', '--offline', '-q'], { cwd: join(root, 'bench/rivals/sched-rayon'), encoding: 'utf8', env: { ...process.env, CARGO_TARGET_DIR: join(work, 'rayon-target') } });
  if (built.status === 0) {
    const rayon = join(work, 'rayon-target/release/sched-rayon');
    exe.rayon = { sched: [rayon, 'sched'], frame: [rayon, 'frame'] };
  } else console.log(`note: the rayon twin did not build offline (no rayon in cargo's registry?), so rayon is not measured\n${(built.stderr ?? '').trim().split('\n').slice(-3).join('\n')}`);
}
if (have.tbb) {
  run(['g++', '-O2', '-std=c++20', join(root, 'bench/rivals/sched_tbb.cpp'), '-o', join(work, 'sched_tbb'), '-ltbb']);
  exe.onetbb = { sched: [join(work, 'sched_tbb'), 'sched'], frame: [join(work, 'sched_tbb'), 'frame'] };
}
// rayon and oneTBB start one thread per CPU by default (rayon: that many workers beside the main
// thread; oneTBB: that many arena slots, the main thread's included). Grail's default is the same,
// one worker per CPU; this column states it, so the comparison is like for like whatever the
// platform's default becomes.
// RIVALS_THREADS (set by tools/quiet-window.sh when it pins the run to a CPU set) is the thread
// count every runtime is given; otherwise one per CPU, each runtime's default.
const threads = Number(process.env.RIVALS_THREADS) || cpus().length;
const pinned = Boolean(process.env.RIVALS_THREADS);
const wide = `grail-llvm-w${threads}`;
exe[wide] = exe['grail-llvm'];
const envOf = { [wide]: { GRAIL_WORKERS: String(threads) } };
if (pinned) for (const c of ['grail-native', 'grail-llvm']) envOf[c] = { GRAIL_WORKERS: String(threads) };
const rivalEnv = pinned ? { RAYON_NUM_THREADS: String(threads) } : {};
const columns = ['grail-native', 'grail-llvm', wide, 'rayon', 'onetbb'].filter(c => exe[c]);
const rivalsHere = ['rayon', 'onetbb'].filter(c => exe[c]);

// ---- run, interleaved round by round so every program sees the same load
const load = [loadavg()];
const seen = {}; // column -> key -> values
const cpu = {};
const checksums = {};
for (let r = 0; r < rounds; r++) {
  for (const column of columns) {
    for (const name of ['sched', 'frame']) {
      const m = measure(exe[column][name], { env: { ...process.env, ...rivalEnv, ...envOf[column] } });
      (cpu[`${column}.${name}`] ??= []).push(m.cpu);
      for (const line of m.stdout.trim().split('\n')) {
        const [key, value, unit] = line.split(' ');
        // frame's checksum is the same computation in every program: the one output compared.
        if (name === 'frame' && key === 'checksum') (checksums[column] ??= new Set()).add(value);
        if (unit === '-' || value === undefined) continue;
        ((seen[column] ??= {})[`${name}.${key}`] ??= []).push(Number(value));
      }
    }
  }
}
load.push(loadavg());
const median = values => values ? [...values].sort((a, b) => a - b)[values.length >> 1] : undefined;

// ---- one table. Rows name what is compared; a rival's figure is the closest thing it has.
const rows = [
  ['join, from the main thread (ns)', 'sched.join', 'sched.join_main'],
  ['join, on a worker (ns)', null, 'sched.join'],
  ['spawn a job and wait (ns)', 'sched.job_spawn_wait', 'sched.job_spawn_wait'],
  ['task spawn+join, one at a time (ns)', 'sched.task_spawn_join', null],
  ['burst of 100k spawns, per spawn (ns)', 'sched.task_burst', 'sched.task_burst'],
  ['fib(32) serial (us)', 'sched.fib32_serial', 'sched.fib32_serial'],
  ['fib(32) nested join, from main (us)', 'sched.fib32_join_main', 'sched.fib32_join_main'],
  ['fib(32) nested join, in a task (us)', 'sched.fib32_join_task', 'sched.fib32_join_task'],
  ['frame median (us)', 'frame.frame_median', 'frame.frame_median'],
  ['frame p99 (us)', 'frame.frame_p99', 'frame.frame_p99'],
  ['frame max (us)', 'frame.frame_max', 'frame.frame_max'],
  ['600 frames (ms)', 'frame.frames_total', 'frame.frames_total'],
  ['I/O task worst lateness (us)', 'frame.io_worst_late', 'frame.io_worst_late'],
  ['importer rounds (more is better)', 'frame.bg_rounds', 'frame.bg_rounds'],
];
const headOf = { 'grail-native': 'Grail-native', 'grail-llvm': 'Grail-LLVM', [wide]: `LLVM w=${threads}`, rayon: 'rayon', onetbb: 'oneTBB' };
const heads = columns.map(c => headOf[c]);
const commit = picked ? picked.commit : tree === root ? run(['git', '-C', root, 'rev-parse', '--short=12', 'HEAD']).stdout.trim() : `${tree} (GRAIL_SCHED_TREE)`;
console.log(`Grail: ${commit}`);
console.log(`sched-rivals: median of ${rounds} rounds (wall time measured inside each program); ratio = Grail / best rival (for importer rounds, best rival / Grail)`);
console.log(`${''.padEnd(38)} ${heads.map(h => h.padStart(12)).join(' ')}  native/best   LLVM/best   w${threads}/best`);
const table = {};
for (const [label, mine, theirs] of rows) {
  const value = {};
  for (const c of columns) value[c] = median(seen[c]?.[c.startsWith('grail') ? mine : theirs] ?? undefined);
  const rivals = rivalsHere.map(c => value[c]).filter(v => v !== undefined);
  const more = label.includes('more is better');
  const best = rivals.length ? (more ? Math.max(...rivals) : Math.min(...rivals)) : undefined;
  const r = c => more ? ratio(best, value[c]) : ratio(value[c], best);
  table[label] = value;
  console.log(`${label.padEnd(38)} ${columns.map(c => String(value[c] ?? '-').padStart(12)).join(' ')}  ${r('grail-native').padStart(10)}  ${r('grail-llvm').padStart(10)}  ${r(wide).padStart(10)}`);
}
console.log(`CPU seconds per whole run (median): ${columns.map(c => `${c} sched ${median(cpu[`${c}.sched`]).toFixed(2)} frame ${median(cpu[`${c}.frame`]).toFixed(2)}`).join('; ')}`);
const v = versions();
console.log(`${threads} CPUs; load average ${load[0]} at start, ${load[1]} at end; ${Object.values(v).join('; ')}; rayon/oneTBB: see bench/rivals/sched-rayon/Cargo.lock, /usr/include/oneapi/tbb/version.h`);
writeFileSync(join(root, '.work/sched-rivals.json'), JSON.stringify({ rounds, threads, tree, commit, load, versions: v, table, raw: seen, cpu, at: new Date().toISOString() }, null, 2) + '\n');
const seenChecksums = new Set(Object.values(checksums).flatMap(set => [...set]));
if (seenChecksums.size !== 1) {
  console.log(`OUTPUT DIFFERS: frame checksums ${JSON.stringify(Object.fromEntries(Object.entries(checksums).map(([k, v]) => [k, [...v]])))}`);
  process.exit(1);
}
if (jsonPath) writeResults(jsonPath, {
  tool: 'sched-rivals', title: 'The scheduler against rayon and oneTBB', commit, versions: v, load,
  commands: [`bun tools/sched-rivals.mjs --rounds ${rounds}`, 'Grail-native: grail build --no-cache', 'Grail-LLVM: --backend=llvm --overflow=wrap, clang -O2', `LLVM w=${threads}: the same with GRAIL_WORKERS=${threads}`, 'rayon: cargo build --release (bench/rivals/sched-rayon)', 'oneTBB: g++ -O2 -std=c++20 sched_tbb.cpp -ltbb'],
  tables: [{
    id: 'scheduler', title: 'The scheduler: join, spawn, nested join and a frame loop', chart: true, threshold: 1, primary: 'grail-llvm', direction: 'lower',
    note: `Wall time measured inside each program, median of ${rounds} rounds. The bar: match or beat rayon and oneTBB.`,
    columns: columns.map(key => ({ key, label: headOf[key], grail: key.startsWith('grail') })),
    rows: rows.map(([label]) => {
      const m = label.match(/^(.*?) \((.*)\)$/);
      const more = label.includes('more is better');
      return { name: more ? label.replace(' (more is better)', '') : m ? m[1] : label, unit: more ? 'rounds' : m ? m[2] : '', direction: more ? 'higher' : 'lower', values: table[label] };
    }),
  }],
});
// One line the gate's summary picks up.
console.log(`sched-rivals (${commit}): LLVM/best ${['join, from the main thread (ns)', 'fib(32) nested join, in a task (us)', 'frame p99 (us)'].map(label => { const v = table[label]; const best = Math.min(...rivalsHere.map(c => v[c]).filter(x => x !== undefined)); return `${label.replace(/ \(.*\)$/, '')} ${ratio(v['grail-llvm'], best)}`; }).join(', ')}`);
