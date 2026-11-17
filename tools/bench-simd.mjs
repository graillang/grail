// The SIMD benchmarks against C with intrinsics (docs/design/simd.md): bench/simd_dot.grl built with
// --backend=llvm and with the native backend, bench/simd_dot.c with clang -O2, all run interleaved on
// one core, RUNS times each; reports ns per element (fastest and median) and each Grail build's ratio
// to C. The machine is shared, so the fastest run is the figure and the median says how noisy it was.
//   bun tools/bench-simd.mjs [--compiler PATH] [--runs N] [--rounds R] [--cpu K]
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { root, buildCompiler, compileProgram } from './native.mjs';

const arg = (name, fallback) => {
  const at = process.argv.indexOf(name);
  return at === -1 ? fallback : process.argv[at + 1];
};
const compiler = arg('--compiler', null) ?? buildCompiler();
const runs = Number(arg('--runs', '15'));
const rounds = arg('--rounds', '200000');
const cpu = arg('--cpu', '5');
const work = join(root, '.work/bench-simd');
const builds = {
  'grail llvm': compileProgram(compiler, [join(root, 'bench/simd_dot.grl')], join(work, 'llvm'), { target: 'x86_64', backend: 'llvm', name: 'dot' }),
  'grail native': compileProgram(compiler, [join(root, 'bench/simd_dot.grl')], join(work, 'native'), { target: 'x86_64', name: 'dot' }),
};
const c = join(work, 'dot-c');
const cc = spawnSync('clang', ['-O2', '-o', c, join(root, 'bench/simd_dot.c')], { encoding: 'utf8' });
if (cc.status !== 0) throw new Error(cc.stderr);
builds.c = c;
const times = Object.fromEntries(Object.keys(builds).map(k => [k, []]));
const sums = {};
for (let i = 0; i < runs; i += 1) {
  for (const [name, exe] of Object.entries(builds)) {
    // The native build runs the scalar-lane expansion (S1): a tenth of the rounds.
    const r = name === 'grail native' ? String(Math.max(1, Math.floor(Number(rounds) / 10))) : rounds;
    const out = spawnSync('taskset', ['-c', cpu, exe, r], { encoding: 'utf8' }).stdout.trim().split('\n');
    times[name].push(Number(out[1].split(' ')[1]));
    sums[name] = Number(out[0]) / Number(r);
  }
}
const stat = list => {
  const sorted = [...list].sort((a, b) => a - b);
  return { min: sorted[0], median: sorted[Math.floor(sorted.length / 2)] };
};
const base = stat(times.c);
for (const name of Object.keys(builds)) {
  const s = stat(times[name]);
  const ratio = name === 'c' ? '' : `  ${(s.min / base.min).toFixed(3)}x C (median ${(s.median / base.median).toFixed(3)}x)`;
  console.log(`${name.padEnd(13)} ${s.min.toFixed(4)} ns/element (median ${s.median.toFixed(4)})${ratio}`);
}
const values = new Set(Object.values(sums).map(v => v.toPrecision(12)));
console.log(values.size === 1 ? `the same dot product from every build: ${[...values][0]}` : `DIFFERENT results: ${JSON.stringify(sums)}`);
if (values.size !== 1) process.exit(1);
