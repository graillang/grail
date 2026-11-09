// Native FFI regressions: `extern "C"` declarations are resolved by the host
// linker against a freestanding C shim, so these tests exercise the real C ABI
// (argument registers, result register, symbol naming) instead of a stub.
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, rmSync, copyFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { root, hostTarget, targets, targetName, buildCompiler, compileProgram, execute, runner, compilerSources, crossSysroot } from './native.mjs';

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
  {
    name: 'callbacks',
    // C calls the Grail callbacks: 21*2, 14*3, and 5*2 with callee-saved
    // registers clobbered around the call.
    stdout: '42\n42\n10\n',
    symbols: ['c_apply', 'c_apply_preserving'],
    defines: ['c_double', 'c_triple'],
  },
  {
    // C calls Grail callbacks with f64/f32/i8/u16 parameters and float results:
    // 1.5 - 30 + 0.25 + 65000 + 1000000 - 2.5 = 1064969.25; (1.25 * 2.5) * 2 = 6.25.
    name: 'callback_floats',
    stdout: '1064969.25\n6.25\n',
    symbols: ['c_call_fmix', 'c_call_f32'],
    defines: ['g_fmix', 'g_f32'],
  },
  {
    name: 'extern_records',
    // point sum 42, C-swapped x 23, mixed fields -7+300-5+9 = 297 and after C
    // rewrites them 1234-2+7+5 = 1244; then sizeof, s16/short -2/char 7 checks.
    stdout: '1606\n23\n16\n-2\n7\n',
    symbols: ['c_point_sum', 'c_point_swap', 'c_mixed_sum', 'c_mixed_fill', 'c_mixed_size', 'c_mixed_off_d'],
  },
  {
    // C records with f32/f64 fields at C offsets, written by Grail and by C.
    name: 'float_records',
    stdout: '960003.75\n1.5\n-2.25\n640\n1\n7\n0.125\n48\n',
    symbols: ['c_viewport_area', 'c_viewport_fill'],
  },
  {
    // Float-field records returned by value on every classification path.
    name: 'float_record_results',
    stdout: '1.5\n-2.25\n3\n0.75\n-9\n3.125\n1234567890123\n46\n',
    symbols: ['c_vec2', 'c_vec3d', 'c_fi', 'c_di', 'c_quad'],
  },
  {
    // Extern records embedded by value (offsets, projection, assignment, copy-out, results).
    name: 'nested_records',
    stdout: '49044\n21\n3\n-7\n100000000000\n42\n9\n77\n154\n6\n7\n42\n',
    symbols: ['c_outer_sum', 'c_outer_fill', 'c_outer_size', 'c_make_wrap'],
  },
  {
    // A COM-shaped vtable call with seven arguments and two floats through a typed cfn slot.
    name: 'call_com_slot',
    stdout: '1007\n1045\n',
    symbols: ['c_com_object', 'c_com_slot'],
  },
  {
    // Variadic C calls: 60; 55 (ten extra integers, past the registers); 3.75; 146.5 with nine
    // doubles past the eight vector registers and an f32 promoted to double.
    name: 'call_variadic',
    stdout: '60\n55\n3.75\n146.5\n',
    symbols: ['c_vsum', 'c_vmix'],
  },
  {
    // C records returned by value in registers and through a hidden result pointer.
    name: 'call_records',
    stdout: '-7\n300000\n4096\n-12\n42\n-5\n77\n',
    symbols: ['c_make_pair', 'c_make_span', 'c_make_triple'],
  },
  {
    // Floats, narrow integers and stack arguments: 1.5+2.25; 2^24+1 rounded in binary32;
    // -3+0.5+4e9+0.25+100; 1234.75 with Win64 stack slots; 385 from ten floats and ten
    // integers; -5; u32 max; -101; 65535+1 wraps to 0; an unsigned 32-bit compare.
    name: 'call_abi',
    stdout: '3.75\n16777216\n4000000097.75\n1234.75\n385\n385\n-5\n4294967295\n-101\n0\n1\n',
    symbols: ['c_fadd', 'c_fadd32', 'c_mix', 'c_mix6', 'c_many_f', 'c_many_i', 'c_neg32', 'c_u32max',
      'c_s8', 'c_u16', 'c_u32_above'],
  },
  {
    // Dynamic loader hooks: a shared library is loaded by path, two symbols are
    // resolved through dlsym and called through the resolved addresses, then the
    // library is closed. libc is the link input, so the executable is dynamic.
    name: 'dlopen',
    stdout: '42\n42\n42\n0\n',
    symbols: ['dlopen', 'dlsym', 'dlclose'],
    // dlopen/dlsym/dlclose live in libdl before glibc 2.34 (a stub after); strlen in libc.
    linkNote: ['// grail-link: dl', '// grail-link: c'],
    sharedLibrary: 'libdlshim.so',
    hostOnly: true,
  },
];
const selected = process.argv[2] ? [targetName(process.argv[2])] : [hostTarget, ...targets.filter(t => t !== hostTarget)];
const compiler = buildCompiler();
const work = join(root, '.work/ffi');
let executed = 0;
let linkedOnly = 0;
let crossCompiled = 0;

function shim(target) {
  const directory = join(work, target);
  mkdirSync(directory, { recursive: true });
  const object = join(directory, 'shim.o');
  const flags = target === 'riscv64' ? ['-march=rv64imafd', '-mabi=lp64d'] : [];
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
  // Loader fixtures need a real shared object for the target: the host, or a cross target with
  // a glibc sysroot (GRAIL_SYSROOT_<TARGET>), whose loader then runs it under qemu.
  const sysroot = crossSysroot(target);
  if ((target === hostTarget) || sysroot) {
    const cross = sysroot ? [`--target=${triples[target]}`, `--sysroot=${sysroot}`, '-fuse-ld=lld', '-nostdlib',
      ...(target === 'riscv64' ? ['-march=rv64imafd', '-mabi=lp64d'] : [])] : [];
    const library = spawnSync(process.env.GRAIL_ASSEMBLER ?? 'clang', [
      ...cross, '-shared', '-fPIC', '-O1', join(root, 'tests/ffi/dl_shim.c'),
      '-o', join(directory, 'libdlshim.so'),
    ], { cwd: root, maxBuffer: 8 * 1024 * 1024, timeout: 300_000 });
    if (library.status !== 0) throw new Error(`dl_shim.c for ${target} failed: ${library.stderr}`);
  }
  for (const { name, stdout, symbols, defines = [], linkNote = '// grail-link: shim.o', hostOnly = false } of fixtures) {
    if (hostOnly && target !== hostTarget && !sysroot) {
      // A host-loader fixture still has to compile for every target; it cannot be
      // linked there because the host's libc and loader are not target libraries.
      const assembly = join(directory, `${name}.s`);
      const built = spawnSync(compiler, [
        '--default-u64', '--typed-refs', '--target', target, assembly,
        join(root, `tests/ffi/${name}.grl`), ...compilerSources,
      ], { cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: 900_000 });
      assert.equal(built.status, 0, `${target}/${name}: cross compilation failed: ${built.stderr}`);
      const text = readFileSync(assembly, 'utf8');
      assert.ok(/(^|\n)(call|bl) dlsym\n/.test(text), `${target}/${name}: missing loader call after cross compilation`);
      crossCompiled++;
      continue;
    }
    // The fixture is copied next to the shim object: `lib "shim.o"` resolves
    // relative to the declaring source, which is the documented rule.
    const source = join(directory, `${name}.grl`);
    copyFileSync(join(root, `tests/ffi/${name}.grl`), source);
    const executable = compileProgram(compiler, [source], directory, { target, name, defaultU64: true, typedRefs: true });
    const assembly = readFileSync(join(directory, `${name}.s`), 'utf8');
    const notes = assembly.split('\n').filter(line => line.startsWith('// grail-link: '));
    const expectedNotes = Array.isArray(linkNote) ? linkNote : [linkNote];
    assert.deepEqual(notes, expectedNotes, `${target}/${name}: unexpected link notes ${notes}`);
    for (const symbol of symbols) {
      // x86-64 and RISC-V spell the call `call SYM`; AArch64 lowers it to `bl SYM`.
      assert.ok(new RegExp(`(^|\\n)(call|bl) ${symbol}\\n`).test(assembly), `${target}/${name}: missing unmangled call to ${symbol}`);
    }
    assert.ok(!/f_ffi_[a-z_]+_c_/.test(assembly), `${target}/${name}: a C symbol was mangled`);
    for (const symbol of defines) {
      assert.ok(new RegExp(`(^|\\n)${symbol}:\\n`).test(assembly), `${target}/${name}: callback symbol ${symbol} was not exported unmangled`);
    }
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
console.log(`ffi: ${executed} linked and executed, ${linkedOnly} linked only, ${crossCompiled} cross-compiled only${skipped}`);
