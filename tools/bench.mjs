// Times each bench/NAME.grl against bench/NAME.c (clang -O2 -ffp-contract=off) on Linux x86-64.
// Both programs must print the same numbers (floats compared to 12 significant digits, as Grail
// prints the shortest round-trip form and C %.17g). Reports the best of three runs and the ratio.
//   bun tools/bench.mjs [NAME...]        GRAIL_COMPILER selects the compiler (default: build it)
//   GRAIL_BENCH_FLAGS="--backend=llvm"   extra compiler flags for the Grail side
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { root } from './platforms.mjs';

function run(argv, options = {}) {
  const result = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${argv.join(' ')} failed (${result.status})\n${result.stdout}${result.stderr}`);
  return result;
}

function compiler() {
  if (process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER)) return resolve(process.env.GRAIL_COMPILER);
  const built = run(['bun', join(root, 'tools/native.mjs'), 'build'], { cwd: root }).stdout.trim().split('\n').pop();
  return built;
}

function best(exe) {
  let time = Infinity, out = '';
  for (let i = 0; i < 3; i++) {
    const start = process.hrtime.bigint();
    out = run([exe]).stdout;
    time = Math.min(time, Number(process.hrtime.bigint() - start) / 1e9);
  }
  return { time, out };
}

function numbers(text) {
  return text.trim().split(/\s+/).map(word => {
    const n = Number(word);
    return Number.isFinite(n) && /[.e]/i.test(word) ? n.toPrecision(12) : word;
  });
}

const grail = compiler();
const extra = (process.env.GRAIL_BENCH_FLAGS ?? '').split(/\s+/).filter(Boolean);
const names = process.argv.length > 2 ? process.argv.slice(2)
  : readdirSync(join(root, 'bench')).filter(f => f.endsWith('.grl')).map(f => f.slice(0, -4)).sort();
const work = mkdtempSync(join(tmpdir(), 'grail-bench-'));
const runtime = [join(root, 'lib/core.grl'), join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')];
let failed = 0;
try {
  console.log('benchmark      C -O2      Grail      ratio');
  for (const name of names) {
    const asm = join(work, `${name}.s`), obj = join(work, `${name}.o`), exe = join(work, name), cexe = join(work, `${name}-c`);
    run([grail, ...extra, '--typed-refs', asm, join(root, 'bench', `${name}.grl`), ...runtime]);
    run(['clang', '-c', asm, '-o', obj]);
    run(['ld.lld', obj, '-o', exe]);
    run(['clang', '-O2', '-ffp-contract=off', join(root, 'bench', `${name}.c`), '-o', cexe, '-lm']);
    const g = best(exe), c = best(cexe);
    const same = JSON.stringify(numbers(g.out)) === JSON.stringify(numbers(c.out));
    if (!same) failed++;
    console.log(`${name.padEnd(12)} ${c.time.toFixed(3).padStart(7)} s ${g.time.toFixed(3).padStart(8)} s ${(g.time / c.time).toFixed(1).padStart(8)}x${same ? '' : '   OUTPUT DIFFERS: ' + JSON.stringify([g.out, c.out])}`);
  }
} finally {
  rmSync(work, { recursive: true, force: true });
}
if (failed) process.exit(1);
