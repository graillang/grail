// SIMD in registers (docs/design/simd.md, S1): tests/simd/inline_loop.grl calls a small SIMD
// function in a loop over two slices, and tests/simd/array_field_loop.grl loads from a fixed-size
// array field. Built with --backend=llvm for x86-64, the call is inlined and
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
let failed = 0;
const ok = (what, condition, detail = '') => {
  if (condition) return;
  failed += 1;
  console.log(`FAIL ${what}${detail ? `\n${detail}` : ''}`);
};
// Builds `program` with the LLVM backend, runs it, and checks its SIMD loop - found by what it is,
// a backward conditional jump whose body has every instruction in `wanted` - stays in registers.
function check(program, name, stdout, wanted, longest) {
  const exe = compileProgram(compiler, [join(root, program)], work, { target: 'x86_64', backend: 'llvm', name });
  const ran = spawnSync(exe, [], { encoding: 'utf8' });
  ok(`${program} prints ${JSON.stringify(stdout)}`, ran.status === 0 && ran.stdout === stdout, `${ran.status} ${ran.stdout}${ran.stderr}`);
  // The lifted functions are internal, so LLVM may inline the SIMD function into its caller and its
  // symbol may be gone: the loop is found in the object clang wrote for the lifted code.
  const dump = spawnSync('objdump', ['-d', '--no-show-raw-insn', join(work, `${name}.ll.o`)], { encoding: 'utf8' }).stdout;
  const insns = dump.split('\n').map(line => {
    const m = /^\s*([0-9a-f]+):\s+(.*)$/.exec(line);
    return m ? { at: parseInt(m[1], 16), text: m[2].trim() } : null;
  }).filter(Boolean);
  const loops = [];
  for (const insn of insns) {
    const m = /^j([a-z]+)\s+([0-9a-f]+)\b/.exec(insn.text);
    if (!m || m[1] === 'mp') continue;
    const head = parseInt(m[2], 16);
    if (head >= insn.at) continue;
    loops.push(insns.filter(i => i.at >= head && i.at <= insn.at));
  }
  const loop = loops.find(body => wanted.every(w => body.some(i => w.test(i.text))));
  ok(`${program}: a loop with ${wanted.join(' ')}`, loop !== undefined, `${loops.length} loops`);
  if (!loop) return;
  const shown = loop.map(i => i.text).join('\n');
  ok(`${program}: the loop touches no stack slot`, !loop.some(i => /\(%r[sb]p\)|%r[sb]p\)/.test(i.text)), shown);
  ok(`${program}: the loop calls nothing`, !loop.some(i => /^call/.test(i.text)), shown);
  ok(`${program}: the loop is short (no per-lane code)`, loop.length <= longest, shown);
}
// A small SIMD function called in a loop over two slices: packed multiply and add.
check('tests/simd/inline_loop.grl', 'p', '177\n', [/^mulps/, /^addps/], 12);
// Loads straight from a `[f32; 16]` struct field, the structs flat in a vector: the array is the
// load's source, never copied (docs/design/fixed-arrays.md section 6).
check('tests/simd/array_field_loop.grl', 'q', '629\n', [/^movups\s+0x30\(/, /^addps/], 40);
if (failed) process.exit(1);
console.log('test-simd: ok');
