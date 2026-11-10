// The typed-IR fact table (docs/design/typed-ir.md, F2) end to end:
//  - the f32 fixtures print the reference binary32 results on the LLVM backend, and identically
//    with and without --verify-facts;
//  - --verify-facts emits the `fpext(fptrunc(d)) == d` check at every word the lifter treats as
//    an f32, and writes the table into the module as comments;
//  - a slot gets a fact only when its whole body spells it as one eight-byte word: an address-taken
//    f32 local keeps its table entry but is dropped by the lifter, which is why an absent fact is
//    safe.
//   bun tools/test-facts.mjs
import { readFileSync, mkdirSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { root, buildCompiler, compileProgram } from './native.mjs';

const compiler = buildCompiler();
const work = join(root, '.work/facts');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const runtime = join(root, 'compiler/runtime.grl');
const platform = join(root, 'compiler/os-linux.grl');

let failed = 0;
const ok = (name, condition, detail = '') => {
  if (condition) return;
  failed += 1;
  console.log(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
};
const run = (argv) => {
  const result = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (result.error) throw result.error;
  return result;
};

// `show(x: f32)` prints `f64(x)`, so every line is a binary32 value in its shortest round-trip
// decimal: one ulp anywhere in the arithmetic changes the last digit.
const bits = [
  '0.3333333432674408',            // f32(1.0) / f32(3.0)
  '0.30000001192092896',           // f32(0.1) + f32(0.2)
  '0.8999999761581421',            // f32(1.0) - f32(0.1)
  '0.010000000707805157',          // f32(0.1) * f32(0.1)
  '0.1428571492433548',            // f32(1.0) / f32(7.0)
  '4.5',                           // the dot-product chain
  '16777216',                      // rounds to even at the binary32 precision boundary
  '15',                            // f32[] narrow element stores and loads, summed
  '-2.5',                          // negation of a literal
  '9007199254740992',              // i64 -> f32 -> f64
  '0'                              // f32(0.0) - f32(0.0)
];

// Compiles one fixture (the runtime and os-linux module come from compileProgram).
function build(directory, fixture, options) {
  const path = join(work, directory);
  mkdirSync(path, { recursive: true });
  const exe = compileProgram(compiler, [join(root, 'compiler/tests', fixture)], path, { name: 'program', typedRefs: true, ...options });
  return { exe, ll: join(path, 'program.s.ll') };
}

// ---- f32 arithmetic: exact output, with and without the checks ----
const plain = build('f32-bits', 'f32_bits.grl', { backend: 'llvm' });
const checked = build('f32-bits-verify', 'f32_bits.grl', { backend: 'llvm', verifyFacts: true });
const plainOut = run([plain.exe]).stdout.trim().split('\n');
const checkedOut = run([checked.exe]).stdout.trim().split('\n');
ok('f32 arithmetic is bit-exact', plainOut.join('\n') === bits.join('\n'), plainOut.join(' | '));
ok('--verify-facts does not change a value', checkedOut.join('\n') === plainOut.join('\n'));

// ---- what the fact table says, and what the lifter did with it ----
const table = readFileSync(checked.ll, 'utf8').split('\n').filter(line => line.startsWith('; fact'));
const f32slots = table.filter(line => line.includes('what 1'));
const ops = table.filter(line => line.includes('what 7'));
ok('the table names the f32 slots', f32slots.length >= 3, `${f32slots.length} entries`);
ok('the table names the f32 arithmetic sites', ops.length >= 10, `${ops.length} entries`);
ok('every f32 arithmetic fact carries an opcode', ops.every(line => /width (42|43|45|47)$/.test(line)));

const ir = readFileSync(checked.ll, 'utf8');
const main = ir.slice(ir.indexOf('define {i64, i64} @"f_main_main"'), ir.indexOf('\n}\n', ir.indexOf('define {i64, i64} @"f_main_main"')));
ok('f32 locals become real float slots', (main.match(/alloca float/g) ?? []).length >= 3, String((main.match(/alloca float/g) ?? []).length));
for (const kind of ['fadd float', 'fsub float', 'fmul float', 'fdiv float']) {
  ok(`the lifter emits ${kind}`, main.includes(kind));
}
ok('a fact-carrying call is no longer a call', !/call \{i64, i64\} @"rt_f64_op"/.test(main));
ok('widening is a single fpext', /fpext float .* to double/.test(main));
// The verify check is a bit compare of the widening: one per fact use, on the cold path.
ok('--verify-facts emits the round-trip check', /icmp eq i64 %t\d+, %t\d+/.test(main) && ir.includes('rt_abort.cold'));
ok('--verify-facts is off by default', !readFileSync(plain.ll, 'utf8').includes('; fact'));

// ---- an address-taken f32 local must lose the fact, not keep a wrong one ----
const borrowed = build('f32-borrowed', 'f32_borrowed.grl', { backend: 'llvm', verifyFacts: true });
ok('address-taken f32 still prints the exact value', run([borrowed.exe]).stdout.trim() === '3.75');
const borrowedTable = readFileSync(borrowed.ll, 'utf8').split('\n').filter(line => line.startsWith('; fact') && line.includes('what 1'));
ok('the front end still records the borrowed slot', borrowedTable.length >= 1);
ok('the lifter drops a borrowed slot', !readFileSync(borrowed.ll, 'utf8').includes('alloca float'));

if (failed) {
  console.log(`facts: ${failed} check(s) failed`);
  process.exit(1);
}
console.log('facts: the f32 facts hold, and --verify-facts checks every one of them');
