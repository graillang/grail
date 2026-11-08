import { test, expect, describe } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  PLATFORMS, LANES, SUPPORTED, BUILD_ONLY, PLANNED, root,
  platformById, platformId, hostPlatformId, normalizeVersion, readVersion,
  artifactName, artifactPattern, inspectBinary, detectToolchain, laneStatus, buildPlan,
} from './platforms.mjs';

const ALL_IDS = ['linux-x86_64', 'linux-aarch64', 'linux-riscv64', 'windows-x86_64', 'windows-aarch64', 'macos-aarch64', 'macos-x86_64'];

function fakeProbe({ tools = {}, outputs = {}, env = {} } = {}) {
  return {
    env,
    which: name => tools[name] ?? null,
    exec: (name, args) => (typeof outputs[name] === 'function' ? outputs[name](args) : outputs[name] ?? null),
    exists: () => false,
  };
}

describe('platform matrix', () => {
  test('covers exactly the requested cross-platform matrix', () => {
    expect(PLATFORMS.map(p => p.id).sort()).toEqual([...ALL_IDS].sort());
    expect(new Set(PLATFORMS.map(p => p.id)).size).toBe(PLATFORMS.length);
  });

  test('linux is runnable, windows-x86_64 is build-only, other OS targets are planned', () => {
    for (const platform of PLATFORMS) {
      if (platform.os === 'linux') {
        expect(platform.tier).toBe(SUPPORTED);
        expect(platform.runnable).toBe(true);
        expect(platform.compilerTarget).toBeTruthy();
        expect(platform.blocker).toBeNull();
      } else if (platform.id === 'windows-x86_64') {
        expect(platform.tier).toBe(BUILD_ONLY);
        expect(platform.runnable).toBe(false);
        expect(platform.compilerTarget).toBe('windows-x86_64');
        expect(platform.triple).toBe('x86_64-pc-windows-msvc');
        expect(platform.blocker).toMatch(/must not be executed/);
      } else {
        expect(platform.tier).toBe(PLANNED);
        expect(platform.runnable).toBe(false);
        expect(platform.compilerTarget).toBeNull();
        expect(platform.blocker).toMatch(/not implemented/);
      }
    }
  });

  test('every platform declares an archive, installer and required tools', () => {
    for (const platform of PLATFORMS) {
      expect(platform.requiredTools.length).toBeGreaterThan(0);
      expect(['tar.gz', 'zip']).toContain(platform.archiveFormat);
      expect(typeof platform.installer).toBe('string');
      expect(platform.executableSuffix).toBe(platform.os === 'windows' ? '.exe' : '');
    }
  });

  test('maps host runtime triples to platform ids', () => {
    expect(hostPlatformId('linux', 'x64')).toBe('linux-x86_64');
    expect(hostPlatformId('linux', 'arm64')).toBe('linux-aarch64');
    expect(hostPlatformId('linux', 'riscv64')).toBe('linux-riscv64');
    expect(hostPlatformId('win32', 'x64')).toBe('windows-x86_64');
    expect(hostPlatformId('win32', 'arm64')).toBe('windows-aarch64');
    expect(hostPlatformId('darwin', 'arm64')).toBe('macos-aarch64');
    expect(hostPlatformId('darwin', 'x64')).toBe('macos-x86_64');
    expect(hostPlatformId('freebsd', 'x64')).toBeNull();
    expect(platformId('linux', 'ia32')).toBeNull();
  });

  test('rejects unknown platforms with the supported list', () => {
    expect(() => platformById('solaris-sparc')).toThrow(/Unknown platform solaris-sparc/);
  });
});

describe('versions and artifact naming', () => {
  test('reads and normalizes the repo version', () => {
    expect(readVersion({})).toBe(readFileSync(join(root, 'VERSION'), 'utf8').trim());
    expect(normalizeVersion('v1.2.3')).toBe('1.2.3');
    expect(normalizeVersion('1.2.3-rc.1')).toBe('1.2.3-rc.1');
    expect(() => normalizeVersion('1.2')).toThrow(/Invalid Grail version/);
    expect(() => normalizeVersion('latest')).toThrow(/Invalid Grail version/);
  });

  test('uses one deterministic release naming scheme', () => {
    expect(artifactName('linux-x86_64', '0.1.0')).toBe('grail-0.1.0-linux-x86_64.tar.gz');
    expect(artifactName('linux-aarch64', '0.1.0')).toBe('grail-0.1.0-linux-aarch64.tar.gz');
    expect(artifactName('linux-riscv64', '0.1.0')).toBe('grail-0.1.0-linux-riscv64.tar.gz');
    expect(artifactName('windows-x86_64', '0.1.0')).toBe('grail-0.1.0-windows-x86_64.zip');
    expect(artifactName('windows-aarch64', '0.1.0')).toBe('grail-0.1.0-windows-aarch64.zip');
    expect(artifactName('macos-aarch64', '0.1.0')).toBe('grail-0.1.0-macos-aarch64.tar.gz');
    expect(artifactName('macos-x86_64', '0.1.0')).toBe('grail-0.1.0-macos-x86_64.tar.gz');
    expect(artifactName('linux-aarch64', '0.1.0', 'compiler')).toBe('grail-0.1.0-linux-aarch64-compiler');
    expect(artifactName('windows-x86_64', '0.1.0', 'compiler')).toBe('grail-0.1.0-windows-x86_64-compiler.exe');
    expect(artifactName('linux-riscv64', '0.1.0', 'assembly')).toBe('grail-0.1.0-linux-riscv64-compiler.s.gz');
    expect(artifactName('macos-aarch64', '0.1.0', 'notarization')).toBe('grail-0.1.0-macos-aarch64-notary.zip');
  });

  test('artifact patterns accept every generated name', () => {
    for (const platform of PLATFORMS) {
      const pattern = new RegExp(artifactPattern(platform.id));
      for (const kind of ['toolchain', 'compiler', 'assembly', 'notarization']) {
        expect(pattern.test(artifactName(platform.id, '0.1.0', kind))).toBe(true);
      }
      expect(pattern.test(`grail-0.1.0-${platform.id}-bad.tar.gz`)).toBe(false);
    }
  });
});

describe('binary inspection', () => {
  test('recognizes ELF architectures', () => {
    const elf = (machine, bits = 2) => {
      const bytes = Buffer.alloc(64);
      bytes[0] = 0x7f; bytes.write('ELF', 1, 'ascii');
      bytes[4] = bits; bytes[5] = 1;
      bytes.writeUInt16LE(machine, 18);
      return bytes;
    };
    expect(inspectBinary(elf(62))).toMatchObject({ format: 'elf', os: 'linux', arch: 'x86_64', bits: 64 });
    expect(inspectBinary(elf(183))).toMatchObject({ format: 'elf', os: 'linux', arch: 'aarch64' });
    expect(inspectBinary(elf(243))).toMatchObject({ format: 'elf', os: 'linux', arch: 'riscv64' });
  });

  test('recognizes Mach-O and PE architectures', () => {
    const macho = Buffer.alloc(32);
    macho.writeUInt32LE(0xfeedfacf, 0);
    macho.writeUInt32LE(0x0100000c, 4);
    expect(inspectBinary(macho)).toMatchObject({ format: 'macho', os: 'macos', arch: 'aarch64', bits: 64 });

    const pe = Buffer.alloc(0x100);
    pe[0] = 0x4d; pe[1] = 0x5a;
    pe.writeUInt32LE(0x80, 0x3c);
    pe.write('PE\u0000\u0000', 0x80, 'ascii');
    pe.writeUInt16LE(0xaa64, 0x84);
    expect(inspectBinary(pe)).toMatchObject({ format: 'pe', os: 'windows', arch: 'aarch64', bits: 64 });
  });

  test('reports unknown data instead of guessing', () => {
    expect(inspectBinary(Buffer.from('not an executable'))).toMatchObject({ format: 'unknown', os: null, arch: null });
  });
});

describe('toolchain detection', () => {
  test('reports a ready Linux host when clang and ld.lld exist', () => {
    const probe = fakeProbe({ tools: { clang: '/usr/bin/clang', 'ld.lld': '/usr/bin/ld.lld' }, outputs: { clang: 'clang 18', 'ld.lld': 'LLD 18' }, env: { PATH: '/usr/bin' } });
    const result = detectToolchain('linux-x86_64', { probe, host: 'linux-x86_64', env: {} });
    expect(result).toMatchObject({ status: 'ready', ready: true, buildable: true, backend: 'implemented', host: true });
    expect(result.tools.map(t => t.version)).toEqual(['clang 18', 'LLD 18']);
    expect(result.sdk.available).toBe(true);
  });

  test('names every missing tool instead of failing', () => {
    const probe = fakeProbe({ tools: { clang: '/usr/bin/clang' }, outputs: { clang: 'clang 18' }, env: {} });
    const result = detectToolchain('linux-aarch64', { probe, host: 'linux-x86_64', env: {} });
    expect(result.status).toBe('missing-tools');
    expect(result.missing).toEqual(['ld.lld']);
    expect(result.host).toBe(false);
  });

  test('windows-x86_64 is buildable but explicitly non-runnable', () => {
    const tools = {
      clang: '/c/clang', 'lld-link': '/c/lld-link', 'llvm-ar': '/c/llvm-ar',
      'llvm-readobj': '/c/llvm-readobj', 'llvm-objdump': '/c/llvm-objdump',
    };
    const result = detectToolchain('windows-x86_64', { probe: fakeProbe({ tools, outputs: { clang: 'clang 18' }, env: {} }), host: 'linux-x86_64', env: {} });
    expect(result).toMatchObject({ tier: BUILD_ONLY, backend: 'implemented', status: 'build-only', buildable: true, runnable: false });
    expect(result.sdk.available).toBe(true);
    expect(result.blocker).toMatch(/must not be executed/);
  });

  test('does not claim planned platforms are buildable', () => {
    const probe = fakeProbe({ tools: { clang: '/c/clang', 'ld64.lld': '/c/ld64.lld', codesign: '/c/codesign', xcrun: '/c/xcrun' }, outputs: { xcrun: '/SDK/MacOSX.sdk' }, env: {} });
    const mac = detectToolchain('macos-aarch64', { probe, host: 'macos-aarch64', env: {} });
    expect(mac).toMatchObject({ status: 'blocked-backend', buildable: false, backend: 'blocked' });
    expect(mac.blocker).toMatch(/Mach-O/);
    expect(mac.sdk).toMatchObject({ name: 'macOS SDK', available: true, path: '/SDK/MacOSX.sdk' });
  });

  test('detects signing credentials by name without exposing values', () => {
    const output = JSON.stringify(detectToolchain('windows-x86_64', {
      probe: fakeProbe({ tools: { clang: '/c/clang', 'ld.lld': '/c/ld.lld', signtool: '/c/signtool' }, outputs: { clang: '/sysroot' }, env: {} }),
      host: 'windows-x86_64',
      env: { WINDOWS_CERT_FILE: 'cert.pfx', WINDOWS_CERT_PASSWORD: 'super-secret', WINDOWS_TIMESTAMP_URL: 'http://ts' },
    }));
    expect(output).toContain('WINDOWS_CERT_FILE');
    expect(output).not.toContain('super-secret');
    expect(JSON.parse(output).signing.configured).toBe(true);
  });
});

describe('lanes and plan coverage', () => {
  test('every platform is a lane target', () => {
    for (const id of ALL_IDS) expect(LANES.some(lane => lane.target === id)).toBe(true);
  });

  test('required lanes have implemented backends and include Windows static checks', () => {
    const required = LANES.filter(lane => lane.required);
    expect(required.length).toBeGreaterThanOrEqual(5);
    for (const lane of required) {
      expect([SUPPORTED, BUILD_ONLY]).toContain(platformById(lane.target).tier);
      expect(platformById(lane.host).tier).toBe(SUPPORTED);
    }
    expect(required.some(lane => lane.target === 'linux-riscv64')).toBe(true);
    const windows = required.filter(lane => lane.target === 'windows-x86_64');
    expect(windows).toHaveLength(1);
    expect(windows[0]).toMatchObject({ id: 'cross-windows-x86_64', kind: 'cross', execution: 'static' });
  });

  test('planned lanes are non-required and report the backend blocker', () => {
    const planned = LANES.filter(lane => platformById(lane.target).tier === PLANNED);
    expect(planned.length).toBeGreaterThanOrEqual(4);
    expect(planned.every(lane => lane.target !== 'windows-x86_64')).toBe(true);
    for (const lane of planned) expect(lane.required).toBe(false);
    const probe = fakeProbe({ tools: { clang: '/c', 'ld.lld': '/l', 'ld64.lld': '/l', codesign: '/c', xcrun: '/x' }, outputs: { xcrun: '/SDK' }, env: {} });
    const mac = laneStatus(planned.find(lane => lane.target === 'macos-aarch64'), { probe, host: 'macos-aarch64', env: {} });
    expect(mac.status).toBe('blocked-backend');
    expect(mac.blocker).toMatch(/Mach-O/);
  });

  test('cross lane without QEMU is missing-runner, with QEMU is runnable', () => {
    const lane = LANES.find(l => l.id === 'cross-linux-riscv64');
    const absent = laneStatus(lane, { probe: fakeProbe({ tools: { clang: '/c', 'ld.lld': '/l' } }), host: 'linux-x86_64', env: {} });
    expect(absent.status).toBe('missing-runner');
    const present = laneStatus(lane, { probe: fakeProbe({ tools: { clang: '/c', 'ld.lld': '/l', 'qemu-riscv64-static': '/q' } }), host: 'linux-x86_64', env: {} });
    expect(present).toMatchObject({ status: 'runnable', applicable: true, runner: '/q' });
  });

  test('windows-x86_64 cross lane is static-only even when wine is present', () => {
    const lane = LANES.find(l => l.id === 'cross-windows-x86_64');
    const tools = {
      clang: '/c/clang', 'lld-link': '/c/lld-link', 'llvm-ar': '/c/llvm-ar',
      'llvm-readobj': '/c/llvm-readobj', 'llvm-objdump': '/c/llvm-objdump', wine: '/usr/bin/wine',
    };
    const result = laneStatus(lane, { probe: fakeProbe({ tools }), host: 'linux-x86_64', env: {} });
    expect(result).toMatchObject({ status: 'static-only', staticOnly: true, runnable: false, applicable: true, backend: 'implemented' });
    expect(result.blocker).toMatch(/must not be executed/);
  });

  test('the generated plan covers all platforms, lanes and artifact names', () => {
    const probe = fakeProbe({ tools: { clang: '/usr/bin/clang', 'ld.lld': '/usr/bin/ld.lld' }, outputs: { clang: 'clang 18', 'ld.lld': 'LLD 18' }, env: {} });
    const plan = buildPlan({ probe, host: 'linux-x86_64', env: {}, version: '0.1.0' });
    expect(plan.platforms.map(p => p.id)).toEqual(ALL_IDS);
    expect(plan.lanes.map(l => l.id)).toEqual(LANES.map(l => l.id));
    expect(plan.platforms.every(p => p.artifact.startsWith('grail-0.1.0-'))).toBe(true);
    expect(plan.platforms.find(p => p.id === 'linux-x86_64').detection.status).toBe('ready');
    expect(plan.platforms.find(p => p.id === 'windows-x86_64')).toMatchObject({ tier: BUILD_ONLY, runnable: false });
    expect(plan.lanes.find(l => l.id === 'cross-windows-x86_64').runnable).toBe(false);
  });
});
