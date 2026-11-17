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
  const exe = compileProgram(compiler, [join(root, 'compiler/tests', fixture)], path, { name: 'program', ...options });
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
// A lifted body's text, from its `define` line (whatever signature the fact gave it) to its end.
const defined = (text, name) => {
  const at = text.search(new RegExp(`^define [^\n]*@"${name.replace(/[.$]/g, '\\$&')}"\\(`, 'm'));
  return at < 0 ? '' : text.slice(at, text.indexOf('\n}\n', at));
};
const main = defined(ir, 'f_main_main');
ok('f32 locals become real float slots', (main.match(/alloca float/g) ?? []).length >= 3, String((main.match(/alloca float/g) ?? []).length));
for (const kind of ['fadd float', 'fsub float', 'fmul float', 'fdiv float']) {
  ok(`the lifter emits ${kind}`, main.includes(kind));
}
ok('a fact-carrying call is no longer a call', !/call (i64|\{i64, i64\}) @"rt_f64_op"/.test(main));
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

// ---- F1: a frame slot or a call argument 0 is a sequence header ----
// `total(&v)` reads through the vector's own header and `main` reads the same vector by index, so
// the fixture exercises what a fact names and what it must never be wrong about.
const native = build('f1-native', 'f1_header.grl', { backend: 'native' });
const f1 = build('f1-header', 'f1_header.grl', { backend: 'llvm' });
const f1checked = build('f1-header-verify', 'f1_header.grl', { backend: 'llvm', verifyFacts: true });
const reference = run([native.exe]).stdout.trim();
const f1out = run([f1.exe]).stdout.trim();
const f1checkedOut = run([f1checked.exe]).stdout.trim();
ok('F1 output matches the native backend', f1out === reference, `${f1out} vs ${reference}`);
ok('--verify-facts does not change an F1 value', f1checkedOut === f1out, `${f1checkedOut} vs ${f1out}`);

const f1ir = readFileSync(f1checked.ll, 'utf8');
const f1table = f1ir.split('\n').filter(line => line.startsWith('; fact'));
const headerSlots = f1table.filter(line => /slot \d+ what (2|3|4|5) /.test(line));
const headerArgs = f1table.filter(line => /call rt_slot\d?w?/.test(line) || /call rt_len/.test(line));
ok('the table names the header slots', headerSlots.length >= 2, `${headerSlots.length} entries`);
ok('the table names the header call arguments', headerArgs.length >= 2, `${headerArgs.length} entries`);
ok('every header fact is a vector kind (2/3/4)',
  f1table.every(line => !/ what (5|6|7|8|9) /.test(line)));

ok('the accessor gets a typed sibling', /define internal \{i64, i64\} @"rt_slot\.h2w8"/.test(f1ir));
ok('the sibling states the header is 24 bytes at eight-byte alignment',
  /define internal \{i64, i64\} @"rt_slot\.h2w8"\(ptr nocapture nofree dereferenceable\(24\) align 8 %a0/.test(f1ir));
// An element address under a fact is written in place: the bounds check against the hoisted
// `len` and a `getelementptr` on the hoisted `data` pointer, so neither field is re-loaded and the
// address keeps its provenance (the sibling stays for the accessors that return a value).
ok('a fact-carrying element address is a getelementptr on the hoisted data pointer',
  /= load ptr, ptr %t\d+, align 8/.test(f1ir) && /getelementptr i8, ptr %t\d+, i64 %t\d+\n%t\d+ = ptrtoint ptr/.test(f1ir));
ok('the header loads are `align 8`', /load i64, ptr %t\d+, align 8/.test(f1ir));
// A vector may still grow, so the lowering claims nothing about its header being invariant: the
// hoist is the two loads it emits itself, not a promise to LLVM.
ok('a vector fact carries no invariant.load', !f1ir.includes('!invariant.load'));
ok('a vector fact carries no alias.scope', !f1ir.includes('!alias.scope'));
ok('--verify-facts emits the header checks', /icmp ne i64 %t\d+, 0/.test(f1ir) && /icmp uge i64 %t\d+, %t\d+/.test(f1ir));
ok('--verify-facts emits the element-range check', /icmp ult i64 %t\d+, %t\d+/.test(f1ir));

// ---- a deliberately wrong fact must abort, not print a plausible number ----
// `--f1-what=N` is a test aid that records the wrong kind for every binding. Claiming a vector
// header for a slot that holds something else makes the `cap >= len` check read `+16` of a word
// that is not a header, which is exactly the failure mode `--verify-facts` exists for.
const wrong = build('f1-wrong', 'f1_header.grl', { backend: 'llvm', verifyFacts: true, extra: ['--f1-what=2'] });
const wrongRun = run([wrong.exe]);
ok('a wrong fact aborts under --verify-facts', wrongRun.status !== 0,
  `exit ${wrongRun.status}, printed ${JSON.stringify(wrongRun.stdout.trim())}`);
ok('the right facts do not abort', run([f1checked.exe]).status === 0);

// ---- SEQ-STABLE: a slice's descriptor is read once per function, and a forged claim aborts ----
// docs/design/release-builds-and-parity.md. A slice (`&[T]`, `&mut [T]`) gets the F1 kind 5, its
// `data` is loaded as a pointer at the one write of its slot, and every element address in the
// function is a `getelementptr` on it. `--f1-what=5` claims the same of every binding, including a
// vector that grows inside the loop that reads it; under --verify-facts each access re-reads the
// header and the first one after the growth aborts.
const stableWant = '198.5\n5175\n781\n';
const stable = build('seq-stable', 'seq_stable.grl', { backend: 'llvm' });
const stableRun = run([stable.exe]);
ok('slice loops print the reference values', stableRun.stdout === stableWant, JSON.stringify(stableRun.stdout));
const stableIr = readFileSync(stable.ll, 'utf8');
ok('a slice element address is a getelementptr on the hoisted data pointer',
  /= load ptr, ptr %t\d+, align 8/.test(stableIr) && /getelementptr i8, ptr %t\d+, i64 %t\d+/.test(stableIr));
const stableChecked = build('seq-stable-verify', 'seq_stable.grl', { backend: 'llvm', verifyFacts: true });
const stableCheckedRun = run([stableChecked.exe]);
ok('slice facts hold under --verify-facts', stableCheckedRun.status === 0 && stableCheckedRun.stdout === stableWant,
  `exit ${stableCheckedRun.status}, printed ${JSON.stringify(stableCheckedRun.stdout)}`);
const forged = build('seq-stable-forged', 'seq_stable.grl', { backend: 'llvm', verifyFacts: true, extra: ['--f1-what=5'] });
const forgedRun = run([forged.exe]);
ok('a forged SEQ-STABLE fact aborts under --verify-facts', forgedRun.status !== 0,
  `exit ${forgedRun.status}, printed ${JSON.stringify(forgedRun.stdout.trim())}`);

// ---- the range fact: a proved index, the check removed, and the check put back ----
// `u8[0; 10]` gives the analysis a literal length and `while i < 5` bounds the index, so every access
// in the fixture is in range. The default build must be untouched (the pass is off), the
// --range-facts build must drop the accessors' compare, and --verify-facts must put a runtime check
// back at each site -- which cannot fire, and does not.
const rangeNative = build('range-native', 'range_fact.grl', { backend: 'native' });
const rangePlain = build('range-plain', 'range_fact.grl', { backend: 'llvm' });
const rangeOn = build('range-on', 'range_fact.grl', { backend: 'llvm', rangeFacts: true });
const rangeChecked = build('range-on-verify', 'range_fact.grl', { backend: 'llvm', rangeFacts: true, verifyFacts: true });
const rangeReference = run([rangeNative.exe]).stdout.trim();
ok('range fixture: the native reference prints something', rangeReference.length > 0, rangeReference);
ok('range fixture: the default LLVM build matches native', run([rangePlain.exe]).stdout.trim() === rangeReference);
ok('range fixture: --range-facts matches native', run([rangeOn.exe]).stdout.trim() === rangeReference,
  `${run([rangeOn.exe]).stdout.trim()} vs ${rangeReference}`);
const rangeCheckedRun = run([rangeChecked.exe]);
ok('range fixture: --verify-facts re-inserts the check and it does not fire',
  rangeCheckedRun.status === 0 && rangeCheckedRun.stdout.trim() === rangeReference,
  `exit ${rangeCheckedRun.status}, ${JSON.stringify(rangeCheckedRun.stdout.trim())}`);

const plainIr = readFileSync(rangePlain.ll, 'utf8');
const onIr = readFileSync(rangeOn.ll, 'utf8');
const checkedIr = readFileSync(rangeChecked.ll, 'utf8');
const accessorCalls = text => (text.match(/call (i64|\{i64, i64\}) @"rt_atb"/g) ?? []).length;
ok('the pass is off by default: the accessor is called and no verdict is recorded',
  accessorCalls(plainIr) > 0 && !plainIr.includes('; range '));
ok('--range-facts proves the access it is given and stops calling the accessor',
  accessorCalls(onIr) < accessorCalls(plainIr) && /load i8, ptr %t\d+, align 1/.test(onIr),
  `${accessorCalls(onIr)} vs ${accessorCalls(plainIr)} calls`);
ok('--verify-facts re-inserts a runtime check for it', /icmp ult i64 %t\d+, %t\d+/.test(checkedIr));
ok('--verify-facts records the verdict it checked', /^; range \d+ 3$/m.test(checkedIr));

// ---- the fixpoint must converge before it decides anything ----
// Before widening, a loop longer than the round cap was judged on an interval that had not
// converged: `while i < 100` over `u8[0; 30]` was proved after 24 rounds with `i` in about [0, 23],
// and the --range-facts build read 70 bytes past the end instead of aborting. With widening it
// converges, and the guard (100) still does not prove the access against the length (30), so the
// pass must keep the accessor call - the checked code - and record no verdict.
const mainOf = text => defined(text, 'f_main_main');
for (const [fixture, aborts] of [['range_long_trip.grl', true]]) {
  const tag = fixture.replace('.grl', '').replace(/_/g, '-');
  const native = run([build(`${tag}-native`, fixture, { backend: 'native' }).exe]);
  const on = build(`${tag}-on`, fixture, { backend: 'llvm', rangeFacts: true });
  const verify = build(`${tag}-verify`, fixture, { backend: 'llvm', rangeFacts: true, verifyFacts: true });
  const onRun = run([on.exe]);
  ok(`${fixture}: the native reference ${aborts ? 'aborts' : 'exits 0'}`, (native.status !== 0) === aborts, `exit ${native.status}`);
  ok(`${fixture}: --range-facts behaves as the checked build`, onRun.status === native.status && onRun.stdout === native.stdout,
    `exit ${onRun.status} ${JSON.stringify(onRun.stdout.trim())} vs exit ${native.status} ${JSON.stringify(native.stdout.trim())}`);
  ok(`${fixture}: --range-facts keeps the accessor call`, accessorCalls(mainOf(readFileSync(on.ll, 'utf8'))) === 1);
  ok(`${fixture}: no verdict is recorded`, !readFileSync(verify.ll, 'utf8').includes('; range '));
}

// ---- widening proves loops the cap used to stop ----
// `while i < 300` over `u8[1; 300]` converges only because the head's join widens `i`, and a loop
// that pushes converges only because the length generation is widened; in both the guard then
// proves `v[i]`, so the accessor call goes and --verify-facts records the verdict it checks.
for (const [fixture, expect] of [['range_long_proof.grl', '300'], ['range_push_loop.grl', '0']]) {
  const tag = fixture.replace('.grl', '').replace(/_/g, '-');
  const native = run([build(`${tag}-native`, fixture, { backend: 'native' }).exe]);
  const on = build(`${tag}-on`, fixture, { backend: 'llvm', rangeFacts: true });
  const verify = build(`${tag}-verify`, fixture, { backend: 'llvm', rangeFacts: true, verifyFacts: true });
  const onRun = run([on.exe]);
  const verifyRun = run([verify.exe]);
  ok(`${fixture}: --range-facts matches native`, onRun.status === 0 && onRun.stdout === native.stdout && native.stdout.trim() === expect,
    `${JSON.stringify(onRun.stdout.trim())} vs ${JSON.stringify(native.stdout.trim())}`);
  ok(`${fixture}: widening proves the access and drops the accessor call`, accessorCalls(mainOf(readFileSync(on.ll, 'utf8'))) === 0);
  ok(`${fixture}: --verify-facts records and checks the verdict`, /^; range \d+ 3$/m.test(readFileSync(verify.ll, 'utf8')) && verifyRun.stdout === native.stdout);
}

// ---- the signature fact: exact arity and result width, and a forged one refused ----
// A lifted body is defined with exactly its argument words and a call passes exactly those, so a
// fact that says fewer than the body reads would hand it garbage, and one that says one result word
// where the caller reads two would drop %rdx. The lifter finds both (a body reading an argument
// register past its fact; a caller reading %rdx after a one-word call), drops the fact for the body
// and for every call to it (the module is lowered again in the six-word form), and under
// --verify-facts fails the compile naming the fact.
const signature = build('signature', 'signature.grl', { backend: 'llvm', verifyFacts: true });
const sigIr = readFileSync(signature.ll, 'utf8');
ok('signature: the facts are recorded', /^; fact f_main_two signature 2$/m.test(sigIr) && /^; fact f_main_as_shape signature 1$/m.test(sigIr));
ok('signature: a two-word body takes two words and gives one', /^define internal i64 @"f_main_two"\(i64 %a0, i64 %a1\)/m.test(sigIr), sigIr.match(/^define.*f_main_two.*$/m)?.[0]);
ok('signature: a `&dyn` result stays two words', /^define internal \{i64, i64\} @"f_main_as_shape"\(i64 %a0\)/m.test(sigIr), sigIr.match(/^define.*f_main_as_shape.*$/m)?.[0]);
ok('signature: the right facts run', run([signature.exe]).stdout === '44 7\n', JSON.stringify(run([signature.exe]).stdout));
const refused = (directory, forge, flag = '--forge-signature=', file = flag === '--forge-signature=' ? 'signature.grl' : 'indirect_words.grl') => {
  try {
    build(directory, file, { backend: 'llvm', verifyFacts: true, extra: [`${flag}${forge}`] });
    return '';
  } catch (error) {
    return String(error.message);
  }
};
const fewer = refused('signature-fewer', 'f_main_two:1');
ok('signature: a fact with fewer argument words than the body reads fails under --verify-facts', /the signature fact of f_main_two is wrong: it gives 1 argument words and the body reads %rsi/.test(fewer), fewer.slice(0, 400));
const narrow = refused('signature-narrow', 'f_main_as_shape:1:1');
ok('signature: a one-word result fact for a two-word result fails under --verify-facts', /the signature fact of f_main_as_shape is wrong: it gives a one-word result and \S+ reads %rdx/.test(narrow), narrow.slice(0, 400));
const quiet = build('signature-quiet', 'signature.grl', { backend: 'llvm', extra: ['--forge-signature=f_main_two:1'] });
ok('signature: without --verify-facts a forged fact is dropped (six words again) and the program is right', run([quiet.exe]).stdout === '44 7\n' && /^define internal \{i64, i64\} @"f_main_two"\(i64 %a0, i64 %a1, i64 %a2, i64 %a3, i64 %a4, i64 %a5\)/m.test(readFileSync(quiet.ll, 'utf8')));

// ---- the FFI fact: a C call with floats is lifted, typed as C types it ----
const ffi = build('ffi-floats', 'ffi_float_calls.grl', { backend: 'llvm', verifyFacts: true });
const ffiIr = readFileSync(ffi.ll, 'utf8');
ok('ffi: the C functions are declared with their float types', /^declare double @"scale"\(i64, double, float\)$/m.test(ffiIr) && /^declare float @"half"\(float\)$/m.test(ffiIr));
// The externs are blocking (the default): the foreign-call marker around each call (native.grl
// ffi_marker_enter/leave) must not keep the caller out of the LLVM module.
ok('ffi: the caller of a blocking extern is lifted and calls it typed', /call double @"scale"\(i64 %t\d+, double %t\d+, float %t\d+\)/.test(ffiIr) && /^define [^\n]*@"f_main_main"/m.test(ffiIr));
ok('ffi: the values are the native build\'s', run([ffi.exe]).stdout === '500\n1.5\n', JSON.stringify(run([ffi.exe]).stdout));

// ---- the indirect-call fact: a closure call passes only its words; a short fact is refused ----
const indirect = build('indirect-words', 'indirect_words.grl', { backend: 'llvm', verifyFacts: true });
const indirectIr = readFileSync(indirect.ll, 'utf8');
ok('indirect: the fact is recorded', /^; fact f_main_apply indirect 0 words 2$/m.test(indirectIr), indirectIr.match(/^; fact f_main_apply.*$/gm));
ok('indirect: the call passes poison past its words', /call \{i64, i64\} %t\d+\(i64 %t\d+, i64 %t\d+, i64 poison, i64 poison, i64 poison, i64 poison\)/.test(indirectIr));
ok('indirect: the values are right', run([indirect.exe]).stdout === '30\n', JSON.stringify(run([indirect.exe]).stdout));
const shortFact = refused('indirect-short', 'f_main_apply', '--forge-indirect=');
ok('indirect: a fact one word short fails under --verify-facts', /the signature fact of f_main_apply is wrong: an indirect call passes 1 words but %rsi was loaded for it/.test(shortFact), shortFact.slice(0, 400));

// ---- a byval C record from a lifted body: never a one-word typed call ----
spawnSync('cc', ['-O2', '-c', join(root, 'compiler/tests/ffi_byval.c'), '-o', join(root, 'compiler/tests/ffi_byval.o')], { stdio: 'inherit' });
const byval = build('ffi-byval', 'ffi_byval.grl', { backend: 'llvm', verifyFacts: true });
ok('ffi: a byval record argument crosses whole on the LLVM backend', run([byval.exe]).stdout === '7043\n', JSON.stringify(run([byval.exe]).stdout));

if (failed) {
  console.log(`facts: ${failed} check(s) failed`);
  process.exit(1);
}
console.log('facts: the f32, F1, range and signature facts hold, --verify-facts checks every one of them, and a wrong fact aborts or is refused');
