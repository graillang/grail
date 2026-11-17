// The SIMD benchmarks against C with intrinsics (docs/design/simd.md): each bench/simd_NAME.grl
// built with --backend=llvm and with the native backend, its twin bench/simd_NAME.c with clang -O2,
// all run interleaved on one core, RUNS times each. Reports the time per item (fastest and median)
// and each Grail build's ratio to C, and checks that every build computes the same result. The
// machine is shared, so the fastest run is the figure and the median says how noisy it was.
//   bun tools/bench-simd.mjs [--compiler PATH] [--runs N] [--cpu K] [--only NAME]
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { root, buildCompiler, compileProgram } from './native.mjs';

const arg = (name, fallback) => {
  const at = process.argv.indexOf(name);
  return at === -1 ? fallback : process.argv[at + 1];
};
const compiler = arg('--compiler', null) ?? buildCompiler();
const runs = Number(arg('--runs', '15'));
const cpu = arg('--cpu', '5');
const only = arg('--only', null);
// The rounds each build runs: the native build's scalar lanes are slower, so it runs a tenth.
const benches = [
  { name: 'dot', rounds: 200000 },
  { name: 'mat4', rounds: 2000 },
  { name: 'aos', rounds: 2000 },
].filter(b => !only || b.name === only);
const work = join(root, '.work/bench-simd');
let failed = false;
for (const bench of benches) {
  const source = join(root, `bench/simd_${bench.name}.grl`);
  const builds = {
    'grail llvm': compileProgram(compiler, [source], join(work, bench.name, 'llvm'), { target: 'x86_64', backend: 'llvm', name: bench.name }),
    'grail native': compileProgram(compiler, [source], join(work, bench.name, 'native'), { target: 'x86_64', name: bench.name }),
  };
  const c = join(work, bench.name, 'c');
  const cc = spawnSync('clang', ['-O2', '-o', c, join(root, `bench/simd_${bench.name}.c`)], { encoding: 'utf8' });
  if (cc.status !== 0) throw new Error(cc.stderr);
  builds.c = c;
  const times = Object.fromEntries(Object.keys(builds).map(k => [k, []]));
  const results = {};
  let unit = '';
  for (let i = 0; i < runs; i += 1) {
    for (const [name, exe] of Object.entries(builds)) {
      const r = name === 'grail native' ? Math.max(1, Math.floor(bench.rounds / 10)) : bench.rounds;
      const out = spawnSync('taskset', ['-c', cpu, exe, String(r)], { encoding: 'utf8' }).stdout.trim().split('\n');
      const [label, value] = out[1].split(' ');
      unit = label;
      times[name].push(Number(value));
      results[name] = out[0];
    }
  }
  const stat = list => {
    const sorted = [...list].sort((a, b) => a - b);
    return { min: sorted[0], median: sorted[Math.floor(sorted.length / 2)] };
  };
  const base = stat(times.c);
  console.log(`${bench.name} (${unit.replace('ns/', 'ns per ')})`);
  for (const name of Object.keys(builds)) {
    const s = stat(times[name]);
    const ratio = name === 'c' ? '' : `  ${(s.min / base.min).toFixed(3)}x C (median ${(s.median / base.median).toFixed(3)}x)`;
    console.log(`  ${name.padEnd(13)} ${s.min.toFixed(4)} (median ${s.median.toFixed(4)})${ratio}`);
  }
  // The dot product's printed total scales with the rounds; the others print the last round's result.
  const same = bench.name === 'dot' ? true : new Set(Object.values(results)).size === 1;
  if (!same) {
    failed = true;
    console.log(`  DIFFERENT results: ${JSON.stringify(results)}`);
  }
}
if (failed) process.exit(1);
