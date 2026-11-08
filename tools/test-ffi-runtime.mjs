// Native Linux test for the first Grail-facing wrappers over the C OS ABI.
//
// Uses GRAIL_FFI_COMPILER, or GRAIL_COMPILER, pointing at a compiler built
// from current main with the merged v3 FFI.
// The hosted Linux C backend is linked with the host C library and runs on
// libc's TLS through the compiler's foreign-call bridge.
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

// The compiler's host-TLS bridge (docs/ffi.md) lets the real runtime own the thread pointer.
const runtime = join(root, 'compiler/runtime.grl');
const osRuntime = join(root, 'compiler/os-linux.grl');

const wrapper = 'lib/sys/grail_ffi.grl';
const linkNote = '// grail-link: grail_ffi';
const cases = [
  {
    name: 'native',
    entry: 'tests/ffi-runtime/native.grl',
    output: 'ffi-runtime: ok',
    host_symbols: ['grail_ffi_init', 'grail_ffi_file_open', 'grail_ffi_file_handle',
      'grail_os_file_read', 'grail_os_file_write', 'grail_os_file_stat', 'grail_os_time_now',
      'grail_os_env_get', 'grail_os_env_set', 'grail_os_file_close'],
    cross_symbols: ['grail_ffi_init', 'grail_os_file_read', 'grail_os_file_stat',
      'grail_os_time_now', 'grail_os_env_get'],
    check_file: true,
  },
  {
    name: 'socket',
    entry: 'tests/ffi-runtime/socket.grl',
    output: 'ffi-socket: ok',
    host_symbols: ['grail_ffi_socket_create', 'grail_ffi_socket_handle',
      'grail_ffi_socket_accept', 'grail_os_socket_bind', 'grail_os_socket_listen',
      'grail_os_socket_connect', 'grail_os_socket_send', 'grail_os_socket_recv',
      'grail_os_socket_shutdown', 'grail_os_socket_close', 'grail_os_socket_local_address',
      'grail_os_socket_peer_address'],
    cross_symbols: ['grail_ffi_socket_create', 'grail_ffi_socket_handle',
      'grail_ffi_socket_accept', 'grail_os_socket_bind', 'grail_os_socket_listen',
      'grail_os_socket_connect', 'grail_os_socket_send', 'grail_os_socket_recv',
      'grail_os_socket_shutdown', 'grail_os_socket_close', 'grail_os_socket_local_address',
      'grail_os_socket_peer_address'],
    check_file: false,
  },
  {
    name: 'proc_thread',
    entry: 'tests/ffi-runtime/proc_thread.grl',
    output: 'ffi-proc-thread: ok',
    host_symbols: ['grail_ffi_process_spawn', 'grail_ffi_process_handle',
      'grail_os_process_wait', 'grail_os_process_id', 'grail_os_process_close',
      'grail_ffi_thread_spawn', 'grail_ffi_thread_handle', 'grail_os_thread_join'],
    cross_symbols: ['grail_ffi_process_spawn', 'grail_ffi_process_handle',
      'grail_os_process_wait', 'grail_os_process_id', 'grail_os_process_close',
      'grail_ffi_thread_spawn', 'grail_ffi_thread_handle', 'grail_os_thread_join'],
    check_file: false,
  },
];

function compileAssembly(testCase, target, name) {
  const assembly = join(work, `${name}.s`);
  run(compiler, ['--default-u64', '--typed-refs', '--target', target, '--overflow=checked',
    assembly, testCase.entry, wrapper, runtime, osRuntime]);
  const text = readFileSync(assembly, 'utf8');
  const notes = text.split('\n').filter(line => line.startsWith('// grail-link: '));
  if (notes.length !== 1 || notes[0] !== linkNote) {
    throw new Error(`${name}: expected one ${linkNote} note, got ${JSON.stringify(notes)}`);
  }
  return { assembly, text };
}

for (const testCase of cases) {
  const host = compileAssembly(testCase, 'x86_64', `${testCase.name}-x86_64`);
  for (const symbol of testCase.host_symbols) {
    if (!new RegExp(`(^|\\n)call ${symbol}\\n`).test(host.text)) {
      throw new Error(`${testCase.name}-x86_64: missing unmangled call to ${symbol}`);
    }
  }
  const hostObject = join(work, `${testCase.name}-x86_64.o`);
  run(clang, ['-c', host.assembly, '-o', hostObject]);
  const executable = join(work, `${testCase.name}-x86_64`);
  run(clang, ['-nostartfiles', '-no-pie', hostObject, backend,
    '-o', executable, '-lc', '-lpthread', '-ldl', '-Wl,-e,_start']);
  const executed = spawnSync(executable, [], { cwd: scratch, encoding: 'utf8' });
  if (executed.status !== 0) {
    throw new Error(`${testCase.name}-x86_64: exit ${executed.status}\n${executed.stdout}${executed.stderr}`);
  }
  if (executed.stdout.trim() !== testCase.output) {
    throw new Error(`${testCase.name}-x86_64: unexpected output ${JSON.stringify(executed.stdout)}`);
  }
  if (testCase.check_file) {
    const notePath = join(scratch, 'ffi_note.txt');
    const note = readFileSync(notePath, 'utf8');
    if (note !== 'hello ffi') {
      throw new Error(`${testCase.name}-x86_64: file content ${JSON.stringify(note)}`);
    }
    rmSync(notePath);
  }

  for (const target of ['aarch64', 'riscv64']) {
    const cross = compileAssembly(testCase, target, `${testCase.name}-${target}`);
    const branch = target === 'aarch64' ? 'bl' : 'call';
    for (const symbol of testCase.cross_symbols) {
      if (!new RegExp(`(^|\\n)${branch} ${symbol}\\n`).test(cross.text)) {
        throw new Error(`${testCase.name}-${target}: missing ${branch} ${symbol}`);
      }
    }
  }
}

if (!existsSync(join(root, 'lib/sys/grail_ffi_linux.o'))) {
  throw new Error('ffi-runtime: backend object was not produced');
}
console.log('ffi-runtime: file, socket and process/thread tests built, linked and executed on x86_64; aarch64/riscv64 assembly checked');
