// Release packaging: one deterministic layout for every platform.
//
//   grail-VERSION-PLATFORM/
//     bin/grail[.exe]
//     lib/grail/runtime.grl
//     lib/grail/std/*.grl
//     share/doc/grail/{README.md,LICENSE,CHANGELOG.md}
//     share/grail/package.json       (version, commit, file digests)
//     install.sh / install.ps1
//
// Linux/macOS use tar.gz, Windows uses zip. SHA256SUMS is written next to the
// artifacts so release uploads can be verified independently.
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { createArchive, listArchive } from './archive.mjs';
import {
  BUILD_ONLY, SUPPORTED, artifactName, gitCommit, inspectBinary, platformById, root,
} from './platforms.mjs';

export function sha256(data) {
  return createHash('sha256').update(data).digest('hex');
}

export function packageName(platform, version) {
  return `grail-${version}-${platformById(platform).id}`;
}

export function packageLayout(platform, version) {
  const target = platformById(platform);
  const name = packageName(platform, version);
  const binary = `bin/grail${target.executableSuffix}`;
  return {
    name,
    binary,
    runtime: 'lib/grail/runtime.grl',
    std: 'lib/grail/std',
    docs: 'share/doc/grail',
    manifest: 'share/grail/package.json',
    installer: target.installer,
    entries: [
      binary,
      'lib/grail/runtime.grl',
      'lib/grail/std/',
      'share/doc/grail/README.md',
      'share/doc/grail/LICENSE',
      'share/doc/grail/CHANGELOG.md',
      'share/grail/package.json',
      'install.sh',
      'install.ps1',
    ],
  };
}

export function packageEntries({ platform, version, compiler, commit = gitCommit(), read = readFileSync, list = readdirSync }) {
  const target = platformById(platform);
  const layout = packageLayout(platform, version);
  const entries = [];
  const add = (path, data, mode = 0o644) => {
    const bytes = Buffer.isBuffer(data) ? data : Buffer.from(data);
    entries.push({ path: `${layout.name}/${path}`, data: bytes, mode });
  };

  add(layout.binary, compiler, 0o755);
  add(layout.runtime, read(join(root, 'compiler/runtime.grl')));
  const standardLibrary = list(join(root, 'lib')).filter(file => file.endsWith('.grl')).sort();
  if (standardLibrary.length === 0) throw new Error('lib/ contains no .grl modules');
  for (const file of standardLibrary) add(`${layout.std}/${file}`, read(join(root, 'lib', file)));
  add(`${layout.docs}/README.md`, read(join(root, 'README.md')));
  add(`${layout.docs}/LICENSE`, read(join(root, 'LICENSE')));
  add(`${layout.docs}/CHANGELOG.md`, read(join(root, 'CHANGELOG.md')));
  add('install.sh', read(join(root, 'packaging/install.sh')), 0o755);
  add('install.ps1', read(join(root, 'packaging/install.ps1')));

  if (target.tier === BUILD_ONLY) {
    add(`${layout.docs}/WINDOWS-BUILD-ONLY.txt`, [
      'Grail for windows-x86_64',
      '========================',
      '',
      'This archive contains a PE/COFF cross-build of the Grail compiler.',
      '',
      'Status: build-only. The compiler emits and links PE32+ console images, and',
      'tools/windows.mjs check statically verifies COFF objects, imports and image',
      'headers. The Windows runtime is NOT implemented: command-line argv recovery,',
      'worker threads, file/directory host services and .pdata/unwind data are',
      'missing. Do not execute this binary or treat it as a supported Windows release.',
      '',
      'The supported runnable platforms remain Linux x86-64, AArch64 and RISC-V 64.',
      '',
    ].join('\n'));
  }

  const files = Object.fromEntries(entries.map(entry => [entry.path.slice(layout.name.length + 1), sha256(entry.data)]));
  const manifest = {
    schema: 1,
    name: 'grail',
    version,
    platform: target.id,
    os: target.os,
    arch: target.arch,
    target: target.triple,
    tier: target.tier,
    runnable: target.tier === SUPPORTED,
    runtime: target.tier === SUPPORTED ? 'verified' : target.tier === BUILD_ONLY ? 'unverified' : 'not-implemented',
    commit: commit ?? null,
    files,
  };
  add(layout.manifest, `${JSON.stringify(manifest, null, 2)}\n`);
  return { entries, manifest, layout };
}

export function verifyCompiler(compiler, platform) {
  const target = platformById(platform);
  const info = inspectBinary(compiler);
  if (info.format === 'unknown') throw new Error(`compiler for ${target.id} is not an ELF, Mach-O or PE executable`);
  if (info.os !== target.os || info.arch !== target.arch) {
    throw new Error(`compiler targets ${info.os}/${info.arch}, expected ${target.os}/${target.arch}`);
  }
  return info;
}

export function writeChecksums(directory) {
  const names = readdirSync(directory)
    .filter(name => name.startsWith('grail-') && !name.endsWith('.sha256'))
    .sort();
  const lines = names.map(name => `${sha256(readFileSync(join(directory, name)))}  ${name}`);
  writeFileSync(join(directory, 'SHA256SUMS'), `${lines.join('\n')}\n`);
  return lines;
}

export function createPackage({ platform, version, compiler, outDir, commit = gitCommit(), verify = true, env = process.env }) {
  const target = platformById(platform);
  const bytes = Buffer.isBuffer(compiler) ? compiler : readFileSync(compiler);
  const info = verify ? verifyCompiler(bytes, platform) : inspectBinary(bytes);
  const name = artifactName(platform, version, 'toolchain');
  const { entries, manifest, layout } = packageEntries({ platform, version, compiler: bytes, commit });
  const archive = createArchive(target.archiveFormat, entries, { env });
  mkdirSync(outDir, { recursive: true });
  const artifact = join(outDir, name);
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
    binary: info,
    manifest,
    layout,
  };
}

export function verifyPackage(artifact, platform, version = '0.1.0') {
  const target = platformById(platform);
  const layout = packageLayout(platform, version);
  const names = listArchive(artifact).map(name => name.replace(/^[^/]+\//, ''));
  const required = [
    layout.binary,
    layout.runtime,
    layout.manifest,
    'install.sh',
    'install.ps1',
    'share/doc/grail/README.md',
    'share/doc/grail/LICENSE',
  ];
  if (target.tier === BUILD_ONLY) required.push(`${layout.docs}/WINDOWS-BUILD-ONLY.txt`);
  const missing = required.filter(name => !names.includes(name));
  if (!names.some(name => name.startsWith(`${layout.std}/`))) missing.push(`${layout.std}/*.grl`);
  if (!names.some(name => name.startsWith(`${layout.docs}/CHANGELOG.md`))) missing.push(`${layout.docs}/CHANGELOG.md`);
  if (missing.length) throw new Error(`${target.id} package is missing: ${missing.join(', ')}`);
  return { names, required };
}
