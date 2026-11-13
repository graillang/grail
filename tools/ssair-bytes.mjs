// Byte-identity harness for the typed-IR stage (docs/design/typed-ir.md, "A typed IR with SSA
// values"). It compiles one input with two compilers -- the tree-built compiler from before a
// change and the one after it -- and compares the emitted x86-64 assembly word for word, per
// function, so a change to the word stream cannot land by accident.
//
// The unit of comparison is one emitted function: from its `.type NAME,@function` line up to and
// including its `.size` line. The text between functions (`.data`, string pools, vtable words,
// directives) is compared as one more unit per run, so a difference that is not a function body
// cannot hide.
//
//   bun tools/ssair-bytes.mjs --old .work/ssair/old --new .work/ssair/new [--filter RE] [--jobs N]
//   bun tools/ssair-bytes.mjs --old A --new B --self      the compiler's own sources
//
// Exit status is 0 only when every unit matched.
import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { availableParallelism } from 'node:os';
import { root, compilerSources } from './native.mjs';

const usage = `usage: bun tools/ssair-bytes.mjs --old PATH --new PATH [options]

  --old PATH      the pre-change compiler (tree-built from the parent commit)
  --new PATH      the compiler under test
  --filter RE     only cases whose name matches RE
  --jobs N        cases in flight at once (default: half the CPUs)
  --limit N       stop after N cases
  --self          compile compiler/*.grl with both compilers and compare (not the corpus)
  --keep          keep the emitted .s files under .work/ssair-bytes/
  --show N        print N differing units per case (default 2)
  --list          print the selected case names and exit
`;

function parse(argv) {
  const o = {
    old: null, new: null, filter: null, limit: 0, self: false, keep: false, show: 2, list: false,
    jobs: Math.max(1, Math.floor(availableParallelism() / 2)),
    paths: [],
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const v = () => { if (i + 1 >= argv.length) throw new Error(`${a} needs a value\n${usage}`); return argv[++i]; };
    if (a === '--old') o.old = resolve(root, v());
    else if (a === '--new') o.new = resolve(root, v());
    else if (a === '--filter') o.filter = new RegExp(v());
    else if (a === '--jobs') o.jobs = Number(v());
    else if (a === '--limit') o.limit = Number(v());
    else if (a === '--self') o.self = true;
    else if (a === '--keep') o.keep = true;
    else if (a === '--show') o.show = Number(v());
    else if (a === '--list') o.list = true;
    else if (a === '--help' || a === '-h') { console.log(usage); process.exit(0); }
    else if (a.startsWith('-')) throw new Error(`unknown flag ${a}\n${usage}`);
    else o.paths.push(a);
  }
  if (!o.old || !o.new) throw new Error(`both --old and --new are required\n${usage}`);
  for (const path of [o.old, o.new]) if (!existsSync(path)) throw new Error(`no compiler at ${path}`);
  return o;
}

// Resolves with the exit status and the merged output; never rejects on a non-zero compiler exit.
function run(argv) {
  return new Promise((done, fail) => {
    const child = spawn(argv[0], argv.slice(1), { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    child.stdout.on('data', d => { out += d; });
    child.stderr.on('data', d => { out += d; });
    child.on('error', fail);
    child.on('close', status => done({ status, out }));
  });
}

// One emitted function per unit, plus the "(no function)" runs for the text between bodies. The
// stream marks a body with `.type NAME,@function` and has no `.size`, so a body runs from its
// `.type` line to the line before the next one. A symbol emitted twice keeps distinct units by
// carrying its occurrence index.
function units(text) {
  const out = [];
  let pending = [];
  let current = null;
  const occurrences = new Map();
  const nameOf = (symbol) => {
    const n = occurrences.get(symbol) ?? 0;
    occurrences.set(symbol, n + 1);
    return n === 0 ? symbol : `${symbol}#${n + 1}`;
  };
  const flush = () => {
    if (pending.length === 0) return;
    out.push({ name: '(no function)', text: pending.join('\n') });
    pending = [];
  };
  for (const line of text.split('\n')) {
    const start = /^\.type ([^,]+),@function$/.exec(line);
    if (start) {
      if (current === null) flush(); else out.push(current);
      current = { name: nameOf(start[1]), text: [line] };
      continue;
    }
    if (current === null) pending.push(line); else current.text.push(line);
  }
  if (current !== null) out.push(current);
  flush();
  // Two `(no function)` runs that are adjacent in the file stay distinct units: one before the
  // first body and one after the last.
  let run = 0;
  for (const unit of out) if (unit.name === '(no function)') { run += 1; if (run > 1) unit.name = `(no function)#${run}`; }
  return out;
}

function words(text) {
  return text.split(/[ \t\n\r]+/).filter(w => w.length !== 0);
}

// null when the two files are byte-identical, else the differing units and the first words that moved.
function compare(oldText, newText, show) {
  if (oldText === newText) return { identical: true, total: units(newText).length, differing: 0, lines: [] };
  const before = units(oldText);
  const after = units(newText);
  const index = new Map();
  for (const u of before) index.set(u.name, u);
  const lines = [];
  let differing = 0;
  const seen = new Set();
  for (const u of after) {
    seen.add(u.name);
    const was = index.get(u.name);
    if (was === undefined) {
      differing += 1;
      if (lines.length < show) lines.push(`  + ${u.name}: only in the new stream`);
      continue;
    }
    if (was.text === u.text) continue;
    differing += 1;
    if (lines.length < show) {
      const a = words(was.text);
      const b = words(u.text);
      let k = 0;
      while (k < a.length && k < b.length && a[k] === b[k]) k += 1;
      lines.push(`  ! ${u.name}: ${a.length} -> ${b.length} words, first difference at word ${k}`);
      lines.push(`      old: ${a.slice(Math.max(0, k - 3), k + 6).join(' ')}`);
      lines.push(`      new: ${b.slice(Math.max(0, k - 3), k + 6).join(' ')}`);
    }
  }
  for (const u of before) if (!seen.has(u.name)) {
    differing += 1;
    if (lines.length < show) lines.push(`  - ${u.name}: only in the old stream`);
  }
  return { identical: false, total: after.length, differing, lines };
}

// One corpus case: the same source in the same directory for both compilers, so a relative path in
// the source cannot resolve differently between them.
async function corpusCase(test, o, work) {
  const dir = join(work, `case-${test.name}`);
  mkdirSync(dir, { recursive: true });
  let files;
  if (test.files) files = test.files.map(f => resolve(root, f));
  else {
    const input = join(dir, 'input.grl');
    writeFileSync(input, test.source);
    files = [input, ...(test.modules ?? []).map(m => resolve(root, m))];
  }
  const flags = test.flags ?? [];
  const overflow = test.overflow ?? 'checked';
  const sources = [...files, resolve(root, 'compiler/runtime.grl'), resolve(root, 'compiler/os-linux.grl')];
  const emit = async (compiler, name) => {
    const out = join(dir, `${name}.s`);
    const result = await run([compiler, ...flags, '--target', 'x86_64', `--overflow=${overflow}`, out, ...sources]);
    if (result.status !== 0) throw new Error(`${name} compiler refused the case: ${result.out.trim().split('\n').slice(0, 3).join(' | ')}`);
    return readFileSync(out, 'utf8');
  };
  return compare(await emit(o.old, 'old'), await emit(o.new, 'new'), o.show);
}

async function selfCheck(o, work) {
  const dir = join(work, 'self');
  mkdirSync(dir, { recursive: true });
  const emit = async (compiler, name) => {
    const out = join(dir, `${name}.s`);
    const result = await run([compiler, '--target', 'x86_64', out, ...compilerSources]);
    if (result.status !== 0) throw new Error(`${name} compiler refused the compiler's own sources: ${result.out.trim().split('\n').slice(0, 3).join(' | ')}`);
    return readFileSync(out, 'utf8');
  };
  return compare(await emit(o.old, 'old'), await emit(o.new, 'new'), o.show);
}

async function main() {
  const o = parse(process.argv.slice(2));
  const work = join(root, '.work/ssair-bytes');
  if (existsSync(work)) rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  const started = Date.now();
  const report = (ok, what, cases, units, differingCases, differingUnits) => {
    const seconds = ((Date.now() - started) / 1000).toFixed(1);
    console.log(`${ok ? 'identical' : 'DIFFERENT'}  ${what}  ${cases} cases, ${units} function units, ${differingCases} differing cases, ${differingUnits} differing units  ${seconds}s`);
  };
  if (o.self) {
    const diff = await selfCheck(o, work);
    if (!diff.identical) {
      console.error('the compiler\'s own sources differ:');
      console.error(diff.lines.join('\n'));
    }
    report(diff.identical, 'self sources', 1, diff.total, diff.identical ? 0 : 1, diff.differing);
    if (!o.keep) rmSync(work, { recursive: true, force: true });
    process.exit(diff.identical ? 0 : 1);
  }
  const all = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
  const selected = all
    .filter(t => !t.reject)
    .filter(t => !t.targets || t.targets.includes('x86_64'))
    .filter(t => !t.backends || t.backends.includes('native'))
    .filter(t => !o.filter || o.filter.test(t.name))
    .filter(t => o.paths.length === 0 || o.paths.some(p => t.name.includes(p)))
    .slice(0, o.limit || undefined);
  if (selected.length === 0) throw new Error('no cases selected');
  if (o.list) { for (const t of selected) console.log(t.name); process.exit(0); }
  const failures = [];
  let completed = 0;
  let unitsCompared = 0;
  let next = 0;
  const worker = async () => {
    for (;;) {
      const i = next++;
      if (i >= selected.length) return;
      const test = selected[i];
      try {
        const diff = await corpusCase(test, o, work);
        completed += 1;
        unitsCompared += diff.total;
        if (!diff.identical) failures.push({ name: test.name, diff });
      } catch (error) {
        completed += 1;
        failures.push({ name: test.name, error: String(error.message ?? error) });
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(Math.max(1, o.jobs), selected.length) }, worker));
  failures.sort((a, b) => (a.name < b.name ? -1 : 1));
  for (const f of failures.slice(0, 8)) {
    console.error(`case ${f.name}:`);
    if (f.error) console.error(`  ${f.error}`);
    else { console.error(`  ${f.diff.differing}/${f.diff.total} units differ`); console.error(f.diff.lines.join('\n')); }
  }
  if (failures.length > 8) console.error(`... and ${failures.length - 8} more differing cases`);
  report(failures.length === 0, 'corpus x86_64', completed, unitsCompared, failures.length,
    failures.reduce((n, f) => n + (f.diff ? f.diff.differing : 0), 0));
  if (o.keep) console.log(`emitted assembly kept under ${work}`);
  else rmSync(work, { recursive: true, force: true });
  process.exit(failures.length === 0 ? 0 : 1);
}

main();
