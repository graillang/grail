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
//   bun tools/compile-perf.mjs            fail when a figure is more than 3% above the committed
//                                         baseline (bench/results/compile-perf.json), or when
//                                         syn4000 / syn1000 exceeds 4.4 (growth faster than linear)
//   bun tools/compile-perf.mjs --release  the same rows for the release compiler too (`release_`),
//                                         built or reused under the release lock; the post-landing
//                                         run (GRAIL_LAND_MODE=post) always measures them
//   bun tools/compile-perf.mjs --update   write the baseline from this run; a change that makes a
//                                         figure smaller updates it in the same commit
//   GRAIL_COMPILER names the compiler that builds the tree's (default: the tree's own build)
// The compiler measured is always stage 2: the tree's compiler built by the tree's compiler. How
// fast a compiler runs depends on the backend that compiled it, so a figure taken with a compiler
// some other seed built (an older checkout's, the landing service's base) measures that seed's
// code generation too, and two runners would disagree about one tree. Stage 2 is a function of the
// tree alone - the self-host fixed point is that stage 2 and stage 3 are the same bytes.
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { buildCompiler, root } from './native.mjs';
import { scalingProgram } from './compile-bench.mjs';
import { measurer } from './rivals/common.mjs';

const update = process.argv.includes('--update');
const baselinePath = join(root, 'bench/results/compile-perf.json');
const tolerance = 1.03;
const maxRatio = 4.4;
const work = join(root, '.work/compile-perf', `run-${process.pid}`);
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
process.on('exit', () => rmSync(work, { recursive: true, force: true }));
// Stage 1: the tree's compiler built by GRAIL_COMPILER (or the bootstrap); stage 2: built by stage 1.
const stage1 = buildCompiler();
const stage2 = spawnSync('bun', [join(root, 'tools/native.mjs'), 'build'], { cwd: root, encoding: 'utf8', env: { ...process.env, GRAIL_COMPILER: stage1 }, maxBuffer: 1 << 26 });
const compiler = stage2.status === 0 ? stage2.stdout.trim().split('\n').pop() : '';
if (!existsSync(compiler)) {
  console.error(`compile-perf: the tree's compiler did not build itself (stage 2)\n${stage2.stdout}${stage2.stderr}`);
  process.exit(1);
}
console.log(`compile-perf: measuring stage 2 ${compiler}`);
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
// One compiler's rows: the checks, then syn1000 built cold and after the edit, in one directory, so
// the second build has the first one's store. `prefix` names the compiler's rows.
const figures = {};
function rows(grail, prefix) {
  for (const [name, text] of Object.entries(programs)) {
    const dir = join(work, `${prefix}${name}`);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'main.grl'), text);
    cpSync(join(template, 'store'), join(dir, 'store'), { recursive: true });
    const env = { ...process.env, GRAIL_JOBS: '1', GRAIL_CACHE_DIR: join(dir, 'store') };
    const m = measure([grail, 'check', 'main.grl'], { cwd: dir, env });
    if (!(m.instructions > 0)) {
      console.error('compile-perf: the kernel refused perf_event (no instruction count); nothing measured');
      process.exit(2);
    }
    figures[`${prefix}${name}`] = m.instructions;
    console.log(`${(prefix + name).padEnd(28)} ${(m.instructions / 1e9).toFixed(3)} G instructions, ${text.split('\n').length} lines`);
  }
  const dir = join(work, `${prefix}build-syn1000`);
  mkdirSync(dir, { recursive: true });
  const text = programs.syn1000;
  cpSync(join(template, 'store'), join(dir, 'store'), { recursive: true });
  const env = { ...process.env, GRAIL_JOBS: '1', GRAIL_CACHE_DIR: join(dir, 'store') };
  const at = text.indexOf('% 1000', text.search(/fn work500\(/));
  const edited = text.slice(0, at) + '% 1001' + text.slice(at + 6);
  for (const [name, source] of [['build_syn1000', text], ['build_syn1000_edited', edited]]) {
    writeFileSync(join(dir, 'main.grl'), source);
    const m = measure([grail, 'build', 'main.grl'], { cwd: dir, env });
    figures[`${prefix}${name}`] = m.instructions;
    console.log(`${(prefix + name).padEnd(28)} ${(m.instructions / 1e9).toFixed(3)} G instructions`);
  }
}
rows(compiler, '');
const ratio = figures.syn4000 / figures.syn1000;
console.log(`syn4000/syn1000 ${ratio.toFixed(2)} (at most ${maxRatio})`);
// The shipped compiler is the release build (bun tools/native.mjs release): with --release (or in
// the landing service's post-landing run, GRAIL_LAND_MODE=post) its rows are measured and guarded
// too, `release_` before each name. GRAIL_RELEASE_COMPILER names one; otherwise the tree's is built
// - beside stage 2, so it is the tree's whatever seed started - or reused when it already is, under
// the host's release lock, because a release build is a whole-compiler clang run.
const releaseRows = process.argv.includes('--release') || process.env.GRAIL_LAND_MODE === 'post';
if (releaseRows) {
  let release = process.env.GRAIL_RELEASE_COMPILER;
  if (!release || !existsSync(release)) {
    const lock = process.env.GRAIL_RELEASE_LOCK ?? join(process.env.HOME ?? '/tmp', 'grail-release.lock');
    const built = spawnSync('flock', [lock, 'bun', join(root, 'tools/native.mjs'), 'release'], { cwd: root, encoding: 'utf8', env: { ...process.env, GRAIL_COMPILER: stage1, GRAIL_COMMAND_TIMEOUT: process.env.GRAIL_COMMAND_TIMEOUT ?? '3000' }, maxBuffer: 1 << 26 });
    release = built.status === 0 ? built.stdout.trim().split('\n').pop() : '';
    if (!existsSync(release)) {
      console.error(`compile-perf: the release compiler did not build\n${built.stdout}${built.stderr}`);
      process.exit(1);
    }
  }
  console.log(`compile-perf: measuring release ${release}`);
  rows(release, 'release_');
}

if (update) {
  const commit = spawnSync('git', ['-C', root, 'rev-parse', '--short=12', 'HEAD'], { encoding: 'utf8' }).stdout.trim() || 'unknown';
  // Rows this run did not measure (the release rows without --release) keep their baseline.
  const kept = existsSync(baselinePath) ? JSON.parse(readFileSync(baselinePath, 'utf8')) : {};
  const carried = Object.fromEntries(Object.entries(kept).filter(([k]) => k.startsWith('release_') && !(k in figures)));
  writeFileSync(baselinePath, `${JSON.stringify({ what: 'user instructions of `grail check` (hello, syn1000, syn4000) and `grail build` (syn1000 cold, then after a one-function edit), GRAIL_JOBS=1, the stage-2 dev compiler and (release_) the release compiler, a store `grail cache warm` filled (tools/compile-perf.mjs)', ...figures, ...carried, ratio: Number(ratio.toFixed(3)), head: commit }, null, 2)}\n`);
  console.log(`compile-perf: baseline written to ${baselinePath}`);
  process.exit(0);
}
const failures = [];
if (ratio > maxRatio) failures.push(`syn4000/syn1000 is ${ratio.toFixed(2)}: checking grows faster than the program (at most ${maxRatio})`);
if (!existsSync(baselinePath)) failures.push(`no baseline at ${baselinePath}: run with --update`);
else {
  const base = JSON.parse(readFileSync(baselinePath, 'utf8'));
  for (const name of Object.keys(figures)) {
    const band = tolerance;
    const was = base[name];
    // The release rows are guarded from the first baseline that has them (--release --update).
    if (!was && name.startsWith('release_')) { console.log(`${name}: no baseline yet (bun tools/compile-perf.mjs --release --update)`); continue; }
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
