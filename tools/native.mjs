// Build/test orchestration only. Language checking and instruction selection live in Grail.
import { cpus } from 'node:os';
import { compareMachO, compareObjects } from './asm-oracle.mjs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync, renameSync, rmSync, statSync, accessSync, linkSync, copyFileSync, chmodSync, constants as fsConstants } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { constants as zlibConstants, zstdCompressSync, zstdDecompressSync } from 'node:zlib';
export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
// Executable/bootstrap targets: these are assembled, linked and run on this host (or under QEMU).
export const targets = ['x86_64', 'aarch64', 'riscv64'];
// Mach-O targets are cross-built and inspected only; they are never executed here, so they stay out
// of `targets` and are never selected by `bootstrap.mjs update all` or the code generators.
export const machoTargets = ['macos-x86_64', 'macos-aarch64'];
export const allTargets = [...targets, ...machoTargets];
export const hostTarget = ({ x64: 'x86_64', arm64: 'aarch64', riscv64: 'riscv64' })[process.arch];
// The compiler itself is a Linux host binary: its platform module is os-linux. darwin.grl (and
// os-windows.grl) are per-target platform modules selected when building for those targets.
export const compilerSources = ['native', 'lexer', 'ownership', 'machine', 'optimize', 'llvm', 'ir', 'fncache', 'jobs', 'asm_x86', 'asm_a64', 'asm_rv64', 'elf', 'coff', 'macho', 'fmt', 'explain', 'bindgen', 'pkg', 'docgen', 'cli', 'runtime', 'os-linux'].map(n => join(root, 'compiler', `${n}.grl`));
// A standard module the compiler itself uses: `grail build --watch` hashes its inputs with XXH64
// (lib/xxhash.grl), so the compiler is built with that module in its source list.
// Every tool builds through a store of its own run, inside this worktree: a test run must neither
// depend on what an earlier run left behind (a second run with the same compiler would restore
// every module, and a case that counts compiler runs would find none) nor leave anything in a home
// directory. Tools started by this one inherit the same store, so one run compiles the runtime
// once. A tool that inspects the store sets its own (tools/cache-test.mjs).
if (!process.env.GRAIL_CACHE_DIR) {
  const stores = join(root, '.work/build-cache');
  const store = join(stores, `run-${process.pid}`);
  // Stores of runs that were killed before they could remove theirs.
  if (existsSync(stores)) {
    for (const name of readdirSync(stores)) {
      const pid = /^run-(\d+)$/.exec(name)?.[1];
      if (!pid || !existsSync(`/proc/${pid}`)) rmSync(join(stores, name), { recursive: true, force: true });
    }
  }
  process.env.GRAIL_CACHE_DIR = store;
  process.on('exit', () => rmSync(store, { recursive: true, force: true }));
}
const compilerStdSources = ['xxhash', 'bytes'].map(n => join(root, 'lib', `${n}.grl`));
compilerSources.push(...compilerStdSources);
export const triples = { x86_64: 'x86_64-linux-gnu', aarch64: 'aarch64-linux-gnu', riscv64: 'riscv64-linux-gnu', 'macos-x86_64': 'x86_64-apple-macos11', 'macos-aarch64': 'arm64-apple-macos11' };
export const emulations = { x86_64: 'elf_x86_64', aarch64: 'aarch64elf', riscv64: 'elf64lriscv' };
export const machoArchitectures = { 'macos-x86_64': 'x86_64', 'macos-aarch64': 'arm64' };
// Targets string used inside .tbd stubs (tapi names the platform, not the Grail target).
const platformTargets = ['x86_64-macos', 'arm64-macos'];
// lld's Mach-O port needs a libSystem to link against. Without an SDK on hand, a stub tbd exported
// from the object's own undefined symbols is enough to produce and inspect a real executable.
function libSystemStub(directory, object, architecture) {
  const bare = ['x86_64-macos', 'arm64-macos'];
  const nm = spawnSync(process.env.GRAIL_NM ?? 'llvm-nm', ['-u', object], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  if (nm.error) throw new Error('linking a Mach-O executable needs llvm-nm (or GRAIL_NM) to build a libSystem stub');
  if (nm.status !== 0) throw new Error(`llvm-nm failed on ${object}\n${nm.stderr ?? ''}`);
  const symbols = nm.stdout.split('\n').map(line => line.trim()).filter(line => line.startsWith('_'));
  const stub = `${directory}/libSystem.tbd`;
  writeFileSync(stub, `--- !tapi-tbd\ntbd-version: 4\ntargets: [ ${bare.join(', ')} ]\ninstall-name: '/usr/lib/libSystem.B.dylib'\ncurrent-version: 1311\nexports:\n  - targets: [ ${bare.join(', ')} ]\n    symbols: [ ${[...symbols, 'dyld_stub_binder'].join(', ')} ]\n...\n`);
  return { stub, architecture };
}
// A framework's install location is fixed by Apple's layout; the stub only carries the exports a
// cross-link needs, so this is linkage scaffolding, not a copy of the framework.
export function frameworkInstallName(name) {
  return `/System/Library/Frameworks/${name}.framework/Versions/C/${name}`;
}

// Writes <dir>/<Name>.framework/<Name>.tbd. `symbols` are C names and are prefixed like ld64 does.
export function frameworkStub(dir, name, symbols = []) {
  if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(name)) throw new Error(`invalid framework name ${JSON.stringify(name)}`);
  const bundle = join(dir, `${name}.framework`);
  mkdirSync(bundle, { recursive: true });
  const exports = symbols.map(symbol => (symbol.startsWith('_') ? symbol : `_${symbol}`));
  const path = join(bundle, `${name}.tbd`);
  writeFileSync(path, [
    '--- !tapi-tbd',
    'tbd-version: 4',
    `targets: [ ${platformTargets.join(', ')} ]`,
    `install-name: '${frameworkInstallName(name)}'`,
    'current-version: 1',
    'exports:',
    `  - targets: [ ${platformTargets.join(', ')} ]`,
    `    symbols: [ ${exports.join(', ')} ]`,
    '...',
    '',
  ].join('\n'));
  return { name, path, directory: bundle };
}

// Extra ld64 arguments for the requested frameworks: an SDK resolves the real .tbd files, while a
// cross-build without one gets generated stubs from the caller's export lists.
export function frameworkArguments(frameworks = [], { directory, sdk } = {}) {
  if (frameworks.length === 0) return { args: [], stubs: [] };
  const args = [];
  let search = directory;
  if (sdk) {
    search = join(sdk, 'System/Library/Frameworks');
    args.push('-syslibroot', sdk);
  } else {
    if (!directory) throw new Error('frameworks need an SDK (GRAIL_SDK) or a stub directory');
    mkdirSync(directory, { recursive: true });
  }
  const stubs = [];
  for (const framework of frameworks) {
    const request = typeof framework === 'string' ? { name: framework } : framework;
    if (!sdk) {
      // A stub has to state what the framework exports. Without that list the name is
      // unverifiable, so an unknown framework fails here instead of being invented.
      if (!Array.isArray(request.symbols) || request.symbols.length === 0) {
        throw new Error(`framework ${request.name} needs a macOS SDK (GRAIL_SDK) or an explicit export list`);
      }
      stubs.push(frameworkStub(search, request.name, request.symbols));
    }
    args.push('-framework', request.name);
  }
  if (search) args.push('-F', search);
  return { args, stubs };
}

// Ad-hoc signing: `codesign --sign -` is the macOS tool, otherwise lld writes the signature itself
// with -adhoc_codesign (the default for arm64, optional for x86_64).
export function adhocSigner() {
  const probe = spawnSync(process.env.GRAIL_CODESIGN ?? 'codesign', ['--version'], { encoding: 'utf8' });
  return process.platform === 'darwin' && !probe.error && probe.status === 0 ? 'codesign' : 'ld64.lld';
}

export function signAdhoc(binary, signer = adhocSigner()) {
  if (signer !== 'codesign') return { signed: false, signer, reason: 'no codesign on this host; lld writes the ad-hoc signature at link time' };
  command([process.env.GRAIL_CODESIGN ?? 'codesign', '--force', '--sign', '-', binary]);
  return { signed: true, signer };
}

export function targetName(target) {
  if (!allTargets.includes(target)) throw new Error(`Unsupported target ${target}; expected ${allTargets.join(', ')}`);
  return target;
}
export function command(argv, options = {}) {
  // GRAIL_COMMAND_TIMEOUT (seconds) raises the limit for a step known to be long on a loaded host,
  // such as clang -O2 over the whole compiler's LLVM module in `release`.
  const result = spawnSync(argv[0], argv.slice(1), { cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: Number(process.env.GRAIL_COMMAND_TIMEOUT ?? 2400) * 1000, ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${argv.join(' ')} failed (${result.signal ?? result.status})\n${result.stdout ?? ''}${result.stderr ?? ''}`);
  return result;
}
// The compiler is the authority on link inputs: foreign declarations emit
// `// grail-link: INPUT` comments. Relative object/archive/shared inputs resolve
// against the declaring sources; bare names become -lNAME; flags pass through.
export function linkInputs(assembly, base) {
  const found = assembly
    .split('\n')
    .filter(line => line.startsWith('// grail-link: '))
    .map(line => line.slice('// grail-link: '.length).trim())
    .map(input => {
      if (input.startsWith('/') || input.startsWith('-')) return input;
      if (/[\\/]/.test(input) || /\.(o|a|so)$/.test(input)) return resolve(base, input);
      return `-l${input}`;
    });
  return [...new Set(found)];
}
// A `-lNAME` link input resolves symbols against a shared library, so a host ELF
// executable needs the platform loader and the system library directories: ld.lld
// has neither by default.
const dynamicLoaders = {
  x86_64: ['/lib64/ld-linux-x86-64.so.2', '/lib/ld-linux-x86-64.so.2'],
  aarch64: ['/lib/ld-linux-aarch64.so.1'],
  riscv64: ['/lib/ld-linux-riscv64-lp64d.so.1', '/lib/ld-linux-riscv64-lp64.so.1'],
};
// A cross target's glibc sysroot (GRAIL_SYSROOT_AARCH64, GRAIL_SYSROOT_RISCV64): dynamically
// linked cross executables link against its libraries and run under qemu with `-L sysroot`.
export function crossSysroot(target) {
  if (target === hostTarget) return null;
  const value = process.env[`GRAIL_SYSROOT_${target.toUpperCase()}`];
  return value && existsSync(value) ? value : null;
}
export function dynamicLinkFlags(target, linkArgs) {
  // A shared library named by path (`lib "../third_party/x/liby.so"`) makes the image dynamic exactly
  // as a `-lNAME` does: without the interpreter and libc the call would land on an unrelocated PLT
  // slot. platform/audio found this: its shim is a path, and the program crashed on the first call.
  if (!linkArgs.some(input => input.startsWith('-l') || input.endsWith('.so'))) return [];
  const sysroot = crossSysroot(target);
  if (sysroot) {
    const loader = (dynamicLoaders[target] ?? []).find(candidate => existsSync(join(sysroot, candidate)));
    // Fedora-style lib64 trees and Debian-style multiarch trees.
    const multiarch = `usr/lib/${target}-linux-gnu`;
    const dirs = ['lib64', 'usr/lib64', multiarch, 'lib', 'usr/lib'].map(d => join(sysroot, d)).filter(existsSync);
    // --sysroot resolves the absolute paths inside glibc's libc.so linker script.
    return [`--sysroot=${sysroot}`, ...(loader ? ['--dynamic-linker', loader] : []), ...dirs.map(d => `-L${d}`), '-lc'];
  }
  if (target !== hostTarget) return [];
  const loader = (dynamicLoaders[target] ?? []).find(candidate => existsSync(candidate));
  // libc always: the runtime creates its threads through a weak pthread_create (docs/ffi.md).
  return [...(loader ? ['--dynamic-linker', loader] : []), '-L/usr/lib', '-L/usr/lib64', '-lc'];
}
// What clang needs to compile an LLVM module for a target, besides the triple. RISC-V: the ISA and
// ABI the assembly is written for. AArch64: atomics inline - clang's default for Linux calls
// `__aarch64_cas8_acq_rel` and friends in libgcc, and a Grail program links no libgcc.
export function moduleFlags(target) {
  if (target === 'riscv64') return ['-march=rv64imafd', '-mabi=lp64d'];
  if (target === 'aarch64') return ['-mno-outline-atomics'];
  return [];
}
// One assembly file to one object: the compiler's own assembler for the targets it covers (Linux
// x86-64/AArch64/RISC-V, Windows x86-64), clang for the rest (macOS). GRAIL_ASM_ORACLE=1 holds each
// internal ELF object to clang's from the same text (tools/asm-oracle.mjs).
export function assembleObject(source, object, target = hostTarget) {
  const flags = target === 'riscv64' ? ['-march=rv64imafd', '-mabi=lp64d'] : [];
  if ((target === 'x86_64' || target === 'aarch64' || target === 'riscv64' || target === 'windows-x86_64' || target === 'macos-aarch64') && internalAssembler) {
    command([internalAssembler, 'asm', ...(target === 'x86_64' ? [] : ['--target', target]), source, '-o', object]);
    if (process.env.GRAIL_ASM_ORACLE === '1' && target !== 'windows-x86_64') {
      const reference = `${object}.clang.o`;
      command(['clang', `--target=${triples[target]}`, ...flags, '-c', source, '-o', reference]);
      // Mach-O compares structurally (llvm-readobj's view; tools/asm-oracle.mjs compareMachO).
      const diff = target === 'macos-aarch64' ? compareMachO(reference, object) : compareObjects(readFileSync(reference), readFileSync(object));
      rmSync(reference);
      if (diff) throw new Error(`internal assembler differs from clang on ${source}: ${typeof diff === 'string' ? diff : diff.message}`);
    }
    return object;
  }
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[target]}`, ...flags, '-c', source, '-o', object]);
  return object;
}

export function assemble(source, executable, target = hostTarget, linkArgs = [], { frameworkArgs = [], sign = false, sdk = undefined } = {}) {
  targetName(target);
  // Unique per process: two concurrent builds of the same target otherwise truncate each
  // other's object file mid-assembly, which clang reports as SIGBUS. `object` is this process's
  // scratch copy; `stable` is the name callers read (`tools/test-ffi.mjs` opens `<exe>.o`), so the
  // scratch copy is renamed into place once assembly succeeds.
  const object = `${executable}.${process.pid}.o`;
  const stable = `${executable}.o`;
  assembleObject(source, object, target);
  if (machoTargets.includes(target)) {
    // An SDK supplies the real libSystem.tbd; a cross-build without one links against a stub
    // exported from this object's own imports.
    const system = sdk
      ? ['-syslibroot', sdk, '-L', join(sdk, 'usr/lib')]
      : ['-L', dirname(libSystemStub(dirname(object), object, machoArchitectures[target]).stub)];
    const link = [
      process.env.GRAIL_LINKER ?? 'ld64.lld',
      '-arch', machoArchitectures[target],
      '-platform_version', 'macos', '11.0', '11.0',
      ...(sign ? ['-adhoc_codesign'] : []),
      ...system, '-lSystem',
      ...frameworkArgs,
      ...linkArgs,
      '-e', '_main',
      object, '-o', executable,
    ];
    command(link);
    // On macOS the platform tool owns ad-hoc signing; elsewhere lld already wrote the signature.
    if (sign) signAdhoc(executable);
    renameSync(object, stable);
    return executable;
  }
  command([
    process.env.GRAIL_LINKER ?? 'ld.lld', '-m', emulations[target], object,
    ...linkArgs, ...dynamicLinkFlags(target, linkArgs), '-o', executable,
  ]);
  renameSync(object, stable);
  return executable;
}
// Shared Mach-O libraries. A Grail program still needs an entry function, so the image keeps its
// (local) `_main` stub; `-exported_symbols_list` decides what the dylib actually exports.
export function assembleDylib(source, output, target = hostTarget, { installName, exports = [], linkArgs = [], rpath = [] } = {}) {
  targetName(target);
  if (!machoTargets.includes(target)) throw new Error(`shared dylibs are Mach-O only, not ${target}`);
  if (!installName) throw new Error('a Mach-O dylib needs an install name (-install_name)');
  if (exports.length === 0) throw new Error('a Mach-O dylib needs at least one exported symbol');
  const symbols = exports.map(symbol => (symbol.startsWith('_') ? symbol : `_${symbol}`));
  // `--export NAME` makes the compiler emit `.globl` at the definition, so this only checks the
  // assembly really carries the requested globals (catches a caller that compiled without it).
  const assembly = readFileSync(source, 'utf8');
  for (const symbol of symbols) {
    if (!new RegExp(`^\\.globl\\s+${symbol}\\s*$`, 'm').test(assembly)) {
      throw new Error(`${symbol} is not global in ${source}; compile it with --export`);
    }
  }
  const object = `${output}.o`;
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[target]}`, '-c', source, '-o', object]);
  const list = `${output}.exports`;
  writeFileSync(list, `${symbols.join('\n')}\n`);
  const { stub } = libSystemStub(dirname(object), object, machoArchitectures[target]);
  command([
    process.env.GRAIL_LINKER ?? 'ld64.lld',
    '-arch', machoArchitectures[target],
    '-platform_version', 'macos', '11.0', '11.0',
    '-dylib',
    '-install_name', installName,
    '-current_version', '1', '-compatibility_version', '1',
    '-exported_symbols_list', list,
    ...rpath.flatMap(path => ['-rpath', path]),
    '-L', dirname(stub), '-lSystem',
    ...linkArgs,
    object, '-o', output,
  ]);
  return output;
}

export function runner(target = hostTarget) {
  targetName(target);
  if (machoTargets.includes(target)) throw new Error(`${target} executables cannot be executed on ${process.platform}; they need macOS hardware (or a Darwin emulator)`);
  if (target === hostTarget) return [];
  const variable = `GRAIL_QEMU_${target.toUpperCase()}`;
  const sysroot = crossSysroot(target);
  const loaderPath = sysroot ? ['-L', sysroot] : [];
  if (process.env[variable]) return [process.env[variable], ...loaderPath];
  const local = join(root, '.work/architectures/toolchain/usr/bin', `qemu-${target}-static`);
  return [existsSync(local) ? local : `qemu-${target}-static`, ...loaderPath];
}
export function execute(executable, args = [], target = hostTarget, options = {}) {
  // Prevent negative tests from producing host core files; argv is never interpolated.
  return spawnSync('sh', ['-c', 'ulimit -c 0; exec "$@"', 'grail-test', ...runner(target), executable, ...args], {
    cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: 900_000, ...options,
  });
}
// Bootstrap seeds. The seed assembly *is* the compiler, it compresses about 20:1 to 30:1, and a reseed
// rewrites it, so it is stored compressed: checked in as text it would add ~50 MB per reseed (GitHub
// warns per file above 50 MB - GH001) while nothing reads it as text. `zstd` decompresses the ~160 MB
// AArch64/RISC-V seeds far faster than gzip and Bun ships libzstd, so no tool or npm package is needed.
// Every reader goes through seedAssemblyPath(), which holds the bytes to the manifest's digests and
// decompresses once into a file named by the compressed digest under .work.
export const seedDirectory = join(root, 'compiler/bootstrap');
export const seedCache = join(root, '.work/bootstrap-seeds');
export const seedManifestSchema = 2;
const seedCompressionLevel = 19;
export const digest = bytes => createHash('sha256').update(bytes).digest('hex');
// The x86-64 seed keeps the name `native.s` (it is this host's compiler) with the compressed suffix.
export function seedFile(target) {
  return target === 'x86_64' ? 'native.s.zst' : `${target}.s.zst`;
}
export function compressSeed(assembly) {
  return zstdCompressSync(assembly, { params: { [zlibConstants.ZSTD_c_compressionLevel]: seedCompressionLevel } });
}
export function readSeedManifest() {
  const manifest = JSON.parse(readFileSync(join(seedDirectory, 'manifest.json'), 'utf8'));
  if (manifest.schema !== seedManifestSchema) {
    throw new Error(`compiler/bootstrap/manifest.json is schema ${manifest.schema}, expected ${seedManifestSchema} (stale tool copy or old seed format)`);
  }
  return manifest;
}
export function seedEntry(target) {
  const entry = readSeedManifest().targets?.[target];
  if (!entry) throw new Error(`compiler/bootstrap/manifest.json records no ${target} bootstrap seed (run bun tools/bootstrap.mjs update all)`);
  return entry;
}
// Manifest entries name the compressed file, the digest of the compressed bytes it caches by, and the
// digest and size of the assembly it decompresses to - the identity a seed promises, and the only
// reason a stale seed is visible at all.
export function seedManifest(sources) {
  const entries = {};
  for (const target of targets) {
    const file = seedFile(target);
    const path = join(seedDirectory, file);
    if (!existsSync(path)) continue;
    const compressed = readFileSync(path);
    const assembly = zstdDecompressSync(compressed);
    entries[target] = {
      file,
      compression: 'zstd',
      sha256: digest(assembly),
      compressedSha256: digest(compressed),
      uncompressedBytes: assembly.length,
    };
  }
  return { schema: seedManifestSchema, sources, targets: entries };
}
// The decompressed seed for `target`, verified against the manifest and cached by compressed digest.
export function seedAssemblyPath(target) {
  const entry = seedEntry(target);
  const path = join(seedDirectory, entry.file);
  if (!existsSync(path)) throw new Error(`missing bootstrap seed compiler/bootstrap/${entry.file} (run bun tools/bootstrap.mjs update all)`);
  const compressed = readFileSync(path);
  const key = digest(compressed);
  if (entry.compressedSha256 && entry.compressedSha256 !== key) {
    throw new Error(`Bootstrap integrity check failed: compiler/bootstrap/${entry.file} is ${key}, the manifest records ${entry.compressedSha256}`);
  }
  const cached = join(seedCache, `${key}.s`);
  if (existsSync(cached)) return cached;
  if (entry.compression !== 'zstd') throw new Error(`compiler/bootstrap/${entry.file} declares unsupported compression ${entry.compression}`);
  const assembly = zstdDecompressSync(compressed);
  const actual = digest(assembly);
  if (actual !== entry.sha256) {
    throw new Error(`Bootstrap integrity check failed: compiler/bootstrap/${entry.file} decompresses to ${actual}, the manifest records ${entry.sha256}`);
  }
  mkdirSync(seedCache, { recursive: true });
  const pending = `${cached}.pending`;
  writeFileSync(pending, assembly);
  renameSync(pending, cached);
  return cached;
}
// A run that produces a seed must name its files the same way every time: the site table writes them
// relative to the working directory (PWD), while spawnSync's cwd is `root`, so pin PWD to it instead
// of whatever directory the shell happened to be in.
export function compilerEnvironment() {
  return { ...process.env, PWD: root };
}
// The compiler that compiles the tree's sources: an explicit development bootstrap when
// GRAIL_COMPILER names one (a two-step reseed, or a seed that predates a syntax change), else the
// checked-in seed assembled for this host. This is the only place GRAIL_COMPILER is honoured, and
// it is deliberately NOT what `build` returns.
export function bootstrapCompiler() {
  if (process.env.GRAIL_COMPILER) {
    const supplied = resolve(root, process.env.GRAIL_COMPILER);
    if (!existsSync(supplied)) {
      throw new Error(`GRAIL_COMPILER names ${supplied}, which does not exist`);
    }
    const stat = statSync(supplied);
    if (!stat.isFile()) throw new Error(`GRAIL_COMPILER names ${supplied}, which is not a file`);
    try {
      accessSync(supplied, fsConstants.X_OK);
    } catch {
      throw new Error(`GRAIL_COMPILER names ${supplied}, which is not executable`);
    }
    return supplied;
  }
  if (process.platform !== 'linux' || !hostTarget) throw new Error('Grail currently supports Linux on x86-64, ARM64 and RISC-V 64; other operating systems are not implemented');
  const assembly = seedAssemblyPath(hostTarget);
  const directory = join(root, '.work/native', 'seed');
  mkdirSync(directory, { recursive: true });
  // Named by the seed's digest (the cached assembly is `<digest>.s`) and assembled once: assembling
  // it on every call gave the bootstrap a new mtime each time, and buildCompiler's key - which named
  // that mtime - then rebuilt the whole compiler on every `build`.
  const executable = join(directory, `bootstrap-${basename(assembly, '.s')}`);
  if (existsSync(executable)) return executable;
  const pending = assemble(assembly, join(directory, `bootstrap.pending.${process.pid}`));
  claimExecutable(pending, executable);
  for (const leftover of [pending, `${pending}.o`]) if (existsSync(leftover)) rmSync(leftover);
  return executable;
}
// The tree's compiler: ALWAYS built from compilerSources by the bootstrap, cached by a hash of
// what went into it. It never hands back the bootstrap itself - a `build` that printed a supplied
// path and succeeded looked like a build and was not one, which cost two people a debugging
// session. Use `bootstrapCompiler()` when you want the compiler to build WITH, and
// `bun tools/native.mjs compiler` to print a path without building anything.
// Put a finished build in place without ever replacing one that is already there. A rename over an
// existing executable unlinks the file other processes are running, so their /proc/self/exe reads
// "... (deleted)" and anything that re-runs the compiler by its own path (a compile-time probe)
// fails. A hard link fails instead when the name exists; the loser keeps the winner's identical
// build and drops its own.
function claimExecutable(pending, executable) {
  try {
    linkSync(pending, executable);
  } catch (error) {
    if (error?.code !== 'EEXIST') throw error;
  }
  rmSync(pending, { force: true });
}
// The internal assembler (`grail asm`, compiler/asm_x86.grl) assembles Linux objects once the tree's
// compiler exists, as `grail build` does; only the compiler's own first build uses clang.
let internalAssembler = null;
// A tool that runs a compiler it was handed (a test stripe) assembles with that compiler.
export function useAssemblerOf(compiler) {
  internalAssembler = compiler;
}
export function buildCompiler() {
  const executable = buildTreeCompiler();
  internalAssembler ??= executable;
  return executable;
}
function buildTreeCompiler() {
  const base = bootstrapCompiler();
  const hash = createHash('sha256');
  hash.update(readFileSync(fileURLToPath(import.meta.url)));
  // The base by content, never by path or mtime: the same bootstrap rebuilt or copied elsewhere is
  // the same compiler, and a different one at the same path is not.
  hash.update(`${digest(readFileSync(base))}\u0000`);
  for (const file of compilerSources) hash.update(readFileSync(file));
  const directory = join(root, '.work/native', hash.digest('hex').slice(0, 24));
  const executable = join(directory, 'grail');
  if (existsSync(executable)) return executable;
  mkdirSync(directory, { recursive: true });
  // Every intermediate carries this process's id: two tools that build the compiler at the same
  // time in one worktree compute the same hash and therefore the same directory, and with shared
  // names one run's `compiler.s` or `grail.pending.o` disappears under the other. The symptom is a
  // clang "no preprocessable inputs" or an ld "cannot open ...grail.pending.o", which reads like a
  // broken build rather than two builds colliding. The final name is still claimed by rename,
  // which is atomic, so the loser of the race simply finds the executable already there.
  const output = join(directory, `compiler.${process.pid}.s`);
  // A seed from before typed references and the u64 default became the only modes still needs the
  // switches to read today's sources; a newer bootstrap accepts them too, so they are passed
  // unconditionally until the reseed drops them.
  command([base, '--default-u64', '--typed-refs', output, ...compilerSources], { env: compilerEnvironment() });
  const pending = assemble(output, join(directory, `grail.pending.${process.pid}`));
  claimExecutable(pending, executable);
  for (const leftover of [output, pending, `${pending}.o`, `${pending}.s`]) {
    if (existsSync(leftover)) rmSync(leftover);
  }
  return executable;
}
// The compiler as it should be run: the same sources, lowered through the LLVM backend and compiled
// with clang -O2. It emits byte-for-byte what the natively built compiler emits - that is checked
// here, on the compiler's own sources, before the binary is accepted - and it does so several times
// faster, because the native backend trades the speed of the code it writes for the speed of
// writing it (docs/design/compile-speed.md). `buildCompiler()` stays what the tests build with: it
// is the product of the native backend, and so the thing they exist to test.
//
// The native compiler of these sources lowers them (never an older release binary, whose older
// LLVM backend could carry a miscompile in), and the result is accepted only if it compiles the
// compiler to the same text and objects and its programs pass a corpus slice. The LLVM module is
// compiled in parallel parts (`grail llvm-compile`).
// Profile-guided optimisation of the release compiler: tools/pgo/grail.profdata.xz is the profile
// of a training run (`bun tools/native.mjs pgo-train`: a cold check and build of a 26 000-line
// program and the compiler's own check), and clang lays out and inlines the compiler's code by it -
// about 9% fewer instructions per compile, output unchanged. A function changed since the training
// has no profile and is compiled as without one; GRAIL_PGO=0 builds with no profile at all.
const pgoProfile = join(root, 'tools/pgo/grail.profdata.xz');
function profileUse(log) {
  if (process.env.GRAIL_PGO === '0' || !existsSync(pgoProfile)) return [];
  const packed = readFileSync(pgoProfile);
  const digest = createHash('sha256').update(packed).digest('hex').slice(0, 16);
  const path = join(root, '.work/pgo', `${digest}.profdata`);
  if (!existsSync(path)) {
    mkdirSync(dirname(path), { recursive: true });
    const unpacked = spawnSync('xz', ['-dc', pgoProfile], { maxBuffer: 1 << 28 });
    if (unpacked.status !== 0) {
      log('xz is not available: building the release compiler without its profile');
      return [];
    }
    writeFileSync(path, unpacked.stdout);
  }
  return [`-fprofile-use=${path}`, '-Wno-profile-instr-unprofiled', '-Wno-profile-instr-out-of-date', '-Wno-backend-plugin'];
}
// `bun tools/native.mjs pgo-train`: the instrumented release compiler (clang -fprofile-generate, the
// counters written at exit by tools/pgo/shim.c), the training runs with one process each
// (GRAIL_JOBS=1, so no forked worker's counters are lost), and the merged profile written to
// tools/pgo/grail.profdata.xz. Run it after large changes to the compiler, and commit the profile.
export async function trainProfile({ log = () => {} } = {}) {
  const { scalingProgram } = await import('./compile-bench.mjs');
  if (hostTarget !== 'x86_64') throw new Error('the profile is trained on x86_64 Linux');
  const native = buildCompiler();
  const work = join(root, '.work/pgo-train');
  rmSync(work, { recursive: true, force: true });
  mkdirSync(join(work, 'raw'), { recursive: true });
  const stem = join(work, 'grail');
  const flags = ['--default-u64', '--typed-refs', '--overflow=wrap'];
  log(`lowering with ${native}`);
  command([native, ...flags, '--backend=llvm', `${stem}.s`, ...compilerSources], { env: compilerEnvironment() });
  log('clang -O2 -fprofile-generate');
  const resource = spawnSync('clang', ['--print-resource-dir'], { encoding: 'utf8' }).stdout.trim();
  const runtime = join(resource, 'lib', 'x86_64-pc-linux-gnu', 'libclang_rt.profile.a');
  const generate = ['-fprofile-generate', '-mllvm', '-disable-vp=true'];
  command([native, 'llvm-compile', `${stem}.s.ll`, `${stem}.ll.o`, emulations[hostTarget], 'clang', `--target=${triples[hostTarget]}`, ...moduleFlags(hostTarget), '-c', '-flto=thin', ...generate]);
  command(['clang', `--target=${triples[hostTarget]}`, '-c', `${stem}.s`, '-o', `${stem}.o`]);
  command(['clang', '-O2', '-ffreestanding', '-fno-stack-protector', '-fno-builtin', `-DPGO_DIR="${join(work, 'raw')}"`, '-c', join(root, 'tools/pgo/shim.c'), '-o', `${stem}.shim.o`]);
  const instrumented = `${stem}.instrumented`;
  command(['ld.lld', '-m', emulations[hostTarget], `${stem}.o`, '--whole-archive', `${stem}.ll.o`, '--no-whole-archive', `${stem}.shim.o`, '--wrap=rt_shutdown', runtime, '--thinlto-jobs=8', '-mllvm', '-disable-vp=true', '-o', instrumented]);
  log('training');
  const program = join(work, 'train');
  mkdirSync(program, { recursive: true });
  writeFileSync(join(program, 'main.grl'), scalingProgram(1000));
  const env = { ...process.env, GRAIL_JOBS: '1' };
  command([instrumented, 'check', 'main.grl'], { cwd: program, env: { ...env, GRAIL_CACHE_DIR: join(program, 'store1') } });
  command([instrumented, 'build', 'main.grl', '-o', 'p'], { cwd: program, env: { ...env, GRAIL_CACHE_DIR: join(program, 'store2') } });
  command([instrumented, ...flags, `${stem}.self.s`, ...compilerSources], { env: { ...compilerEnvironment(), GRAIL_JOBS: '1' } });
  const raws = readdirSync(join(work, 'raw')).map(name => join(work, 'raw', name));
  command(['llvm-profdata', 'merge', '-o', `${stem}.profdata`, ...raws]);
  const packed = spawnSync('xz', ['-9', '-c', `${stem}.profdata`], { maxBuffer: 1 << 28 });
  if (packed.status !== 0) throw new Error('xz failed');
  writeFileSync(pgoProfile, packed.stdout);
  log(`${raws.length} runs merged into ${pgoProfile}`);
  return pgoProfile;
}
export function buildReleaseCompiler({ log = () => {} } = {}) {
  if (hostTarget !== 'x86_64') throw new Error('the release compiler is built on x86_64 Linux for now');
  const native = buildCompiler();
  const directory = dirname(native);
  const executable = join(directory, 'grail-release');
  if (existsSync(executable)) return executable;
  const stem = join(directory, `release.${process.pid}`);
  // A release build wraps on overflow, as every `grail build --release` does.
  const flags = ['--default-u64', '--typed-refs', '--overflow=wrap'];
  // The lowering is always the current native compiler's: an older release binary would carry
  // an older LLVM backend, and a miscompile in it into the new compiler.
  log(`lowering with ${native}`);
  const run = spawnSync(native, [...flags, '--backend=llvm', `${stem}.s`, ...compilerSources], { encoding: 'utf8', env: compilerEnvironment(), maxBuffer: 1 << 26 });
  if (run.status !== 0) throw new Error(`lowering the compiler through the LLVM backend failed (${run.signal ?? run.status}): ${(run.stderr ?? '').trim().split('\n')[0]}`);
  log('clang -O2');
  // Cut in parts and compiled in parallel (`grail llvm-compile`): one clang -O2 over the whole
  // compiler's module is serial and takes most of the build.
  // `-flto=thin`: the parts are ThinLTO bitcode in an archive, and the link below optimises across
  // them (a function of one part is inlined into another), with the backend run in parallel.
  command([native, 'llvm-compile', `${stem}.s.ll`, `${stem}.ll.o`, emulations[hostTarget], process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[hostTarget]}`, ...moduleFlags(hostTarget), '-c', '-flto=thin', ...profileUse(log)]);
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[hostTarget]}`, '-c', `${stem}.s`, '-o', `${stem}.o`]);
  const pending = `${stem}.pending`;
  const thinJobs = Math.max(1, Math.min(Number(process.env.GRAIL_JOBS) || cpus().length, 8));
  command([process.env.GRAIL_LINKER ?? 'ld.lld', '-m', emulations[hostTarget], `${stem}.o`, '--whole-archive', `${stem}.ll.o`, '--no-whole-archive', `--thinlto-jobs=${thinJobs}`, `--thinlto-cache-dir=${join(root, '.work/thinlto')}`, '-o', pending]);
  for (const leftover of [`${stem}.s`, `${stem}.s.ll`, `${stem}.o`, `${stem}.ll.o`]) if (existsSync(leftover)) rmSync(leftover);
  for (const part of readdirSync(directory).filter(name => name.startsWith(`${basename(stem)}.s.ll.`))) rmSync(join(directory, part));
  // The acceptance test, before the binary is accepted:
  // (1) both compilers compile the compiler to one assembly file, and (2) each one's own assembler
  // (`grail asm`, which every release build runs and the text alone does not exercise) makes one
  // object of it;
  log('checking that it emits what the native build emits');
  const outputs = [native, pending].map((compiler, index) => {
    const out = `${stem}.check${index}.s`;
    const object = `${stem}.check${index}.o`;
    command([compiler, ...flags, out, ...compilerSources], { env: compilerEnvironment() });
    command([compiler, 'asm', out, '-o', object]);
    const digest = createHash('sha256').update(readFileSync(out)).update(readFileSync(object)).digest('hex');
    rmSync(out);
    rmSync(object);
    return digest;
  });
  if (outputs[0] !== outputs[1]) {
    rmSync(pending);
    throw new Error('the release compiler does not emit what the native build emits for the compiler\'s own sources: not accepted');
  }
  // (3) programs it builds run: a slice of the corpus through its own `grail build` path.
  log('running a corpus slice with it');
  const slice = spawnSync('bun', [join(root, 'tools/test-native.mjs'), hostTarget, '--jobs', '4'], {
    cwd: root, encoding: 'utf8', maxBuffer: 1 << 26,
    env: { ...process.env, GRAIL_TEST_COMPILER: pending, GRAIL_TEST_FILTER: '^(hello|string|alloc|thread|sched)' },
  });
  if (slice.status !== 0) {
    rmSync(pending);
    throw new Error(`the release compiler's programs fail the corpus slice: not accepted\n${(slice.stdout ?? '').split('\n').filter(l => /FAIL|passed/.test(l)).join('\n')}`);
  }
  claimExecutable(pending, executable);
  return executable;
}
// The compiler's own sources without the portable runtime and the host's platform module:
// compileProgram appends those per target, so this is what "the compiler, as a program" means.
export function targetCompilerInputs() {
  return compilerSources.filter(file => !/(runtime|os-linux)\.grl$/.test(file));
}
// The compiler itself, cross-built for a target this host can assemble and link for. The Windows
// image is tools/windows.mjs's (an ELF orchestrator writes no COFF), the Mach-O one is here.
export function buildTargetCompiler(target = hostTarget, { directory = join(root, `.work/compiler-${target}`) } = {}) {
  if (!machoTargets.includes(target)) throw new Error(`buildTargetCompiler handles the Mach-O targets; ${target} has its own tool`);
  return compileProgram(buildCompiler(), targetCompilerInputs(), directory, { target, name: 'grail' });
}
// Emit assembly only: shared libraries and link-only tests need the object without a program link.
export function compileOnly(compiler, inputs, directory, { target = hostTarget, name = 'module', exports = [], runtime = join(root, 'compiler/runtime.grl'), osRuntime = join(root, 'compiler/os-linux.grl'), darwin = join(root, 'compiler/darwin.grl') } = {}) {
  targetName(target);
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, `${name}.s`);
  const platform = machoTargets.includes(target) ? [resolve(root, darwin)] : [resolve(root, osRuntime)];
  const files = [...inputs.map(p => resolve(root, p)), resolve(root, runtime), ...platform];
  const numeric = [...exports.flatMap(name => ['--export', name])];
  command([compiler, ...numeric, '--target', target, assembly, ...files]);
  return assembly;
}
// backend 'llvm' (or GRAIL_BACKEND=llvm) lowers through compiler/llvm.grl: the compiler writes
// NAME.s.ll beside NAME.s, clang -O2 compiles it, and the object joins the link.
export function compileProgram(compiler, inputs, directory, { target = hostTarget, overflow = 'checked', name = 'program', interfaces = null, runtime = join(root, 'compiler/runtime.grl'), osRuntime = join(root, 'compiler/os-linux.grl'), darwin = join(root, 'compiler/darwin.grl'), frameworks = [], sdk = process.env.GRAIL_SDK, sign = false, backend = process.env.GRAIL_BACKEND ?? 'native', verifyFacts = process.env.GRAIL_VERIFY_FACTS === '1', rangeFacts = process.env.GRAIL_RANGE_FACTS === '1', extra = [], output = null } = {}) {
  targetName(target);
  if (!['checked', 'wrap'].includes(overflow)) throw new Error('overflow must be checked or wrap');
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, `${name}.s`);
  const platform = machoTargets.includes(target) ? [resolve(root, darwin)] : [resolve(root, osRuntime)];
  const files = [...inputs.map(p => resolve(root, p)), resolve(root, runtime), ...platform];
  const llvm = backend === 'llvm';
  if (llvm && !['x86_64', 'aarch64', 'riscv64'].includes(target)) throw new Error('the LLVM backend is implemented for Linux x86_64, aarch64 and riscv64');
  // On the native backend --verify-facts cross-checks the refinements the prover discharged: a proved
  // obligation still emits its runtime check, so a wrong proof aborts instead of passing unnoticed.
  if (rangeFacts && !llvm) throw new Error('--range-facts derives range facts in the LLVM lifter; it needs the llvm backend');
  // `interfaces` compiles against the interface directory a previous emit produced instead of the
  // modules' sources (B1 stage 2). It changes what the checker sees, not what it is given.
  const interfaceFlags = interfaces ? ['--interface', interfaces] : [];
  // A content stamp over everything that can change the binary: the compiler image, the inputs,
  // the flags. A program whose stamp still matches is not recompiled — the parity suite builds over
  // sixty programs and a lane's gate should not rebuild the ones a change did not touch.
  const stampFile = join(directory, `${name}.stamp`);
  const stampParts = [compiler, backend, target, overflow, name, verifyFacts ? '1' : '0', rangeFacts ? '1' : '0',
    interfaces ?? '', ...extra, ...files];
  for (const file of [compiler, ...files]) {
    let st;
    try {
      st = statSync(file);
    } catch {
      st = null;
    }
    stampParts.push(st ? `${file}:${st.size}:${st.mtimeMs}` : `${file}:missing`);
  }
  const stamp = createHash('sha256').update(stampParts.join('\0')).digest('hex');
  const executable = join(directory, name);
  // The same stamp also names a shared store, so twenty worktrees with identical inputs keep one copy
  // of an artefact instead of twenty: /home filled to 100 % twice while the swarm was running.
  const shared = join(process.env.GRAIL_BUILD_CACHE ?? join(process.env.HOME ?? '/tmp', '.cache/grail-builds'), stamp, name);
  // A caller that asks for the compiler's own output (`output`) is measuring the compiler - the
  // unit-identity check compiles the same program twice, an empty unit store then a warm one, and
  // counts what each run reports - so it gets a real compile, never a stored artefact.
  if ((process.env.GRAIL_NO_BUILD_CACHE !== '1') && !output) {
    try {
      if (readFileSync(stampFile, 'utf8') === stamp && statSync(executable).size > 0) {
        if (output) output.push('');
        return executable;
      }
    } catch {
      // no stamp, or a half-written artifact: build it
    }
    try {
      if (statSync(shared).size > 0) {
        mkdirSync(dirname(executable), { recursive: true });
        copyFileSync(shared, executable);
        if (process.platform !== 'win32') chmodSync(executable, 0o755);
        writeFileSync(stampFile, stamp);
        if (output) output.push('');
        return executable;
      }
    } catch {
      // not in the shared store: build it
    }
  }
  const compiled = command([compiler, ...interfaceFlags, ...(llvm ? ['--backend=llvm'] : []), ...(verifyFacts ? ['--verify-facts'] : []), ...(rangeFacts ? ['--range-facts'] : []), ...extra, '--target', target, `--overflow=${overflow}`, assembly, ...files]);
  // `output`, when a caller passes an array, receives what the compiler printed.
  if (output) output.push(`${compiled.stdout ?? ''}${compiled.stderr ?? ''}`);
  const linkArgs = linkInputs(readFileSync(assembly, 'utf8'), dirname(resolve(root, inputs[0])));
  if (llvm) {
    const object = join(directory, `${name}.ll.o`);
    command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[target]}`, ...moduleFlags(target), '-O2', '-c', `${assembly}.ll`, '-o', object]);
    linkArgs.unshift(object);
  }
  const framework = machoTargets.includes(target) ? frameworkArguments(frameworks, { directory, sdk }) : { args: [] };
  const built = assemble(assembly, join(directory, name), target, linkArgs, { frameworkArgs: framework.args, sign, sdk });
  try {
    writeFileSync(stampFile, stamp);
  } catch {
    // a cache that cannot be recorded is no reason to fail the build
  }
  try {
    if (!existsSync(shared)) {
      mkdirSync(dirname(shared), { recursive: true });
      copyFileSync(built, shared);
    }
  } catch {
    // a full disk must not fail a good build; the worktree's artefact is the authority
  }
  return built;
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const mode = process.argv[2] ?? 'build';
  if (mode === 'compiler' || mode === 'which') {
    // The compiler you would build with, without building anything: the development bootstrap when
    // GRAIL_COMPILER names one, else the checked-in seed assembled for this host.
    process.stdout.write(bootstrapCompiler() + '\n');
    process.exit(0);
  }
  if (mode === 'build') {
    console.log(buildCompiler());
  } else if (mode === 'release') {
    // The compiler to ship and to measure: `bun tools/native.mjs release`.
    console.log(buildReleaseCompiler({ log: line => console.error(line) }));
  } else if (mode === 'pgo-train') {
    console.log(await trainProfile({ log: line => console.error(line) }));
  } else if (mode === 'compiler') {
    // `bun tools/native.mjs compiler --target macos-aarch64`: the compiler as a Mach-O binary.
    const at = process.argv.indexOf('--target');
    const target = at === -1 ? hostTarget : process.argv[at + 1];
    console.log(buildTargetCompiler(target).executable ?? buildTargetCompiler(target));
  } else {
    throw new Error('usage: bun tools/native.mjs <build|release|pgo-train|compiler> [--target T]');
  }
}
