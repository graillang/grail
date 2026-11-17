// The compile-speed guard of the landing gate (tools/landsvc/suites.txt): user-space instructions of
// `grail check` on hello world and on the scaling program at N = 1000 and 4000 (compile-bench's
// `scalingProgram`), single process (GRAIL_JOBS=1), with the tree's compiler. Each check starts from
// a copy of a store that one hello-world check filled - the runtime, platform and core modules, which
// a toolchain ships ready - so a figure is a project's first check, as compile-rivals measures it.
// Instructions, not seconds: they do not move with the machine's load.
//   bun tools/compile-perf.mjs            fail when a figure is more than 10% above the committed
//                                         baseline (bench/results/compile-perf.json), or when
//                                         syn4000 / syn1000 exceeds 4.4 (growth faster than linear)
//   bun tools/compile-perf.mjs --update   write the baseline from this run; a change that makes a
//                                         figure smaller updates it in the same commit
//   GRAIL_COMPILER selects the compiler (default: build the tree's)
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { buildCompiler, root } from './native.mjs';
import { scalingProgram } from './compile-bench.mjs';
import { measurer } from './rivals/common.mjs';

const update = process.argv.includes('--update');
const baselinePath = join(root, 'bench/results/compile-perf.json');
const tolerance = 1.10;
const maxRatio = 4.4;
const work = join(root, '.work/compile-perf', `run-${process.pid}`);
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
process.on('exit', () => rmSync(work, { recursive: true, force: true }));
const compiler = process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER) ? process.env.GRAIL_COMPILER : buildCompiler();
const measure = measurer(root, join(root, '.work/compile-perf'));

const programs = {
  hello: 'fn main() {\n    println("hello, world");\n}\n',
  syn1000: scalingProgram(1000),
  syn4000: scalingProgram(4000),
};
// The toolchain's own modules, checked once into a template store.
const template = join(work, 'template');
mkdirSync(template, { recursive: true });
writeFileSync(join(template, 'main.grl'), 'fn main() {\n    println("template");\n}\n');
measure([compiler, 'check', 'main.grl'], { cwd: template, env: { ...process.env, GRAIL_JOBS: '1', GRAIL_CACHE_DIR: join(template, 'store') } });
const figures = {};
for (const [name, text] of Object.entries(programs)) {
  const dir = join(work, name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'main.grl'), text);
  cpSync(join(template, 'store'), join(dir, 'store'), { recursive: true });
  const env = { ...process.env, GRAIL_JOBS: '1', GRAIL_CACHE_DIR: join(dir, 'store') };
  const m = measure([compiler, 'check', 'main.grl'], { cwd: dir, env });
  if (!(m.instructions > 0)) {
    console.error('compile-perf: the kernel refused perf_event (no instruction count); nothing measured');
    process.exit(2);
  }
  figures[name] = m.instructions;
  console.log(`${name.padEnd(8)} ${(m.instructions / 1e9).toFixed(3)} G instructions, ${text.split('\n').length} lines`);
}
const ratio = figures.syn4000 / figures.syn1000;
console.log(`syn4000/syn1000 ${ratio.toFixed(2)} (at most ${maxRatio})`);

if (update) {
  const commit = spawnSync('git', ['-C', root, 'rev-parse', '--short=12', 'HEAD'], { encoding: 'utf8' }).stdout.trim() || 'unknown';
  writeFileSync(baselinePath, `${JSON.stringify({ what: 'user instructions of `grail check`, GRAIL_JOBS=1, a store holding only the toolchain modules, dev compiler (tools/compile-perf.mjs)', ...figures, ratio: Number(ratio.toFixed(3)), head: commit }, null, 2)}\n`);
  console.log(`compile-perf: baseline written to ${baselinePath}`);
  process.exit(0);
}
const failures = [];
if (ratio > maxRatio) failures.push(`syn4000/syn1000 is ${ratio.toFixed(2)}: checking grows faster than the program (at most ${maxRatio})`);
if (!existsSync(baselinePath)) failures.push(`no baseline at ${baselinePath}: run with --update`);
else {
  const base = JSON.parse(readFileSync(baselinePath, 'utf8'));
  for (const name of Object.keys(programs)) {
    const was = base[name];
    if (!was) { failures.push(`${name}: not in the baseline`); continue; }
    const change = figures[name] / was;
    const note = `${name}: ${(figures[name] / 1e9).toFixed(3)} G against ${(was / 1e9).toFixed(3)} G (${((change - 1) * 100).toFixed(1)}%)`;
    if (change > tolerance) failures.push(`${note}, more than ${Math.round((tolerance - 1) * 100)}% above the baseline`);
    else if (change < 1 / tolerance) console.log(`${note}: faster - commit the new baseline (bun tools/compile-perf.mjs --update)`);
    else console.log(note);
  }
}
for (const f of failures) console.log(`FAIL ${f}`);
console.log(failures.length ? `compile-perf: ${failures.length} failed` : 'compile-perf: ok');
process.exit(failures.length ? 1 : 0);
