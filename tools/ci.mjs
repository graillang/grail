#!/usr/bin/env bun
// Cross-platform CI driver. Compiler-free commands (matrix, plan, lint) run
// everywhere; build/test/package/sign use the host compiler and report a
// distinct exit code when a lane is blocked or a tool is missing.
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { chmodSync, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { gzipSync, gunzipSync } from 'node:zlib';
import {
  PLATFORMS, LANES, BUILD_ONLY, PLANNED, SUPPORTED, artifactName, artifactPattern, buildPlan,
  detectToolchain, findRunner, gitCommit, hostPlatformId, inspectBinary, platformById,
  readVersion, root,
} from './platforms.mjs';
import { buildCompiler, command, compilerSources, assemble, compileProgram } from './native.mjs';
import { compileProgram as compileWindowsProgram, headers as windowsHeaders, inspectImage as inspectPeImage, inspectObject as inspectPeObject } from './windows.mjs';
import { createPackage, sha256, verifyPackage, writeChecksums } from './package.mjs';
import { buildObjectBundle, verifyObjectBundle } from './objects.mjs';
import { executeSigning, formatPlan, signingPlan } from './sign.mjs';

export const EXIT = { ok: 0, usage: 1, notApplicable: 2, blocked: 3, missing: 4, failed: 5 };

class Blocked extends Error {
  constructor(message, code = EXIT.blocked) {
    super(message);
    this.exitCode = code;
  }
}

function parse(argv) {
  const options = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) { options._.push(arg); continue; }
    const key = arg.slice(2);
    if (key === 'json' || key === 'execute' || key === 'compile-only' || key === 'allow-blocked' || key === 'all' || key === 'strict') {
      options[key] = true;
    } else if (i + 1 < argv.length) {
      options[key] = argv[i + 1];
      i += 1;
    } else {
      options[key] = true;
    }
  }
  return options;
}

function relative(path) {
  return path.startsWith(`${root}/`) ? path.slice(root.length + 1) : path;
}

function sourceDigests() {
  return Object.fromEntries(compilerSources.map(path => [relative(path), sha256(readFileSync(path))]));
}

export function bootstrapStatus() {
  const directory = join(root, 'compiler/bootstrap');
  const manifestPath = join(directory, 'manifest.json');
  if (!existsSync(manifestPath)) return { fresh: false, detail: 'compiler/bootstrap/manifest.json is missing' };
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const actualSources = sourceDigests();
  const sourcesMatch = JSON.stringify(manifest.sources) === JSON.stringify(actualSources);
  const changed = Object.keys(actualSources).filter(name => manifest.sources?.[name] !== actualSources[name]);
  const targets = {};
  for (const target of ['x86_64', 'aarch64', 'riscv64']) {
    const recorded = manifest.targets?.[target];
    if (!recorded) { targets[target] = { match: false, detail: 'not recorded' }; continue; }
    const path = join(directory, recorded.file);
    if (!existsSync(path)) { targets[target] = { match: false, detail: `missing ${recorded.file}` }; continue; }
    const bytes = recorded.file.endsWith('.gz') ? gunzipSync(readFileSync(path)) : readFileSync(path);
    const digest = sha256(bytes);
    targets[target] = { match: digest === recorded.sha256, file: recorded.file, sha256: digest };
  }
  const targetsMatch = Object.values(targets).every(entry => entry.match);
  return {
    fresh: sourcesMatch && targetsMatch,
    sourcesMatch,
    targetsMatch,
    changed,
    targets,
    detail: sourcesMatch && targetsMatch
      ? 'published bootstrap matches compiler sources'
      : changed.length
        ? `published bootstrap is stale for: ${changed.join(', ')}`
        : 'published bootstrap assembly digests do not match the manifest',
  };
}

function stage0Info() {
  if (process.env.GRAIL_COMPILER) {
    const path = resolve(root, process.env.GRAIL_COMPILER);
    return { kind: 'env', path, exists: existsSync(path), info: existsSync(path) ? inspectBinary(path) : null };
  }
  const host = hostPlatformId();
  if (!host) return { kind: 'bootstrap', path: null, exists: false, info: null };
  const platform = platformById(host);
  const file = platform.arch === 'x86_64' ? 'native.s' : `${platform.arch}.s.gz`;
  return { kind: 'bootstrap', path: join(root, 'compiler/bootstrap', file), exists: existsSync(join(root, 'compiler/bootstrap', file)), info: null };
}

export function preflight() {
  const host = hostPlatformId();
  const bootstrap = bootstrapStatus();
  const stage0 = stage0Info();
  const blockers = [];
  if (!host) blockers.push(`unsupported host ${process.platform}/${process.arch}; Grail CI supports linux/win32/darwin on x64/arm64/riscv64`);
  if (!stage0.exists) blockers.push(`no stage0 compiler: ${stage0.kind === 'env' ? process.env.GRAIL_COMPILER : 'published bootstrap'}`);
  if (stage0.kind === 'bootstrap' && !bootstrap.fresh) blockers.push(`${bootstrap.detail}; set GRAIL_COMPILER to a tree-built compiler or refresh bootstraps`);
  const toolchain = host ? detectToolchain(host) : null;
  const windows = detectToolchain('windows-x86_64');
  if (toolchain && !toolchain.ready) blockers.push(`host toolchain incomplete: ${[...toolchain.missing, ...(toolchain.sdk.available ? [] : [toolchain.sdk.name])].join(', ')}`);
  return {
    schema: 1,
    host,
    hostPlatform: host ? platformById(host) : null,
    version: (() => { try { return readVersion(); } catch (error) { return null; } })(),
    commit: gitCommit(),
    bootstrap,
    stage0,
    toolchain,
    windows,
    ready: blockers.length === 0,
    blockers,
  };
}

function detect(platforms, options) {
  const rows = platforms.map(id => ({ platform: id, ...detectToolchain(id) }));
  if (options.json) return rows;
  return rows.map(row => [
    `${row.platform}  ${row.tier.padEnd(10)}  runnable=${String(row.runnable).padEnd(5)}  backend=${row.backend.padEnd(11)}  status=${row.status}`,
    `  tools: ${row.tools.map(tool => `${tool.name}${tool.found ? '' : ' (missing)'}`).join(', ') || 'none'}`,
    `  sdk: ${row.sdk.name ?? 'none'}${row.sdk.available ? '' : ' (missing)'}${row.sdk.path ? ` at ${row.sdk.path}` : ''}`,
    `  signing: ${row.signing.kind} ${row.signing.available ? 'ready' : row.signing.optional ? 'optional/unsigned' : 'not configured'}`,
    row.blocker ? `  blocker: ${row.blocker}` : '',
  ].filter(Boolean).join('\n')).join('\n');
}

function matrix(plan, options) {
  const rows = plan.platforms.map(platform => ({
    platform: platform.id,
    os: platform.os,
    arch: platform.arch,
    tier: platform.tier,
    runnable: platform.runnable,
    triple: platform.triple,
    compilerTarget: platform.compilerTarget,
    runner: platform.hostedRunner ?? 'self-hosted',
    artifact: platform.tier === BUILD_ONLY ? platform.objects : platform.artifact,
  }));
  if (options.json) return rows;
  const width = Math.max(...rows.map(row => row.platform.length));
  const lines = rows.map(row => `${row.platform.padEnd(width)}  ${row.tier.padEnd(10)}  ${(row.runnable ? 'runnable' : 'no-exec').padEnd(9)}  ${row.os.padEnd(7)}  ${row.arch.padEnd(7)}  ${row.runner.padEnd(14)}  ${row.artifact}`);
  const lanes = plan.lanes.map(lane => `  ${lane.status.padEnd(15)} ${lane.required ? 'required ' : 'optional '} ${lane.kind.padEnd(6)} ${lane.host} -> ${lane.target} (${lane.execution})`);
  return [`${'platform'.padEnd(width)}  tier        exec       os       arch     runner          artifact`, ...lines, '', 'lanes:', ...lanes].join('\n');
}

function hostFor(platform) {
  const host = hostPlatformId();
  if (!host) throw new Blocked(`unsupported host ${process.platform}/${process.arch}`, EXIT.notApplicable);
  return host;
}

function buildTarget(platformId, options = {}) {
  const target = platformById(platformId);
  if (target.tier === PLANNED) throw new Blocked(`cannot build ${target.id}: ${target.blocker}`);
  if (target.id === 'windows-x86_64') return buildWindowsCompiler(target, options);
  if (target.os !== 'linux') throw new Blocked(`cannot build ${target.id}: no backend`);
  const host = hostFor();
  if (host !== 'linux-x86_64' && host !== target.id) {
    throw new Blocked(`cannot build ${target.id} from ${host}; use the native ${target.id} lane or linux-x86_64`, EXIT.notApplicable);
  }
  const bootstrap = bootstrapStatus();
  if (!process.env.GRAIL_COMPILER && !bootstrap.fresh) {
    throw new Blocked(`stage0 unavailable: ${bootstrap.detail}\n  set GRAIL_COMPILER=/path/to/tree-built/grail or run: bun tools/bootstrap.mjs update all`);
  }
  let stage0;
  try {
    stage0 = buildCompiler();
  } catch (error) {
    throw new Blocked(`stage0 build failed: ${error.message}`);
  }
  const stage0Binary = inspectBinary(stage0);
  if (stage0Binary.format !== 'elf' || stage0Binary.arch !== (host === 'linux-x86_64' ? 'x86_64' : platformById(host).arch)) {
    throw new Blocked(`stage0 ${stage0} is ${stage0Binary.format}/${stage0Binary.arch}, which cannot build ${target.id}`);
  }
  const work = join(root, '.work/ci', target.id);
  mkdirSync(work, { recursive: true });
  const assembly = join(work, 'compiler.s');
  command([stage0, '--default-u64', '--typed-refs', '--target', target.compilerTarget, assembly, ...compilerSources]);
  const executable = assemble(assembly, join(work, `grail${target.executableSuffix}`), target.compilerTarget);
  const binary = inspectBinary(executable);
  if (binary.format !== 'elf' || binary.arch !== target.arch) {
    throw new Error(`built compiler is ${binary.format}/${binary.arch}, expected elf/${target.arch}`);
  }
  const outDir = resolve(root, options.out ?? 'dist');
  mkdirSync(outDir, { recursive: true });
  const version = options.version ?? readVersion();
  const name = artifactName(target.id, version, 'compiler');
  const artifact = join(outDir, name);
  writeFileSync(artifact, readFileSync(executable));
  chmodSync(artifact, 0o755);
  const assemblyArtifact = join(outDir, artifactName(target.id, version, 'assembly'));
  writeFileSync(assemblyArtifact, gzipSync(readFileSync(assembly), { level: 9 }));
  const manifest = {
    schema: 1,
    name: 'grail',
    version,
    platform: target.id,
    target: target.triple,
    compilerTarget: target.compilerTarget,
    commit: gitCommit(),
    stage0: { kind: process.env.GRAIL_COMPILER ? 'env' : 'bootstrap', path: stage0, sha256: sha256(readFileSync(stage0)), ...stage0Binary },
    binary,
    sources: sourceDigests(),
    assembly: assemblyArtifact,
  };
  const manifestPath = join(outDir, `${name}.build.json`);
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  writeChecksums(outDir);
  return { platform: target.id, artifact, assembly: assemblyArtifact, manifest: manifestPath, binary, version };
}

function inspectWindowsArtifacts(built) {
  const object = inspectPeObject(built.object);
  const image = inspectPeImage(built.executable);
  const headers = windowsHeaders(built.executable);
  const imports = image.split('\n')
    .map(line => line.match(/^\s+Symbol: (\S+)/))
    .filter(Boolean)
    .map(match => match[1])
    .sort();
  if (!/Format: COFF-x86-64/.test(object)) throw new Error('Windows object is not COFF x86-64');
  if (!/Machine: IMAGE_FILE_MACHINE_AMD64/.test(object)) throw new Error('Windows object has the wrong COFF machine');
  if (!/Name: grail_entry/.test(object)) throw new Error('Windows object is missing grail_entry');
  if (!/Name: kernel32\.dll/.test(image)) throw new Error('PE image is missing the kernel32 import descriptor');
  if (!/Magic\s+020b\t\(PE32\+\)/.test(headers)) throw new Error('Windows image is not PE32+');
  if (!/Subsystem\s+00000003\t\(Windows CUI\)/.test(headers)) throw new Error('Windows image is not a console image');
  const entry = headers.match(/AddressOfEntryPoint\s+([0-9a-f]+)/)?.[1] ?? '0';
  if (Number.parseInt(entry, 16) === 0) throw new Error('Windows image has no entry point');
  return { object: 'COFF-x86-64', machine: 'IMAGE_FILE_MACHINE_AMD64', image: 'PE32+', subsystem: 'console', entryRva: `0x${entry}`, imports, executed: false };
}

function buildWindowsCompiler(target, options = {}) {
  const host = hostFor();
  if (host !== 'linux-x86_64') {
    throw new Blocked(`windows-x86_64 cross-builds run from linux-x86_64, not ${host}`, EXIT.notApplicable);
  }
  const bootstrap = bootstrapStatus();
  if (!process.env.GRAIL_COMPILER && !bootstrap.fresh) {
    throw new Blocked(`stage0 unavailable: ${bootstrap.detail}\n  set GRAIL_COMPILER=/path/to/tree-built/grail or run: bun tools/bootstrap.mjs update all`);
  }
  let stage0;
  try {
    stage0 = buildCompiler();
  } catch (error) {
    throw new Blocked(`stage0 build failed: ${error.message}`);
  }
  const stage0Binary = inspectBinary(stage0);
  if (stage0Binary.format !== 'elf' || stage0Binary.arch !== 'x86_64') {
    throw new Blocked(`stage0 ${stage0} is ${stage0Binary.format}/${stage0Binary.arch}, expected ELF x86_64`);
  }
  const work = join(root, '.work/ci', target.id);
  mkdirSync(work, { recursive: true });
  const sources = compilerSources.filter(path => !path.endsWith('/runtime.grl'));
  const built = compileWindowsProgram(stage0, sources, work, { name: 'grail' });
  const staticChecks = inspectWindowsArtifacts(built);
  const binary = inspectBinary(built.executable);
  if (binary.format !== 'pe' || binary.arch !== 'x86_64') {
    throw new Error(`built Windows compiler is ${binary.format}/${binary.arch}, expected pe/x86_64`);
  }
  const outDir = resolve(root, options.out ?? 'dist');
  mkdirSync(outDir, { recursive: true });
  const version = options.version ?? readVersion();
  const name = artifactName(target.id, version, 'compiler');
  const artifact = join(outDir, name);
  writeFileSync(artifact, readFileSync(built.executable));
  chmodSync(artifact, 0o755);
  const assemblyArtifact = join(outDir, artifactName(target.id, version, 'assembly'));
  writeFileSync(assemblyArtifact, gzipSync(readFileSync(built.assembly), { level: 9 }));
  const manifest = {
    schema: 1,
    name: 'grail',
    version,
    platform: target.id,
    target: target.triple,
    compilerTarget: target.compilerTarget,
    tier: target.tier,
    runnable: false,
    runtime: 'unverified',
    commit: gitCommit(),
    stage0: { kind: process.env.GRAIL_COMPILER ? 'env' : 'bootstrap', path: stage0, sha256: sha256(readFileSync(stage0)), ...stage0Binary },
    binary,
    staticChecks,
    sources: sourceDigests(),
    assembly: assemblyArtifact,
  };
  const manifestPath = join(outDir, `${name}.build.json`);
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  writeChecksums(outDir);
  return { platform: target.id, artifact, assembly: assemblyArtifact, manifest: manifestPath, binary, version, tier: target.tier, runnable: false, staticChecks };
}

function qemuFor(target, env = process.env) {
  return env[`GRAIL_QEMU_${target.arch.toUpperCase()}`] ?? findRunner(target.id, { which: name => {
    for (const directory of (env.PATH ?? '').split(':')) {
      if (directory && existsSync(join(directory, name))) return join(directory, name);
    }
    const local = join(root, '.work/architectures/toolchain/usr/bin', name);
    return existsSync(local) ? local : null;
  } });
}

function testTarget(platformId, options = {}) {
  const target = platformById(platformId);
  if (target.tier === PLANNED) throw new Blocked(`cannot test ${target.id}: ${target.blocker}`);
  if (target.id === 'windows-x86_64') return windowsStaticCheck(target, options);
  if (target.os === 'macos') return macosStaticCheck(target, options);
  const host = hostFor();
  const checkOnly = options['compile-only'] ?? false;
  let compiler = options.compiler ? resolve(root, options.compiler) : null;
  let built = null;
  if (!compiler) {
    const version = options.version ?? readVersion();
    const candidate = resolve(root, options.out ?? 'dist', artifactName(target.id, version, 'compiler'));
    if (existsSync(candidate)) compiler = candidate;
    else built = buildTarget(target.id, options), compiler = built.artifact;
  }
  const info = inspectBinary(compiler);
  if (info.format !== 'elf' || info.arch !== target.arch) throw new Error(`${compiler} is ${info.format}/${info.arch}, expected elf/${target.arch}`);

  if (target.id !== host) {
    const qemu = qemuFor(target);
    if (!qemu) {
      if (!checkOnly) throw new Blocked(`cross execution for ${target.id} needs ${target.qemu} (or GRAIL_QEMU_${target.arch.toUpperCase()})`, EXIT.missing);
      return crossCompileCheck(target);
    }
    if (checkOnly) return crossCompileCheck(target);
    const result = spawnSync('bun', ['tools/test-native.mjs', target.compilerTarget], {
      cwd: root,
      stdio: 'inherit',
      env: { ...process.env, GRAIL_COMPILER: compiler, [`GRAIL_QEMU_${target.arch.toUpperCase()}`]: qemu },
    });
    if (result.status !== 0) throw new Error(`${target.id} native tests failed (${result.status})`);
    return { platform: target.id, compiler, mode: 'qemu', runner: qemu, status: 'passed' };
  }

  const result = spawnSync('bun', ['tools/test-native.mjs', target.compilerTarget], {
    cwd: root,
    stdio: 'inherit',
    env: { ...process.env, GRAIL_COMPILER: compiler },
  });
  if (result.status !== 0) throw new Error(`${target.id} native tests failed (${result.status})`);
  if (options.full && target.id === 'linux-x86_64') {
    const cli = spawnSync('bun', ['tools/test-cli.mjs'], { cwd: root, stdio: 'inherit', env: { ...process.env, GRAIL_COMPILER: compiler } });
    if (cli.status !== 0) throw new Error(`linux-x86_64 CLI tests failed (${cli.status})`);
    const authority = spawnSync('bun', ['tools/test-authority.mjs'], { cwd: root, stdio: 'inherit', env: { ...process.env, GRAIL_COMPILER: compiler } });
    if (authority.status !== 0) throw new Error(`linux-x86_64 authority tests failed (${authority.status})`);
  }
  return { platform: target.id, compiler, mode: 'native', status: 'passed' };
}

function macosStaticCheck(target, options = {}) {
  const host = hostFor();
  if (host !== 'linux-x86_64' && host !== 'macos-aarch64' && host !== 'macos-x86_64') {
    throw new Blocked(`macOS object checks run from linux-x86_64 or macOS, not ${host}`, EXIT.notApplicable);
  }
  const provided = options.compiler ? inspectBinary(resolve(root, options.compiler)) : null;
  const stage0 = provided && provided.format === 'elf' && provided.arch === 'x86_64'
    ? resolve(root, options.compiler)
    : buildCompiler();
  const result = spawnSync('bun', ['tools/test-macos.mjs'], {
    cwd: root,
    stdio: 'inherit',
    env: { ...process.env, GRAIL_COMPILER: stage0 },
  });
  if (result.status !== 0) throw new Error(`macOS static checks failed (${result.status})`);
  return {
    platform: target.id,
    compiler: stage0,
    mode: 'static',
    runnable: false,
    status: 'passed',
    note: 'Mach-O objects and linked images inspected; no macOS execution is claimed',
  };
}

function windowsStaticCheck(target, options = {}) {
  const host = hostFor();
  if (host !== 'linux-x86_64' && host !== 'windows-x86_64') {
    throw new Blocked(`windows-x86_64 static checks run from linux-x86_64, not ${host}`, EXIT.notApplicable);
  }
  const provided = options.compiler ? inspectBinary(resolve(root, options.compiler)) : null;
  const stage0 = provided && provided.format === 'elf' && provided.arch === 'x86_64'
    ? resolve(root, options.compiler)
    : buildCompiler();
  const result = spawnSync('bun', ['tools/windows.mjs', 'check'], {
    cwd: root,
    stdio: 'inherit',
    env: { ...process.env, GRAIL_COMPILER: stage0 },
  });
  if (result.status !== 0) throw new Error(`windows-x86_64 static checks failed (${result.status})`);
  return {
    platform: target.id,
    compiler: stage0,
    mode: 'static',
    runnable: false,
    status: 'passed',
    note: 'COFF objects and PE images inspected; no execution because the Windows runtime is not implemented',
  };
}

function crossCompileCheck(target) {
  // The target compiler is a foreign-architecture binary; smoke codegen must be
  // driven by the host stage0 with --target, not by executing the target.
  const stage0 = buildCompiler();
  const directory = join(root, '.work/ci', target.id, 'smoke');
  const executable = compileProgram(stage0, ['book/examples/hello.grl'], directory, {
    target: target.compilerTarget,
    defaultU64: false,
    typedRefs: false,
    name: 'hello',
  });
  const info = inspectBinary(executable);
  if (info.format !== 'elf' || info.arch !== target.arch) throw new Error(`smoke program is ${info.format}/${info.arch}, expected elf/${target.arch}`);
  return { platform: target.id, compiler: stage0, mode: 'compile-only', binary: info, status: 'passed', note: `execution skipped: ${target.qemu} not installed` };
}

function lint() {
  const checks = [];
  const check = (name, ok, detail = '') => checks.push({ name, ok, detail });
  let version = null;
  try { version = readVersion(); check('VERSION is semver', true, version); } catch (error) { check('VERSION is semver', false, error.message); }
  const ids = PLATFORMS.map(platform => platform.id);
  for (const required of ['linux-x86_64', 'linux-aarch64', 'linux-riscv64', 'windows-x86_64', 'windows-aarch64', 'macos-aarch64', 'macos-x86_64']) {
    check(`matrix includes ${required}`, ids.includes(required));
  }
  check('platform ids are unique', new Set(ids).size === ids.length);
  for (const platform of PLATFORMS) {
    const pattern = new RegExp(artifactPattern(platform.id));
    const name = artifactName(platform.id, version ?? '0.0.0');
    check(`${platform.id} artifact name`, pattern.test(name), name);
    check(`${platform.id} has a lane`, LANES.some(lane => lane.target === platform.id));
  }
  for (const lane of LANES) {
    if (lane.required) check(`required lane ${lane.id} targets an implemented backend`, [SUPPORTED, BUILD_ONLY].includes(platformById(lane.target).tier));
  }
  const workflow = join(root, '.github/workflows/ci.yml');
  if (existsSync(workflow)) {
    const text = readFileSync(workflow, 'utf8');
    for (const id of ids) check(`workflow mentions ${id}`, text.includes(id));
    check('workflow runs the tooling tests', text.includes('bun test tools'));
    check('workflow runs the CI driver', text.includes('tools/ci.mjs'));
  } else {
    check('workflow exists', false, '.github/workflows/ci.yml');
  }
  const docs = join(root, 'docs/tooling/cross-platform-ci.md');
  if (existsSync(docs)) {
    const text = readFileSync(docs, 'utf8');
    for (const id of ids) check(`matrix doc mentions ${id}`, text.includes(id));
  } else {
    check('matrix doc exists', false, 'docs/tooling/cross-platform-ci.md');
  }
  for (const script of ['tools/ci.mjs', 'packaging/install.sh']) {
    const path = join(root, script);
    const executable = existsSync(path) && (statSync(path).size > 0) && ((statSync(path).mode & 0o111) !== 0);
    check(`${script} is executable`, executable);
  }
  check('install.ps1 exists', existsSync(join(root, 'packaging/install.ps1')));
  check('windows-x86_64 has a required cross lane', LANES.some(lane => lane.required && lane.target === 'windows-x86_64'));
  check('windows-x86_64 lane is static-only', LANES.filter(lane => lane.target === 'windows-x86_64').every(lane => lane.execution === 'static'));
  for (const id of ['windows-x86_64', 'macos-aarch64', 'macos-x86_64']) {
    const name = artifactName(id, version ?? '0.0.0', 'objects');
    check(`${id} object bundle name`, new RegExp(artifactPattern(id)).test(name), name);
    check(`${id} required static lane`, LANES.some(lane => lane.required && lane.target === id));
  }
  check('LSP/debugger/profiler plan exists', existsSync(join(root, 'docs/tooling/lsp-debugger-profiler.md')));
  check('FFI test runner exists', existsSync(join(root, 'tools/test-ffi.mjs')));
  check('CI runs the FFI shim test', readFileSync(join(root, '.github/workflows/ci.yml'), 'utf8').includes('tools/test-ffi.mjs'));
  check('LSP server exists', existsSync(join(root, 'tools/lsp.mjs')));
  check('LSP stdio test exists', existsSync(join(root, 'tools/lsp.test.mjs')));
  check('DWARF line-table test exists', existsSync(join(root, 'tools/test-debug-lines.mjs')));
  check('VERSION file matches compiler --version', readFileSync(join(root, 'compiler/cli.grl'), 'utf8').includes(`grail ${version ?? '0.0.0'}`), version ?? '');
  const failed = checks.filter(entry => !entry.ok);
  return { ok: failed.length === 0, checks, failed };
}



function run(argv) {
  const options = parse(argv);
  const commandName = options._[0] ?? 'help';
  const platform = options.platform ?? hostPlatformId();
  const all = options.all ? PLATFORMS.map(entry => entry.id) : null;

  if (commandName === 'help' || options.help) {
    console.log(`usage: bun tools/ci.mjs <command> [options]

  matrix [--json]                     platform support matrix and lanes
  plan [--json]                       full CI plan (platforms, lanes, artifacts)
  detect [--platform ID] [--all]      toolchain/SDK/signing detection
  preflight [--json] [--strict]       host, stage0, bootstrap and toolchain status
  lint [--json]                       static checks (matrix, docs, workflow, scripts)
  build --platform ID [--out DIR]     build the compiler for ID (Linux targets)
  test --platform ID [--compile-only] run native/qemu tests or a cross compile check
  package --platform ID [--compiler PATH] [--out DIR]
                                      create a .tar.gz/.zip and SHA256SUMS
  objects --platform ID [--compiler PATH] [--out DIR]
                                      build a non-executable COFF/Mach-O object bundle
                                      (windows-x86_64, macos-aarch64, macos-x86_64)
  sign --platform ID --artifact PATH [--binary PATH|--tree DIR] [--execute]
                                      print signing/notarization commands (dry-run by default)
  all [--platform ID]                 preflight + build + test + package + sign dry-run

exit codes: 0 ok, 1 usage/internal, 2 not applicable, 3 blocked, 4 missing dependency, 5 failure`);
    return EXIT.ok;
  }

  if (commandName === 'matrix') {
    console.log(options.json ? JSON.stringify(matrix(buildPlan(options), options), null, 2) : matrix(buildPlan(options), options));
    return EXIT.ok;
  }

  if (commandName === 'plan') {
    const plan = buildPlan(options);
    console.log(JSON.stringify(plan, null, 2));
    return EXIT.ok;
  }

  if (commandName === 'detect') {
    const platforms = all ?? [platform];
    const output = detect(platforms, options);
    console.log(typeof output === 'string' ? output : JSON.stringify(output, null, 2));
    return EXIT.ok;
  }

  if (commandName === 'preflight') {
    const status = preflight();
    console.log(JSON.stringify(status, null, 2));
    return status.ready || !options.strict ? EXIT.ok : EXIT.blocked;
  }

  if (commandName === 'lint') {
    const result = lint();
    if (options.json) console.log(JSON.stringify(result, null, 2));
    else {
      for (const check of result.checks) console.log(`${check.ok ? 'ok  ' : 'FAIL'} ${check.name}${check.detail ? `: ${check.detail}` : ''}`);
      console.log(result.ok ? `lint passed (${result.checks.length} checks)` : `lint failed (${result.failed.length}/${result.checks.length})`);
    }
    return result.ok ? EXIT.ok : EXIT.failed;
  }

  if (commandName === 'build') {
    try {
      const built = buildTarget(platform, { out: options.out, version: options.version });
      console.log(JSON.stringify(built, null, 2));
      return EXIT.ok;
    } catch (error) {
      return fail(error, options);
    }
  }

  if (commandName === 'test') {
    try {
      const result = testTarget(platform, {
        compiler: options.compiler,
        out: options.out,
        version: options.version,
        'compile-only': options['compile-only'],
        full: options.full,
      });
      console.log(JSON.stringify(result, null, 2));
      return EXIT.ok;
    } catch (error) {
      return fail(error, options);
    }
  }

  if (commandName === 'package') {
    try {
      const target = platformById(platform);
      const version = options.version ?? readVersion();
      let compiler = options.compiler ? resolve(root, options.compiler) : null;
      if (!compiler) {
        const built = buildTarget(platform, { out: options.out, version });
        compiler = built.artifact;
      } else if (target.tier === PLANNED && !existsSync(compiler)) {
        throw new Blocked(`no compiler at ${compiler}; planned lanes package a supplied cross-built binary`);
      }
      const result = createPackage({ platform, version, compiler, outDir: resolve(root, options.out ?? 'dist') });
      verifyPackage(result.artifact, platform, version);
      console.log(JSON.stringify({ ...result, manifest: result.manifest }, null, 2));
      return EXIT.ok;
    } catch (error) {
      return fail(error, options);
    }
  }

  if (commandName === 'objects') {
    try {
      if (!options.platform) throw new Blocked('objects needs --platform windows-x86_64|macos-aarch64|macos-x86_64', EXIT.usage);
      const target = platformById(options.platform);
      if (target.tier !== BUILD_ONLY) throw new Blocked(`cannot build object bundles for ${target.id}: tier is ${target.tier}`);
      const version = options.version ?? readVersion();
      const stage0 = options.compiler ? resolve(root, options.compiler) : buildCompiler();
      const result = buildObjectBundle({ platform: target.id, version, outDir: resolve(root, options.out ?? 'dist'), stage0 });
      verifyObjectBundle(result.artifact, target.id, version);
      console.log(JSON.stringify(result, null, 2));
      return EXIT.ok;
    } catch (error) {
      return fail(error, options);
    }
  }

  if (commandName === 'sign') {
    try {
      if (!options.artifact) throw new Blocked('sign needs --artifact PATH', EXIT.usage);
      const plan = signingPlan(platform, {
        artifact: options.artifact,
        tree: options.tree,
        binary: options.binary,
        env: process.env,
      });
      process.stdout.write(formatPlan(plan));
      if (!options.execute) return EXIT.ok;
      executeSigning(plan, { execute: true, env: process.env });
      console.log('signing completed');
      return EXIT.ok;
    } catch (error) {
      return fail(error, options);
    }
  }

  if (commandName === 'all') {
    const status = preflight();
    if (!status.ready) {
      console.error(JSON.stringify(status, null, 2));
      return EXIT.blocked;
    }
    try {
      const built = buildTarget(platform, { out: options.out, version: options.version });
      console.log(`built ${built.artifact}`);
      const tested = testTarget(platform, { compiler: built.artifact, 'compile-only': options['compile-only'] });
      console.log(`tested ${tested.mode}`);
      const packaged = createPackage({ platform, version: built.version, compiler: built.artifact, outDir: resolve(root, options.out ?? 'dist') });
      console.log(`packaged ${packaged.artifact}`);
      const plan = signingPlan(platform, { artifact: packaged.artifact, tree: null, binary: null, env: process.env });
      process.stdout.write(formatPlan(plan));
      return EXIT.ok;
    } catch (error) {
      return fail(error, options);
    }
  }

  console.error(`unknown command ${commandName}; run 'bun tools/ci.mjs help'`);
  return EXIT.usage;
}

function fail(error, options) {
  const code = error.exitCode ?? EXIT.failed;
  console.error(`ci: ${error.message}`);
  if (options['allow-blocked'] && (code === EXIT.blocked || code === EXIT.notApplicable)) return EXIT.ok;
  return code;
}

if (import.meta.main) {
  const code = run(process.argv.slice(2));
  process.exit(code);
}
