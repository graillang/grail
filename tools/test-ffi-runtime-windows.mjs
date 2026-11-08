// Windows evidence for the Grail stdlib wrappers (lib/sys/grail_ffi.grl): the C OS ABI and the
// FFI shim are built into grail_ffi.dll with Zig's MinGW toolchain (its own CRT and ws2_32), and
// each Grail test is compiled for x86_64-windows, imports its `extern "C" lib "grail_ffi"`
// symbols from that DLL, and runs under Wine. The process test spawns cmd.exe instead of /bin/sh.
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { compileProgram } from './windows.mjs';

const root = new URL('..', import.meta.url).pathname;
const work = join(root, '.work/ffi-runtime-windows');
const compiler = process.env.GRAIL_FFI_COMPILER ?? process.env.GRAIL_COMPILER;
if (!compiler) throw new Error('ffi-runtime-windows: set GRAIL_COMPILER to a compiler built from this tree');

function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.status})\n${result.stdout}${result.stderr}`);
}

rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const dll = join(work, 'grail_ffi.dll');
run('zig', ['cc', '-target', 'x86_64-windows-gnu', '-shared', '-std=c11', '-O1', '-DGRAIL_ABI_STATIC', '-Iinclude',
  'runtime/abi/grail_abi.c', 'runtime/abi/grail_error.c', 'runtime/abi/grail_unicode.c',
  'runtime/abi/grail_path.c', 'runtime/abi/grail_handle_table.c', 'runtime/abi/grail_env_store.c',
  'runtime/abi/windows/grail_os_windows.c', 'runtime/abi/ffi/grail_ffi_shim.c',
  '-Wl,--export-all-symbols', '-o', dll, '-lws2_32']);

const cases = [
  { name: 'files', entry: 'tests/ffi-runtime/native.grl', stdout: 'ffi-runtime: ok' },
  { name: 'sockets', entry: 'tests/ffi-runtime/socket.grl', stdout: 'ffi-socket: ok' },
  { name: 'processes-threads', entry: 'tests/ffi-runtime/proc_thread_windows.grl', stdout: 'ffi-proc-thread: ok' },
  { name: 'stdout-capture', entry: 'tests/ffi-runtime/capture_windows.grl', stdout: 'ffi-capture: ok' },
];
for (const testCase of cases) {
  const directory = join(work, testCase.name);
  const built = compileProgram(compiler, [testCase.entry, 'lib/sys/grail_ffi.grl'], directory);
  copyFileSync(dll, join(directory, 'grail_ffi.dll'));
  const executed = spawnSync('wine', [built.executable], {
    cwd: directory, encoding: 'utf8', timeout: 120_000, env: { ...process.env, WINEDEBUG: '-all' },
  });
  if (executed.status !== 0 || !(executed.stdout ?? '').includes(testCase.stdout)) {
    throw new Error(`ffi-runtime-windows ${testCase.name}: exit ${executed.status}\n${executed.stdout}${executed.stderr}`);
  }
}
console.log(`ffi-runtime-windows: ${cases.length} wrapper tests (files, sockets, processes/threads, stdout capture) executed under Wine through grail_ffi.dll`);
