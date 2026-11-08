import { mkdirSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { basename, join } from 'node:path';
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
  'runtime/abi/grail_error_posix.c',
  'runtime/abi/grail_unicode.c',
];

buildAndRun('core', ['tests/abi/test_core.c', ...common]);
buildAndRun('linux-backend', ['tests/abi/test_linux_backend.c',
  'runtime/abi/grail_abi.c', 'runtime/abi/grail_error.c', 'runtime/abi/grail_error_posix.c',
  'runtime/abi/grail_unicode.c', 'runtime/abi/grail_path.c', 'runtime/abi/grail_handle_table.c',
  'runtime/abi/linux/grail_os_linux.c', 'runtime/abi/linux/grail_os_linux_fs.c',
  'runtime/abi/linux/grail_os_linux_thread.c',
  'runtime/abi/linux/grail_os_linux_proc.c', 'runtime/abi/linux/grail_os_linux_net.c'], ['-ldl']);
buildAndRun('handles', ['tests/abi/test_handle_table.c',
  'runtime/abi/grail_handle_table.c']);
buildAndRun('env-store', ['tests/abi/test_env_store.c', 'runtime/abi/grail_env_store.c',
  'runtime/abi/grail_abi.c', 'runtime/abi/grail_error.c']);
buildAndRun('paths-posix', ['tests/abi/test_paths.c', 'runtime/abi/grail_abi.c',
  'runtime/abi/grail_error.c', 'runtime/abi/grail_path.c']);
buildAndRun('paths-windows', ['tests/abi/test_paths.c', 'runtime/abi/grail_abi.c',
  'runtime/abi/grail_error.c', 'runtime/abi/grail_path.c'], ['-DGRAIL_ABI_PATH_WINDOWS=1']);

run(cc, ['-x', 'c++', '-std=c++17', '-fsyntax-only', '-Wall', '-Wextra', '-Werror',
  '-Iinclude', 'tests/abi/test_headers.c']);
console.log('headers: C++17 parses');

function publicFunctionNames() {
  const names = new Set();
  for (const file of readdirSync(join(root, 'include/grail'))) {
    if (!file.endsWith('.h')) continue;
    const text = readFileSync(join(root, 'include/grail', file), 'utf8');
    const pattern = /GRAIL_API[^;]*?\b(grail_[a-z0-9_]+)\s*\(/g;
    for (const match of text.matchAll(pattern)) names.add(match[1]);
  }
  return names;
}

function crossAudit(target, sources) {
  const directory = join(work, 'cross', target.replace(/[^a-z0-9]+/gi, '-'));
  mkdirSync(directory, { recursive: true });
  const objects = [];
  for (const source of sources) {
    const object = join(directory, basename(source).replace(/\.c$/, '.o'));
    run(clang, ['-target', target, '-ffreestanding', '-c', '-std=c11', '-Wall', '-Wextra', '-Wshadow', '-Wconversion', '-Wsign-conversion',
      '-Werror', '-DGRAIL_ABI_BUILD', '-Iinclude', source, '-o', object]);
    objects.push(object);
  }
  const listing = spawnSync('llvm-nm', ['-g', '--defined-only', ...objects], { encoding: 'utf8' });
  if (listing.error) throw listing.error;
  if (listing.status !== 0) throw new Error(`llvm-nm failed for ${target}: ${listing.stderr}`);
  const defined = new Set();
  for (const line of listing.stdout.split('\n')) {
    const fields = line.trim().split(/\s+/);
    if (fields.length < 2) continue;
    let name = fields[fields.length - 1];
    if (name.startsWith('_')) name = name.slice(1);
    defined.add(name);
  }
  const expected = publicFunctionNames();
  const missing = [...expected].filter(name => !defined.has(name)).sort();
  if (missing.length !== 0) {
    throw new Error(`${target}: missing public symbols: ${missing.join(', ')}`);
  }
  console.log(`cross: ${target} compiled ${objects.length} objects, ${expected.size}/${expected.size} public symbols defined`);
}

if (spawnSync(clang, ['--version']).status === 0) {
  const targets = [
    'x86_64-unknown-linux-gnu',
    'aarch64-unknown-linux-gnu',
    'riscv64-unknown-linux-gnu',
    'x86_64-pc-windows-msvc',
    'aarch64-pc-windows-msvc',
    'arm64-apple-macos11',
    'x86_64-apple-macos11',
  ];
  for (const target of targets) {
    run(clang, ['-target', target, '-ffreestanding', '-fsyntax-only', '-std=c11',
      '-Wall', '-Wextra', '-Werror', '-Iinclude', 'tests/abi/test_headers.c']);
    console.log(`headers: ${target} parses`);
  }
  const portable = [
    'runtime/abi/grail_abi.c',
    'runtime/abi/grail_error.c',
    'runtime/abi/grail_unicode.c',
    'runtime/abi/grail_path.c',
    'runtime/abi/grail_handle_table.c',
    'runtime/abi/grail_env_store.c',
  ];
  crossAudit('x86_64-pc-windows-msvc', [...portable,
    'runtime/abi/windows/grail_os_windows.c']);
  crossAudit('aarch64-pc-windows-msvc', [...portable,
    'runtime/abi/windows/grail_os_windows.c']);
  crossAudit('arm64-apple-macos11', [...portable,
    'runtime/abi/macos/grail_os_macos.c']);
  crossAudit('x86_64-apple-macos11', [...portable,
    'runtime/abi/macos/grail_os_macos.c']);
}
console.log('abi: all checks passed');
