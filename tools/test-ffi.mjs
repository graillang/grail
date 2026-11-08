// Native FFI regressions: `extern "C"` declarations are resolved by the host
// linker against a freestanding C shim, so these tests exercise the real C ABI
// (argument registers, result register, symbol naming) instead of a stub.
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, rmSync, copyFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { root, hostTarget, targets, targetName, buildCompiler, compileProgram, execute, runner } from './native.mjs';

const triples = { x86_64: 'x86_64-linux-gnu', aarch64: 'aarch64-linux-gnu', riscv64: 'riscv64-linux-gnu' };
const fixtures = ['call_scalars'];
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
  for (const name of fixtures) {
    // The fixture is copied next to the shim object: `lib "shim.o"` resolves
    // relative to the declaring source, which is the documented rule.
    const source = join(directory, `${name}.grl`);
    copyFileSync(join(root, `tests/ffi/${name}.grl`), source);
    const executable = compileProgram(compiler, [source], directory, { target, name, defaultU64: true, typedRefs: true });
    const assembly = readFileSync(join(directory, `${name}.s`), 'utf8');
    const notes = assembly.split('\n').filter(line => line.startsWith('// grail-link: '));
    assert.equal(notes.length, 1, `${target}/${name}: the six declarations must request exactly one link input: ${notes}`);
    assert.equal(notes[0], '// grail-link: shim.o', `${target}/${name}: unexpected link note ${notes[0]}`);
    for (const symbol of ['c_add', 'c_mul', 'c_identity', 'c_sum4', 'c_choose']) {
      // x86-64 and RISC-V spell the call `call SYM`; AArch64 lowers it to `bl SYM`.
      assert.ok(new RegExp(`(^|\\n)(call|bl) ${symbol}\\n`).test(assembly), `${target}/${name}: missing unmangled call to ${symbol}`);
    }
    assert.ok(!assembly.includes('f_ffi_call_scalars_c_add'), `${target}/${name}: C symbol was mangled`);
    const object = readFileSync(`${executable}.o`).toString('latin1');
    assert.ok(object.includes('c_add'), `${target}/${name}: object does not reference c_add`);
    if (!canRun(target)) {
      linkedOnly++;
      continue;
    }
    const result = execute(executable, [], target, { cwd: directory });
    assert.equal(result.status, 0, `${target}/${name}: exit ${result.status}: ${result.stderr}`);
    // 19+23 = 42, 2*3 = 6, -(-1) = 1, 1+2+3+4 = 10, 9-1+9-1+9-1 = 24 => 83;
    // the u64 identity call returns 7 in the same result register path.
    assert.equal(result.stdout.toString(), '83\n7\n', `${target}/${name}: calls returned wrong values`);
    executed++;
  }
}
const skipped = linkedOnly ? ` (${linkedOnly} linked but not executed: no cross emulator installed)` : '';
console.log(`ffi: ${executed} linked and executed, ${linkedOnly} linked only${skipped}`);
