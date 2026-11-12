// Target object bundles: relocatable COFF and Mach-O objects for cross targets
// whose runtime is not verified here. These archives deliberately contain no
// executable: consumers link the objects themselves, and the manifest/notice
// say so explicitly.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { gzipSync } from 'node:zlib';
import { createArchive, listArchive } from './archive.mjs';
import { BUILD_ONLY, artifactName, gitCommit, inspectBinary, platformById, root } from './platforms.mjs';
import { sha256, writeChecksums } from './package.mjs';
import { buildCompiler, command, compilerSources } from './native.mjs';
import { assemble as assembleCoff, inspectObject as inspectCoff } from './windows.mjs';

export function objectName(platform, stem) {
  return `${stem}${platformById(platform).objectExtension}`;
}

export function objectNotice(platform, version) {
  const target = platformById(platform);
  return [
    `Grail target objects for ${target.id}`,
    '='.repeat(`Grail target objects for ${target.id}`.length),
    '',
    `Version: ${version}`,
    `Format: ${target.objectFormat} relocatable object (${target.triple})`,
    '',
    'This archive contains object files, not executables. The objects must be',
    'linked by the consumer with the platform SDK or runtime it targets.',
    target.os === 'macos'
      ? 'Mach-O objects are statically verified here; no macOS execution is claimed.'
      : 'COFF objects and PE images are statically verified here; no Windows execution is claimed by this bundle.',
    '',
    'Status: build-only. Do not treat this archive as a runnable toolchain or a',
    'supported runtime release.',
    '',
  ].join('\n');
}

export function createObjectBundle({ platform, version, objects, assembly = [], stage0 = null, commit = gitCommit(), outDir, env = process.env }) {
  const target = platformById(platform);
  if (target.tier !== BUILD_ONLY) throw new Error(`${target.id} is ${target.tier}; object bundles are build-only`);
  if (!target.objectFormat) throw new Error(`${target.id} has no object format`);
  if (!objects.length) throw new Error('object bundle needs at least one object');
  for (const entry of objects) {
    if (!entry.data.length) throw new Error(`empty object ${entry.name}`);
    if (!entry.name.endsWith(target.objectExtension)) throw new Error(`${entry.name} needs ${target.objectExtension}`);
  }
  const base = artifactName(target.id, version, 'objects').replace(new RegExp(`\\.${target.archiveFormat.replace('.', '\\.')}$`), '');
  const files = {};
  const entries = [];
  const add = (path, data, mode = 0o644) => {
    const bytes = Buffer.isBuffer(data) ? data : Buffer.from(data);
    entries.push({ path: `${base}/${path}`, data: bytes, mode });
    files[path] = { sha256: sha256(bytes), size: bytes.length };
  };

  const objectRecords = [];
  for (const entry of objects) {
    add(`objects/${entry.name}`, entry.data);
    objectRecords.push({
      path: `objects/${entry.name}`,
      sha256: sha256(entry.data),
      size: entry.data.length,
      ...entry.info,
    });
  }
  const assemblyRecords = [];
  for (const entry of assembly) {
    add(`assembly/${entry.name}`, entry.data);
    assemblyRecords.push({ path: `assembly/${entry.name}`, sha256: sha256(entry.data), size: Buffer.byteLength(entry.data) });
  }

  add('share/doc/grail/OBJECTS-BUILD-ONLY.txt', objectNotice(target.id, version));
  const manifest = {
    schema: 1,
    name: 'grail-target-objects',
    version,
    platform: target.id,
    os: target.os,
    arch: target.arch,
    target: target.triple,
    compilerTarget: target.compilerTarget,
    format: target.objectFormat,
    kind: 'relocatable-object',
    executable: false,
    runnable: false,
    reason: 'Object files are inputs to a linker; this bundle contains no executable and claims no Windows/macOS runtime support.',
    commit: commit ?? null,
    stage0: stage0 ?? null,
    objectSources: Object.fromEntries(compilerSources.map(path => [path.slice(root.length + 1), sha256(readFileSync(path))])),
    objects: objectRecords,
    assembly: assemblyRecords,
    files,
  };
  add('share/grail/objects.json', `${JSON.stringify(manifest, null, 2)}\n`);

  mkdirSync(outDir, { recursive: true });
  const name = artifactName(target.id, version, 'objects');
  const artifact = join(outDir, name);
  const archive = createArchive(target.archiveFormat, entries, { env });
  writeFileSync(artifact, archive);
  writeChecksums(outDir);
  return {
    platform: target.id,
    version,
    artifact,
    name,
    format: target.archiveFormat,
    sha256: sha256(archive),
    size: archive.length,
    executable: false,
    runnable: false,
    manifest,
  };
}

function platformModule(platform) {
  const target = platformById(platform);
  const name = target.os === 'macos' ? 'darwin.grl' : target.os === 'windows' ? 'os-windows.grl' : 'os-linux.grl';
  return join(root, 'compiler', name);
}

// The host compiler is built with os-linux; cross objects replace that module
// with the target's platform boundary, exactly as tools/native.mjs and
// tools/windows.mjs do.
function emittedSources(platform) {
  const common = compilerSources.filter(path => !path.endsWith('/runtime.grl') && !path.endsWith('/os-linux.grl'));
  return [...common, join(root, 'compiler/runtime.grl'), platformModule(platform)];
}

function programSources(platform) {
  return [join(root, 'compiler/runtime.grl'), platformModule(platform)];
}

function assembleObject(platform, assembly, object) {
  const target = platformById(platform);
  if (target.objectFormat === 'coff') return assembleCoff(assembly, object);
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${target.triple}`, '-c', assembly, '-o', object]);
  return object;
}

export function inspectObject(platform, object) {
  const target = platformById(platform);
  if (target.objectFormat === 'coff') {
    const report = inspectCoff(object);
    if (!/Format: COFF-x86-64/.test(report)) throw new Error(`${object}: not a COFF x86-64 object`);
    if (!/Machine: IMAGE_FILE_MACHINE_AMD64/.test(report)) throw new Error(`${object}: wrong COFF machine`);
    return { format: 'coff-x86-64', arch: 'x86_64', machine: 'IMAGE_FILE_MACHINE_AMD64' };
  }
  if (target.objectFormat === 'macho') {
    const headers = command(['llvm-objdump', '--macho', '--private-headers', object]).stdout.toString();
    const expected = target.arch === 'aarch64' ? 'ARM64' : 'X86_64';
    if (!/MH_MAGIC_64/.test(headers)) throw new Error(`${object}: not a 64-bit Mach-O object`);
    if (!new RegExp(`MH_MAGIC_64\\s+${expected}\\b`).test(headers)) throw new Error(`${object}: wrong Mach-O cputype (expected ${expected})`);
    if (!/LC_BUILD_VERSION[\s\S]*platform macos/.test(headers)) throw new Error(`${object}: missing macOS LC_BUILD_VERSION`);
    // Only external symbols are needed and the full local-symbol listing for the
    // compiler object overflows command()'s output buffer.
    const symbols = command(['llvm-nm', '--extern-only', object]).stdout.toString();
    if (!/\bT _main$/m.test(symbols)) throw new Error(`${object}: _main is not a defined text symbol`);
    const binary = inspectBinary(object);
    return { format: 'macho', arch: binary.arch, magic: 'MH_MAGIC_64' };
  }
  throw new Error(`${target.id}: unsupported object format ${target.objectFormat}`);
}

export function buildObjectBundle({ platform, version, outDir, stage0 = null, commit = gitCommit(), env = process.env }) {
  const target = platformById(platform);
  if (target.tier !== BUILD_ONLY) throw new Error(`${target.id} is ${target.tier}; only build-only targets produce object bundles`);
  if (!target.compilerTarget || !target.objectFormat) throw new Error(`${target.id} has no object backend`);
  const compiler = stage0 ?? buildCompiler();
  const info = inspectBinary(compiler);
  if (info.format !== 'elf' || info.arch !== 'x86_64') {
    throw new Error(`stage0 ${compiler} is ${info.format}/${info.arch}; object bundles are cross-built from linux-x86_64`);
  }
  const work = join(root, '.work/objects', target.id);
  mkdirSync(work, { recursive: true });

  const sources = emittedSources(target.id);
  const compilerAssembly = join(work, 'grail.s');
  command([compiler, '--target', target.compilerTarget, compilerAssembly, ...sources]);
  const compilerObject = join(work, objectName(target.id, 'grail'));
  assembleObject(target.id, compilerAssembly, compilerObject);

  const helloAssembly = join(work, 'hello.s');
  const helloInputs = [join(root, 'book/examples/hello.grl'), ...programSources(target.id)];
  command([compiler, '--target', target.compilerTarget, helloAssembly, ...helloInputs]);
  const helloObject = join(work, objectName(target.id, 'hello'));
  assembleObject(target.id, helloAssembly, helloObject);

  const objects = [
    { name: objectName(target.id, 'grail'), data: readFileSync(compilerObject), info: inspectObject(target.id, compilerObject) },
    { name: objectName(target.id, 'hello'), data: readFileSync(helloObject), info: inspectObject(target.id, helloObject) },
  ];
  const assembly = [
    { name: 'grail.s.gz', data: gzipSync(readFileSync(compilerAssembly), { level: 9 }) },
    { name: 'hello.s.gz', data: gzipSync(readFileSync(helloAssembly), { level: 9 }) },
  ];
  return createObjectBundle({
    platform: target.id,
    version,
    objects,
    assembly,
    outDir,
    commit,
    env,
    stage0: {
      kind: process.env.GRAIL_COMPILER ? 'env' : 'bootstrap',
      path: compiler,
      sha256: sha256(readFileSync(compiler)),
      ...info,
    },
  });
}

export function verifyObjectBundle(artifact, platform, version = '0.1.0') {
  const target = platformById(platform);
  const names = listArchive(artifact).map(name => name.replace(/^[^/]+\//, ''));
  const required = [
    `objects/${objectName(target.id, 'grail')}`,
    `objects/${objectName(target.id, 'hello')}`,
    'share/grail/objects.json',
    'share/doc/grail/OBJECTS-BUILD-ONLY.txt',
  ];
  const missing = required.filter(name => !names.includes(name));
  if (missing.length) throw new Error(`${target.id} object bundle is missing: ${missing.join(', ')}`);
  if (names.some(name => /\.(exe|dylib|so)$/.test(name)) || names.includes('bin/grail')) {
    throw new Error(`${target.id} object bundle unexpectedly contains an executable`);
  }
  return { names, required };
}
