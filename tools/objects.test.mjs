import { test, expect, describe } from 'bun:test';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createObjectBundle, objectName, objectNotice, verifyObjectBundle } from './objects.mjs';
import { listArchive } from './archive.mjs';
import { artifactName, readVersion } from './platforms.mjs';

const VERSION = readVersion({});

function temp() {
  return mkdtempSync(join(tmpdir(), 'grail-objects-'));
}

function coff() {
  // Only the bundle writer is exercised here; real COFF inspection is covered by
  // `bun tools/ci.mjs objects --platform windows-x86_64` and tools/windows.mjs check.
  return Buffer.from('COFF-x86-64 synthetic object payload');
}

function macho(arch = 'aarch64') {
  const bytes = Buffer.alloc(64);
  bytes.writeUInt32LE(0xfeedfacf, 0);
  bytes.writeUInt32LE(arch === 'aarch64' ? 0x0100000c : 0x01000007, 4);
  return bytes;
}

function bundle(platform, objects) {
  const directory = temp();
  const result = createObjectBundle({
    platform,
    version: VERSION,
    objects,
    assembly: [{ name: 'grail.s.gz', data: Buffer.from('compressed assembly') }],
    outDir: directory,
    commit: 'object-test',
  });
  return { directory, result };
}

describe('object bundle layout', () => {
  test('names objects and artifacts per platform', () => {
    expect(objectName('windows-x86_64', 'grail')).toBe('grail.obj');
    expect(objectName('macos-aarch64', 'grail')).toBe('grail.o');
    expect(artifactName('windows-x86_64', VERSION, 'objects')).toBe(`grail-${VERSION}-windows-x86_64-objects.zip`);
    expect(artifactName('macos-aarch64', VERSION, 'objects')).toBe(`grail-${VERSION}-macos-aarch64-objects.tar.gz`);
    expect(objectNotice('macos-aarch64', VERSION)).toContain('not executables');
    expect(objectNotice('windows-x86_64', VERSION)).toContain('COFF');
  });

  test('packages Windows COFF objects as explicitly non-executable', () => {
    const { directory, result } = bundle('windows-x86_64', [
      { name: 'grail.obj', data: coff(), info: { format: 'coff-x86-64', arch: 'x86_64' } },
      { name: 'hello.obj', data: coff(), info: { format: 'coff-x86-64', arch: 'x86_64' } },
    ]);
    try {
      expect(result.name).toBe(`grail-${VERSION}-windows-x86_64-objects.zip`);
      expect(result).toMatchObject({ executable: false, runnable: false });
      expect(result.manifest).toMatchObject({
        schema: 1,
        name: 'grail-target-objects',
        platform: 'windows-x86_64',
        format: 'coff',
        kind: 'relocatable-object',
        executable: false,
        runnable: false,
        commit: 'object-test',
      });
      expect(result.manifest.objects).toHaveLength(2);
      expect(result.manifest.files['objects/grail.obj'].sha256).toHaveLength(64);
      const names = verifyObjectBundle(result.artifact, 'windows-x86_64', VERSION).names;
      expect(names).toContain('objects/grail.obj');
      expect(names).toContain('objects/hello.obj');
      expect(names).toContain('share/grail/objects.json');
      expect(names).toContain('share/doc/grail/OBJECTS-BUILD-ONLY.txt');
      expect(names).toContain('assembly/grail.s.gz');
      expect(names.some(name => /\.exe$|^bin\/grail$/.test(name))).toBe(false);
      expect(readFileSync(join(directory, 'SHA256SUMS'), 'utf8')).toContain(result.name);
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });

  test('packages macOS Mach-O objects with the right architecture', () => {
    const { directory, result } = bundle('macos-aarch64', [
      { name: 'grail.o', data: macho('aarch64'), info: { format: 'macho', arch: 'aarch64' } },
      { name: 'hello.o', data: macho('aarch64'), info: { format: 'macho', arch: 'aarch64' } },
    ]);
    try {
      expect(result.name).toBe(`grail-${VERSION}-macos-aarch64-objects.tar.gz`);
      expect(result.manifest).toMatchObject({ platform: 'macos-aarch64', format: 'macho', executable: false, runnable: false });
      const names = listArchive(result.artifact);
      expect(names.every(name => name.startsWith(`grail-${VERSION}-macos-aarch64-objects/`))).toBe(true);
      expect(verifyObjectBundle(result.artifact, 'macos-aarch64', VERSION).names).toContain('objects/grail.o');
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });

  test('rejects runnable or unsupported platform bundles', () => {
    const directory = temp();
    expect(() => createObjectBundle({
      platform: 'linux-x86_64',
      version: VERSION,
      objects: [{ name: 'grail.o', data: Buffer.from('x'), info: {} }],
      outDir: directory,
    })).toThrow(/build-only/);
    expect(() => createObjectBundle({
      platform: 'windows-x86_64',
      version: VERSION,
      objects: [{ name: 'grail.o', data: Buffer.from('x'), info: {} }],
      outDir: directory,
    })).toThrow(/needs \.obj/);
    rmSync(directory, { recursive: true, force: true });
  });
});
