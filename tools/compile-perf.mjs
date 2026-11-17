// The compile-speed guard of the landing gate (tools/landsvc/suites.txt): user-space instructions of
// `grail check` on hello world and on the scaling program at N = 1000 and 4000 (compile-bench's
// `scalingProgram`), single process (GRAIL_JOBS=1), with the tree's compiler. Each check starts from
// a copy of a store `grail cache warm` filled - the runtime, platform and every standard module, which
// a toolchain ships ready (the installer runs it) - so a figure is a project's first check, as
// compile-rivals measures it.
// And of `grail build` on syn1000 from the same store: cold, and again after a one-function edit
// (the first `% 1000` of work500 becomes `% 1001`), which is what the function store and the
// optimiser's memo exist for: an unchanged body is neither compiled nor optimised again.
// Instructions, not seconds: they do not move with the machine's load.
//   bun tools/compile-perf.mjs            fail when a check figure is more than 10% above the committed
//                                         baseline (bench/results/compile-perf.json), a build figure
//                                         more than 3% above it, or when syn4000 / syn1000 exceeds 4.4
//                                         (growth faster than linear)
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
const tolerance = 1.03;
const buildTolerance = 1.03;
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
// The toolchain's own modules - runtime, platform and standard library - checked and built once into
// a template store.
const template = join(work, 'template');
mkdirSync(template, { recursive: true });
writeFileSync(join(template, 'main.grl'), 'fn main() {\n    println("template");\n}\n');
measure([compiler, 'cache', 'warm'], { cwd: template, env: { ...process.env, GRAIL_CACHE_DIR: join(template, 'store') } });
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
// The builds: syn1000 cold and after the edit, in one directory, so the second build has the first
// one's store.
{
  const dir = join(work, 'build-syn1000');
  mkdirSync(dir, { recursive: true });
  const text = programs.syn1000;
  cpSync(join(template, 'store'), join(dir, 'store'), { recursive: true });
  const env = { ...process.env, GRAIL_JOBS: '1', GRAIL_CACHE_DIR: join(dir, 'store') };
  const at = text.indexOf('% 1000', text.search(/fn work500\(/));
  const edited = text.slice(0, at) + '% 1001' + text.slice(at + 6);
  for (const [name, source] of [['build_syn1000', text], ['build_syn1000_edited', edited]]) {
    writeFileSync(join(dir, 'main.grl'), source);
    const m = measure([compiler, 'build', 'main.grl'], { cwd: dir, env });
    figures[name] = m.instructions;
    console.log(`${name.padEnd(20)} ${(m.instructions / 1e9).toFixed(3)} G instructions`);
  }
}
const ratio = figures.syn4000 / figures.syn1000;
console.log(`syn4000/syn1000 ${ratio.toFixed(2)} (at most ${maxRatio})`);
// The shipped compiler is the release build (tools/ci.mjs buildTarget): GRAIL_RELEASE_COMPILER names
// one to measure beside the dev build. Reported only; the baseline stays the dev compiler's.
const release = process.env.GRAIL_RELEASE_COMPILER;
if (release && existsSync(release)) {
  for (const [name, text] of Object.entries(programs)) {
    const dir = join(work, `release-${name}`);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'main.grl'), text);
    cpSync(join(template, 'store'), join(dir, 'store'), { recursive: true });
    const m = measure([release, 'check', 'main.grl'], { cwd: dir, env: { ...process.env, GRAIL_JOBS: '1', GRAIL_CACHE_DIR: join(dir, 'store') } });
    console.log(`release ${name.padEnd(8)} ${(m.instructions / 1e9).toFixed(3)} G instructions (${(figures[name] / m.instructions).toFixed(2)}x fewer than the dev build)`);
  }
}

if (update) {
  const commit = spawnSync('git', ['-C', root, 'rev-parse', '--short=12', 'HEAD'], { encoding: 'utf8' }).stdout.trim() || 'unknown';
  writeFileSync(baselinePath, `${JSON.stringify({ what: 'user instructions of `grail check` (hello, syn1000, syn4000) and `grail build` (syn1000 cold, then after a one-function edit), GRAIL_JOBS=1, a store holding only the toolchain modules, dev compiler (tools/compile-perf.mjs)', ...figures, ratio: Number(ratio.toFixed(3)), head: commit }, null, 2)}\n`);
  console.log(`compile-perf: baseline written to ${baselinePath}`);
  process.exit(0);
}
const failures = [];
if (ratio > maxRatio) failures.push(`syn4000/syn1000 is ${ratio.toFixed(2)}: checking grows faster than the program (at most ${maxRatio})`);
if (!existsSync(baselinePath)) failures.push(`no baseline at ${baselinePath}: run with --update`);
else {
  const base = JSON.parse(readFileSync(baselinePath, 'utf8'));
  for (const name of Object.keys(figures)) {
    const band = name.startsWith('build_') ? buildTolerance : tolerance;
    const was = base[name];
    if (!was) { failures.push(`${name}: not in the baseline`); continue; }
    const change = figures[name] / was;
    const note = `${name}: ${(figures[name] / 1e9).toFixed(3)} G against ${(was / 1e9).toFixed(3)} G (${((change - 1) * 100).toFixed(1)}%)`;
    if (change > band) failures.push(`${note}, more than ${Math.round((band - 1) * 100)}% above the baseline`);
    else if (change < 1 / band) console.log(`${note}: faster - commit the new baseline (bun tools/compile-perf.mjs --update)`);
    else console.log(note);
  }
}
for (const f of failures) console.log(`FAIL ${f}`);
console.log(failures.length ? `compile-perf: ${failures.length} failed` : 'compile-perf: ok');
process.exit(failures.length ? 1 : 0);
