// SIMD in registers (docs/design/simd.md, S1): tests/simd/inline_loop.grl calls a small SIMD
// function in a loop over two slices. Built with --backend=llvm for x86-64, the call is inlined and
// every vector stays in a register: this reads the loop of `dot` in the object clang wrote and fails
// on any stack access (`(%rsp)`, `(%rbp)`) or call inside it, or if the loop is not the packed
// `mulps`/`addps` of the source. A frame vector whose storage SROA cannot promote - a pointer phi, a
// mixed i64/vector access, an address that escapes into a call - shows up here as a store and a load
// per iteration.
//   bun tools/test-simd.mjs [--compiler PATH]
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { root, buildCompiler, compileProgram } from './native.mjs';

const at = process.argv.indexOf('--compiler');
const compiler = at === -1 ? buildCompiler() : process.argv[at + 1];
const work = join(root, '.work/test-simd');
const exe = compileProgram(compiler, [join(root, 'tests/simd/inline_loop.grl')], work, { target: 'x86_64', backend: 'llvm', name: 'p' });
const ran = spawnSync(exe, [], { encoding: 'utf8' });
let failed = 0;
const ok = (what, condition, detail = '') => {
  if (condition) return;
  failed += 1;
  console.log(`FAIL ${what}${detail ? `\n${detail}` : ''}`);
};
ok('the program prints the dot product', ran.status === 0 && ran.stdout === '177\n', `${ran.status} ${ran.stdout}${ran.stderr}`);

const dump = spawnSync('objdump', ['-d', '--no-show-raw-insn', exe], { encoding: 'utf8' }).stdout;
const lines = dump.split('\n');
const from = lines.findIndex(line => /<f_main_dot>:$/.test(line));
const to = lines.findIndex((line, i) => i > from && line.trim() === '');
const body = lines.slice(from + 1, to).map(line => {
  const m = /^\s*([0-9a-f]+):\s+(.*)$/.exec(line);
  return m ? { at: parseInt(m[1], 16), text: m[2].trim() } : null;
}).filter(Boolean);
ok('dot is in the binary', from !== -1 && body.length > 0);
// The loop: the backward conditional jump whose target is inside the function.
const back = body.find(insn => {
  const m = /^j[a-z]+\s+([0-9a-f]+)\b/.exec(insn.text);
  return m && !insn.text.startsWith('jmp') && parseInt(m[1], 16) < insn.at && parseInt(m[1], 16) >= body[0].at;
});
ok('dot has a loop', back !== undefined, body.map(i => i.text).join('\n'));
if (back) {
  const head = parseInt(/^j[a-z]+\s+([0-9a-f]+)/.exec(back.text)[1], 16);
  const loop = body.filter(insn => insn.at >= head && insn.at <= back.at);
  const shown = loop.map(i => i.text).join('\n');
  ok('the loop touches no stack slot', !loop.some(i => /\(%r[sb]p\)|%r[sb]p\)/.test(i.text)), shown);
  ok('the loop calls nothing', !loop.some(i => /^call/.test(i.text)), shown);
  ok('the loop multiplies and adds packed singles', loop.some(i => /^mulps/.test(i.text)) && loop.some(i => /^addps/.test(i.text)), shown);
  ok('the loop is short (no per-lane code)', loop.length <= 12, shown);
}
if (failed) process.exit(1);
console.log('test-simd: ok');
