// The text optimiser knows where a jump goes (compiler/ir.grl `label_number`, compiler/optimize.grl
// `jump_target`). When it does not, every pass that follows a jump falls back to its most
// conservative answer and nothing fails - the code is only slower - which is how a label spelling
// the parser stopped reading went unnoticed for three days. Two checks, so that it cannot again:
//  - a function with a loop and a branch comes out with its loop state in registers and its
//    comparisons fused with their branches, which needs liveness across the back edge;
//  - an `f64` loop keeps its float temporaries in SSE registers (xmm8..xmm14), not frame slots;
//  - a leaf that takes a slot's address is not inlined (its slot cannot become a register);
//  - GRAIL_OPT_STATS=1 makes the optimiser write `# grail-jumps <known> <unknown>` before each
//    body, and over the compiler's own sources nearly every direct jump has a known target.
//   bun tools/test-optimiser-jumps.mjs
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { root, buildCompiler, command, compileProgram, compilerSources } from './native.mjs';

const compiler = buildCompiler();
const work = join(root, '.work/optimiser-jumps');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

let failed = 0;
const ok = (name, condition, detail = '') => {
  if (condition) return;
  failed += 1;
  console.log(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
};

const source = join(work, 'loop.grl');
writeFileSync(source, `fn collatz(seed: u64, rounds: u64) -> u64 {
    mut x = seed;
    mut steps = 0;
    mut i = 0;
    while i < rounds {
        if x % 2 == 0 {
            x = x / 2;
        } else {
            x = wrapping_add(wrapping_mul(x, 3), 1);
        }
        steps = wrapping_add(steps, x % 7);
        i += 1;
    }
    return steps;
}
fn main() {
    println(collatz(27, 1000));
}
`);
const executable = compileProgram(compiler, [source], work, { target: 'x86_64', name: 'loop' });
const ran = spawnSync(executable, [], { encoding: 'utf8' });
// The same sum computed here: the optimised loop still computes what the source says.
let x = 27n, steps = 0n;
for (let i = 0; i < 1000; i++) {
  x = x % 2n === 0n ? x / 2n : (x * 3n + 1n) & 0xffffffffffffffffn;
  steps += x % 7n;
}
ok('the loop prints its sum', ran.status === 0 && ran.stdout.trim() === String(steps), `${ran.status} ${ran.stdout}${ran.stderr}`);

const lines = readFileSync(join(work, 'loop.s'), 'utf8').split('\n');
const from = lines.indexOf('f_main_collatz:');
const to = lines.findIndex((line, i) => i > from && line.startsWith('.set '));
ok('collatz is in the assembly', from !== -1 && to !== -1);
const body = lines.slice(from, to);
// The loop: from the label the last backward `jmp` names to that `jmp`.
const back = body.findLastIndex((line, i) => line.startsWith('jmp .L') && body.indexOf(`${line.slice(4)}:`) !== -1 && body.indexOf(`${line.slice(4)}:`) < i);
ok('collatz has a back edge', back !== -1);
const loop = back === -1 ? [] : body.slice(body.indexOf(`${body[back].slice(4)}:`), back + 1);
const shown = `\n${loop.join('\n')}`;
ok('nothing is stored to the frame inside the loop', loop.length !== 0 && !loop.some(line => /,-\d+\(%rbp\)$/.test(line)), shown);
ok('nothing is loaded from the frame inside the loop', !loop.some(line => /-\d+\(%rbp\),/.test(line)), shown);
ok('the loop test is one compare of two registers and a conditional jump', loop.some((line, i) => /^cmpq %r\w+,%r\w+$/.test(line) && /^jae \.L/.test(loop[i + 1] ?? '')), shown);
ok('no comparison is materialised as a byte and tested again', !loop.some(line => /^(set[a-z]+|movzbq) /.test(line)), shown);

// Float temporaries live in SSE registers (optimize.grl `xmm_choose`): an `f64` scale-and-add loop
// keeps every float in xmm8..xmm14 and touches the frame for none of them.
const floatSource = join(work, 'xform.grl');
writeFileSync(floatSource, `fn scale_add(x: (&mut [f64]), y: (&[f64]), a: f64) -> unit {
    n := x.len();
    mut i = 0;
    while i < n {
        x[i] = x[i] * a + y[i];
        i += 1;
    }
}
fn main() {
    mut x = f64[];
    mut y = f64[];
    for i in 1000 {
        x.push(f64(i));
        y.push(0.5);
    }
    for pass in 3 {
        scale_add(&mut x[0..1000], &y[0..1000], 0.5);
    }
    mut sum: f64 = 0.0;
    for i in 1000 {
        sum = sum + x[i];
    }
    println(sum);
}
`);
const floatExe = compileProgram(compiler, [floatSource], work, { target: 'x86_64', name: 'xform' });
const floatRun = spawnSync(floatExe, [], { encoding: 'utf8' });
// x_k = x_0 / 8 + 0.5 * (1/4 + 1/2 + 1) per element: sum(i) / 8 + 1000 * 0.875.
ok('the float loop prints its sum', floatRun.status === 0 && floatRun.stdout.trim() === String(499500 / 8 + 875), `${floatRun.status} ${floatRun.stdout}${floatRun.stderr}`);
const floatLines = readFileSync(join(work, 'xform.s'), 'utf8').split('\n');
const ffrom = floatLines.indexOf('f_main_scale_add:');
const fbody = floatLines.slice(ffrom, floatLines.findIndex((line, i) => i > ffrom && line.startsWith('.set ')));
const fback = fbody.findLastIndex((line, i) => line.startsWith('jmp .L') && fbody.indexOf(`${line.slice(4)}:`) !== -1 && fbody.indexOf(`${line.slice(4)}:`) < i);
const floop = fback === -1 ? [] : fbody.slice(fbody.indexOf(`${fbody[fback].slice(4)}:`), fback + 1);
const fshown = `\n${floop.join('\n')}`;
ok('the float loop holds its floats in xmm8..xmm14', floop.some(line => /%xmm(8|9|1[0-4])\b/.test(line)), fshown);
ok('no float goes through the frame inside the float loop', floop.length !== 0 && !floop.some(line => /\(%rbp\)/.test(line) && !/^movq -\d+\(%rbp\),%r(cx|ax)$/.test(line)), fshown);

// The inliner copies a small leaf with its slots in scratch registers, so a leaf that takes a slot's
// address (runtime.grl's rt_frame) must stay a call: `leaq %r8,%rax` does not assemble. Inlining only
// happens in a build with unit markers, hence --split; every part has to assemble.
const frameSource = join(work, 'frame.grl');
writeFileSync(frameSource, `unsafe module runtime;
fn frame() -> u64 {
    mut here = 0;
    p := &mut here;
    return p;
}
fn deeper(n: u64) -> u64 {
    if n == 0 {
        return frame();
    }
    return deeper(n - 1);
}
fn main() {
    top := frame();
    low := deeper(20);
    println(low < top);
}
`);
const frameOut = join(work, 'frame.s');
command([compiler, '--split', '--target', 'x86_64', frameOut, frameSource, join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')]);
const parts = readdirSync(work).filter(name => name.startsWith('frame.') && name.endsWith('.s'));
ok('the split build has parts', parts.length > 1, parts.join(' '));
for (const part of parts) {
  const text = readFileSync(join(work, part), 'utf8');
  ok(`${part} takes no register's address`, !/^leaq %/m.test(text), text.split('\n').filter(line => /^leaq %/.test(line)).slice(0, 3).join(' '));
  const as = spawnSync('clang', ['--target=x86_64-linux-gnu', '-c', join(work, part), '-o', join(work, `${part}.o`)], { encoding: 'utf8' });
  ok(`${part} assembles`, as.status === 0, (as.stderr ?? '').split('\n').slice(0, 3).join(' '));
}

// The compiler's own sources: what the optimiser could follow.
const self = join(work, 'self.s');
command([compiler, self, ...compilerSources], { env: { ...process.env, GRAIL_OPT_STATS: '1' } });
let known = 0, unknown = 0, bodies = 0;
for (const match of readFileSync(self, 'utf8').matchAll(/^# grail-jumps (\d+) (\d+)$/gm)) {
  known += Number(match[1]);
  unknown += Number(match[2]);
  bodies += 1;
}
console.log(`optimiser-jumps: ${bodies} bodies, ${known} jumps with a known target, ${unknown} without`);
ok('the compiler has bodies', bodies > 1000, String(bodies));
ok('at least 99% of the compiler\'s direct jumps have a known target', known > 100000 && unknown * 100 <= known + unknown, `${known} known, ${unknown} unknown`);
// The flag is the only thing that writes the lines.
const plain = join(work, 'plain.s');
command([compiler, '--target', 'x86_64', plain, source, join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')]);
ok('no statistics without the flag', !readFileSync(plain, 'utf8').includes('# grail-jumps'));

if (failed) process.exit(1);
console.log('optimiser-jumps: ok');
