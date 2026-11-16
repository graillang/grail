// Runs the scheduler benchmarks (bench/frame.grl, bench/sched.grl) and prints the median of each
// `name value unit` line over N rounds, with the observed range.
//   bun tools/bench-sched.mjs [--rounds N]      GRAIL_COMPILER selects the compiler (default: build it)
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { root } from './platforms.mjs';

function run(argv, options = {}) {
  const result = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${argv.join(' ')} failed (${result.status})\n${result.stdout}${result.stderr}`);
  return result.stdout;
}
const at = process.argv.indexOf('--rounds');
const rounds = at > 0 ? Number(process.argv[at + 1]) : 5;
const compiler = process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER)
  ? resolve(process.env.GRAIL_COMPILER)
  : run(['bun', join(root, 'tools/native.mjs'), 'build'], { cwd: root }).trim().split('\n').pop();
const dir = mkdtempSync(join(tmpdir(), 'grail-bench-sched-'));
try {
  for (const name of ['frame', 'sched']) {
    const exe = join(dir, name);
    run([compiler, 'build', join(root, 'bench', `${name}.grl`), '-o', exe, '--no-cache'], { cwd: dir });
    const seen = new Map();
    for (let i = 0; i < rounds; i++) {
      for (const line of run([exe]).trim().split('\n')) {
        const [key, value, unit] = line.split(' ');
        if (!seen.has(key)) seen.set(key, { unit, values: [] });
        seen.get(key).values.push(Number(value));
      }
    }
    for (const [key, { unit, values }] of seen) {
      if (unit === '-') continue;
      values.sort((a, b) => a - b);
      console.log(`${name}.${key.padEnd(18)} ${String(values[values.length >> 1]).padStart(9)} ${unit.padEnd(2)}  [${values[0]} .. ${values[values.length - 1]}]`);
    }
  }
} finally {
  rmSync(dir, { recursive: true, force: true });
}
