// The build's jobserver (compiler/jobs.grl) and the parallel function bodies that take from it.
//
//  (a) a body worker that dies at once: the module is compiled anyway, to the bytes one process
//      writes, GRAIL_DEBUG says the rest went to one process, and every token is back in the fifo;
//  (b) GRAIL_JOBS bounds a whole build: a project of many modules, every module run and every worker
//      taking a token, never runs more than the bound allows at once;
//  (c) under `make -j`: a build started with MAKEFLAGS naming make's fifo takes its tokens from it,
//      makes no fifo of its own, and gives every token back.
//
// Usage: bun tools/jobs-test.mjs
import { spawn, spawnSync } from 'node:child_process';
import { closeSync, constants, existsSync, mkdirSync, openSync, readFileSync, readSync, rmSync, writeFileSync, writeSync } from 'node:fs';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { buildCompiler, root } from './native.mjs';
import { scalingProgram } from './compile-bench.mjs';

const compiler = buildCompiler();
const work = join(root, '.work/jobs-test');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

// A fifo holding `tokens` tokens, the way make makes one.
function makeFifo(path, tokens) {
  assert.equal(spawnSync('mkfifo', [path]).status, 0, 'mkfifo failed');
  const fd = openSync(path, constants.O_RDWR | constants.O_NONBLOCK);
  if (tokens) writeSync(fd, Buffer.alloc(tokens, 43));
  return fd;
}
// How many tokens are in it now (they are put back after counting).
function tokensIn(fd) {
  const buf = Buffer.alloc(256);
  let n = 0;
  try { n = readSync(fd, buf, 0, 256, null); } catch (error) { if (error.code !== 'EAGAIN') throw error; }
  if (n) writeSync(fd, buf.subarray(0, n));
  return n;
}
function compile(out, files, env) {
  const r = spawnSync(compiler, ['--target', 'x86_64', out, ...files], { cwd: root, encoding: 'utf8', env: { ...process.env, ...env }, maxBuffer: 1 << 26 });
  assert.equal(r.status, 0, `compile failed\n${r.stdout}${r.stderr}`);
  return `${r.stdout}${r.stderr}`;
}

// (a)
const syn = join(work, 'syn1000.grl');
writeFileSync(syn, scalingProgram(1000));
const files = [syn, join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')];
compile(join(work, 'one.s'), files, { GRAIL_JOBS: '1' });
const fifoA = join(work, 'fifo-a');
const fdA = makeFifo(fifoA, 3);
const said = compile(join(work, 'died.s'), files, { GRAIL_JOBSERVER: fifoA, GRAIL_JOBS: '4', GRAIL_BODY_SLICE: '2', GRAIL_TEST_BODY_WORKER_DIE: '1', GRAIL_DEBUG: '1' });
assert.ok(readFileSync(join(work, 'one.s')).equals(readFileSync(join(work, 'died.s'))), 'a module whose body worker died is not the one-process assembly');
assert.match(said, /compiled in one process/, `the fallback must be said under GRAIL_DEBUG:\n${said}`);
assert.equal(tokensIn(fdA), 3, 'a worker that died lost its token');
const parallel = compile(join(work, 'par.s'), files, { GRAIL_JOBSERVER: fifoA, GRAIL_JOBS: '4', GRAIL_DEBUG: '1' });
assert.ok(readFileSync(join(work, 'one.s')).equals(readFileSync(join(work, 'par.s'))), 'parallel bodies are not the one-process assembly');
assert.doesNotMatch(parallel, /compiled in one process/, 'a parallel compile that finished must not fall back');
assert.equal(tokensIn(fdA), 3, 'the tokens of a parallel compile must all come back');
closeSync(fdA);
console.log('jobs: (a) a body worker that died: the one-process bytes, the fallback said, every token back');

// (b) a project of 16 modules, built with GRAIL_JOBS=3.
const project = join(work, 'project');
mkdirSync(join(project, 'src'), { recursive: true });
writeFileSync(join(project, 'grail.toml'), '[package]\nname = "jobs"\nversion = "0.1.0"\n');
const uses = [];
for (let m = 0; m < 16; m++) {
  const fns = [];
  for (let f = 0; f < 40; f++) fns.push(`pub fn f${f}(x: u64) -> u64 {\n    mut y = x + ${f};\n    while y > 100 {\n        y = y / 3;\n    }\n    return y + ${m};\n}\n`);
  writeFileSync(join(project, `src/m${m}.grl`), `module m${m};\n\n${fns.join('\n')}`);
  uses.push(`m${m}`);
}
writeFileSync(join(project, 'src/main.grl'), `${uses.map(u => `use ${u};`).join('\n')}\n\npub fn main() -> u64 {\n    println(${uses.map(u => `${u}::f3(500)`).join(' + ')});\n    return 0;\n}\n`);
function build(env, sample) {
  return new Promise(resolve => {
    rmSync(join(project, 'target'), { recursive: true, force: true });
    const child = spawn(compiler, ['build', '--cache'], { cwd: project, env: { ...process.env, GRAIL_CACHE_DIR: join(work, `store-${Math.random()}`), ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    child.stdout.on('data', d => { out += d; });
    child.stderr.on('data', d => { out += d; });
    let peak = 0;
    // Only this build's processes: the gate runs other legs with the same compiler at the same
    // time, and counting every process on the machine counted theirs.
    const timer = sample ? setInterval(() => {
      const rows = spawnSync('ps', ['-eo', 'pid=,ppid=,args='], { encoding: 'utf8' }).stdout.split('\n')
        .map(line => line.trim().match(/^(\d+)\s+(\d+)\s+(.*)$/)).filter(Boolean)
        .map(m => ({ pid: Number(m[1]), ppid: Number(m[2]), args: m[3] }));
      const mine = new Set([child.pid]);
      for (let grew = true; grew;) {
        grew = false;
        for (const row of rows) if (!mine.has(row.pid) && mine.has(row.ppid)) { mine.add(row.pid); grew = true; }
      }
      const ps = rows.filter(row => mine.has(row.pid) && row.args.startsWith(compiler)).length;
      peak = Math.max(peak, ps);
    }, 25) : null;
    child.on('close', status => { if (timer) clearInterval(timer); resolve({ status, out, peak }); });
  });
}
const bounded = await build({ GRAIL_JOBS: '3' }, true);
assert.equal(bounded.status, 0, `the bounded build failed\n${bounded.out}`);
// The driver, and per token one module run - its wrapper and its compiler - or one worker.
assert.ok(bounded.peak <= 1 + 2 * 3, `GRAIL_JOBS=3 ran ${bounded.peak} compiler processes at once`);
assert.ok(!existsSync(join(project, 'target/jobs.jobs')), 'the build must remove its fifo');
console.log(`jobs: (b) 17 module runs under GRAIL_JOBS=3: at most ${bounded.peak} compiler processes at once`);

// (c) under make's jobserver.
const fifoC = join(work, 'fifo-make');
const fdC = makeFifo(fifoC, 2);
const underMake = await build({ MAKEFLAGS: ` -j3 --jobserver-auth=fifo:${fifoC}` }, true);
assert.equal(underMake.status, 0, `the build under make's jobserver failed\n${underMake.out}`);
assert.equal(tokensIn(fdC), 2, "a build under make's jobserver must give every token back");
assert.ok(underMake.peak <= 1 + 2 * 3, `make -j3 ran ${underMake.peak} compiler processes at once`);
closeSync(fdC);
console.log(`jobs: (c) under make -j3: at most ${underMake.peak} compiler processes at once, every token back`);
// (d) errors in bodies: three bodies of the 1000-function program refuse to check, one in each part
// of the module. Checked and compiled in one process and with the bodies forced across workers, the
// diagnostics, their order and the exit status are the same - a worker that hits an error stops,
// and the module goes back to one process, which reports what one process reports.
let broken = scalingProgram(1000);
for (const k of [120, 510, 930]) broken = broken.replace(`fn work${k}(v: &u64[], k: u64) -> u64 {\n    mut total = 0;`, `fn work${k}(v: &u64[], k: u64) -> u64 {\n    mut total = "text" + 1;`);
const brokenFile = join(work, 'broken.grl');
writeFileSync(brokenFile, broken);
const refuse = (args, env) => {
  const r = spawnSync(compiler, args, { cwd: work, encoding: 'utf8', env: { ...process.env, ...env }, maxBuffer: 1 << 26 });
  return { status: r.status, said: `${r.stdout}${r.stderr}` };
};
for (const [what, args] of [['grail check', ['check', brokenFile]], ['a compile', ['--target', 'x86_64', join(work, 'broken.s'), brokenFile, join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')]]]) {
  const one = refuse(args, { GRAIL_JOBS: '1' });
  const many = refuse(args, { GRAIL_JOBS: '4', GRAIL_BODY_SLICE: '2' });
  assert.notEqual(one.status, 0, `${what} of the broken program must fail`);
  assert.equal((one.said.match(/^error/gm) ?? []).length >= 3, true, `${what} must report the three errors:\n${one.said}`);
  assert.equal(many.status, one.status, `${what}: the exit status differs with parallel bodies`);
  assert.equal(many.said, one.said, `${what}: the diagnostics differ with parallel bodies`);
}
console.log('jobs: (d) errors in three bodies: the same diagnostics, in the same order, with the same status');
console.log('jobserver verified');
