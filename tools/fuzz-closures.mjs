#!/usr/bin/env bun
// A differential fuzzer for closure passing (docs/design/dyn-and-callable-bounds.md, S6(A)).
//
//   bun tools/fuzz-closures.mjs [--cases N] [--seed S] [--jobs J] [--timeout MS] [--keep] [--compiler PATH]
//
// A closure that captures heap data is built and then sent down a random chain of the paths a
// closure value can take - an erased `Fn(..)` parameter, a generic `F: Fn(..)` parameter, a
// `Fn<Owned>` field, a `Keep<F>` field, a vector of closures, a return value, a `&Fn(..)` borrow, a
// capture by another closure, a job payload - and is called at the end. Each program knows the value
// it must print. A missed erase (a frame address kept where a boxed object belongs) shows up as a
// crash or a wrong value; a program the language refuses with a diagnostic is fine.
//
//   fine   printed the expected value, or the compiler refused it with a located diagnostic
//   bug    a crash (signal), a wrong value, a compiler crash or internal error, or a timeout
//
// Deterministic from --seed. Working files live under `.work/fuzz-closures/`. The generated programs
// of a run are what /root/atomics folds into the fuzz seed: `--keep` leaves them in place.
import { spawn } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCompiler } from './native.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const work = join(root, '.work/fuzz-closures');

function parse(argv) {
  const o = { cases: 60, seed: 1, jobs: 4, timeout: 120000, keep: false, compiler: '' };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--cases') o.cases = Number(argv[++i]);
    else if (a === '--seed') o.seed = Number(argv[++i]);
    else if (a === '--jobs') o.jobs = Number(argv[++i]);
    else if (a === '--timeout') o.timeout = Number(argv[++i]);
    else if (a === '--keep') o.keep = true;
    else if (a === '--compiler') o.compiler = argv[++i];
    else throw new Error(`fuzz-closures: unknown option ${a}`);
  }
  return o;
}

function rng(seed) {
  let s = seed >>> 0 || 1;
  return {
    next(n) { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s % n; },
  };
}

// The steps a closure value can take. Each turns an expression `e` (of the closure's type, a
// closure literal at the start) into statements and a new expression, using helpers declared once.
// `owned` steps need a closure that captures no borrow; the generator only captures owned data.
const helpers = `struct Hold { f: Fn<Owned>() -> u64 }
struct Keep<F> { f: F }
fn erased(f: Fn() -> u64) -> u64 { return f(); }
fn erased_mut(f: FnMut() -> u64) -> u64 { mut g = f; return g(); }
fn generic<F: Fn() -> u64>(f: F) -> u64 { return f(); }
fn by_ref(f: &Fn() -> u64) -> u64 { return f(); }
fn keep<F: Fn() -> u64>(f: F) -> Keep<F> { return Keep { f: f }; }
fn give(f: Fn<Owned>() -> u64) -> Fn<Owned>() -> u64 { return f; }
fn twice_generic<F: Fn() -> u64>(f: F) -> u64 { g := || -> u64 f(); return g(); }
fn call_keep<F: Fn() -> u64>(f: F) -> u64 { k := keep(f); g := &k.f; return g(); }
`;

// Terminal uses consume the value and produce a u64; transforms keep a closure.
const transforms = [
  // name, needs the value to be a local, produces lines and the new variable's name
  { name: 'field', make: (v, n) => [`h${n} := Hold { f: ${v} };`, `c${n} := h${n}.f;`] },
  { name: 'vector', make: (v, n) => [`mut vs${n} = (Fn<Owned>() -> u64)[];`, `vs${n}.push(${v});`, `c${n} := vs${n}.pop()!;`] },
  { name: 'returned', make: (v, n) => [`c${n} := give(${v});`] },
  { name: 'nested', make: (v, n) => [`inner${n} := ${v};`, `c${n} := || -> u64 inner${n}();`] },
  { name: 'alias', make: (v, n) => [`c${n} := ${v};`] },
];
const terminals = [
  { name: 'call', make: v => `${v}()` },
  { name: 'erased', make: v => `erased(${v})` },
  { name: 'erased_mut', make: v => `erased_mut(${v})` },
  { name: 'generic', make: v => `generic(${v})` },
  { name: 'by_ref', make: v => `by_ref(&${v})` },
  { name: 'keep', make: v => `call_keep(${v})` },
  { name: 'twice_generic', make: v => `twice_generic(${v})` },
  { name: 'job', make: v => `parallel_join(parallel_spawn(${v}))` },
];

function generate(random, index) {
  const n = 1 + random.next(4);
  const values = Array.from({ length: n }, () => 1 + random.next(9));
  const k = random.next(100);
  const expected = values.reduce((a, b) => a + b, 0) + k;
  const lines = [`    data := u64[${values.join(', ')}];`, `    k := ${k};`];
  // The closure owns its data (moved in), so every path - including the Owned ones - accepts it.
  lines.push(`    c0 := || -> u64 { mut t = k; for i in data.len() { t += data[i]; } return t; };`);
  let current = 'c0';
  const steps = random.next(4);
  const path = [];
  for (let s = 1; s <= steps; s += 1) {
    const t = transforms[random.next(transforms.length)];
    for (const line of t.make(current, s)) lines.push(`    ${line}`);
    current = `c${s}`;
    path.push(t.name);
  }
  const term = terminals[random.next(terminals.length)];
  path.push(term.name);
  lines.push(`    r := ${term.make(current)};`);
  lines.push('    println(r);');
  const source = `${helpers}fn main() {\n${lines.join('\n')}\n}\n`;
  return { id: String(index + 1).padStart(4, '0'), path: path.join(' > '), source, expected: `${expected}\n` };
}

function run(cmd, args, cwd, timeout) {
  return new Promise(done => {
    const child = spawn(cmd, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    let err = '';
    child.stdout.on('data', d => { out += d; });
    child.stderr.on('data', d => { err += d; });
    const timer = setTimeout(() => child.kill('SIGKILL'), timeout);
    child.on('close', (status, signal) => { clearTimeout(timer); done({ status, signal, out, err }); });
  });
}

function classify(c, r) {
  if (r.signal) return { verdict: 'bug', why: `signal ${r.signal}` };
  if (r.status === 0) return r.out === c.expected ? { verdict: 'fine' } : { verdict: 'bug', why: `printed ${JSON.stringify(r.out)}, expected ${JSON.stringify(c.expected)}` };
  const text = r.err + r.out;
  if (/internal|assertion failed|out of bounds|unwrap of None/.test(text)) return { verdict: 'bug', why: text.split('\n')[0] };
  if (/^error(\[E\d+\])?: /m.test(text) && / --> /.test(text)) return { verdict: 'fine', why: `refused: ${text.split('\n')[0]}` };
  return { verdict: 'bug', why: `exit ${r.status}: ${text.split('\n')[0]}` };
}

async function main() {
  const o = parse(process.argv.slice(2));
  const compiler = o.compiler || buildCompiler();
  const random = rng(o.seed);
  const cases = Array.from({ length: o.cases }, (_, i) => generate(random, i));
  rmSync(work, { recursive: true, force: true });
  const results = [];
  let next = 0;
  const worker = async () => {
    for (;;) {
      const i = next++;
      if (i >= cases.length) return;
      const c = cases[i];
      const dir = join(work, c.id);
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'main.grl'), c.source);
      const r = await run(compiler, ['run', 'main.grl', '--no-cache'], dir, o.timeout);
      const v = classify(c, r);
      results[i] = { ...c, ...v };
      if (v.verdict === 'fine' && !o.keep) rmSync(dir, { recursive: true, force: true });
    }
  };
  await Promise.all(Array.from({ length: Math.min(o.jobs, cases.length) }, worker));
  const bugs = results.filter(r => r.verdict === 'bug');
  const refused = results.filter(r => r.verdict === 'fine' && r.why);
  for (const b of bugs) console.log(`BUG ${b.id} [${b.path}]: ${b.why} (${join(work, b.id, 'main.grl')})`);
  const byPath = new Map();
  for (const r of refused) byPath.set(r.why, (byPath.get(r.why) ?? 0) + 1);
  for (const [why, n] of byPath) console.log(`refused x${n}: ${why}`);
  console.log(`fuzz-closures: seed ${o.seed}, ${cases.length} cases, ${cases.length - bugs.length} fine (${refused.length} refused), ${bugs.length} bugs`);
  process.exit(bugs.length === 0 ? 0 : 1);
}

await main();
