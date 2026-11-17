// The internal assembler's name-table ids (compiler/asm_x86.grl): every directive (D_), instruction
// (I_) and register (R_) id is one named constant, no two share a value (a ranged group - I_JCC,
// I_SETCC, I_CMOV - owns 16 from its base), ids stay in their spaces, no use site writes an id as a
// number, and every instruction mnemonic is encoded once in tests/asm/directives-x86_64.s or
// directives-windows-x86_64.s, which the asm-oracle suite holds against clang. Two mnemonics once
// shared an id and one silently encoded as the other.
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const root = join(import.meta.dir, '..');
const source = readFileSync(join(root, 'compiler/asm_x86.grl'), 'utf8');
const problems = [];
const consts = new Map();
for (const m of source.matchAll(/^const ([DIR]_[A-Z0-9_]+): u64 = (\d+);/gm)) consts.set(m[1], Number(m[2]));
const ranged = { I_JCC: 16, I_SETCC: 16, I_CMOV: 16 };
const bounds = new Set(['D_LAST', 'I_FIRST', 'R_BASE']);
const owner = new Map();
for (const [name, value] of consts) {
  if (bounds.has(name)) continue;
  const width = ranged[name] ?? 1;
  for (let v = value; v < value + width; v++) {
    if (owner.has(v)) problems.push(`id ${v}: ${owner.get(v)} and ${name}`);
    owner.set(v, name);
  }
  const space = name[0];
  const last = consts.get('D_LAST'), first = consts.get('I_FIRST'), base = consts.get('R_BASE');
  if (space === 'D' && !(value >= 1 && value <= last)) problems.push(`${name} = ${value} is outside 1..D_LAST`);
  if (space === 'I' && !(value >= first && value + width <= base)) problems.push(`${name} = ${value} is outside I_FIRST..R_BASE`);
  if (space === 'R' && value < base) problems.push(`${name} = ${value} is below R_BASE`);
}
source.split('\n').forEach((line, i) => {
  if (/^const /.test(line)) return;
  if (/def\(&mut o, view\([^)]*\), \d/.test(line)) problems.push(`line ${i + 1}: a literal id in def(): ${line.trim()}`);
  const literal = line.match(/\bid (==|!=|>=|<=|<|>|-) ([1-9]\d*)\b/);
  if (literal) problems.push(`line ${i + 1}: a literal id at a use site: ${line.trim()}`);
});
// Coverage: every literally named mnemonic appears in the x86 instruction suites.
const suites = readdirSync(join(root, 'tests/asm')).filter(f => /x86_64\.s$/.test(f)).map(f => readFileSync(join(root, 'tests/asm', f), 'utf8')).join('\n');
const used = new Set();
for (const line of suites.split('\n')) {
  const words = line.replace(/^[^:\s]+:/, '').trim().split(/\s+/);
  used.add(words[0]);
  // `lock` and `rep` prefix the instruction after them.
  if (words[0] === 'lock' || words[0] === 'rep') used.add(words[1]);
}
for (const m of source.matchAll(/def\(&mut o, view\("([a-z][a-z0-9]*)"\), I_[A-Z0-9_]+\);/g)) {
  if (!used.has(m[1])) problems.push(`instruction \`${m[1]}\` is not encoded in tests/asm/*x86_64.s`);
}
if (problems.length) {
  console.error(`lint-asm-ids: ${problems.length} problem(s)\n  ${problems.join('\n  ')}`);
  process.exit(1);
}
console.log(`lint-asm-ids: ${consts.size} ids, unique, named at every use, every instruction encoded in the suite`);
