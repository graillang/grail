// Times each bench/NAME.grl against bench/NAME.c (clang -O2 -ffp-contract=off) on Linux x86-64.
// Both programs must print the same numbers (floats compared to 12 significant digits, as Grail
// prints the shortest round-trip form and C %.17g). Reports the best of three runs and the ratio.
//   bun tools/bench.mjs [NAME...]        GRAIL_COMPILER selects the compiler (default: build it)
//   GRAIL_BACKEND=llvm                    builds the Grail side through the LLVM backend
//   bun tools/bench.mjs --rounds N [NAME...]
//       Interleaves the two binaries round by round (C, Grail, C, Grail, ...) and reports the
//       median of N runs each instead of the best, with the observed spread in brackets. A shared
//       machine drifts; pairing the runs puts both sides under the same load, and the median is
//       not a favourable outlier. N should be odd and at least 5 to say anything about a gap of a
//       few percent.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { root } from './platforms.mjs';
import { compileProgram } from './native.mjs';

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

function once(exe) {
  const start = process.hrtime.bigint();
  const out = run([exe]).stdout;
  return { time: Number(process.hrtime.bigint() - start) / 1e9, out };
}

function best(exe) {
  let time = Infinity, out = '';
  for (let i = 0; i < 3; i++) {
    const r = once(exe);
    out = r.out;
    time = Math.min(time, r.time);
  }
  return { time, out };
}

const median = values => [...values].sort((a, b) => a - b)[values.length >> 1];

function numbers(text) {
  return text.trim().split(/\s+/).map(word => {
    const n = Number(word);
    return Number.isFinite(n) && /[.e]/i.test(word) ? n.toPrecision(12) : word;
  });
}

const grail = compiler();
const argv = process.argv.slice(2);
const roundsAt = argv.indexOf('--rounds');
const rounds = roundsAt >= 0 ? Number(argv[roundsAt + 1]) : 0;
if (roundsAt >= 0 && !(rounds >= 1)) throw new Error('--rounds needs a count of at least 1');
const rest = roundsAt >= 0 ? argv.filter((_, i) => i !== roundsAt && i !== roundsAt + 1) : argv;
const names = rest.length ? rest
  : readdirSync(join(root, 'bench')).filter(f => f.endsWith('.grl')).map(f => f.slice(0, -4)).sort();
const work = mkdtempSync(join(tmpdir(), 'grail-bench-'));
let failed = 0;
const ratios = [];
try {
  console.log(rounds
    ? `benchmark      C -O2      Grail (${process.env.GRAIL_BACKEND ?? 'native'})      ratio   (median of ${rounds} paired, spread C/G)`
    : `benchmark      C -O2      Grail (${process.env.GRAIL_BACKEND ?? 'native'})      ratio`);
  for (const name of names) {
    const exe = compileProgram(grail, [join(root, 'bench', `${name}.grl`), join(root, 'lib/core.grl')], join(work, name)), cexe = join(work, `${name}-c`);
    run(['clang', '-O2', '-ffp-contract=off', join(root, 'bench', `${name}.c`), '-o', cexe, '-lm']);
    let g, c, spread = '';
    if (rounds) {
      const gs = [], cs = [];
      once(exe); once(cexe); // warm the page cache before the first paired round
      for (let i = 0; i < rounds; i++) {
        const grun = once(exe), crun = once(cexe);
        gs.push(grun.time); cs.push(crun.time);
        g = { time: grun.time, out: grun.out }; c = { time: crun.time, out: crun.out };
      }
      g = { time: median(gs), out: g.out }; c = { time: median(cs), out: c.out };
      spread = `   [${(Math.max(...cs) - Math.min(...cs)).toFixed(3)}/${(Math.max(...gs) - Math.min(...gs)).toFixed(3)}]`;
    } else {
      g = best(exe); c = best(cexe); // C first, so neither side alone sees a cold cache
    }
    const same = JSON.stringify(numbers(g.out)) === JSON.stringify(numbers(c.out));
    if (!same) failed++;
    ratios.push(`${name} ${(g.time / c.time).toFixed(1)}x`);
    console.log(`${name.padEnd(12)} ${c.time.toFixed(3).padStart(7)} s ${g.time.toFixed(3).padStart(8)} s ${(g.time / c.time).toFixed(1).padStart(8)}x${same ? '' : '   OUTPUT DIFFERS: ' + JSON.stringify([g.out, c.out])}${spread}`);
  }
} finally {
  rmSync(work, { recursive: true, force: true });
}
// One line the gate's summary picks up: Grail's time over C's, per program.
console.log(`runtime-bench (${process.env.GRAIL_BACKEND ?? 'native'}): ${ratios.join(', ')}`);
if (failed) process.exit(1);
