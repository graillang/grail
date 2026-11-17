// What the bounds checks in a native build's assembly cost: one count per program, by the two shapes
// the front end and the optimizer leave behind.
//
//   bun tools/checks-native.mjs PROGRAM.s...
//
// A check is either a call to a sequence accessor that checks (`rt_slot`, `rt_slot4`, `rt_slotb`,
// `rt_at`, `rt_at4`, `rt_atb`, `rt_write`) or the arm the optimizer inlined out of one - `movq
// $1,%rdx` into `call rt_trap`, which is `rt_fail`'s index arm and nothing else in the program's own
// functions. Only the program's own functions count: the runtime's bodies carry their own arms and do
// not move with a proof (`--range-facts` / `--no-range-facts` and `--verify-facts` are what change
// this number, see docs/design/native-range-facts.md).
//
// The runtime's functions are the ones the front end emits without an `f_` prefix, so a build's `.s`
// splits into `.type NAME,@function` blocks and only `f_*` ones are read.
import { readFileSync } from 'node:fs';

const CHECKED = new Set(['rt_slot', 'rt_slot4', 'rt_slotb', 'rt_at', 'rt_at4', 'rt_atb', 'rt_write']);

function count(text) {
  const parts = text.split(/^\.type (\S+),@function$/m);
  let accessors = 0;
  let inlined = 0;
  for (let i = 1; i < parts.length; i += 2) {
    const name = parts[i];
    if (!name.startsWith('f_')) continue;
    const body = parts[i + 1].split('\n.type ')[0];
    for (const match of body.matchAll(/\bcall (rt_[a-z0-9_]+)\b/g)) {
      if (CHECKED.has(match[1])) accessors += 1;
    }
    inlined += (body.match(/movq \$1,%rdx\ncall rt_trap/g) ?? []).length;
  }
  return { accessors, inlined, total: accessors + inlined };
}

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('usage: bun tools/checks-native.mjs PROGRAM.s...');
  process.exit(1);
}
for (const file of files) {
  const r = count(readFileSync(file, 'utf8'));
  console.log(`${file.split('/').pop().padEnd(24)} ${String(r.total).padStart(4)}  (${r.accessors} accessor call${r.accessors === 1 ? '' : 's'}, ${r.inlined} inlined)`);
}
