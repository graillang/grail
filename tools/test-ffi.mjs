// Native FFI regressions: `extern "C"` declarations are resolved by the host
// linker against a freestanding C shim, so these tests exercise the real C ABI
// (argument registers, result register, symbol naming) instead of a stub.
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, rmSync, copyFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { root, hostTarget, targets, targetName, buildCompiler, compileProgram, execute, runner } from './native.mjs';

const triples = { x86_64: 'x86_64-linux-gnu', aarch64: 'aarch64-linux-gnu', riscv64: 'riscv64-linux-gnu' };
// name, expected stdout, and the C symbols the assembly must call unmangled.
const fixtures = [
  {
    name: 'call_scalars',
    stdout: '83\n7\n', // 19+23, 2*3, -(-1), 1+2+3+4, 9-1+9-1+9-1 => 83; identity => 7
    symbols: ['c_add', 'c_mul', 'c_negate', 'c_sum4', 'c_choose', 'c_identity'],
  },
  {
    name: 'views_handles',
    stdout: '259\n1\n', // strlen 5 + "ABC" 198 + fill 7 + 7*7 49 => 259; handle round trip => 1
    symbols: ['c_strlen', 'c_sum_bytes', 'c_fill', 'c_open', 'c_close'],
  },
];
const selected = process.argv[2] ? [targetName(process.argv[2])] : [hostTarget, ...targets.filter(t => t !== hostTarget)];
const compiler = buildCompiler();
const work = join(root, '.work/ffi');
let executed = 0;
let linkedOnly = 0;

function shim(target) {
  const directory = join(work, target);
  mkdirSync(directory, { recursive: true });
  const object = join(directory, 'shim.o');
  const flags = target === 'riscv64' ? ['-march=rv64imafd', '-mabi=lp64'] : [];
  const result = spawnSync(process.env.GRAIL_ASSEMBLER ?? 'clang', [
    `--target=${triples[target]}`, ...flags, '-c', '-O1', '-ffreestanding',
    '-fno-stack-protector', '-fno-pic', join(root, 'tests/ffi/shim.c'), '-o', object,
  ], { cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: 900_000 });
  if (result.status !== 0) throw new Error(`shim.c for ${target} failed: ${result.stderr}`);
  return object;
}

function canRun(target) {
  if (target === hostTarget) return true;
  const argv = runner(target);
  return argv.length === 0 ? true : spawnSync('sh', ['-c', `command -v "${argv[0]}" >/dev/null 2>&1 || test -x "${argv[0]}"`]).status === 0;
}

for (const target of selected) {
  const directory = join(work, target);
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  shim(target);
  for (const { name, stdout, symbols } of fixtures) {
    // The fixture is copied next to the shim object: `lib "shim.o"` resolves
    // relative to the declaring source, which is the documented rule.
    const source = join(directory, `${name}.grl`);
    copyFileSync(join(root, `tests/ffi/${name}.grl`), source);
    const executable = compileProgram(compiler, [source], directory, { target, name, defaultU64: true, typedRefs: true });
    const assembly = readFileSync(join(directory, `${name}.s`), 'utf8');
    const notes = assembly.split('\n').filter(line => line.startsWith('// grail-link: '));
    assert.equal(notes.length, 1, `${target}/${name}: the six declarations must request exactly one link input: ${notes}`);
    assert.equal(notes[0], '// grail-link: shim.o', `${target}/${name}: unexpected link note ${notes[0]}`);
    for (const symbol of symbols) {
      // x86-64 and RISC-V spell the call `call SYM`; AArch64 lowers it to `bl SYM`.
      assert.ok(new RegExp(`(^|\\n)(call|bl) ${symbol}\\n`).test(assembly), `${target}/${name}: missing unmangled call to ${symbol}`);
    }
    assert.ok(!/f_ffi_[a-z_]+_c_/.test(assembly), `${target}/${name}: a C symbol was mangled`);
    const object = readFileSync(`${executable}.o`).toString('latin1');
    for (const symbol of symbols) {
      assert.ok(object.includes(symbol), `${target}/${name}: object does not reference ${symbol}`);
    }
    if (!canRun(target)) {
      linkedOnly++;
      continue;
    }
    const result = execute(executable, [], target, { cwd: directory });
    assert.equal(result.status, 0, `${target}/${name}: exit ${result.status}: ${result.stderr}`);
    assert.equal(result.stdout.toString(), stdout, `${target}/${name}: calls returned wrong values`);
    executed++;
  }
}
const skipped = linkedOnly ? ` (${linkedOnly} linked but not executed: no cross emulator installed)` : '';
console.log(`ffi: ${executed} linked and executed, ${linkedOnly} linked only${skipped}`);
