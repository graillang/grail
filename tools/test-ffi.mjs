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
    // Inline C arrays in a C record: bytes, u32, f32, records and i8 read whole as vectors, one
    // assigned back (C sums 100+101+102+1000 + 9 - 3 + 150 = 1459); C strings read back with
    // cstr_bytes (a null CStr reads as empty); and C arrays handed out by pointer and length
    // (strings, ints, records) copied with cslice.
    name: 'c_arrays',
    stdout: '80\nRadeon 680M\n4 100 103\n0.5 1.5\n-3 2.5\n-1 -3\n424242\n1459\nhello from C\n0\n'
      + 'VK_KHR_surface\nVK_KHR_xlib_surface\nVK_EXT_debug_utils\n-6 -8\n2 0.5\n',
    symbols: ['c_ca_fill', 'c_ca_sum', 'c_ca_size', 'c_ca_greeting', 'c_ca_null', 'c_ca_names', 'c_ca_ints', 'c_ca_pts'],
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
    // Record results with floats inside an embedded record, classified over the flattened leaves.
    name: 'nested_float_results',
    stdout: '1.5 3 10.25\n-7 0.25 3.5\n0.5 1.5 2.5\n2.75 42\n',
    symbols: ['c_np_pd', 'c_nf_mixed', 'c_nh_3d', 'c_nf_fi'],
  },
  {
    // Extern records embedded by value (offsets, projection, assignment, copy-out, results).
    name: 'nested_records',
    stdout: '49044\n21\n3\n-7\n100000000000\n42\n9\n77\n154\n6\n7\n42\n',
    symbols: ['c_outer_sum', 'c_outer_fill', 'c_outer_size', 'c_make_wrap'],
  },
  {
    // Bare data pointers: cptr / cptr_mut / cnull, and a pointer field in an extern record.
    name: 'pointers',
    stdout: '10\n198\n1\n0\n60\n24\n',
    symbols: ['c_ptr_sum', 'c_ptr_fill', 'c_is_null', 'c_buf_sum'],
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
    // Records passed to C by value (`v: byval R`): 4, 8, 12, 16, 24 and 40 bytes, mixed int/float
    // fields, an ImVec2-shaped float pair and an embedded array, plus a byval parameter after six
    // integer arguments, a byval record sharing the stack area with a following scalar, and a call
    // through a `cfn` whose signature declares the byval parameter. Then records back out by value
    // (4, 12, 16, 24, 40 bytes), a callee that writes its own copy, and a record that arrives and
    // leaves by value in the same call.
    name: 'byval_records',
    stdout: '63\n-2995\n9000007\n3002001\n7006\n10025\n22650\n4321\n9000015\n176\n4876\n7009000\n3656322\n90662328\n'
      + '9008007\n54321\n3147650\n9000007\n17\n102101100\n41997\n15010005\n11154210\n7008009\n12345\n',
    symbols: ['c_byval4', 'c_byval8', 'c_byval12', 'c_byval16', 'c_byval24', 'c_byval40', 'c_byval_3f',
      'c_byval_mix', 'c_byval_md', 'c_byval_2f', 'c_byval_arr', 'c_byval_4f', 'c_byval_after',
      'c_byval_two', 'c_byval_slot', 'c_byval_tail', 'c_byval_mix_stack', 'c_byval_mutate',
      'c_bv_ret4', 'c_bv_ret12', 'c_bv_ret16', 'c_bv_ret24', 'c_bv_ret40', 'c_bv_roundtrip12',
      'c_bv_roundtrip40'],
  },
  {
    // `!` on None inside an `extern "C"` callback: the unwrap reaches the checked abort path, so C
    // never resumes and the parent sees SIGABRT - not the SIGSEGV a null payload would cause. The
    // fixture is an `unsafe module` (the runtime's raw mode), which is where the defect lived.
    name: 'unwrap_none_callback',
    stdout: 'before\n',
    symbols: ['c_apply'],
    defines: ['unwrap_none_cb'],
    modules: ['lib/core.grl'],
    signal: 'SIGABRT',
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
    // Out-parameters: C writes a handle or a bare pointer through `&mut` slot the Grail side owns,
    // and the Grail side reads it back. Every C twin checksums the value it found in the slot, so
    // these values change if the slot arrives uninitialized, if it is passed by value, or if the
    // write never reaches Grail: 20743/20743, 20763745/20765746/20746 (a seeded slot, then the
    // same slot again), 20739, 91/91 (the out slot as the seventh word), 819705/8197/12293 (two
    // slots in one call), 40/100 and 1/1010202 for a `const void **` and a `void **`, and
    // 28904/28788 for a create-info record with a byte view and the slot last.
    name: 'out_params',
    stdout: '20743\n20743\n20763745\n20765746\n20746\n20739\n20746\n91\n91\n819705\n8197\n12293\n40\n100\n1\n1010202\n28904\n28788\n',
    symbols: ['c_out_create', 'c_out_reread', 'c_out_id', 'c_out_seventh', 'c_out_two',
      'c_out_ptr', 'c_out_ptr_sum', 'c_out_ptr_mut', 'c_out_ptr_list', 'c_out_info'],
  },
  {
    // Records reached by pointer: `cptr(&r)` is the address of r's own C-layout fields, so a
    // create-info struct can point at another struct (13); `&mut R` is the C `R *` the callee fills
    // in place (0), including the fields it leaves alone (0) after C wrote api_version (4194304);
    // an array of handles is a record of handle fields C writes (0 for the call) and Grail passes
    // back (110), a seeded array built from those handles sums to 77, and the handle Grail reads out
    // of the array equals the one C handed back (1); an array of structs sums through two interior
    // element addresses (433); and one count record crosses two declarations of one symbol (8)
    // without aborting at exit.
    name: 'record_pointers',
    stdout: '13\n5\n0\n4194304\n0\n0\n110\n77\n1\n433\n8\n',
    symbols: ['c_create_info', 'c_app_version', 'c_fill_app', 'c_alloc_handles', 'c_sum_handles',
      'c_slot0', 'c_ref_sum', 'c_enum_count'],
  },
  {
    // `&mut` of an extern record held in a plain record's field: a Grail callee's write (7) and two
    // C writes that first checksum what they find (102, 307) reach that field and no other, so the
    // fields read back 40/41/60/61 and the neighbouring `count` stays 5.
    name: 'record_field_refs',
    stdout: '7\n102\n307\n40\n41\n60\n61\n5\n',
    symbols: ['c_pair_write'],
  },
  {
    // More than six word arguments: 7, 8 and 9 words, then the same calls with every argument
    // computed just before the call, so the seventh and eighth argument registers
    // (`%r10`/`%r11` in the compiler's spelling) carry live stores across the call. The position
    // weighted sums are 140, 204, 285; the order check is 123456789; 204 again for eight narrow
    // words; 900, 504 and 868 for the computed arguments.
    name: 'call_words',
    stdout: '140\n204\n285\n123456789\n204\n900\n504\n868\n',
    symbols: ['c_words7', 'c_words8', 'c_words9', 'c_words9_order', 'c_words8n'],
  },
  {
    // C calling back into Grail with eight word arguments: 1 + 2*2 + ... + 8*8 = 204. Only the
    // targets whose ABI passes all eight in integer registers; x86-64 SysV puts the seventh and
    // eighth on the stack, which the callback prologue does not read, so it is refused there.
    name: 'callback_words',
    stdout: '204\n',
    symbols: ['c_call_words8'],
    defines: ['g_words8'],
  },
  {
    // A callback writing into the struct C passes (`p: &mut R`): copy-in/copy-out, written back on
    // every exit. mode 0 edits y and w then falls through (1, x=4, y=15, w=1.5 -> 104156); mode 1
    // returns early after editing x (7, x=14, y=5 -> 714052); mode 2 replaces the whole value
    // (returns 4+5=9, x=9, y=8, w=2.25 -> 909089).
    name: 'callback_record_write',
    stdout: '104156\n714052\n909089\n',
    symbols: ['c_call_record_write'],
    defines: ['edit'],
  },
  {
    // Callbacks with arguments on the caller's stack (decision B7 follow-up, docs/ffi.md): 24
    // parameters mixing integers, doubles, a sign-extended i16, a widened f32 and a zero-extended
    // u8, and a doubles-first list RV64 spills into integer registers. 2895 + 4 * 382.25 = 4424;
    // 357.5 + 700 = 1057.5.
    name: 'callback_stack',
    stdout: '4424\n1057.5\n',
    symbols: ['c_call_wide', 'c_call_floats'],
    defines: ['g_wide', 'g_floats'],
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
  {
    // Foreign calls from runtime-created threads: a pool worker and a green task each call getpid,
    // strlen, malloc/free, close(-1) and read errno (EBADF) and pthread_self on their own glibc TCB
    // (1, 1); then the main thread and a worker hold different errno values at the same time and
    // each reads back its own (42, 21), with both threads inside the shim at once (2). The shim is
    // libc-linked, so like `dlopen` it needs the target's glibc.
    name: 'threads',
    stdout: '1\n1\n42\n21\n2\n',
    symbols: ['ts_errno_hold', 'pthread_self', 'getpid', 'malloc', 'free'],
    linkNote: ['// grail-link: thread_shim.o', '// grail-link: c'],
    modules: ['lib/pool.grl'],
    hostOnly: true,
  },
  {
    // A callback entered on a pthread the shim creates (a thread the runtime never saw) adopts a
    // record for the outermost callback: it allocates, makes a foreign call whose errno is that
    // thread's (EBADF), and re-enters C for a nested callback. Three rounds, so each adoption is
    // released and redone: 11, 111, 211.
    name: 'foreign_thread',
    stdout: '11\n111\n211\n',
    symbols: ['ts_call_on_new_thread', 'ts_call_here', 'close'],
    linkNote: ['// grail-link: thread_shim.o', '// grail-link: c'],
    modules: [],
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
    // A libc-linked object for the threads fixture: real errno/pthread headers, no outlined atomics.
    const threadShim = spawnSync(process.env.GRAIL_ASSEMBLER ?? 'clang', [
      ...(sysroot ? [`--target=${triples[target]}`, `--sysroot=${sysroot}`] : []),
      ...(target === 'riscv64' ? ['-march=rv64imafd', '-mabi=lp64d'] : []),
      ...(target === 'aarch64' ? ['-mno-outline-atomics'] : []),
      '-c', '-O1', '-fno-pic', join(root, 'tests/ffi/thread_shim.c'), '-o', join(directory, 'thread_shim.o'),
    ], { cwd: root, maxBuffer: 8 * 1024 * 1024, timeout: 300_000 });
    if (threadShim.status !== 0) throw new Error(`thread_shim.c for ${target} failed: ${threadShim.stderr}`);
  }
  for (const { name, stdout, symbols, defines = [], linkNote = '// grail-link: shim.o', hostOnly = false,
    modules = [], signal = null, targets: onlyTargets = null } of fixtures) {
    // A fixture whose shape one target refuses is compiled and executed only where it is valid; the
    // refusal itself is asserted at the end of this file.
    if (onlyTargets && !onlyTargets.includes(target)) continue;
    if (hostOnly && target !== hostTarget && !sysroot) {
      // A host-loader fixture still has to compile for every target; it cannot be
      // linked there because the host's libc and loader are not target libraries.
      const assembly = join(directory, `${name}.s`);
      const built = spawnSync(compiler, [
        '--target', target, assembly,
        join(root, `tests/ffi/${name}.grl`), ...modules.map(m => join(root, m)), ...compilerSources,
      ], { cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: 900_000 });
      assert.equal(built.status, 0, `${target}/${name}: cross compilation failed: ${built.stderr}`);
      const text = readFileSync(assembly, 'utf8');
      for (const symbol of symbols) {
        assert.ok(new RegExp(`(^|\\n)(call|bl) ${symbol}\\n`).test(text), `${target}/${name}: missing call to ${symbol} after cross compilation`);
      }
      crossCompiled++;
      continue;
    }
    // The fixture is copied next to the shim object: `lib "shim.o"` resolves
    // relative to the declaring source, which is the documented rule.
    const source = join(directory, `${name}.grl`);
    copyFileSync(join(root, `tests/ffi/${name}.grl`), source);
    const executable = compileProgram(compiler, [source, ...modules.map(m => join(root, m))], directory, { target, name });
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
    if (signal) {
      // An aborting fixture pins the signal (SIGABRT, not the SIGSEGV a bad unwrap would produce)
      // and whatever ran before it.
      assert.equal(result.signal, signal, `${target}/${name}: expected ${signal}, got ${result.signal} (${result.status})`);
      assert.equal(result.stdout.toString(), stdout, `${target}/${name}: output before the abort`);
      executed++;
      continue;
    }
    assert.equal(result.status, 0, `${target}/${name}: exit ${result.status}: ${result.stderr}`);
    assert.equal(result.stdout.toString(), stdout, `${target}/${name}: calls returned wrong values`);
    executed++;
  }
}
// Windows: byval records, callbacks with stack arguments and record writes, and nested-float
// results execute under Wine as tests/windows-cases.json cases (tools/windows.mjs).

const skipped = linkedOnly ? ` (${linkedOnly} linked but not executed: no cross emulator installed)` : '';
console.log(`ffi: ${executed} linked and executed, ${linkedOnly} linked only, ${crossCompiled} cross-compiled only${skipped}`);
