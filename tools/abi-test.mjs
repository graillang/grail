import { mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = new URL('..', import.meta.url).pathname;
const work = join(root, '.work/abi-tests');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

const cc = process.env.CC ?? 'cc';
const clang = process.env.GRAIL_CLANG ?? 'clang';
const cflags = ['-std=c11', '-D_GNU_SOURCE', '-Wall', '-Wextra', '-Werror', '-Iinclude', '-pthread'];

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

function buildAndRun(name, sources, extra = []) {
  const executable = join(work, name);
  run(cc, [...cflags, ...extra, ...sources, '-o', executable]);
  const output = run(executable, []).trim();
  console.log(output);
}

const common = [
  'runtime/abi/grail_abi.c',
  'runtime/abi/grail_error.c',
  'runtime/abi/grail_unicode.c',
];

buildAndRun('core', ['tests/abi/test_core.c', ...common]);
buildAndRun('linux-backend', ['tests/abi/test_linux_backend.c',
  'runtime/abi/grail_abi.c', 'runtime/abi/grail_error.c', 'runtime/abi/grail_unicode.c',
  'runtime/abi/grail_path.c', 'runtime/abi/grail_handle_table.c',
  'runtime/abi/linux/grail_os_linux.c', 'runtime/abi/linux/grail_os_linux_fs.c',
  'runtime/abi/linux/grail_os_linux_thread.c',
  'runtime/abi/linux/grail_os_linux_proc.c', 'runtime/abi/linux/grail_os_linux_net.c'], ['-ldl']);
buildAndRun('skeleton-windows', ['tests/abi/test_skeleton.c',
  'runtime/abi/grail_abi.c', 'runtime/abi/grail_error.c',
  'runtime/abi/windows/grail_os_windows.c']);
buildAndRun('skeleton-macos', ['tests/abi/test_skeleton.c',
  'runtime/abi/grail_abi.c', 'runtime/abi/grail_error.c',
  'runtime/abi/macos/grail_os_macos.c']);
buildAndRun('handles', ['tests/abi/test_handle_table.c',
  'runtime/abi/grail_handle_table.c']);
buildAndRun('paths-posix', ['tests/abi/test_paths.c', 'runtime/abi/grail_abi.c',
  'runtime/abi/grail_error.c', 'runtime/abi/grail_path.c']);
buildAndRun('paths-windows', ['tests/abi/test_paths.c', 'runtime/abi/grail_abi.c',
  'runtime/abi/grail_error.c', 'runtime/abi/grail_path.c'], ['-DGRAIL_ABI_PATH_WINDOWS=1']);

if (spawnSync(clang, ['--version']).status === 0) {
  const targets = [
    'x86_64-unknown-linux-gnu',
    'aarch64-unknown-linux-gnu',
    'riscv64-unknown-linux-gnu',
    'x86_64-pc-windows-msvc',
    'arm64-apple-macos11',
  ];
  for (const target of targets) {
    run(clang, ['-target', target, '-ffreestanding', '-fsyntax-only', '-std=c11',
      '-Wall', '-Wextra', '-Werror', '-Iinclude', 'tests/abi/test_headers.c']);
    console.log(`headers: ${target} parses`);
  }
}
console.log('abi: all checks passed');
