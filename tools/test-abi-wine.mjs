// Executed Windows evidence for the C ABI without a Windows SDK:
// Zig cross-builds a PE harness, Wine runs it against the pinned Win32 backend.
// A macOS ARM64 compile-only harness checks the same metadata/reparse/DNS calls.
import { spawnSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const work = join(root, '.work/abi-wine');
const prefix = join(root, '.work/wine-prefix');
mkdirSync(work, { recursive: true });

function requireTool(name, args = ['--version']) {
  const result = spawnSync(name, args, { encoding: 'utf8' });
  if (result.error || result.status !== 0) {
    throw new Error(`abi-wine: required tool '${name}' is not available`);
  }
}

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

requireTool('zig', ['version']);
requireTool('wine');
requireTool('clang');

const executable = join(work, 'grail_abi_wine.exe');
run('zig', ['cc', '-target', 'x86_64-windows-gnu', '-std=c11', '-O1', '-DGRAIL_ABI_STATIC',
  '-Iinclude',
  'runtime/abi/grail_abi.c',
  'runtime/abi/grail_error.c',
  'runtime/abi/grail_handle_table.c',
  'runtime/abi/grail_env_store.c',
  'runtime/abi/windows/grail_os_windows.c',
  'tests/abi/wine_harness.c',
  '-o', executable, '-lws2_32']);

const executed = spawnSync('wine', [executable], {
  cwd: work,
  encoding: 'utf8',
  timeout: 120_000,
  env: { ...process.env, WINEPREFIX: prefix, WINEDEBUG: '-all' },
});
if (executed.error) throw executed.error;
if (executed.status !== 0) {
  process.stderr.write(executed.stdout ?? '');
  process.stderr.write(executed.stderr ?? '');
  throw new Error(`abi-wine: Wine harness failed with status ${executed.status}`);
}
if (!/wine-abi: PASS \(\d+ checks\)/.test(executed.stdout ?? '')) {
  process.stderr.write(executed.stdout ?? '');
  process.stderr.write(executed.stderr ?? '');
  throw new Error('abi-wine: harness did not report PASS');
}
if (!/wine-abi: symlink ok/.test(executed.stdout ?? '')) {
  throw new Error('abi-wine: the reparse/readlink path was skipped by the host');
}
for (const line of (executed.stdout ?? '').split('\n')) {
  if (line.startsWith('wine-abi:')) console.log(line.trim());
}

run('clang', ['-target', 'arm64-apple-macos11', '-ffreestanding', '-fsyntax-only', '-std=c11',
  '-Wall', '-Wextra', '-Wshadow', '-Wconversion', '-Wsign-conversion', '-Werror', '-Iinclude',
  'tests/abi/macos_metadata_dns_check.c']);
console.log('abi-wine: macOS ARM64 metadata/reparse/DNS call sites compile');
