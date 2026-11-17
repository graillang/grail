// Native test for Borg session-state persistence through the C OS ABI.
//
// Builds the Linux reference backend into `lib/sys/grail_ffi_linux.o` (the object the wrapper
// declares), compiles `borg/tests/ffi/store_test.grl` with `lib/sys/grail_ffi.grl`,
// `borg/src/ffi/store.grl` and the event modules it persists, links against the host C library and
// runs it in a scratch directory. The expected output is the committed
// `borg/tests/parity/store.txt`.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { buildCompiler, root } from './native.mjs';

const work = join(root, '.work/borg-store');
const scratch = join(work, 'scratch');
const cc = process.env.CC ?? 'cc';
const clang = process.env.GRAIL_CLANG ?? 'clang';

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    process.stderr.write(result.stdout ?? '');
    process.stderr.write(result.stderr ?? '');
    throw new Error(`${command} ${args.join(' ')} failed with status ${result.status}`);
  }
  return result.stdout;
}

rmSync(work, { recursive: true, force: true });
mkdirSync(join(work, 'obj'), { recursive: true });
mkdirSync(scratch, { recursive: true });

// The same backend sources tools/test-ffi-runtime.mjs builds.
const sources = [
  'runtime/abi/grail_abi.c',
  'runtime/abi/grail_error.c',
  'runtime/abi/grail_error_posix.c',
  'runtime/abi/grail_unicode.c',
  'runtime/abi/grail_path.c',
  'runtime/abi/grail_handle_table.c',
  'runtime/abi/grail_env_store.c',
  'runtime/abi/linux/grail_os_linux.c',
  'runtime/abi/linux/grail_os_linux_fs.c',
  'runtime/abi/linux/grail_os_linux_thread.c',
  'runtime/abi/linux/grail_os_linux_proc.c',
  'runtime/abi/linux/grail_os_linux_net.c',
  'runtime/abi/ffi/grail_ffi_shim.c',
];
const objects = [];
for (const source of sources) {
  const object = join(work, 'obj', `${source.split('/').pop().replace(/\.c$/, '')}.o`);
  run(cc, ['-std=c11', '-D_GNU_SOURCE', '-O1', '-fno-pic', '-fno-pie', '-Iinclude', '-c', source, '-o', object]);
  objects.push(object);
}
const backend = join(root, 'lib/sys/grail_ffi_linux.o');
run(cc, ['-r', ...objects, '-o', backend]);

// A hosted build must leave libc's thread pointer alone; the test-only runtime copy does that, the
// same way tools/test-ffi-runtime.mjs does.
const runtimeSource = readFileSync(join(root, 'compiler/runtime.grl'), 'utf8');
const start = runtimeSource.indexOf('fn rt_thread_init() -> u64 {');
const end = runtimeSource.indexOf('\n}', start);
if (start < 0 || end < 0) throw new Error('borg-store: cannot locate rt_thread_init in compiler/runtime.grl');
const block = runtimeSource.slice(start, end + 2);
if (!block.includes('    raw_tp_set(w);')) throw new Error('borg-store: rt_thread_init no longer sets the thread pointer');
const patched = block.replace('    raw_tp_set(w);', "    // hosted FFI test: preserve libc's thread pointer/TLS.");
const runtime = join(work, 'runtime_hosted.grl');
writeFileSync(runtime, runtimeSource.slice(0, start) + patched + runtimeSource.slice(end + 2));

const compiler = buildCompiler();
const assembly = join(work, 'store.s');
run(compiler, ['--target', 'x86_64', '--overflow=checked', assembly,
  'borg/tests/ffi/store_test.grl', 'borg/src/ffi/store.grl', 'lib/sys/grail_ffi.grl',
  'borg/src/events.grl', 'borg/src/journal.grl', 'borg/src/json.grl', 'lib/core.grl', 'lib/strings.grl', 'lib/bytes.grl', 'lib/float.grl', 'lib/iter.grl', 'lib/vecs.grl', 'lib/order.grl',
  'lib/hash.grl', 'lib/io.grl', 'lib/fs.grl', 'lib/env.grl', runtime,
  'compiler/os-linux.grl']);

run(clang, ['-c', assembly, '-o', join(work, 'store.o')]);
const executable = join(work, 'store');
run(clang, ['-nostartfiles', '-no-pie', join(work, 'store.o'), backend, '-o', executable,
  '-lc', '-lpthread', '-ldl', '-Wl,-e,_start']);

const executed = spawnSync(executable, [scratch], { cwd: scratch, encoding: 'utf8' });
if (executed.error) throw executed.error;
if (executed.status !== 0) {
  process.stderr.write(executed.stdout ?? '');
  process.stderr.write(executed.stderr ?? '');
  throw new Error(`store test exited with ${executed.status}`);
}
const actual = (executed.stdout ?? '').trimEnd();
const expectedPath = join(root, 'borg/tests/parity/store.txt');
if (process.argv.includes('--regenerate')) {
  writeFileSync(expectedPath, actual + '\n');
  console.log(`store: wrote ${actual.split('\n').length} reference lines`);
} else {
  if (!existsSync(expectedPath)) throw new Error(`missing reference ${expectedPath}; run with --regenerate`);
  const expected = readFileSync(expectedPath, 'utf8').trimEnd();
  if (actual !== expected) {
    console.error('store: output differs from borg/tests/parity/store.txt');
    const want = expected.split('\n');
    const got = actual.split('\n');
    for (let i = 0; i < Math.max(want.length, got.length); i++) {
      if (want[i] === got[i]) continue;
      console.error(`  line ${i + 1}\n    reference: ${want[i] ?? '(missing)'}\n    grail:     ${got[i] ?? '(missing)'}`);
    }
    process.exit(1);
  }
  console.log(`store: ${expected.split('\n').length} reference lines match`);
}
