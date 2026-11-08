// Build/test orchestration only. Language checking and instruction selection live in Grail.
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, renameSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';
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
export const compilerSources = ['native', 'lexer', 'ownership', 'machine', 'optimize', 'fmt', 'cli', 'runtime', 'os-linux'].map(n => join(root, 'compiler', `${n}.grl`));
const triples = { x86_64: 'x86_64-linux-gnu', aarch64: 'aarch64-linux-gnu', riscv64: 'riscv64-linux-gnu', 'macos-x86_64': 'x86_64-apple-macos11', 'macos-aarch64': 'arm64-apple-macos11' };
const emulations = { x86_64: 'elf_x86_64', aarch64: 'aarch64elf', riscv64: 'elf64lriscv' };
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
  const result = spawnSync(argv[0], argv.slice(1), { cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: 900_000, ...options });
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
export function assemble(source, executable, target = hostTarget, linkArgs = [], { frameworkArgs = [], sign = false, sdk = undefined } = {}) {
  targetName(target);
  const object = `${executable}.o`;
  const flags = target === 'riscv64' ? ['-march=rv64imafd', '-mabi=lp64'] : [];
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[target]}`, ...flags, '-c', source, '-o', object]);
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
    return executable;
  }
  command([process.env.GRAIL_LINKER ?? 'ld.lld', '-m', emulations[target], object, ...linkArgs, '-o', executable]);
  return executable;
}
// Shared Mach-O libraries. A Grail program still needs an entry function, so the image keeps its
// (local) `_main` stub; `-exported_symbols_list` decides what the dylib actually exports.
export function assembleDylib(source, output, target = hostTarget, { installName, exports = [], linkArgs = [] } = {}) {
  targetName(target);
  if (!machoTargets.includes(target)) throw new Error(`shared dylibs are Mach-O only, not ${target}`);
  if (!installName) throw new Error('a Mach-O dylib needs an install name (-install_name)');
  if (exports.length === 0) throw new Error('a Mach-O dylib needs at least one exported symbol');
  const symbols = exports.map(symbol => (symbol.startsWith('_') ? symbol : `_${symbol}`));
  // The compiler emits module functions as local labels (only the process entry is global), so the
  // requested exports are promoted here before assembling. A first-class `--export` compiler flag
  // would move this into the compiler; the driver step keeps the dylib surface explicit meanwhile.
  const marked = `${output}.exports.s`;
  const assembly = readFileSync(source, 'utf8');
  // An export must name a label this module actually defines; otherwise the driver would turn a
  // typo into a global undefined reference and the linker would accept it.
  for (const symbol of symbols) {
    if (!new RegExp(`^${symbol}:`, 'm').test(assembly)) {
      throw new Error(`export ${symbol} is not defined by this module`);
    }
  }
  const declarations = symbols
    .filter(symbol => !new RegExp(`^\\.globl\\s+${symbol}\\s*$`, 'm').test(assembly))
    .map(symbol => `.globl ${symbol}\n`)
    .join('');
  writeFileSync(marked, declarations + assembly);
  const object = `${output}.o`;
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[target]}`, '-c', marked, '-o', object]);
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
  if (process.env[variable]) return [process.env[variable]];
  const local = join(root, '.work/architectures/toolchain/usr/bin', `qemu-${target}-static`);
  return [existsSync(local) ? local : `qemu-${target}-static`];
}
export function execute(executable, args = [], target = hostTarget, options = {}) {
  // Prevent negative tests from producing host core files; argv is never interpolated.
  return spawnSync('sh', ['-c', 'ulimit -c 0; exec "$@"', 'grail-test', ...runner(target), executable, ...args], {
    cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: 900_000, ...options,
  });
}
export function buildCompiler() {
  // Explicit development bootstrap, used while a new intrinsic is staged before artifact refresh.
  if (process.env.GRAIL_COMPILER) {
    const supplied = resolve(root, process.env.GRAIL_COMPILER);
    if (!existsSync(supplied)) throw new Error(`Missing development compiler ${supplied}`);
    return supplied;
  }
  if (process.platform !== 'linux' || !hostTarget) throw new Error('Grail currently supports Linux on x86-64, ARM64 and RISC-V 64; other operating systems are not implemented');
  const boot = join(root, 'compiler/bootstrap', hostTarget === 'x86_64' ? 'native.s' : `${hostTarget}.s.gz`);
  const recorded = JSON.parse(readFileSync(join(root, 'compiler/bootstrap/manifest.json'), 'utf8'));
  const bootBytes = boot.endsWith('.gz') ? gunzipSync(readFileSync(boot)) : readFileSync(boot);
  const bootDigest = createHash('sha256').update(bootBytes).digest('hex');
  if (recorded.targets[hostTarget]?.sha256 !== bootDigest) throw new Error('Bootstrap integrity check failed');
  const hash = createHash('sha256');
  hash.update(readFileSync(fileURLToPath(import.meta.url)));
  hash.update(readFileSync(boot));
  for (const file of compilerSources) hash.update(readFileSync(file));
  const directory = join(root, '.work/native', hash.digest('hex').slice(0, 24));
  const executable = join(directory, 'grail');
  if (existsSync(executable)) return executable;
  mkdirSync(directory, { recursive: true });
  let assembly = boot;
  if (boot.endsWith('.gz')) { assembly = join(directory, 'bootstrap.s'); writeFileSync(assembly, gunzipSync(readFileSync(boot))); }
  const bootstrap = assemble(assembly, join(directory, 'bootstrap'));
  const output = join(directory, 'compiler.s');
  command([bootstrap, '--default-u64', '--typed-refs', output, ...compilerSources]);
  const pending = assemble(output, join(directory, 'grail.pending'));
  renameSync(pending, executable);
  return executable;
}
// Emit assembly only: shared libraries and link-only tests need the object without a program link.
export function compileOnly(compiler, inputs, directory, { target = hostTarget, name = 'module', defaultU64 = true, typedRefs = false, runtime = join(root, 'compiler/runtime.grl'), osRuntime = join(root, 'compiler/os-linux.grl'), darwin = join(root, 'compiler/darwin.grl') } = {}) {
  targetName(target);
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, `${name}.s`);
  const platform = machoTargets.includes(target) ? [resolve(root, darwin)] : [resolve(root, osRuntime)];
  const files = [...inputs.map(p => resolve(root, p)), resolve(root, runtime), ...platform];
  const numeric = [...(defaultU64 ? ['--default-u64'] : []), ...(typedRefs ? ['--typed-refs'] : [])];
  command([compiler, ...numeric, '--target', target, assembly, ...files]);
  return assembly;
}
export function compileProgram(compiler, inputs, directory, { target = hostTarget, overflow = 'checked', name = 'program', defaultU64 = true, typedRefs = false, runtime = join(root, 'compiler/runtime.grl'), osRuntime = join(root, 'compiler/os-linux.grl'), darwin = join(root, 'compiler/darwin.grl'), frameworks = [], sdk = process.env.GRAIL_SDK, sign = false } = {}) {
  targetName(target);
  if (!['checked', 'wrap'].includes(overflow)) throw new Error('overflow must be checked or wrap');
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, `${name}.s`);
  const platform = machoTargets.includes(target) ? [resolve(root, darwin)] : [resolve(root, osRuntime)];
  const files = [...inputs.map(p => resolve(root, p)), resolve(root, runtime), ...platform];
  const numeric = [...(defaultU64 ? ['--default-u64'] : []), ...(typedRefs ? ['--typed-refs'] : [])];
  command([compiler, ...numeric, '--target', target, `--overflow=${overflow}`, assembly, ...files]);
  const linkArgs = linkInputs(readFileSync(assembly, 'utf8'), dirname(resolve(root, inputs[0])));
  const framework = machoTargets.includes(target) ? frameworkArguments(frameworks, { directory, sdk }) : { args: [] };
  return assemble(assembly, join(directory, name), target, linkArgs, { frameworkArgs: framework.args, sign, sdk });
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const mode = process.argv[2] ?? 'build';
  if (mode === 'build') console.log(buildCompiler());
  else throw new Error('usage: bun tools/native.mjs build');
}
