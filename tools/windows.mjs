// Windows x86-64 (PE/COFF) cross-build driver: object assembly, import libraries, linking and
// static inspection. Instruction selection and ABI emission live in the Grail compiler; this file
// only orchestrates the COFF assembler and LLD, exactly as tools/native.mjs orchestrates ELF.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCompiler, command, root } from './native.mjs';

export const windowsTarget = 'windows-x86_64';
export const windowsAarch64 = 'windows-aarch64';
export const dll = 'kernel32.dll';
// PE target descriptors: the assembler triple, the short-import Machine value and the linker name.
export const targets = {
  [windowsTarget]: { triple: 'x86_64-pc-windows-msvc', machine: 0x8664, linkMachine: 'x64' },
  [windowsAarch64]: { triple: 'aarch64-pc-windows-msvc', machine: 0xaa64, linkMachine: 'arm64' },
};
// Every Win32 entry point the compiler can emit an import for (`raw_map` and process exit today).
// Win32 entry points the compiler can emit, grouped by the DLL that exports them.
export const imports = {
  'kernel32.dll': [
    'CloseHandle',
    'CreateDirectoryA',
    'CreateFileA',
    'CreateProcessA',
    'CreateThread',
    'DeleteFileA',
    'ExitProcess',
    'ExitThread',
    'FlushFileBuffers',
    'GetCommandLineA',
    'GetCurrentProcessId',
    'GetEnvironmentStringsA',
    'GetEnvironmentVariableA',
    'GetExitCodeProcess',
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
    'WaitForSingleObject',
    'WriteFile',
  ],
  'combase.dll': [
    'CoInitializeEx',
    'CoUninitialize',
  ],
  'kernelbase.dll': [
    'WaitOnAddress',
    'WakeByAddressSingle',
    'WakeByAddressAll',
  ],
};
// Flat list used to cross-check the compiler's import table.
export const kernel32 = Object.values(imports).flat();
const workDirectory = join(root, '.work/windows');

// A COFF short import object: a 20-byte import header followed by "Symbol\0DLL\0". LLD turns these
// into IAT slots and an import descriptor, so the compiler only ever names `__imp_<Symbol>`.
export function shortImport(name, library = dll, machine = 0x8664) {
  const data = Buffer.from(`${name}\0${library}\0`, 'latin1');
  const header = Buffer.alloc(20);
  header.writeUInt16LE(0x0000, 0); // Sig1
  header.writeUInt16LE(0xffff, 2); // Sig2
  header.writeUInt16LE(0, 4); // Version
  header.writeUInt16LE(machine, 6); // IMAGE_FILE_MACHINE_AMD64 or _ARM64
  header.writeUInt32LE(0, 8); // TimeDateStamp
  header.writeUInt32LE(data.length, 12); // SizeOfData
  header.writeUInt16LE(0, 16); // Ordinal/hint
  header.writeUInt16LE(4, 18); // IMPORT_NAME_NOPREFIX
  return Buffer.concat([header, data]);
}

// `extern "C" lib "X"` declarations on a PE target emit `// grail-link: import X SYMBOL`; each
// becomes a short import of SYMBOL from X.dll (or X itself when it already names a .dll).
export function programImports(assembly) {
  const found = {};
  for (const line of assembly.split('\n')) {
    const match = /^\/\/ grail-link: import (\S+) (\S+)$/.exec(line.trim());
    if (!match) continue;
    const dllName = /\.dll$/i.test(match[1]) ? match[1] : `${match[1]}.dll`;
    (found[dllName] ??= new Set()).add(match[2]);
  }
  return Object.fromEntries(Object.entries(found).map(([k, v]) => [k, [...v]]));
}

export function writeImportLibrary(directory = join(workDirectory, 'lib'), machine = 0x8664, extra = {}) {
  mkdirSync(directory, { recursive: true });
  const objects = [];
  const all = { ...imports };
  for (const [library, names] of Object.entries(extra)) {
    const known = new Set(Object.values(all).flat());
    all[library] = [...(all[library] ?? []), ...names.filter(name => !known.has(name))];
  }
  for (const [library, names] of Object.entries(all)) {
    for (const name of names) {
      const path = join(directory, `${name}.obj`);
      writeFileSync(path, shortImport(name, library, machine));
      objects.push(path);
    }
  }
  const library = join(directory, 'kernel32.lib');
  command(['llvm-ar', 'rcs', library, ...objects]);
  return library;
}

export function assemble(source, object, target = windowsTarget) {
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${targets[target].triple}`, '-c', source, '-o', object]);
  return object;
}

export function link(objects, executable, { entry = 'grail_entry', subsystem = 'console', machine = 'x64', pdb = null } = {}) {
  command([
    process.env.GRAIL_WIN_LINKER ?? 'lld-link',
    '/nologo',
    // A CodeView object (grail --debug) links with /DEBUG into a PDB next to the image.
    ...(pdb ? ['/debug', `/pdb:${pdb}`] : []),
    `/machine:${machine}`,
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
  target = windowsTarget,
  runtime = join(root, 'compiler/runtime.grl'),
  osRuntime = join(root, 'compiler/os-windows.grl'),
  shims = [],
  debug = false,
} = {}) {
  const spec = targets[target];
  if (!spec) throw new Error(`unsupported Windows target ${target}`);
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, `${name}.s`);
  const object = join(directory, `${name}.obj`);
  const executable = join(directory, `${name}.exe`);
  const files = [...inputs.map(p => resolve(root, p)), resolve(root, runtime), resolve(root, osRuntime)];
  command([compiler, '--default-u64', '--typed-refs', ...(debug ? ['--debug'] : []), '--target', target, assembly, ...files]);
  assemble(assembly, object, target);
  // A C-ABI shim (for example the in-process COM object) is assembled for the same target.
  const shimObjects = shims.map((shim, i) => {
    const shimObject = join(directory, `shim-${i}.obj`);
    assemble(resolve(root, shim), shimObject, target);
    return shimObject;
  });
  const library = writeImportLibrary(join(directory, 'lib'), spec.machine,
    programImports(readFileSync(assembly, 'utf8')));
  const pdb = debug ? join(directory, `${name}.pdb`) : null;
  link([object, ...shimObjects, library], executable, { machine: spec.linkMachine, pdb });
  return { assembly, object, executable, library, shimObjects, pdb };
}

export function inspectObject(object) {
  return command(['llvm-readobj', '--file-headers', '--sections', '--symbols', object]).stdout.toString();
}

export function inspectImage(executable) {
  return command(['llvm-readobj', '--file-headers', '--sections', '--coff-imports', executable]).stdout.toString();
}

export function rawSection(object, section) {
  return command(['llvm-objdump', '-s', '-j', section, object]).stdout.toString();
}

export function inspectRelocations(object) {
  return command(['llvm-readobj', '--relocations', object]).stdout.toString();
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
    let target = windowsTarget;
    const positional = [...rest];
    const flag = positional.indexOf('--target');
    if (flag !== -1) {
      target = positional[flag + 1];
      positional.splice(flag, 2);
    }
    const [destination = join(workDirectory, 'program'), ...inputs] = positional;
    if (inputs.length === 0) usage();
    // Bake the input list into the artifact name so repeated builds reuse the directory.
    const directory = dirname(destination);
    const built = compileProgram(buildCompiler(), inputs, directory, {
      name: destination.split('/').pop(),
      target,
    });
    console.log(built.executable);
  } else if (mode === 'check') {
    const { check } = await import('./test-windows.mjs');
    process.exitCode = await check(buildCompiler());
  } else {
    usage();
  }
}
