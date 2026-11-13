// The typed IR's serializer, checked as a format rather than by eye (docs/design/typed-ir.md, "The
// serializer"). Compiles one fixture with `--emit-ir` and asserts:
//
//  1. the file opens with the version line, every unit ends with `end`, and no unit is empty;
//  2. each unit's declared counts (`ins`, `labels`, `calls`) equal the lines it carries;
//  3. every value id a `d=`/`u=` field names exists in the same unit's value table, or is 0;
//  4. the emitted assembly is byte-identical with and without the flag: the IR is a description of
//     the stream, so asking for it cannot change what the backend lowers;
//  5. the facts reach the IR: a fixture with an `f32` local has at least one value typed 1, and a
//     fixture with a `T[]` local has at least one value typed 2.
//
//   bun tools/ssair-ir.mjs [--compiler PATH]
import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { root, compilerSources } from './native.mjs';

const usage = 'usage: bun tools/ssair-ir.mjs [--compiler PATH] [--keep]';
function parse(argv) {
  const o = { compiler: null, keep: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--compiler') o.compiler = resolve(root, argv[++i]);
    else if (argv[i] === '--keep') o.keep = true;
    else if (argv[i] === '--help' || argv[i] === '-h') { console.log(usage); process.exit(0); }
    else throw new Error(`unknown argument ${argv[i]}\n${usage}`);
  }
  if (!o.compiler) {
    const fallback = join(root, '.work/ssair/new');
    if (existsSync(fallback)) o.compiler = fallback;
    else throw new Error(`no compiler: pass --compiler PATH\n${usage}`);
  }
  if (!existsSync(o.compiler)) throw new Error(`no compiler at ${o.compiler}`);
  return o;
}

const o = parse(process.argv.slice(2));
const work = join(root, '.work/ssair-ir');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

let failures = 0;
const check = (ok, what) => {
  if (ok) console.log(`ok    ${what}`);
  else { console.log(`FAIL  ${what}`); failures += 1; }
};

// Both variants are built from the same input path: the assembly embeds the source's path in its
// error-location strings, so a different path would be a difference that is not the flag's.
function compile(source, name, emitIr) {
  const dir = join(work, name);
  mkdirSync(dir, { recursive: true });
  const input = join(work, 'input.grl');
  writeFileSync(input, source);
  const out = join(dir, 'out.s');
  const flags = [o.compiler, '--target', 'x86_64', ...(emitIr ? ['--emit-ir'] : []), out,
    input, resolve(root, 'compiler/runtime.grl'), resolve(root, 'compiler/os-linux.grl')];
  const result = spawnSync(flags[0], flags.slice(1), { cwd: root, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (result.status !== 0) throw new Error(`${name}: compiler failed\n${result.stdout ?? ''}${result.stderr ?? ''}`);
  return { assembly: readFileSync(out, 'utf8'), ir: emitIr ? readFileSync(`${out}.tir`, 'utf8') : null };
}

// A unit is `fn ...` through its `end` line. Counts are checked against what the unit carries.
function units(text) {
  const lines = text.split('\n');
  const out = [];
  let current = null;
  for (const line of lines) {
    if (line.startsWith('fn ')) { current = { head: line, body: [] }; continue; }
    if (current === null) continue;
    if (line === 'end') { out.push(current); current = null; continue; }
    current.body.push(line);
  }
  return out;
}

const number = (head, key) => {
  const m = new RegExp(`\\b${key} (\\d+)`).exec(head);
  return m ? Number(m[1]) : null;
};

const fixture = `module irtest;

fn sum_of(input: u64[]) -> u64 {
    mut total = 0;
    for i in input.len() {
        total = total + input[i];
    }
    return total;
}

fn main() -> u64 {
    mut values = u64[];
    mut i = 0;
    while i < 5 {
        values.push(i * 3);
        i += 1;
    }
    ratio: f32 := 2.5;
    return sum_of(values) + u64(ratio);
}
`;

const withIr = compile(fixture, 'fixture', true);
const withoutIr = compile(fixture, 'fixture-plain', false);
const text = withIr.ir.endsWith('\n') ? withIr.ir : `${withIr.ir}\n`;
const all = units(text);

check(text.startsWith('ssair 1\n'), 'the file opens with the version line');
check(all.length > 0, `the file carries units (${all.length})`);
check(text.trimEnd().endsWith('end'), 'the last unit is terminated');
check(all.every(u => u.body.length > 0), 'no unit is empty');
const insOk = all.every(u => number(u.head, 'ins') === u.body.filter(l => l.startsWith('i ')).length);
const isLabel = line => /^i \d+ label /.test(line);
const labelsOk = all.every(u => number(u.head, 'labels') === u.body.filter(isLabel).length);
check(insOk, "each unit's `ins` count equals its `i` lines");
check(all.every(u => number(u.head, 'calls') === u.body.filter(l => l.startsWith('c ')).length), "each unit's `calls` count equals its `c` lines");
check(labelsOk, "each unit's `labels` count equals its label instructions");

// Every value a unit names must exist in that unit's table.
let dangling = 0;
for (const u of all) {
  const ids = new Set(u.body.filter(l => l.startsWith('v ')).map(l => Number(l.split(' ')[1])));
  for (const line of u.body) {
    if (!line.startsWith('i ')) continue;
    const fields = line.split(' ');
    for (const field of fields) {
      if (field.startsWith('d=')) { const id = Number(field.slice(2)); if (id !== 0 && !ids.has(id)) dangling += 1; }
      if (field.startsWith('u=')) {
        for (const part of field.slice(2).split(',')) { const id = Number(part); if (id !== 0 && !ids.has(id)) dangling += 1; }
      }
    }
  }
}
check(dangling === 0, `no instruction names a value outside its unit's table (${dangling} dangling)`);
check(withIr.assembly === withoutIr.assembly, 'the flag does not change the emitted assembly');

// Facts reach the IR: `ratio` is an f32 local (a slot of type 1) and `values` is a `u64[]` (type 2).
const types = new Set(all.flatMap(u => u.body.filter(l => l.startsWith('v ')).map(l => / ty=(\d+),/.exec(l)?.[1]).filter(Boolean)));
check(types.has('1'), 'an f32 slot reaches the IR as a typed value');
check(types.has('2'), 'a sequence header reaches the IR as a typed value');
const typed = all.flatMap(u => u.body.filter(l => l.startsWith('v ') && !/ ty=0,/.test(l))).length;
console.log(`${all.length} units, ${all.reduce((n, u) => n + u.body.filter(l => l.startsWith('i ')).length, 0)} instructions, ${typed} typed values, types ${[...types].sort().join(',')}`);

if (!o.keep) rmSync(work, { recursive: true, force: true });
console.log(failures === 0 ? 'ir: all checks passed' : `ir: ${failures} checks failed`);
process.exit(failures === 0 ? 0 : 1);
