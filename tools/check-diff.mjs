// The front end's differential guard: two compilers given the same inputs must say the same thing.
// Every corpus case (tests/native-cases.json: inline sources and files, with the modules they list)
// and every standalone example (compiler/tests, book/examples, examples) is compiled by BASE and by
// NEW, and their exit status, stdout and stderr are compared byte for byte; with --build the
// assembly they wrote is compared too. Meant for changes that must not move a verdict or a
// diagnostic: a speed-up of the parser, the checker or the borrow checker.
//   bun tools/check-diff.mjs --base OLD_COMPILER [--new NEW_COMPILER] [--build] [--filter REGEX]
//                            [--jobs N] [--keep]
// --new defaults to this tree's compiler (`bun tools/native.mjs which`). Without --build each
// compile is `--check`, the run `grail check` makes. Exit 1 when anything differs, listing it.
import { spawn, execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';
import { root } from './platforms.mjs';

const argv = process.argv.slice(2);
const option = (name, fallback = null) => { const at = argv.indexOf(name); return at < 0 ? fallback : argv[at + 1]; };
const base = option('--base') && resolve(option('--base'));
if (!base) { console.error('usage: bun tools/check-diff.mjs --base OLD [--new NEW] [--build] [--filter REGEX] [--jobs N] [--keep]'); process.exit(2); }
const fresh = option('--new') ? resolve(option('--new')) : execFileSync('bun', [join(root, 'tools/native.mjs'), 'which'], { encoding: 'utf8' }).trim().split('\n').pop();
const build = argv.includes('--build');
const filter = option('--filter') ? new RegExp(option('--filter')) : null;
const jobs = Number(option('--jobs', '4'));
const work = join(root, '.work/check-diff');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

const runtime = join(root, 'compiler/runtime.grl');
const platform = join(root, 'compiler/os-linux.grl');
const roots = ['--module-root', join(root, 'lib')];

// ---- the inputs ------------------------------------------------------------------------------
const jobsList = [];
const cases = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
cases.forEach((test, i) => {
  if (test.driver || test.project || test.interfaces || test.interfaceFiles || test.roots || test.pending) return;
  if (test.targets && !test.targets.includes('x86_64')) return;
  if (test.backends && !test.backends.includes('native')) return;
  const dir = join(work, `case-${i}`);
  let files;
  if (test.files) files = [...test.files, ...(test.modules ?? [])].map(f => resolve(root, f));
  else if (test.source !== undefined) { mkdirSync(dir, { recursive: true }); writeFileSync(join(dir, 'input.grl'), test.source); files = [join(dir, 'input.grl'), ...(test.modules ?? []).map(f => resolve(root, f))]; }
  else return;
  const extra = [...(test.noRoots ? [] : roots), '--overflow=' + (test.overflow ?? 'checked'), ...(test.flags ?? [])];
  jobsList.push({ name: test.name, dir, files, extra });
});
const walk = dir => readdirSync(dir).flatMap(f => { const p = join(dir, f); return statSync(p).isDirectory() ? walk(p) : (f.endsWith('.grl') ? [p] : []); });
for (const dir of ['compiler/tests', 'book/examples', 'examples']) {
  for (const file of walk(join(root, dir))) {
    const name = file.slice(root.length + 1);
    jobsList.push({ name, dir: join(work, name.replaceAll('/', '_')), files: [file], extra: [...roots, '--overflow=checked'] });
  }
}
const selected = jobsList.filter(j => !filter || filter.test(j.name));

// ---- running ---------------------------------------------------------------------------------
function run(compiler, job, side) {
  const dir = join(job.dir, side);
  mkdirSync(dir, { recursive: true });
  const asm = join(dir, 'out.s');
  const args = ['--target', 'x86_64', ...(build ? [] : ['--check']), ...job.extra, asm, ...job.files, runtime, platform];
  return new Promise(done => {
    const child = spawn(compiler, args, { cwd: job.dir, stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, GRAIL_JOBS: '1' } });
    const out = [], err = [];
    child.stdout.on('data', d => out.push(d));
    child.stderr.on('data', d => err.push(d));
    const timer = setTimeout(() => child.kill('SIGKILL'), 600000);
    child.on('error', error => { clearTimeout(timer); done({ status: -1, signal: String(error), stdout: '', stderr: '', asm: null }); });
    child.on('close', (status, signal) => {
      clearTimeout(timer);
      done({ status, signal, stdout: Buffer.concat(out).toString(), stderr: Buffer.concat(err).toString(), asm: build && existsSync(asm) ? readFileSync(asm) : null });
    });
  });
}
const differences = [];
let next = 0, done = 0;
async function worker() {
  while (next < selected.length) {
    const job = selected[next++];
    mkdirSync(job.dir, { recursive: true });
    const [a, b] = await Promise.all([run(base, job, 'base'), run(fresh, job, 'new')]);
    if (a.status === -1 || b.status === -1) { console.error(`check-diff: cannot run a compiler: ${a.signal ?? ''} ${b.signal ?? ''}`); process.exit(2); }
    const why = [];
    if (a.status !== b.status || a.signal !== b.signal) why.push(`exit ${a.status}/${a.signal} -> ${b.status}/${b.signal}`);
    if (a.stdout !== b.stdout) why.push('stdout differs');
    if (a.stderr !== b.stderr) why.push('stderr differs');
    if (build && !(a.asm === null ? b.asm === null : (b.asm !== null && a.asm.equals(b.asm)))) why.push('assembly differs');
    if (why.length) {
      differences.push({ name: job.name, why, a, b });
      writeFileSync(join(job.dir, 'diff.txt'), `${why.join('; ')}\n--- base\n${a.stdout}${a.stderr}\n--- new\n${b.stdout}${b.stderr}\n`);
    } else if (!argv.includes('--keep')) rmSync(job.dir, { recursive: true, force: true });
    done++;
  }
}
await Promise.all(Array.from({ length: jobs }, worker));
for (const d of differences) {
  console.log(`DIFF ${d.name}: ${d.why.join('; ')}`);
  if (d.a.stdout + d.a.stderr !== d.b.stdout + d.b.stderr) console.log(`  base: ${JSON.stringify((d.a.stdout + d.a.stderr).slice(0, 400))}\n  new:  ${JSON.stringify((d.b.stdout + d.b.stderr).slice(0, 400))}`);
}
console.log(`check-diff: ${done} inputs (${build ? 'build' : 'check'}), ${differences.length} differ${filter ? `, filter ${filter}` : ''}`);
process.exit(differences.length ? 1 : 0);
