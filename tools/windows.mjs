// Windows x86-64 (PE/COFF) cross-build driver: object assembly, import libraries, linking and
// static inspection. Instruction selection and ABI emission live in the Grail compiler; this file
// only orchestrates the COFF assembler and LLD, exactly as tools/native.mjs orchestrates ELF.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCompiler, command, root } from './native.mjs';

export const windowsTarget = 'windows-x86_64';
export const triple = 'x86_64-pc-windows-msvc';
export const dll = 'kernel32.dll';
// Every Win32 entry point the compiler can emit an import for (`raw_map` and process exit today).
export const kernel32 = [
  'CloseHandle',
  'CreateDirectoryA',
  'CreateFileA',
  'DeleteFileA',
  'ExitProcess',
  'ExitThread',
  'FlushFileBuffers',
  'GetCommandLineA',
  'GetCurrentProcessId',
  'GetEnvironmentStringsA',
  'GetEnvironmentVariableA',
  'GetFileAttributesA',
  'GetLastError',
  'GetStdHandle',
  'GetSystemTimeAsFileTime',
  'GetTickCount64',
  'MoveFileA',
  'ReadFile',
  'RemoveDirectoryA',
  'SetFilePointerEx',
  'Sleep',
  'SwitchToThread',
  'TerminateProcess',
  'VirtualAlloc',
  'VirtualFree',
  'WriteFile',
];
const workDirectory = join(root, '.work/windows');

// A COFF short import object: a 20-byte import header followed by "Symbol\0DLL\0". LLD turns these
// into IAT slots and an import descriptor, so the compiler only ever names `__imp_<Symbol>`.
export function shortImport(name, library = dll) {
  const data = Buffer.from(`${name}\0${library}\0`, 'latin1');
  const header = Buffer.alloc(20);
  header.writeUInt16LE(0x0000, 0); // Sig1
  header.writeUInt16LE(0xffff, 2); // Sig2
  header.writeUInt16LE(0, 4); // Version
  header.writeUInt16LE(0x8664, 6); // IMAGE_FILE_MACHINE_AMD64
  header.writeUInt32LE(0, 8); // TimeDateStamp
  header.writeUInt32LE(data.length, 12); // SizeOfData
  header.writeUInt16LE(0, 16); // Ordinal/hint
  header.writeUInt16LE(4, 18); // IMPORT_NAME_NOPREFIX
  return Buffer.concat([header, data]);
}

export function writeImportLibrary(directory = join(workDirectory, 'lib')) {
  mkdirSync(directory, { recursive: true });
  const objects = [];
  for (const name of kernel32) {
    const path = join(directory, `${name}.obj`);
    writeFileSync(path, shortImport(name));
    objects.push(path);
  }
  const library = join(directory, 'kernel32.lib');
  command(['llvm-ar', 'rcs', library, ...objects]);
  return library;
}

export function assemble(source, object) {
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triple}`, '-c', source, '-o', object]);
  return object;
}

export function link(objects, executable, { entry = 'grail_entry', subsystem = 'console' } = {}) {
  command([
    process.env.GRAIL_WIN_LINKER ?? 'lld-link',
    '/nologo',
    `/entry:${entry}`,
    `/subsystem:${subsystem}`,
    '/nodefaultlib',
    '/dynamicbase',
    '/nxcompat',
    `/out:${executable}`,
    ...objects,
  ]);
  return executable;
}

// Compile a Grail program for Windows x86-64 and return its assembly, COFF object and PE image.
export function compileProgram(compiler, inputs, directory, {
  name = 'program',
  runtime = join(root, 'compiler/runtime.grl'),
  osRuntime = join(root, 'compiler/os-windows.grl'),
} = {}) {
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, `${name}.s`);
  const object = join(directory, `${name}.obj`);
  const executable = join(directory, `${name}.exe`);
  const files = [...inputs.map(p => resolve(root, p)), resolve(root, runtime), resolve(root, osRuntime)];
  command([compiler, '--default-u64', '--typed-refs', '--target', windowsTarget, assembly, ...files]);
  assemble(assembly, object);
  const library = writeImportLibrary(join(directory, 'lib'));
  link([object, library], executable);
  return { assembly, object, executable, library };
}

export function inspectObject(object) {
  return command(['llvm-readobj', '--file-headers', '--sections', '--symbols', object]).stdout.toString();
}

export function inspectImage(executable) {
  return command(['llvm-readobj', '--file-headers', '--sections', '--coff-imports', executable]).stdout.toString();
}

export function inspectUnwind(object) {
  return command(['llvm-readobj', '--unwind', object]).stdout.toString();
}

export function headers(executable) {
  return command(['llvm-objdump', '-p', executable]).stdout.toString();
}

function usage() {
  throw new Error('usage: bun tools/windows.mjs <build|check|implib> [args]');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [mode, ...rest] = process.argv.slice(2);
  if (mode === 'implib') {
    console.log(writeImportLibrary(rest[0]));
  } else if (mode === 'build') {
    const [destination = join(workDirectory, 'program'), ...inputs] = rest;
    if (inputs.length === 0) usage();
    // Bake the input list into the artifact name so repeated builds reuse the directory.
    const directory = dirname(destination);
    const built = compileProgram(buildCompiler(), inputs, directory, {
      name: destination.split('/').pop(),
    });
    console.log(built.executable);
  } else if (mode === 'check') {
    const { check } = await import('./test-windows.mjs');
    process.exitCode = await check(buildCompiler());
  } else {
    usage();
  }
}
