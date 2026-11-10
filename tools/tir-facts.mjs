// Counts the call sites a typed-IR fact would have to cover in the word stream the LLVM
// lifter consumes (docs/design/typed-ir.md). Measurement only: it reads a stream, never
// changes what the compiler emits, and is not wired into the test suite.
//
//   grail --debug --target x86_64 --overflow=checked OUT.s ENTRY.grl runtime.grl os-linux.grl
//   bun tools/tir-facts.mjs OUT.s [OUT.s...]
//
// `--debug` skips optimize.grl and writes the raw stream, which is exactly what
// `--backend=llvm` lowers (compiler/native.grl: `debug != 0 || backend != 0`).
//
// Columns, counted per function in .text:
//   F1   calls whose first word is a sequence header `{data, len, cap}`: the sites that
//        would carry "this word points at a header of element width W".
//   F2   `call rt_f32_round`: the front end emits one per f32 arithmetic result, so it
//        marks an f32-valued word exactly.
//   fop  `call rt_f64_op` / `rt_f64_cmp`: arithmetic that becomes real float arithmetic
//        when both operands are f32.
//   F1%  F1 sites in functions whose name starts with rt_ (the runtime helpers that are
//        inlined into the hot loop, so their parameters need the fact too).
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';

const headers = new Set([
  'rt_new', 'rt_slot', 'rt_slotu', 'rt_slot4', 'rt_slot4u', 'rt_slotb',
  'rt_at', 'rt_at4', 'rt_atb', 'rt_atbu', 'rt_len', 'rt_push', 'rt_push4', 'rt_pushb',
  'rt_fill', 'rt_fill4', 'rt_fillb', 'rt_write', 'rt_view', 'rt_slice', 'rt_vslice',
  'rt_reserve', 'rt_reserveb',
]);
const floats = new Set(['rt_f64_op', 'rt_f64_cmp']);
const columns = ['F1', 'F2', 'fop'];

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('usage: bun tools/tir-facts.mjs STREAM.s [STREAM.s...]');
  process.exit(1);
}

for (const file of files) {
  const per = new Map();
  let section = '.text';
  let fn = '?';
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    const directive = /^\s*\.(text|section|bss|data|rodata)\b/.exec(line);
    if (directive) {
      section = directive[1] === 'section' ? (/\.section\s+(\S+)/.exec(line)?.[1] ?? '') : `.${directive[1]}`;
      continue;
    }
    const label = /^([A-Za-z_][\w.$]*):$/.exec(line);
    if (label && section === '.text') { fn = label[1]; continue; }
    const call = /^call (rt_[a-z0-9_]+)$/.exec(line);
    if (!call) continue;
    const row = per.get(fn) ?? { F1: 0, F2: 0, fop: 0 };
    if (headers.has(call[1])) row.F1 += 1;
    if (call[1] === 'rt_f32_round') row.F2 += 1;
    if (floats.has(call[1])) row.fop += 1;
    per.set(fn, row);
  }
  const zero = () => ({ F1: 0, F2: 0, fop: 0 });
  const sum = keep => {
    const out = zero();
    for (const [name, row] of per) if (keep(name)) for (const c of columns) out[c] += row[c];
    return out;
  };
  const show = (label, row) =>
    console.log(`  ${label.padEnd(16)}${columns.map(c => String(row[c]).padStart(7)).join('')}`);
  const program = sum(name => !name.startsWith('rt_'));
  const runtime = sum(name => name.startsWith('rt_'));
  const total = sum(() => true);
  console.log(`${basename(file)}: ${per.size} functions with relocatable calls`);
  show('', Object.fromEntries(columns.map(c => [c, c])));
  show('program', program);
  show('runtime', runtime);
  show('all', total);
}
