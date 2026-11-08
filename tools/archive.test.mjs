import { test, expect, describe } from 'bun:test';
import { mkdtempSync, readFileSync, existsSync, statSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { gunzipSync } from 'node:zlib';
import {
  createTar, createTarGz, createZip, createArchive, writeArchive, listArchive,
  crc32, sourceDateEpoch, normalizeEntries,
} from './archive.mjs';
import { createPackage, verifyPackage, packageEntries, packageLayout, sha256, writeChecksums } from './package.mjs';
import { artifactName, readVersion } from './platforms.mjs';

const VERSION = readVersion({});

function temp() {
  return mkdtempSync(join(tmpdir(), 'grail-tooling-'));
}

function sampleEntries() {
  return [
    { path: 'grail/bin/grail', data: Buffer.from('binary payload'), mode: 0o755 },
    { path: 'grail/README.md', data: Buffer.from('# Grail\n') },
    { path: 'grail/lib/grail/std/core.grl', data: Buffer.from('module core;\n') },
  ];
}

function elf(arch = 'x86_64', bits = 2) {
  const machine = { x86_64: 62, aarch64: 183, riscv64: 243 }[arch];
  const bytes = Buffer.alloc(4096);
  bytes[0] = 0x7f; bytes.write('ELF', 1, 'ascii');
  bytes[4] = bits; bytes[5] = 1;
  bytes.writeUInt16LE(machine, 18);
  return bytes;
}

function pe(arch = 'aarch64') {
  const bytes = Buffer.alloc(4096);
  bytes[0] = 0x4d; bytes[1] = 0x5a;
  bytes.writeUInt32LE(0x80, 0x3c);
  bytes.write('PE\u0000\u0000', 0x80, 'ascii');
  bytes.writeUInt16LE(arch === 'aarch64' ? 0xaa64 : 0x8664, 0x84);
  return bytes;
}

function macho(arch = 'aarch64') {
  const bytes = Buffer.alloc(4096);
  bytes.writeUInt32LE(0xfeedfacf, 0);
  bytes.writeUInt32LE(arch === 'aarch64' ? 0x0100000c : 0x01000007, 4);
  return bytes;
}

describe('tar.gz writer', () => {
  test('creates a readable, sorted, deterministic archive', () => {
    const first = createTarGz(sampleEntries());
    const second = createTarGz([...sampleEntries()].reverse());
    expect(first.equals(second)).toBe(true);
    const names = listArchiveNames(first);
    expect(names).toEqual(['grail/README.md', 'grail/bin/grail', 'grail/lib/grail/std/core.grl']);
  });

  test('writes ustar headers with modes and sizes', () => {
    const tar = createTar([{ path: 'grail/bin/grail', data: Buffer.from('binary payload'), mode: 0o755 }]);
    const header = tar.subarray(0, 512);
    expect(header.toString('ascii', 257, 263)).toBe('ustar\u0000');
    expect(header.toString('ascii', 100, 108).replace(/\u0000/g, '')).toBe('0000755');
    expect(parseInt(header.toString('ascii', 124, 136), 8)).toBe(Buffer.byteLength('binary payload'));
    expect(tar.subarray(-1024).every(byte => byte === 0)).toBe(true);
  });

  test('is readable by the system tar', () => {
    if (!spawnSync('tar', ['--version']).status === 0) return;
    const directory = temp();
    const path = join(directory, 'sample.tar.gz');
    writeArchive(path, 'tar.gz', sampleEntries());
    const result = spawnSync('tar', ['-tzf', path], { encoding: 'utf8' });
    expect(result.status).toBe(0);
    expect(result.stdout.trim().split('\n')).toEqual(['grail/README.md', 'grail/bin/grail', 'grail/lib/grail/std/core.grl']);
    rmSync(directory, { recursive: true, force: true });
  });

  test('rejects unsafe or oversized paths', () => {
    expect(() => normalizeEntries([{ path: '../escape', data: '' }])).toThrow(/Unsafe archive path/);
    expect(() => normalizeEntries([{ path: '/absolute', data: '' }])).toThrow(/Unsafe archive path/);
    expect(() => createTar([{ path: `${'a'.repeat(101)}`, data: '' }])).toThrow(/longer than 100 bytes/);
  });
});

describe('zip writer', () => {
  test('matches the canonical CRC-32 vector', () => {
    expect(crc32(Buffer.from('123456789'))).toBe(0xcbf43926);
  });

  test('creates a deterministic UTF-8 zip with correct CRCs', () => {
    const zip = createZip(sampleEntries());
    expect(zip.equals(createZip([...sampleEntries()].reverse()))).toBe(true);
    expect(zip.readUInt32LE(0)).toBe(0x04034b50);
    expect(zip.readUInt16LE(6) & 0x0800).toBe(0x0800);
    const names = listArchiveNames(zip);
    expect(names).toEqual(['grail/README.md', 'grail/bin/grail', 'grail/lib/grail/std/core.grl']);
    // Each central-directory record must point at a local header with the same CRC.
    const eocd = zip.length - 22;
    const count = zip.readUInt16LE(eocd + 10);
    let offset = zip.readUInt32LE(eocd + 16);
    for (let i = 0; i < count; i += 1) {
      const nameLength = zip.readUInt16LE(offset + 28);
      const extra = zip.readUInt16LE(offset + 30);
      const comment = zip.readUInt16LE(offset + 32);
      const local = zip.readUInt32LE(offset + 42);
      const stored = zip.readUInt32LE(local + 14);
      const size = zip.readUInt32LE(local + 18);
      const data = zip.subarray(local + 30 + zip.readUInt16LE(local + 26), local + 30 + zip.readUInt16LE(local + 26) + size);
      expect(crc32(data)).toBe(stored);
      offset += 46 + nameLength + extra + comment;
    }
  });

  test('python zipfile can read and test the archive', () => {
    const python = spawnSync('python3', ['--version'], { encoding: 'utf8' });
    if (python.status !== 0) return;
    const directory = temp();
    const path = join(directory, 'sample.zip');
    writeArchive(path, 'zip', sampleEntries());
    const result = spawnSync('python3', ['-c', 'import sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); assert z.testzip() is None; print("\\n".join(z.namelist()))', path], { encoding: 'utf8' });
    expect(result.status).toBe(0);
    expect(result.stdout.trim()).toBe('grail/README.md\ngrail/bin/grail\ngrail/lib/grail/std/core.grl');
    rmSync(directory, { recursive: true, force: true });
  });
});

describe('SOURCE_DATE_EPOCH', () => {
  test('validates and defaults to the epoch', () => {
    expect(sourceDateEpoch({})).toBe(0);
    expect(sourceDateEpoch({ SOURCE_DATE_EPOCH: '1700000000' })).toBe(1700000000);
    expect(() => sourceDateEpoch({ SOURCE_DATE_EPOCH: 'yesterday' })).toThrow(/SOURCE_DATE_EPOCH/);
  });
});

describe('release packaging', () => {
  test('packages a Linux toolchain with the expected layout and checksums', () => {
    const directory = temp();
    const result = createPackage({
      platform: 'linux-x86_64',
      version: VERSION,
      compiler: elf('x86_64'),
      outDir: directory,
      commit: 'test-commit',
    });
    expect(result.name).toBe(artifactName('linux-x86_64', VERSION, 'toolchain'));
    expect(result.name).toBe(`grail-${VERSION}-linux-x86_64.tar.gz`);
    expect(result.binary).toMatchObject({ format: 'elf', os: 'linux', arch: 'x86_64' });
    expect(existsSync(result.artifact)).toBe(true);
    const names = verifyPackage(result.artifact, 'linux-x86_64', VERSION).names;
    expect(names).toContain('bin/grail');
    expect(names).toContain('lib/grail/runtime.grl');
    expect(names).toContain('share/grail/package.json');
    expect(names).toContain('install.sh');
    expect(names.some(name => /^lib\/grail\/std\/.+\.grl$/.test(name))).toBe(true);

    const sums = readFileSync(join(directory, 'SHA256SUMS'), 'utf8');
    expect(sums).toContain(`${sha256(readFileSync(result.artifact))}  ${result.name}`);
    const manifest = result.manifest;
    expect(manifest).toMatchObject({ name: 'grail', version: VERSION, platform: 'linux-x86_64', commit: 'test-commit' });
    expect(manifest.files['bin/grail']).toBe(sha256(elf('x86_64')));
    rmSync(directory, { recursive: true, force: true });
  });

  test('rejects a compiler built for the wrong platform', () => {
    const directory = temp();
    expect(() => createPackage({ platform: 'linux-aarch64', version: VERSION, compiler: elf('x86_64'), outDir: directory }))
      .toThrow(/compiler targets linux\/x86_64, expected linux\/aarch64/);
    rmSync(directory, { recursive: true, force: true });
  });

  test('creates Windows zip and macOS tar.gz skeletons', () => {
    const directory = temp();
    const windows = createPackage({ platform: 'windows-aarch64', version: VERSION, compiler: pe('aarch64'), outDir: directory });
    expect(windows.name).toBe(`grail-${VERSION}-windows-aarch64.zip`);
    expect(verifyPackage(windows.artifact, 'windows-aarch64', VERSION).names).toContain('bin/grail.exe');

    const mac = createPackage({ platform: 'macos-aarch64', version: VERSION, compiler: macho('aarch64'), outDir: directory });
    expect(mac.name).toBe(`grail-${VERSION}-macos-aarch64.tar.gz`);
    expect(listArchive(mac.artifact).every(name => name.startsWith(`grail-${VERSION}-macos-aarch64/`))).toBe(true);
    expect(readFileSync(join(directory, 'SHA256SUMS'), 'utf8').trim().split('\n')).toHaveLength(2);
    rmSync(directory, { recursive: true, force: true });
  });

  test('is byte-reproducible for identical inputs', () => {
    const one = temp();
    const two = temp();
    createPackage({ platform: 'linux-riscv64', version: VERSION, compiler: elf('riscv64'), outDir: one, commit: 'abc' });
    createPackage({ platform: 'linux-riscv64', version: VERSION, compiler: elf('riscv64'), outDir: two, commit: 'abc' });
    const name = `grail-${VERSION}-linux-riscv64.tar.gz`;
    expect(readFileSync(join(one, name)).equals(readFileSync(join(two, name)))).toBe(true);
    rmSync(one, { recursive: true, force: true });
    rmSync(two, { recursive: true, force: true });
  });

  test('install.sh installs the packaged layout under DESTDIR', () => {
    const directory = temp();
    const result = createPackage({ platform: 'linux-x86_64', version: VERSION, compiler: elf('x86_64'), outDir: directory });
    const unpack = join(directory, 'unpack');
    spawnSync('mkdir', ['-p', unpack]);
    const extract = spawnSync('tar', ['-xzf', result.artifact, '-C', unpack]);
    expect(extract.status).toBe(0);
    const tree = join(unpack, `grail-${VERSION}-linux-x86_64`);
    const destination = join(directory, 'root');
    const install = spawnSync('sh', [join(tree, 'install.sh'), '/opt/grail'], {
      env: { ...process.env, DESTDIR: destination },
      encoding: 'utf8',
    });
    expect(install.status).toBe(0);
    expect(existsSync(join(destination, 'opt/grail/bin/grail'))).toBe(true);
    expect(statSync(join(destination, 'opt/grail/bin/grail')).mode & 0o777).toBe(0o755);
    expect(existsSync(join(destination, 'opt/grail/lib/grail/runtime.grl'))).toBe(true);
    expect(existsSync(join(destination, 'opt/grail/lib/grail/std/collections.grl'))).toBe(true);
    rmSync(directory, { recursive: true, force: true });
  });

  test('writeChecksums covers every artifact and ignores its own output', () => {
    const directory = temp();
    writeFileSync(join(directory, 'grail-0.1.0-linux-x86_64.tar.gz'), 'a');
    writeFileSync(join(directory, 'grail-0.1.0-windows-x86_64.zip'), 'b');
    writeFileSync(join(directory, 'notes.txt'), 'ignored');
    writeChecksums(directory);
    const lines = readFileSync(join(directory, 'SHA256SUMS'), 'utf8').trim().split('\n');
    expect(lines).toHaveLength(2);
    expect(lines[0]).toEndWith('grail-0.1.0-linux-x86_64.tar.gz');
    writeChecksums(directory);
    expect(readFileSync(join(directory, 'SHA256SUMS'), 'utf8').trim().split('\n')).toHaveLength(2);
    rmSync(directory, { recursive: true, force: true });
  });

  test('packageEntries contains a stable, documented file set', () => {
    const { entries, layout } = packageEntries({ platform: 'linux-aarch64', version: VERSION, compiler: elf('aarch64'), commit: 'c' });
    const paths = entries.map(entry => entry.path.slice(layout.name.length + 1));
    expect(paths).toContain('bin/grail');
    expect(paths).toContain('install.sh');
    expect(paths).toContain('install.ps1');
    expect(paths).toContain('share/grail/package.json');
    expect(paths.filter(path => path.startsWith('lib/grail/std/')).length).toBeGreaterThan(5);
    expect(entries.find(entry => entry.path.endsWith('/bin/grail')).mode).toBe(0o755);
  });
});

function listArchiveNames(input) {
  const bytes = Buffer.isBuffer(input) ? input : readFileSync(input);
  const directory = temp();
  const path = join(directory, 'archive');
  writeFileSync(path, bytes);
  try {
    return listArchive(path);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}
