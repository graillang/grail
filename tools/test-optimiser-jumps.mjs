// The text optimiser knows where a jump goes (compiler/ir.grl `label_number`, compiler/optimize.grl
// `jump_target`). When it does not, every pass that follows a jump falls back to its most
// conservative answer and nothing fails - the code is only slower - which is how a label spelling
// the parser stopped reading went unnoticed for three days. Two checks, so that it cannot again:
//  - a function with a loop and a branch comes out with its loop state in registers and its
//    comparisons fused with their branches, which needs liveness across the back edge;
//  - GRAIL_OPT_STATS=1 makes the optimiser write `# grail-jumps <known> <unknown>` before each
//    body, and over the compiler's own sources nearly every direct jump has a known target.
//   bun tools/test-optimiser-jumps.mjs
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
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
