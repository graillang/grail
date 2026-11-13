// Windows x86-64 (PE/COFF) cross-build driver: object assembly, import libraries, linking and
// static inspection. Instruction selection and ABI emission live in the Grail compiler; this file
// only orchestrates the COFF assembler and LLD, exactly as tools/native.mjs orchestrates ELF.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCompiler, command, compilerSources, root } from './native.mjs';

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
    'CreateDirectoryW',
    'CreateFileW',
    'CreateProcessW',
    'CreateThread',
    'DeleteFileW',
    'ExitProcess',
    'FindClose',
    'FindFirstFileW',
    'FindNextFileW',
    'FreeEnvironmentStringsW',
    'GetCommandLineW',
    'GetCurrentDirectoryW',
    'GetCurrentProcessId',
    'GetEnvironmentStringsW',
    'GetExitCodeProcess',
    'GetFileAttributesW',
    'GetLastError',
    'GetModuleFileNameW',
    'GetStdHandle',
    'GetTickCount64',
    'CreateEventW',
    'CancelIoEx',
    'ReadFile',
    'RemoveDirectoryW',
    'SetConsoleCP',
    'SetConsoleOutputCP',
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
  // Sockets: Winsock 2 lives in ws2_32. ConnectEx is not imported at all - it is reached through
  // WSAIoctl's extension table, because Wine does not export it. CancelIoEx/CreateEventW are
  // kernel32: the request's event is how a parked operation is waited on.
  'ws2_32.dll': [
    'WSAStartup',
    'WSACleanup',
    'WSAGetLastError',
    'WSASocketW',
    'WSARecv',
    'WSASend',
    'WSAGetOverlappedResult',
    'WSAIoctl',
    'bind',
    'connect',
    'accept',
    'closesocket',
    'getsockname',
    'listen',
    'setsockopt',
  ],
};
// Win32 entry points the *runtime* declares for itself, in compiler/os-windows.grl, with
// `extern "C" lib "kernel32"`. They are not in the compiler's table because the compiler never
// emits them: only the Windows platform module calls them (green-task fibers). The list here is
// cross-checked against those declarations by tools/test-windows.mjs.
export const runtimeImports = {
  'kernel32.dll': [
    'AddVectoredExceptionHandler',
    'ConvertThreadToFiber',
    'CreateFiberEx',
    'CreateIoCompletionPort',
    'DeleteFiber',
    'GetActiveProcessorCount',
    'GetQueuedCompletionStatus',
    'PostQueuedCompletionStatus',
    'SwitchToFiber',
  ],
};
// Flat list used to cross-check the compiler's import table.
export const kernel32 = Object.values(imports).flat();
// Every symbol a linked Windows program may need a short import for.
export const linked = [...Object.values(imports).flat(), ...Object.values(runtimeImports).flat()];
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
    // A Grail program is as deeply recursive as its data (the compiler is the extreme case), and
    // Windows gives a thread 1 MiB of stack by default against Linux's 8 MiB. CreateThread(0, 0)
    // inherits this reserve from the image, so one flag covers the main thread and every thread the
    // runtime starts.
    '/stack:8388608',
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
  command([compiler, ...(debug ? ['--debug'] : []), '--target', target, assembly, ...files]);
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

// The compiler's own sources without the Linux platform module: compileProgram appends the portable
// runtime and the target's platform module, so the list here stops at cli.grl.
export function compilerInputs() {
  return compilerSources.filter(file => !/(runtime|os-linux)\.grl$/.test(file));
}

// The compiler itself as a PE image: `grail.exe`, cross-built from the seed-built compiler.
export function buildWindowsCompiler(compiler = buildCompiler(), { target = windowsTarget, directory = join(workDirectory, 'compiler') } = {}) {
  return compileProgram(compiler, compilerInputs(), directory, { name: 'grail', target });
}

// A native Windows compiler is only credible if it runs, so this proves it where it can: under Wine
// on a Linux host (which needs `wine <exe>`), or natively on Windows when GRAIL_WINE is empty. Two
// proofs, because "it starts" proves nothing:
//   1. it compiles hello-world end to end - assemble, import library, lld-link - and the image
//      prints its line when run;
//   2. it compiles the compiler's own sources, and what came out is checked: against the Linux-built
//      compiler's assembly for the same target when that compiler can run here, and otherwise by
//      linking stage 2 and letting it compile hello itself (which is what --full always does).
export function selfhost({ full = false, target = windowsTarget, existing = null } = {}) {
  const configured = process.env.GRAIL_WINE;
  // Unset: prefix the compiler's own binary with `wine`. Empty: run it directly (a Windows host).
  const prefix = configured === undefined ? ['wine'] : (configured.trim() ? configured.trim().split(/\s+/) : []);
  const env = { ...process.env, WINEDEBUG: process.env.WINEDEBUG ?? '-all' };
  const path = file => (prefix.length ? file.replace(/\//g, '\\') : file);
  const run = argv => command([...prefix, ...argv], { env, maxBuffer: 256 * 1024 * 1024 });

  // `existing` is a grail.exe already built for Windows (the CI job downloads one): building it
  // again would need the Linux seed compiler, which a Windows host does not have.
  const built = existing ? { executable: resolve(root, existing) } : buildWindowsCompiler(buildCompiler(), { target });
  const directory = dirname(built.executable);
  const platform = './compiler/os-windows.grl';

  // 1. hello through the Windows compiler, then through the same assembler and linker the driver
  // runs natively on Windows.
  const helloDirectory = join(directory, 'hello');
  mkdirSync(helloDirectory, { recursive: true });
  const source = join(helloDirectory, 'hello.grl');
  writeFileSync(source, 'fn main() {\n    println("Hello, Windows!");\n}\n');
  const assembly = join(helloDirectory, 'hello.s');
  const object = join(helloDirectory, 'hello.obj');
  const runtime = join(root, 'compiler/runtime.grl');
  run([built.executable, '--target', target, path(assembly), path(source), path(runtime), path(join(root, platform))]);
  const library = writeImportLibrary(join(helloDirectory, 'lib'), targets[target].machine,
    programImports(readFileSync(assembly, 'utf8')));
  assemble(assembly, object, target);
  const hello = join(helloDirectory, 'hello.exe');
  link([object, library], hello, { machine: targets[target].linkMachine });
  const printed = run([hello]).stdout.toString();
  if (!printed.split(/\r?\n/).includes('Hello, Windows!')) {
    throw new Error(`windows selfhost: the program the Windows compiler produced printed ${JSON.stringify(printed)}`);
  }
  console.error(`windows selfhost: ${basename(built.executable)} compiled, linked and ran hello-world`);

  // The same compile with the source spelled the other way: a Windows path is accepted as
  // `C:\dir\x.grl` or `C:/dir/x.grl`, and the compiler's module search and diagnostics do not care
  // which. Under Wine the drive-letter spelling is Z:\..., which no Unix call would accept; on a
  // Windows host it is the forward-slash spelling of the native C:\... path.
  const other = join(helloDirectory, 'hello-spelled.s');
  const spelled = prefix.length
    ? `Z:${helloDirectory.replace(/\//g, '\\')}\\hello.grl`
    : `${helloDirectory.replace(/\\/g, '/')}/hello.grl`;
  run([built.executable, '--target', target, path(other), spelled, path(runtime), path(join(root, platform))]);
  if (!/^\.globl grail_entry$/m.test(readFileSync(other, 'utf8'))) {
    throw new Error('windows selfhost: a forward-slash source path produced no grail_entry');
  }
  console.error('windows selfhost: the compiler accepts both path spellings');

  // 2. the compiler compiling itself. The file list is relative to the repository, as a user would
  // write it, so both compilers see the same paths and neither embeds a host-specific absolute one
  // (the site table records the path it was given).
  const sources = [...compilerInputs(), runtime, join(root, platform)].map(file => relative(root, file));
  console.error('windows selfhost: the Windows compiler is compiling the compiler (this takes minutes)...');
  const fromWindows = join(directory, 'stage2-windows.s');
  run([built.executable, '--target', target, relative(root, fromWindows), ...sources]);
  const stage2 = readFileSync(fromWindows);
  if (stage2.length === 0) throw new Error('windows selfhost: the self-compile wrote no assembly');

  // The Linux-built compiler is the reference when it can run here: same target, same file list, so
  // the two answers must be byte for byte the same.
  const reference = !existing && process.platform === 'linux' ? buildCompiler() : null;
  if (reference) {
    const fromLinux = join(directory, 'stage2-linux.s');
    command([reference, '--target', target, relative(root, fromLinux), ...sources]);
    const linux = readFileSync(fromLinux);
    if (!stage2.equals(linux)) {
      throw new Error(`windows selfhost: the Windows compiler's stage 2 differs from the Linux compiler's (${stage2.length} vs ${linux.length} bytes)`);
    }
    console.error(`windows selfhost: stage 2 from the Windows compiler is byte-identical to the Linux compiler's (${stage2.length} bytes)`);
  } else {
    console.error('windows selfhost: no runnable Linux reference here; stage 2 is checked by running it (--full)');
  }

  if (full || !reference) {
    // Stage 2 is the compiler the Windows compiler wrote: link it and let it compile hello itself.
    // Equal output is the self-host fixpoint; a stage 2 that only looks right fails here.
    const stage2Library = writeImportLibrary(join(directory, 'lib2'), targets[target].machine,
      programImports(stage2.toString('utf8')));
    const stage2Object = join(directory, 'stage2.obj');
    assemble(fromWindows, stage2Object, target);
    const stage2Exe = join(directory, 'grail2.exe');
    link([stage2Object, stage2Library], stage2Exe, { machine: targets[target].linkMachine });
    const stage3 = join(directory, 'stage2-hello.s');
    run([stage2Exe, '--target', target, path(stage3), path(source), path(runtime), path(join(root, platform))]);
    if (!readFileSync(stage3).equals(readFileSync(assembly))) {
      throw new Error("windows selfhost: stage 2 (built by the Windows compiler) compiles hello to different assembly");
    }
    console.error('windows selfhost: stage 2, built by the Windows compiler, compiles hello to the same assembly');
  }
  return { built, hello };
}

function usage() {
  throw new Error('usage: bun tools/windows.mjs <build|check|implib|selfhost> [args]');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [mode, ...rest] = process.argv.slice(2);
  if (mode === 'compiler') {
    // The compiler as a PE image: what `windows.mjs selfhost` and the native CI job start from.
    console.log(buildWindowsCompiler(buildCompiler()).executable);
  } else if (mode === 'implib') {
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
  } else if (mode === 'selfhost') {
    const at = rest.indexOf('--existing');
    const existing = at === -1 ? null : rest[at + 1];
    const result = selfhost({ full: rest.includes('--full'), existing });
    console.log(result.built.executable);
  } else {
    usage();
  }
}
