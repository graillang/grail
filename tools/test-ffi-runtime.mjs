// Native Linux test for the first Grail-facing wrappers over the C OS ABI.
//
// Uses GRAIL_FFI_COMPILER, or GRAIL_COMPILER, pointing at a compiler built
// from current main with the merged v3 FFI.
// The hosted Linux C backend is linked with the host C library and normal
// dynamic TLS; a test-only runtime copy keeps libc's thread pointer intact.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const work = join(root, '.work/ffi-runtime');
const scratch = join(work, 'scratch');
const compiler = process.env.GRAIL_FFI_COMPILER ?? process.env.GRAIL_COMPILER;
if (!compiler) {
  throw new Error('ffi-runtime: set GRAIL_COMPILER (or GRAIL_FFI_COMPILER) to a compiler built from this tree');
}
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
  run(cc, ['-std=c11', '-D_GNU_SOURCE', '-O1', '-fno-pic', '-fno-pie', '-Iinclude',
    '-c', source, '-o', object]);
  objects.push(object);
}
const backend = join(root, 'lib/sys/grail_ffi_linux.o');
run(cc, ['-r', ...objects, '-o', backend]);

const runtimeSource = readFileSync(join(root, 'compiler/runtime.grl'), 'utf8');
const threadStart = runtimeSource.indexOf('fn rt_thread_init() -> u64 {');
if (threadStart < 0) {
  throw new Error('ffi-runtime: compiler/runtime.grl has no rt_thread_init');
}
const threadEnd = runtimeSource.indexOf('\n}', threadStart);
if (threadEnd < 0) {
  throw new Error('ffi-runtime: cannot delimit rt_thread_init');
}
const threadBlock = runtimeSource.slice(threadStart, threadEnd + 2);
if (!threadBlock.includes('    raw_tp_set(w);')) {
  throw new Error('ffi-runtime: rt_thread_init no longer sets the thread pointer');
}
const patchedThread = threadBlock.replace(
  '    raw_tp_set(w);', '    // FFI runtime test only: preserve libc\'s thread pointer/TLS.');
const runtime = join(work, 'runtime_nofs.grl');
writeFileSync(runtime, runtimeSource.slice(0, threadStart) + patchedThread +
  runtimeSource.slice(threadEnd + 2));
const osRuntime = join(root, 'compiler/os-linux.grl');

const entry = 'tests/ffi-runtime/native.grl';
const wrapper = 'lib/sys/grail_ffi.grl';
const linkNote = '// grail-link: grail_ffi_linux.o';

function compileAssembly(target, name) {
  const assembly = join(work, `${name}.s`);
  run(compiler, ['--default-u64', '--typed-refs', '--target', target, '--overflow=checked',
    assembly, entry, wrapper, runtime, osRuntime]);
  const text = readFileSync(assembly, 'utf8');
  const notes = text.split('\n').filter(line => line.startsWith('// grail-link: '));
  if (notes.length !== 1 || notes[0] !== linkNote) {
    throw new Error(`${name}: expected one ${linkNote} note, got ${JSON.stringify(notes)}`);
  }
  return { assembly, text };
}

const host = compileAssembly('x86_64', 'native-x86_64');
for (const symbol of ['grail_ffi_init', 'grail_ffi_file_open', 'grail_ffi_file_handle',
  'grail_os_file_read', 'grail_os_file_write', 'grail_os_file_stat', 'grail_os_time_now',
  'grail_os_env_get', 'grail_os_env_set', 'grail_os_file_close']) {
  if (!new RegExp(`(^|\\n)call ${symbol}\\n`).test(host.text)) {
    throw new Error(`native-x86_64: missing unmangled call to ${symbol}`);
  }
}
run(clang, ['-c', host.assembly, '-o', join(work, 'native-x86_64.o')]);
const executable = join(work, 'native-x86_64');
run(clang, ['-nostartfiles', '-no-pie', join(work, 'native-x86_64.o'), backend,
  '-o', executable, '-lc', '-lpthread', '-ldl', '-Wl,-e,_start']);
const executed = spawnSync(executable, [], { cwd: scratch, encoding: 'utf8' });
if (executed.status !== 0) {
  throw new Error(`native-x86_64: exit ${executed.status}\n${executed.stdout}${executed.stderr}`);
}
if (executed.stdout.trim() !== 'ffi-runtime: ok') {
  throw new Error(`native-x86_64: unexpected output ${JSON.stringify(executed.stdout)}`);
}
const note = readFileSync(join(scratch, 'ffi_note.txt'), 'utf8');
if (note !== 'hello ffi') {
  throw new Error(`native-x86_64: file content ${JSON.stringify(note)}`);
}
rmSync(join(scratch, 'ffi_note.txt'));

for (const target of ['aarch64', 'riscv64']) {
  const cross = compileAssembly(target, `native-${target}`);
  const branch = target === 'aarch64' ? 'bl' : 'call';
  for (const symbol of ['grail_ffi_init', 'grail_os_file_read', 'grail_os_file_stat',
    'grail_os_time_now', 'grail_os_env_get']) {
    if (!new RegExp(`(^|\\n)${branch} ${symbol}\\n`).test(cross.text)) {
      throw new Error(`native-${target}: missing ${branch} ${symbol}`);
    }
  }
}

if (!existsSync(join(root, 'lib/sys/grail_ffi_linux.o'))) {
  throw new Error('ffi-runtime: backend object was not produced');
}
console.log('ffi-runtime: x86_64 built, linked and executed; aarch64/riscv64 assembly checked');
