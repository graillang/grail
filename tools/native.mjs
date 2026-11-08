// Build/test orchestration only. Language checking and instruction selection live in Grail.
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, renameSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';
export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const targets = ['x86_64', 'aarch64', 'riscv64'];
export const hostTarget = ({ x64: 'x86_64', arm64: 'aarch64', riscv64: 'riscv64' })[process.arch];
export const compilerSources = ['native', 'lexer', 'ownership', 'machine', 'optimize', 'fmt', 'cli', 'runtime'].map(n => join(root, 'compiler', `${n}.grl`));
const triples = { x86_64: 'x86_64-linux-gnu', aarch64: 'aarch64-linux-gnu', riscv64: 'riscv64-linux-gnu' };
const emulations = { x86_64: 'elf_x86_64', aarch64: 'aarch64elf', riscv64: 'elf64lriscv' };
export function targetName(target) {
  if (!targets.includes(target)) throw new Error(`Unsupported target ${target}; expected ${targets.join(', ')}`);
  return target;
}
export function command(argv, options = {}) {
  const result = spawnSync(argv[0], argv.slice(1), { cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: 900_000, ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${argv.join(' ')} failed (${result.signal ?? result.status})\n${result.stdout ?? ''}${result.stderr ?? ''}`);
  return result;
}
export function assemble(source, executable, target = hostTarget) {
  targetName(target);
  const object = `${executable}.o`;
  const flags = target === 'riscv64' ? ['-march=rv64imafd', '-mabi=lp64'] : [];
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[target]}`, ...flags, '-c', source, '-o', object]);
  command([process.env.GRAIL_LINKER ?? 'ld.lld', '-m', emulations[target], object, '-o', executable]);
  return executable;
}
export function runner(target = hostTarget) {
  targetName(target);
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
export function compileProgram(compiler, inputs, directory, { target = hostTarget, overflow = 'checked', name = 'program', defaultU64 = true, typedRefs = false, runtime = join(root, 'compiler/runtime.grl') } = {}) {
  targetName(target);
  if (!['checked', 'wrap'].includes(overflow)) throw new Error('overflow must be checked or wrap');
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, `${name}.s`);
  const files = [...inputs.map(p => resolve(root, p)), resolve(root, runtime)];
  const numeric = [...(defaultU64 ? ['--default-u64'] : []), ...(typedRefs ? ['--typed-refs'] : [])];
  command([compiler, ...numeric, '--target', target, `--overflow=${overflow}`, assembly, ...files]);
  return assemble(assembly, join(directory, name), target);
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const mode = process.argv[2] ?? 'build';
  if (mode === 'build') console.log(buildCompiler());
  else throw new Error('usage: bun tools/native.mjs build');
}
