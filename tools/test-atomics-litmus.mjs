// The atomics family's litmus suite (docs/design/concurrency-stages-5-7.md, "Stage 7"), built for
// x86_64, aarch64 and riscv64 with the native backend and with --backend=llvm, and run (the two
// cross targets under qemu-user, PATH must reach qemu-*-static):
//  - tests/atomics/litmus.grl: message passing (relaxed data, release flag, acquire read), a
//    compare_exchange counter, a compare_exchange_weak retry loop, fetch_add, a narrow fetch_add that
//    wraps at 16 bits, all from 24 jobs; fetch_min/fetch_max at the boundaries of i64, u8 and i8;
//  - tests/atomics/litmus_sb.grl: store buffering with sequentially consistent stores and loads,
//    which asserts no forbidden outcome except under qemu-aarch64 (it says why). Under the
//    repository's patched qemu-aarch64 (tools/qemu/build.sh, whose `--version` ends in
//    `(grail-stlr-rcsc)`) this tool asserts it instead: the program cannot tell the patched emulator
//    from the stock one, both report CPU implementer 0x00, but the runner's version line can;
//  - tests/atomics/widths.grl: every width wraps at its own size, min/max signedness from T.
// Which of these can catch a fault under qemu and which only on weakly ordered hardware is listed
// in book/chapters/concurrency.md, "Litmus tests".
//   bun tools/test-atomics-litmus.mjs [--compiler PATH] [--target T]
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { root, buildCompiler, compileProgram, execute, runner, targets, hostTarget } from './native.mjs';

const argv = process.argv.slice(2);
const at = argv.indexOf('--compiler');
const compiler = at === -1 ? buildCompiler() : argv[at + 1];
const only = argv.indexOf('--target');
const chosen = only === -1 ? targets : [argv[only + 1]];
const work = join(root, '.work/atomics-litmus');
const programs = [
  { file: 'tests/atomics/litmus.grl', expected: 'tests/atomics/litmus.expected' },
  { file: 'tests/atomics/litmus_sb.grl', check: out => /^store buffering: (no forbidden outcome|not asserted under an emulator that reports implementer 0x00; forbidden outcomes: \d+)\n$/.test(out) },
  { file: 'tests/atomics/widths.grl', expected: 'tests/atomics/widths.expected' },
];
// Whether `target` runs under an emulator whose store-release is RCsc (tools/qemu/stlr-rcsc.patch).
const rcsc = target => {
  if (target === hostTarget || target !== 'aarch64') return false;
  const version = spawnSync(runner(target)[0], ['--version'], { encoding: 'utf8' });
  const line = (version.stdout ?? '').split('\n')[0];
  console.log(`${target} emulator: ${runner(target)[0]}: ${line}`);
  return line.includes('(grail-stlr-rcsc)');
};
let failed = 0;
for (const target of chosen) {
  const strict = rcsc(target);
  for (const backend of ['native', 'llvm']) {
    for (const program of programs) {
      const name = program.file.split('/').pop().replace('.grl', '');
      const label = `${target} ${backend} ${name}`;
      let ran;
      try {
        const exe = compileProgram(compiler, [program.file], join(work, `${name}-${target}-${backend}`), { target, backend, name });
        ran = execute(exe, [], target, { encoding: 'utf8' });
      } catch (error) {
        failed += 1;
        console.log(`FAIL ${label}: ${String(error.message).split('\n').slice(0, 6).join('\n')}`);
        continue;
      }
      const out = ran.stdout.toString();
      const want = program.expected ? readFileSync(join(root, program.expected), 'utf8') : null;
      let good = ran.status === 0 && (want !== null ? out === want : program.check(out));
      // Under the patched emulator the store-buffering count is asserted, not only reported.
      if (strict && name === 'litmus_sb' && !/forbidden outcomes: 0\n$|no forbidden outcome\n$/.test(out)) good = false;
      if (!good) {
        failed += 1;
        console.log(`FAIL ${label}: status ${ran.status} ${ran.signal ?? ''}\n${out}${ran.stderr}`);
      } else {
        console.log(`ok   ${label}${name === 'litmus_sb' ? `: ${out.trim()}` : ''}`);
      }
    }
  }
}
if (failed) {
  console.log(`atomics-litmus: ${failed} failed`);
  process.exit(1);
}
console.log('atomics-litmus: ok');
