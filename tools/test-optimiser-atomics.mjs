// The text optimiser treats every `atom.*` op as a barrier of at least its ordering
// (compiler/ir.grl, `parse`): nothing is forwarded, merged, hoisted or dropped across an acquire,
// release or sequentially consistent op, and a relaxed op is neither eliminated nor merged with
// its neighbour. These checks read the optimised x86-64 assembly, where machine.grl writes each
// atomic op as a `# atom.<op> <order> <width>` comment followed by its instructions, and fail if
// a pass moved a load across an acquire or folded an atomic away:
//  - a spin on an acquire load keeps the load inside the loop, and the relaxed read of the data it
//    guards stays after the loop;
//  - a word read through a pointer before an acquire load is read again after it;
//  - two relaxed loads of one cell are two loads, two relaxed stores are two stores, and a relaxed
//    load after a relaxed store to the same cell is a load (no store-to-load forwarding);
//  - the program computes what the source says.
//   bun tools/test-optimiser-atomics.mjs [--compiler PATH]
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { root, buildCompiler, compileProgram } from './native.mjs';

const at = process.argv.indexOf('--compiler');
const compiler = at === -1 ? buildCompiler() : process.argv[at + 1];
const work = join(root, '.work/optimiser-atomics');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

let failed = 0;
const ok = (name, condition, detail = '') => {
  if (condition) return;
  failed += 1;
  console.log(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
};

const source = join(work, 'barrier.grl');
writeFileSync(source, `struct Shared {
    flag: Atomic<u64>,
    data: Atomic<u64>,
    count: Atomic<u64>
}
fn reader<a>(s: (&a Shared)) -> u64 {
    while s.flag.load_acquire() == 0 {}
    return s.data.load_relaxed();
}
fn reread<a, b>(s: (&a Shared), cell: (&b u64)) -> u64 {
    before := load(cell);
    while s.flag.load_acquire() == 0 {}
    return before + load(cell);
}
fn twice<a>(s: (&a Shared)) -> u64 {
    return s.count.load_relaxed() + s.count.load_relaxed();
}
fn store_twice<a>(s: (&a Shared)) -> unit {
    s.count.store_relaxed(1);
    s.count.store_relaxed(2);
}
fn store_then_load<a>(s: (&a Shared)) -> u64 {
    s.count.store_relaxed(5);
    return s.count.load_relaxed();
}
fn main() {
    s := Shared { flag: Atomic::new(1), data: Atomic::new(40), count: Atomic::new(0) };
    cell := 1;
    println(reader(&s) + reread(&s, &cell));
    store_twice(&s);
    println(twice(&s));
    println(store_then_load(&s));
}
`);
const executable = compileProgram(compiler, [source], work, { target: 'x86_64', name: 'barrier' });
const ran = spawnSync(executable, [], { encoding: 'utf8' });
ok('the program prints what the source computes', ran.status === 0 && ran.stdout === '42\n4\n5\n', `${ran.status} ${ran.stdout}${ran.stderr}`);

const lines = readFileSync(join(work, 'barrier.s'), 'utf8').split('\n');
const body = name => {
  const from = lines.indexOf(`f_main_${name}:`);
  const to = lines.findIndex((line, i) => i > from && line.startsWith('.set '));
  ok(`${name} is in the assembly`, from !== -1 && to !== -1);
  return from === -1 ? [] : lines.slice(from, to);
};
const ops = (b, op) => b.flatMap((line, i) => line === `# ${op}` ? [i] : []);
const show = b => `\n${b.join('\n')}`;
// Each marker is followed by its expansion: a load from or a store to the cell.
const expanded = (b, i, instruction) => b[i + 1] === instruction;

// The spin: the acquire load sits between the loop's label and its backward jump, and the relaxed
// load of the data comes after that jump.
{
  const b = body('reader');
  const acquire = ops(b, 'atom.load acquire u64');
  const relaxed = ops(b, 'atom.load relaxed u64');
  ok('reader keeps one acquire load and one relaxed load', acquire.length === 1 && relaxed.length === 1, show(b));
  ok('the acquire load is a load', acquire.length === 1 && expanded(b, acquire[0], 'movq (%rdi),%rax'), show(b));
  const back = b.findIndex((line, i) => /^j[a-z]+ \.L/.test(line) && b.indexOf(`${line.split(' ')[1]}:`) !== -1 && b.indexOf(`${line.split(' ')[1]}:`) < i);
  const head = back === -1 ? -1 : b.indexOf(`${b[back].split(' ')[1]}:`);
  ok('reader has a loop', back !== -1, show(b));
  ok('the acquire load is inside the loop', head < acquire[0] && acquire[0] < back, show(b));
  ok('the relaxed data load is after the loop', relaxed[0] > back, show(b));
}
// A word read through a pointer before the acquire is read again after it: the reread is not
// forwarded from the first read across the barrier.
{
  const b = body('reread');
  const acquire = ops(b, 'atom.load acquire u64');
  ok('reread keeps its acquire load', acquire.length === 1, show(b));
  const derefs = b.flatMap((line, i) => /^movq \(%r(?!bp)\w+\),%r\w+$/.test(line) && b[i - 1] !== `# atom.load acquire u64` ? [i] : []);
  ok('the pointer is read before the acquire', derefs.some(i => i < acquire[0]), show(b));
  ok('the pointer is read again after the acquire', derefs.some(i => i > acquire[0]), show(b));
}
{
  const b = body('twice');
  const loads = ops(b, 'atom.load relaxed u64');
  ok('two relaxed loads stay two loads', loads.length === 2 && loads.every(i => expanded(b, i, 'movq (%rdi),%rax')), show(b));
}
{
  const b = body('store_twice');
  const stores = ops(b, 'atom.store relaxed u64');
  ok('two relaxed stores stay two stores', stores.length === 2 && stores.every(i => expanded(b, i, 'movq %rax,(%rdi)')), show(b));
}
{
  const b = body('store_then_load');
  const store = ops(b, 'atom.store relaxed u64');
  const load = ops(b, 'atom.load relaxed u64');
  ok('a relaxed load after a relaxed store is still a load, after the store', store.length === 1 && load.length === 1 && store[0] < load[0], show(b));
}

if (failed) process.exit(1);
console.log('optimiser-atomics: ok');
