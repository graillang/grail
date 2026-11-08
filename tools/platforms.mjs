// Cross-platform build/distribution matrix.
//
// This module is deliberately compiler-free: it describes the platforms Grail
// intends to ship, detects host tools, names artifacts and reads binaries. CI,
// packaging and signing all import it so the matrix cannot drift between them.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

export const SUPPORTED = 'supported';
export const BUILD_ONLY = 'build-only';
export const PLANNED = 'planned';

const linuxBlocker = null;
const windowsBlocker = 'PE/COFF output exists only for windows-x86_64; ARM64 PE code generation ' +
  'is not implemented, so this lane is distribution scaffolding';
const macosBlocker = 'Mach-O objects build and pass static checks, but no macOS execution is ' +
  'verified here; release artifacts are non-executable object bundles, not runnable toolchains';

// `requiredTools` are needed to build and link a compiler for the platform on its
// own host. Linux cross lanes reuse the x86-64 host tools with a target triple.
export const PLATFORMS = [
  {
    id: 'linux-x86_64',
    os: 'linux',
    osLabel: 'Linux',
    arch: 'x86_64',
    archLabel: 'x86-64',
    tier: SUPPORTED,
    runnable: true,
    compilerTarget: 'x86_64',
    triple: 'x86_64-linux-gnu',
    emulation: 'elf_x86_64',
    elfMachine: 62,
    assemblerFlags: [],
    executableSuffix: '',
    archiveFormat: 'tar.gz',
    installer: 'install.sh',
    qemu: 'qemu-x86_64-static',
    requiredTools: ['clang', 'ld.lld'],
    hostedRunner: 'ubuntu-24.04',
    blocker: linuxBlocker,
    signing: { kind: 'gpg', optional: true, tool: 'gpg', requiredEnv: ['GRAIL_GPG_KEY'] },
  },
  {
    id: 'linux-aarch64',
    os: 'linux',
    osLabel: 'Linux',
    arch: 'aarch64',
    archLabel: 'AArch64',
    tier: SUPPORTED,
    runnable: true,
    compilerTarget: 'aarch64',
    triple: 'aarch64-linux-gnu',
    emulation: 'aarch64elf',
    elfMachine: 183,
    assemblerFlags: [],
    executableSuffix: '',
    archiveFormat: 'tar.gz',
    installer: 'install.sh',
    qemu: 'qemu-aarch64-static',
    requiredTools: ['clang', 'ld.lld'],
    hostedRunner: 'ubuntu-24.04-arm',
    blocker: linuxBlocker,
    signing: { kind: 'gpg', optional: true, tool: 'gpg', requiredEnv: ['GRAIL_GPG_KEY'] },
  },
  {
    id: 'linux-riscv64',
    os: 'linux',
    osLabel: 'Linux',
    arch: 'riscv64',
    archLabel: 'RISC-V 64',
    tier: SUPPORTED,
    runnable: true,
    compilerTarget: 'riscv64',
    triple: 'riscv64-linux-gnu',
    emulation: 'elf64lriscv',
    elfMachine: 243,
    assemblerFlags: ['-march=rv64imafd', '-mabi=lp64'],
    executableSuffix: '',
    archiveFormat: 'tar.gz',
    installer: 'install.sh',
    qemu: 'qemu-riscv64-static',
    requiredTools: ['clang', 'ld.lld'],
    hostedRunner: null,
    blocker: linuxBlocker,
    signing: { kind: 'gpg', optional: true, tool: 'gpg', requiredEnv: ['GRAIL_GPG_KEY'] },
  },
  {
    id: 'windows-x86_64',
    os: 'windows',
    osLabel: 'Windows',
    arch: 'x86_64',
    archLabel: 'x86-64',
    tier: BUILD_ONLY,
    runnable: false,
    compilerTarget: 'windows-x86_64',
    triple: 'x86_64-pc-windows-msvc',
    emulation: null,
    elfMachine: null,
    assemblerFlags: [],
    executableSuffix: '.exe',
    archiveFormat: 'zip',
    installer: 'install.ps1',
    qemu: null,
    requiredTools: ['clang', 'lld-link', 'llvm-ar', 'llvm-readobj', 'llvm-objdump'],
    hostedRunner: 'ubuntu-24.04',
    crossHost: 'linux-x86_64',
    objectFormat: 'coff',
    objectExtension: '.obj',
    blocker:
      'PE/COFF objects and console images build and pass static checks. Release artifacts here ' +
      'are non-executable object bundles; Windows execution is verified separately under Wine ' +
      'and this lane does not claim a hosted Windows toolchain',
    signing: {
      kind: 'authenticode',
      optional: false,
      tool: 'signtool',
      alternatives: ['signtool', 'signtool.exe', 'osslsigncode'],
      requiredEnv: ['WINDOWS_CERT_FILE', 'WINDOWS_CERT_PASSWORD', 'WINDOWS_TIMESTAMP_URL'],
    },
  },
  {
    id: 'windows-aarch64',
    os: 'windows',
    osLabel: 'Windows',
    arch: 'aarch64',
    archLabel: 'AArch64',
    tier: PLANNED,
    runnable: false,
    compilerTarget: null,
    triple: 'aarch64-pc-windows-msvc',
    emulation: null,
    elfMachine: null,
    assemblerFlags: [],
    executableSuffix: '.exe',
    archiveFormat: 'zip',
    installer: 'install.ps1',
    qemu: null,
    requiredTools: ['clang', 'ld.lld'],
    sysroot: 'mingw-w64',
    hostedRunner: 'windows-11-arm',
    blocker: windowsBlocker,
    signing: {
      kind: 'authenticode',
      optional: false,
      tool: 'signtool',
      alternatives: ['signtool', 'signtool.exe', 'osslsigncode'],
      requiredEnv: ['WINDOWS_CERT_FILE', 'WINDOWS_CERT_PASSWORD', 'WINDOWS_TIMESTAMP_URL'],
    },
  },
  {
    id: 'macos-aarch64',
    os: 'macos',
    osLabel: 'macOS',
    arch: 'aarch64',
    archLabel: 'AArch64',
    tier: BUILD_ONLY,
    runnable: false,
    compilerTarget: 'macos-aarch64',
    triple: 'arm64-apple-macos11',
    emulation: null,
    elfMachine: null,
    assemblerFlags: [],
    executableSuffix: '',
    archiveFormat: 'tar.gz',
    installer: 'install.sh',
    qemu: null,
    requiredTools: ['clang', 'llvm-objdump', 'llvm-nm'],
    objectFormat: 'macho',
    objectExtension: '.o',
    hostedRunner: 'ubuntu-24.04',
    crossHost: 'linux-x86_64',
    blocker: macosBlocker,
    signing: {
      kind: 'apple',
      optional: false,
      tool: 'codesign',
      alternatives: ['codesign', 'xcrun'],
      requiredEnv: ['APPLE_SIGNING_IDENTITY', 'APPLE_NOTARY_PROFILE'],
    },
  },
  {
    id: 'macos-x86_64',
    os: 'macos',
    osLabel: 'macOS',
    arch: 'x86_64',
    archLabel: 'x86-64',
    tier: BUILD_ONLY,
    runnable: false,
    compilerTarget: 'macos-x86_64',
    triple: 'x86_64-apple-macos11',
    emulation: null,
    elfMachine: null,
    assemblerFlags: [],
    executableSuffix: '',
    archiveFormat: 'tar.gz',
    installer: 'install.sh',
    qemu: null,
    requiredTools: ['clang', 'llvm-objdump', 'llvm-nm'],
    objectFormat: 'macho',
    objectExtension: '.o',
    hostedRunner: 'ubuntu-24.04',
    crossHost: 'linux-x86_64',
    blocker: macosBlocker,
    signing: {
      kind: 'apple',
      optional: false,
      tool: 'codesign',
      alternatives: ['codesign', 'xcrun'],
      requiredEnv: ['APPLE_SIGNING_IDENTITY', 'APPLE_NOTARY_PROFILE'],
    },
  },
];

// Build lanes. `required` marks the gates that must pass before a release:
// native Linux x86-64/AArch64 plus cross-built RISC-V64 (and cross AArch64).
export const LANES = [
  { id: 'native-linux-x86_64', host: 'linux-x86_64', target: 'linux-x86_64', kind: 'native', execution: 'native', required: true },
  { id: 'native-linux-aarch64', host: 'linux-aarch64', target: 'linux-aarch64', kind: 'native', execution: 'native', required: true },
  { id: 'cross-linux-aarch64', host: 'linux-x86_64', target: 'linux-aarch64', kind: 'cross', execution: 'qemu', required: true },
  { id: 'cross-linux-riscv64', host: 'linux-x86_64', target: 'linux-riscv64', kind: 'cross', execution: 'qemu', required: true },
  { id: 'native-linux-riscv64', host: 'linux-riscv64', target: 'linux-riscv64', kind: 'native', execution: 'native', required: false },
  { id: 'cross-windows-x86_64', host: 'linux-x86_64', target: 'windows-x86_64', kind: 'cross', execution: 'static', required: true },
  { id: 'native-windows-x86_64', host: 'windows-x86_64', target: 'windows-x86_64', kind: 'native', execution: 'static', required: false },
  { id: 'cross-windows-aarch64', host: 'windows-x86_64', target: 'windows-aarch64', kind: 'cross', execution: 'native', required: false },
  { id: 'native-windows-aarch64', host: 'windows-aarch64', target: 'windows-aarch64', kind: 'native', execution: 'native', required: false },
  { id: 'cross-macos-aarch64', host: 'linux-x86_64', target: 'macos-aarch64', kind: 'cross', execution: 'static', required: true },
  { id: 'cross-macos-x86_64', host: 'linux-x86_64', target: 'macos-x86_64', kind: 'cross', execution: 'static', required: true },
  { id: 'native-macos-aarch64', host: 'macos-aarch64', target: 'macos-aarch64', kind: 'native', execution: 'static', required: false },
  { id: 'native-macos-x86_64', host: 'macos-x86_64', target: 'macos-x86_64', kind: 'native', execution: 'static', required: false },
  { id: 'cross-macos-x86_64-native', host: 'macos-aarch64', target: 'macos-x86_64', kind: 'cross', execution: 'static', required: false },
];

const HOST_KEYS = {
  'linux-x64': 'linux-x86_64',
  'linux-arm64': 'linux-aarch64',
  'linux-riscv64': 'linux-riscv64',
  'win32-x64': 'windows-x86_64',
  'win32-arm64': 'windows-aarch64',
  'darwin-arm64': 'macos-aarch64',
  'darwin-x64': 'macos-x86_64',
};

export function platformById(id) {
  const platform = PLATFORMS.find(p => p.id === id);
  if (!platform) throw new Error(`Unknown platform ${id}; expected ${PLATFORMS.map(p => p.id).join(', ')}`);
  return platform;
}

export function platformId(platform, arch) {
  return HOST_KEYS[`${platform}-${arch}`] ?? null;
}

export function hostPlatformId(platform = process.platform, arch = process.arch) {
  return platformId(platform, arch);
}

export function hostPlatform(platform = process.platform, arch = process.arch) {
  const id = hostPlatformId(platform, arch);
  return id ? platformById(id) : null;
}

export function normalizeVersion(value) {
  const version = String(value ?? '').trim().replace(/^v/, '');
  if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version)) {
    throw new Error(`Invalid Grail version ${JSON.stringify(value)}; expected MAJOR.MINOR.PATCH[-PRERELEASE]`);
  }
  return version;
}

export function readVersion(env = process.env) {
  if (env.GRAIL_VERSION) return normalizeVersion(env.GRAIL_VERSION);
  const file = join(root, 'VERSION');
  if (existsSync(file)) return normalizeVersion(readFileSync(file, 'utf8'));
  throw new Error('No GRAIL_VERSION and no VERSION file');
}

export function gitCommit(cwd = root) {
  const result = spawnSync('git', ['rev-parse', 'HEAD'], { cwd, encoding: 'utf8' });
  return result.status === 0 ? result.stdout.trim() : null;
}

// Artifact names are the release contract: `grail-VERSION-PLATFORM[-KIND].EXT`.
export const ARTIFACT_KINDS = ['toolchain', 'compiler', 'assembly', 'notarization', 'objects'];

export function artifactName(platform, version, kind = 'toolchain') {
  const p = platformById(platform);
  const base = `grail-${normalizeVersion(version)}-${p.id}`;
  if (!ARTIFACT_KINDS.includes(kind)) throw new Error(`Unknown artifact kind ${kind}; expected ${ARTIFACT_KINDS.join(', ')}`);
  if (kind === 'toolchain') return `${base}.${p.archiveFormat}`;
  if (kind === 'compiler') return `${base}-compiler${p.executableSuffix}`;
  if (kind === 'assembly') return `${base}-compiler.s.gz`;
  if (kind === 'objects') return `${base}-objects.${p.archiveFormat}`;
  return `${base}-notary.zip`;
}

export function artifactPattern(platform) {
  const p = platformById(platform);
  const extension = p.executableSuffix ? `|\\${p.executableSuffix}` : '';
  return `^grail-\\d+\\.\\d+\\.\\d+(?:-[0-9A-Za-z.-]+)?-${p.id}(?:-compiler(?:\\.s\\.gz)?|-notary|-objects)?(?:\\.(?:tar\\.gz|zip)${extension})?$`;
}

// Reads just enough of an executable to prove which OS/architecture it targets.
export function inspectBinary(input) {
  const bytes = Buffer.isBuffer(input) ? input : readFileSync(input);
  if (bytes.length >= 20 && bytes[0] === 0x7f && bytes.toString('ascii', 1, 4) === 'ELF') {
    const machine = bytes.readUInt16LE(18);
    const arch = { 62: 'x86_64', 183: 'aarch64', 243: 'riscv64' }[machine] ?? `elf-${machine}`;
    return { format: 'elf', os: 'linux', arch, bits: bytes[4] === 2 ? 64 : 32, endian: bytes[5] === 1 ? 'little' : 'big' };
  }
  if (bytes.length >= 8) {
    const little = bytes.readUInt32LE(0);
    const big = bytes.readUInt32BE(0);
    if ([0xfeedface, 0xfeedfacf].includes(little) || [0xfeedface, 0xfeedfacf].includes(big)) {
      const le = [0xfeedface, 0xfeedfacf].includes(little);
      const magic = le ? little : big;
      const cpu = le ? bytes.readUInt32LE(4) : bytes.readUInt32BE(4);
      const arch = cpu === 0x01000007 ? 'x86_64' : cpu === 0x0100000c ? 'aarch64' : `macho-${cpu}`;
      return { format: 'macho', os: 'macos', arch, bits: magic === 0xfeedfacf ? 64 : 32, endian: le ? 'little' : 'big' };
    }
  }
  if (bytes.length >= 0x40 && bytes[0] === 0x4d && bytes[1] === 0x5a) {
    const offset = bytes.readUInt32LE(0x3c);
    if (offset + 6 <= bytes.length && bytes.toString('ascii', offset, offset + 4) === 'PE\u0000\u0000') {
      const machine = bytes.readUInt16LE(offset + 4);
      const arch = { 0x8664: 'x86_64', 0xaa64: 'aarch64' }[machine] ?? `pe-${machine.toString(16)}`;
      return { format: 'pe', os: 'windows', arch, bits: machine === 0x8664 || machine === 0xaa64 ? 64 : 32, endian: 'little' };
    }
  }
  return { format: 'unknown', os: null, arch: null, bits: null, endian: null };
}

export function createProbe(env = process.env, spawn = spawnSync) {
  const windows = process.platform === 'win32';
  const delimiter = windows ? ';' : ':';
  const extensions = windows ? ['', ...(env.PATHEXT ?? '.EXE;.CMD;.BAT').split(';')] : [''];
  return {
    which(name) {
      if (name.includes('/') || name.includes('\\')) return existsSync(name) ? name : null;
      for (const directory of (env.PATH ?? '').split(delimiter)) {
        if (!directory) continue;
        for (const extension of extensions) {
          const candidate = join(directory, name + extension);
          if (existsSync(candidate)) return candidate;
        }
      }
      const local = join(root, '.work/architectures/toolchain/usr/bin', name);
      return existsSync(local) ? local : null;
    },
    exec(name, args = []) {
      const result = spawn(name, args, { env, encoding: 'utf8', timeout: 20_000 });
      if (result.error || result.status !== 0) return null;
      return `${result.stdout ?? ''}${result.stderr ?? ''}`.trim();
    },
    exists(name) {
      return existsSync(name);
    },
  };
}

const VERSION_ARGS = {
  clang: ['--version'],
  'ld.lld': ['--version'],
  'ld64.lld': ['--version'],
  lld: ['--version'],
  gpg: ['--version'],
  codesign: ['--version'],
  osslsigncode: ['--version'],
};

function toolVersion(probe, name) {
  const args = VERSION_ARGS[name];
  if (!probe.exec || !args) return null;
  const output = probe.exec(name, args);
  return output ? output.split('\n')[0].trim() : null;
}

export function findRunner(platform, probe) {
  const p = platformById(platform);
  if (!p.qemu) return null;
  return probe.which(p.qemu) ?? null;
}

function detectSdk(platform, probe, env = process.env) {
  if (platform.os === 'linux') {
    return { name: 'glibc (assembler/linker only)', available: true, path: null, detail: 'static ELF, no SDK required' };
  }
  if (platform.os === 'macos' && platform.tier === BUILD_ONLY) {
    return {
      name: 'Mach-O object toolchain',
      available: true,
      path: null,
      detail: 'clang emits Mach-O objects; no SDK or linker is needed for object bundles',
    };
  }
  if (platform.os === 'macos') {
    const xcrun = probe.which('xcrun');
    const path = xcrun ? probe.exec('xcrun', ['--sdk', 'macosx', '--show-sdk-path']) : null;
    return {
      name: 'macOS SDK',
      available: Boolean(path),
      path: path ? path.split('\n').pop().trim() : null,
      detail: path ? 'xcrun resolved the macOS SDK' : 'requires macOS with Xcode command-line tools',
    };
  }
  if (platform.os === 'windows' && platform.tier === BUILD_ONLY) {
    return {
      name: 'COFF toolchain (in-tree import library)',
      available: true,
      path: null,
      detail: 'clang, lld-link and llvm-ar assemble/link PE images; the kernel32 short-import library is generated in-tree',
    };
  }
  if (platform.os === 'windows') {
    const sysroot = probe.which('clang') ? probe.exec('clang', [`--target=${platform.triple}`, '-print-sysroot']) : null;
    const msvc = env.VCToolsInstallDir ?? env.WindowsSdkDir ?? null;
    // `-print-sysroot` prints the compiler's default sysroot, which may be `/` or empty
    // for a MinGW-less LLVM. Only a non-empty, non-root path counts as a usable SDK.
    const usable = Boolean(msvc) || Boolean(sysroot && sysroot !== '/' && sysroot.length > 0);
    return {
      name: platform.sysroot ?? 'Windows SDK',
      available: usable,
      path: msvc ?? (sysroot && sysroot !== '/' ? sysroot : null),
      detail: usable ? 'Windows/MinGW sysroot found' : 'requires a Windows SDK or mingw-w64 sysroot',
    };
  }
  return { name: null, available: false, path: null, detail: 'unknown platform' };
}

export function describeSigning(platform, probe, env = probe.env ?? process.env) {
  const signing = platform.signing;
  const tools = (signing.alternatives ?? [signing.tool]).map(name => ({ name, path: probe.which(name) })).filter(t => t.path);
  return {
    kind: signing.kind,
    optional: signing.optional,
    requiredEnv: [...signing.requiredEnv],
    tools,
    tool: tools[0]?.name ?? null,
    available: tools.length > 0 && signing.requiredEnv.every(name => Boolean(env[name])),
    configured: signing.requiredEnv.every(name => Boolean(env[name])),
    missing: signing.requiredEnv.filter(name => !env[name]),
  };
}

export function detectToolchain(platform, options = {}) {
  const target = platformById(platform);
  const env = options.env ?? process.env;
  const probe = options.probe ?? { ...createProbe(env), env };
  if (!probe.env) probe.env = env;
  const host = options.host ?? hostPlatformId();
  const tools = target.requiredTools.map(name => {
    const path = probe.which(name);
    return { name, path, found: Boolean(path), version: path ? toolVersion(probe, name) : null };
  });
  const missing = tools.filter(tool => !tool.found).map(tool => tool.name);
  const sdk = detectSdk(target, probe, env);
  const signing = describeSigning(target, probe, env);
  const backend = target.tier === PLANNED ? 'blocked' : 'implemented';
  const runnable = target.tier === SUPPORTED && target.runnable === true;
  const ready = missing.length === 0 && sdk.available;
  return {
    platform: target.id,
    host: host === target.id,
    tier: target.tier,
    backend,
    runnable,
    ready,
    buildable: backend === 'implemented' && ready,
    status: backend === 'blocked' ? 'blocked-backend' : !ready ? 'missing-tools' : runnable ? 'ready' : 'build-only',
    tools,
    missing,
    sdk,
    signing,
    blocker: target.blocker,
    qemu: target.qemu ? { name: target.qemu, path: findRunner(target.id, probe) } : null,
    notes: host === target.id ? [] : [`host is ${host ?? 'unsupported'}; tools listed are what this platform needs`],
  };
}

export function laneStatus(lane, options = {}) {
  const host = options.host ?? hostPlatformId();
  const target = platformById(lane.target);
  const probe = options.probe ?? { ...createProbe(options.env ?? process.env), env: options.env ?? process.env };
  const runner = lane.execution === 'qemu' ? findRunner(target.id, probe) : null;
  const applicable = host === lane.host;
  const backend = target.tier === PLANNED ? 'blocked' : 'implemented';
  const staticOnly = lane.execution === 'static';
  let status;
  if (backend === 'blocked') status = 'blocked-backend';
  else if (!applicable) status = 'not-applicable';
  else if (lane.execution === 'qemu' && !runner) status = 'missing-runner';
  else if (staticOnly) status = 'static-only';
  else status = 'runnable';
  return {
    id: lane.id,
    host: lane.host,
    target: lane.target,
    kind: lane.kind,
    execution: lane.execution,
    required: lane.required,
    applicable,
    backend,
    runnable: status === 'runnable',
    staticOnly,
    status,
    runner,
    blocker: target.blocker,
  };
}

export function buildPlan(options = {}) {
  const env = options.env ?? process.env;
  const version = options.version ? normalizeVersion(options.version) : readVersion(env);
  const probe = options.probe ?? { ...createProbe(env), env };
  const host = options.host ?? hostPlatformId();
  return {
    schema: 1,
    version,
    commit: gitCommit(),
    host,
    platforms: PLATFORMS.map(platform => ({
      id: platform.id,
      tier: platform.tier,
      runnable: platform.runnable === true,
      os: platform.os,
      arch: platform.arch,
      triple: platform.triple,
      compilerTarget: platform.compilerTarget,
      hostedRunner: platform.hostedRunner,
      artifact: artifactName(platform.id, version, 'toolchain'),
      assembly: artifactName(platform.id, version, 'assembly'),
      objects: artifactName(platform.id, version, 'objects'),
      blocker: platform.blocker,
      detection: detectToolchain(platform.id, { env, probe, host }),
    })),
    lanes: LANES.map(lane => laneStatus(lane, { env, probe, host })),
  };
}
