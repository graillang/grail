// Tag-time release assembly for every target this tree can honestly build.
//
// Release builds start from the checked-in bootstrap seed (native.mjs
// buildCompiler) and refuse GRAIL_COMPILER: a tag must reproduce on a fresh
// clone with no development compiler and no network beyond the runner's
// toolchain. Nothing here publishes a claim the toolchain cannot support:
//
//   linux-x86_64 / linux-aarch64 / linux-riscv64  real ELF compiler executables
//   windows-x86_64                                cross-built PE32+ compiler image
//                                                 plus a COFF object bundle; not
//                                                 runnable on Windows yet
//   windows-aarch64                               planned, not built or published
//   macos-aarch64 / macos-x86_64                  static-checked Mach-O object
//                                                 bundles only; no executable
//
// Commands:
//   version --tag vX.Y.Z                 validate a tag against VERSION
//   build --platform ID [--out DIR]      build one target's release assets
//   assemble --dir DIR [--out DIR]       merge targets into checksums + README
//   verify --dir DIR                     recompute checksums, check the claims
//   dry-run [--out DIR]                  build everything locally, assemble, verify
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, relative, resolve, sep } from 'node:path';
import {
  BUILD_ONLY, PLANNED, PLATFORMS, SUPPORTED, artifactName, gitCommit, hostPlatformId,
  inspectBinary, normalizeVersion, platformById, readVersion, root,
} from './platforms.mjs';
import { bootstrapStatus, buildTarget } from './ci.mjs';
import { buildCompiler } from './native.mjs';
import { createPackage, sha256, verifyPackage, writeChecksums } from './package.mjs';
import { buildObjectBundle, verifyObjectBundle } from './objects.mjs';

export const EXIT = { ok: 0, usage: 1, failed: 5 };

// What each target's artifacts are allowed to claim. `runsOn` and `limits`
// are the text a release publishes; keep them in step with docs/platform-status.md.
const POLICY = {
  'linux-x86_64': {
    runsOn: 'Linux x86-64 (static ELF)',
    verified: 'ELF machine x86_64, package layout and every file SHA-256',
    execution: 'native test suite and CLI regressions against the shipped compiler run in the release workflow',
    limits: 'none known for the compiler; the packaged runtime and std library are the tree at the tagged commit',
  },
  'linux-aarch64': {
    runsOn: 'Linux AArch64 (static ELF)',
    verified: 'ELF machine aarch64, package layout and every file SHA-256',
    execution: 'native test suite on the AArch64 release runner; cross-built artifacts are ELF-checked only',
    limits: 'a cross-built copy is not executed; only the native AArch64 lane runs the suite',
  },
  'linux-riscv64': {
    runsOn: 'Linux RISC-V 64 (static ELF)',
    verified: 'ELF machine riscv64, package layout and every file SHA-256',
    execution: 'shipped compiler smoke-run under qemu-riscv64-static and a compile-only ELF check in the release workflow',
    limits: 'not executed on RISC-V hardware; the full qemu suite remains in .github/workflows/ci.yml',
  },
  'windows-x86_64': {
    runsOn: '**Nothing yet.** A PE32+ console image; the Windows runtime is incomplete, so this is not a runnable compiler',
    verified: 'COFF object and PE32+ image static checks (grail_entry, kernel32 import, console subsystem), package layout and SHA-256',
    execution: 'no Windows execution; Wine execution of generated programs is a ci.yml check, not a compiler claim',
    limits: 'argv recovery, worker threads, file/directory host services and .pdata/unwind data are missing; the .exe must not be used as a toolchain',
  },
  'macos-aarch64': {
    runsOn: '**Nothing.** A non-executable Mach-O object bundle; no macOS execution is claimed',
    verified: 'Mach-O MH_MAGIC_64, ARM64 cputype, LC_BUILD_VERSION for macOS, _main in .text, bundle manifest and SHA-256',
    execution: 'none; the bundle contains no executable and is never run',
    limits: 'no macOS compiler executable is built or published',
  },
  'macos-x86_64': {
    runsOn: '**Nothing.** A non-executable Mach-O object bundle; no macOS execution is claimed',
    verified: 'Mach-O MH_MAGIC_64, X86_64 cputype, LC_BUILD_VERSION for macOS, _main in .text, bundle manifest and SHA-256',
    execution: 'none; the bundle contains no executable and is never run',
    limits: 'no macOS compiler executable is built or published',
  },
};

const PLATFORM_IDS = PLATFORMS.map(platform => platform.id);
const PLANNED_IDS = PLATFORMS.filter(platform => platform.tier === PLANNED).map(platform => platform.id);

function parse(argv) {
  const options = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) { options._.push(arg); continue; }
    const key = arg.slice(2);
    if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
      options[key] = argv[i + 1];
      i += 1;
    } else {
      options[key] = true;
    }
  }
  return options;
}

function versionOf(options = {}) {
  return normalizeVersion(options.version ?? readVersion());
}

function insideRoot(path) {
  return path === root || path.startsWith(`${root}${sep}`);
}

function releaseAssets(platformId, version) {
  const target = platformById(platformId);
  if (target.os === 'macos') return [artifactName(platformId, version, 'objects')];
  const compiler = artifactName(platformId, version, 'compiler');
  const assets = [
    artifactName(platformId, version, 'toolchain'),
    compiler,
    `${compiler}.build.json`,
    artifactName(platformId, version, 'assembly'),
  ];
  if (target.id === 'windows-x86_64') assets.push(artifactName(platformId, version, 'objects'));
  return assets;
}

function seedInfo() {
  const status = bootstrapStatus();
  if (!status.targetsMatch) {
    throw new Error(`the checked-in bootstrap seed is corrupt: ${status.detail}\n  run bun tools/bootstrap.mjs verify all on a host with all three seeds`);
  }
  return {
    targetDigestsMatch: status.targetsMatch,
    sourcesMatch: status.sourcesMatch,
    changedSources: status.changed,
    targets: status.targets,
  };
}

function stage0FromSeed() {
  if (process.env.GRAIL_COMPILER) {
    throw new Error('refusing a release build with GRAIL_COMPILER set: releases must start from the checked-in bootstrap seed');
  }
  let stage0;
  try {
    stage0 = buildCompiler();
  } catch (error) {
    throw new Error(`cannot build stage0 from the checked-in bootstrap seed: ${error.message}`);
  }
  const info = inspectBinary(stage0);
  if (info.format !== 'elf') throw new Error(`stage0 ${stage0} is ${info.format}, expected ELF`);
  return {
    path: stage0,
    sha256: sha256(readFileSync(stage0)),
    ...info,
    origin: 'checked-in bootstrap seed (tools/native.mjs buildCompiler)',
  };
}

export function buildPlatform(platformId, options = {}) {
  const target = platformById(platformId);
  if (!PLATFORM_IDS.includes(platformId)) throw new Error(`unknown platform ${platformId}`);
  if (target.tier === PLANNED) {
    throw new Error(`${target.id} has no compiler backend (${target.blocker}); it is not built or published`);
  }
  if (!POLICY[platformId]) throw new Error(`no release policy for ${platformId}`);
  const version = versionOf(options);
  const seed = seedInfo();
  const stage0 = stage0FromSeed();
  const host = hostPlatformId();
  const buildKind = host === target.id ? 'native' : 'cross';
  if (buildKind === 'cross' && host !== 'linux-x86_64' && target.tier === SUPPORTED) {
    throw new Error(`${target.id} is cross-built from linux-x86_64, not ${host}`);
  }
  const outDir = resolve(root, options.out ?? join('dist/release', platformId));
  if (!insideRoot(outDir)) throw new Error(`release output must stay inside the repository (${outDir})`);
  mkdirSync(outDir, { recursive: true });

  const assets = releaseAssets(platformId, version);
  for (const name of [...assets, `release-${platformId}.json`]) rmSync(join(outDir, name), { force: true });

  console.log(`release: ${platformId}: stage0 ${relative(root, stage0.path)} (${stage0.sha256.slice(0, 16)}…), building ${buildKind}`);

  let built;
  if (target.tier === SUPPORTED) {
    built = buildTarget(platformId, { out: outDir, version, stage0: stage0.path });
    const pkg = createPackage({ platform: platformId, version, compiler: built.artifact, outDir });
    verifyPackage(pkg.artifact, platformId, version);
    if (buildKind === 'native') smokeInstalledPackage(pkg.artifact, platformId, version);
  } else if (target.id === 'windows-x86_64') {
    built = buildTarget(platformId, { out: outDir, version, stage0: stage0.path });
    const pkg = createPackage({ platform: platformId, version, compiler: built.artifact, outDir });
    verifyPackage(pkg.artifact, platformId, version);
    const bundle = buildObjectBundle({ platform: platformId, version, outDir, stage0: stage0.path });
    verifyObjectBundle(bundle.artifact, platformId, version);
  } else {
    built = buildObjectBundle({ platform: platformId, version, outDir, stage0: stage0.path });
    verifyObjectBundle(built.artifact, platformId, version);
  }

  for (const name of assets) {
    const path = join(outDir, name);
    if (!existsSync(path)) throw new Error(`${platformId}: expected asset ${name} was not written`);
  }
  const binary = target.tier === SUPPORTED
    ? inspectBinary(join(outDir, artifactName(platformId, version, 'compiler')))
    : target.id === 'windows-x86_64'
      ? inspectBinary(join(outDir, artifactName(platformId, version, 'compiler')))
      : null;
  if (target.tier === SUPPORTED && (binary.format !== 'elf' || binary.arch !== target.arch)) {
    throw new Error(`${platformId}: compiler is ${binary.format}/${binary.arch}, expected elf/${target.arch}`);
  }
  if (target.id === 'windows-x86_64' && (binary.format !== 'pe' || binary.arch !== 'x86_64')) {
    throw new Error(`windows-x86_64: compiler is ${binary.format}/${binary.arch}, expected pe/x86_64`);
  }

  const summary = {
    schema: 1,
    kind: 'grail-release-target',
    version,
    commit: gitCommit(),
    platform: target.id,
    os: target.os,
    arch: target.arch,
    triple: target.triple,
    tier: target.tier,
    runnable: target.tier === SUPPORTED,
    build: {
      kind: buildKind,
      host,
      stage0: {
        origin: stage0.origin,
        path: relative(root, stage0.path),
        sha256: stage0.sha256,
        format: stage0.format,
        arch: stage0.arch,
      },
    },
    seed,
    assets: assets.map(name => ({ name, sha256: sha256(readFileSync(join(outDir, name))), size: statSync(join(outDir, name)).size })),
    verification: {
      structural: POLICY[platformId].verified,
      execution: POLICY[platformId].execution,
      limits: POLICY[platformId].limits,
    },
    runsOn: POLICY[platformId].runsOn,
  };
  writeFileSync(join(outDir, `release-${platformId}.json`), `${JSON.stringify(summary, null, 2)}\n`);
  writeChecksums(outDir);
  console.log(`release: ${platformId}: ${assets.length} assets in ${relative(root, outDir)}`);
  return summary;
}

function walkFiles(directory, found = []) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === 'upload') continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) walkFiles(path, found);
    else if (entry.isFile()) found.push(path);
  }
  return found;
}

function readSummaries(directory) {
  const summaries = new Map();
  for (const path of walkFiles(directory)) {
    const match = basename(path).match(/^release-(.+)\.json$/);
    if (!match || !PLATFORM_IDS.includes(match[1])) continue;
    const summary = JSON.parse(readFileSync(path, 'utf8'));
    if (summary.kind !== 'grail-release-target') throw new Error(`${path}: not a release target summary`);
    if (summaries.has(summary.platform)) throw new Error(`duplicate release summary for ${summary.platform}`);
    summaries.set(summary.platform, { summary, path });
  }
  return summaries;
}

function gapList(summaries, version) {
  const gaps = [
    '`windows-aarch64` is not built or published: ARM64 PE/COFF code generation is not implemented, so the lane remains planned.',
    'macOS artifacts contain no compiler executable and nothing is executed on macOS; they are static-checked Mach-O object bundles only.',
    'Windows x86-64 artifacts are cross-built on Linux and are not executed on Windows; the PE32+ compiler image is not a runnable toolchain yet.',
    'RISC-V 64 is cross-built and smoke-checked under qemu; it is not executed on RISC-V hardware by this release lane.',
    'Artifacts are unsigned by default. `bun tools/ci.mjs sign` prints the GPG, Authenticode and codesign/notary commands; signing runs only when the credentials and `RELEASE_SIGNING=true` are configured.',
  ];
  const stale = [...summaries.values()].find(({ summary }) => summary.seed && summary.seed.sourcesMatch === false);
  if (stale) {
    gaps.push('The checked-in bootstrap seed predates the compiler sources at this commit. Every build here proves that seed can compile the tree, but `bun tools/ci.mjs preflight` reports it as stale until `bun tools/bootstrap.mjs update all` is run on a host with all three seeds. `release.json` records the seed and source digests.');
  }
  return gaps;
}

function releaseReadme(version, commit, summaries, gaps) {
  const rows = PLATFORMS.filter(platform => summaries.has(platform.id)).map(platform => {
    const { summary } = summaries.get(platform.id);
    const names = summary.assets.map(asset => `\`${asset.name}\``).join('<br>');
    return `| ${names} | ${summary.runsOn} | ${summary.build.kind} on ${summary.build.host} | ${summary.verification.structural} | ${summary.verification.execution} |`;
  });
  return [
    `# Grail ${version} release artifacts`,
    '',
    `Built from commit \`${commit}\` on tag \`v${version}\`.`,
    '',
    'Verify every download with:',
    '',
    '```sh',
    'sha256sum -c SHA256SUMS',
    '```',
    '',
    '## What each artifact runs on',
    '',
    '| Artifacts | Runs on | Built | Verified here | Execution evidence |',
    '| --- | --- | --- | --- | --- |',
    ...rows,
    '',
    '## Not covered by this release',
    '',
    ...gaps.map(gap => `- ${gap}`),
    '',
    '## How it was built',
    '',
    'Every artifact starts from the checked-in bootstrap seed in `compiler/bootstrap/`.',
    'Release builds refuse `GRAIL_COMPILER`, so no development compiler is needed or accepted;',
    'only the runner toolchain (Bun, Clang, LLD and the LLVM inspection tools) is installed.',
    'Per-target stage0 and source digests are recorded in `release.json`.',
    '',
    '```sh',
    'git checkout v' + version,
    'GRAIL_VERSION=' + version + ' bun tools/release.mjs dry-run --out dist/release',
    'GRAIL_VERSION=' + version + ' bun tools/release.mjs assemble --dir dist/release --out dist/release/upload',
    'bun tools/release.mjs verify --dir dist/release/upload',
    '```',
    '',
    'The release workflow runs the same `build`, `assemble` and `verify` commands, then attaches',
    'this file, `SHA256SUMS` and `release.json` to the GitHub release.',
    '',
  ].join('\n');
}

export function assembleRelease(options = {}) {
  const directory = resolve(root, options.dir ?? 'dist/release');
  if (!insideRoot(directory)) throw new Error(`release staging dir must stay inside the repository (${directory})`);
  if (!existsSync(directory)) throw new Error(`no release staging directory at ${directory}`);
  const version = versionOf(options);
  const summaries = readSummaries(directory);
  const missing = PLATFORMS.filter(platform => platform.tier !== PLANNED && !summaries.has(platform.id)).map(platform => platform.id);
  if (missing.length) throw new Error(`release is missing built targets: ${missing.join(', ')}`);
  for (const { summary, path } of summaries.values()) {
    if (summary.version !== version) throw new Error(`${path}: version ${summary.version}, expected ${version}`);
    if (summary.commit !== gitCommit()) throw new Error(`${path}: commit ${summary.commit}, expected ${gitCommit()}`);
  }

  const outDir = resolve(root, options.out ?? join(directory, 'upload'));
  if (!insideRoot(outDir) || outDir === root) throw new Error(`release output must stay inside the repository (${outDir})`);
  rmSync(outDir, { recursive: true, force: true });
  mkdirSync(outDir, { recursive: true });

  const copied = new Map();
  const platforms = [];
  for (const platform of PLATFORMS) {
    const entry = summaries.get(platform.id);
    if (!entry) continue;
    const { summary, path } = entry;
    for (const asset of summary.assets) {
      const source = join(dirname(path), asset.name);
      if (!existsSync(source)) throw new Error(`${platform.id}: missing asset ${source}`);
      const digest = sha256(readFileSync(source));
      if (digest !== asset.sha256) throw new Error(`${platform.id}: ${asset.name} digest ${digest}, expected ${asset.sha256}`);
      const target = join(outDir, asset.name);
      if (copied.has(asset.name)) {
        if (copied.get(asset.name) !== digest) throw new Error(`asset name collision with different bytes: ${asset.name}`);
      } else {
        copyFileSync(source, target);
        copied.set(asset.name, digest);
      }
    }
    platforms.push({
      platform: summary.platform,
      tier: summary.tier,
      runnable: summary.runnable,
      target: summary.triple,
      build: summary.build,
      assets: summary.assets,
      verification: summary.verification,
      seed: summary.seed,
    });
  }

  const names = readdirSync(outDir).sort();
  const sums = names.map(name => `${sha256(readFileSync(join(outDir, name)))}  ${name}`);
  writeFileSync(join(outDir, 'SHA256SUMS'), `${sums.join('\n')}\n`);

  const gaps = gapList(summaries, version);
  const commit = gitCommit();
  writeFileSync(join(outDir, 'RELEASE-README.md'), releaseReadme(version, commit, summaries, gaps));
  const release = {
    schema: 1,
    kind: 'grail-release',
    name: 'grail',
    version,
    commit,
    assets: names.map(name => ({ name, sha256: sha256(readFileSync(join(outDir, name))), size: statSync(join(outDir, name)).size })),
    platforms,
    notCovered: gaps,
  };
  writeFileSync(join(outDir, 'release.json'), `${JSON.stringify(release, null, 2)}\n`);
  console.log(`release: assembled ${names.length} assets for ${version} in ${relative(root, outDir)}`);
  return release;
}

export function verifyRelease(options = {}) {
  const directory = resolve(root, options.dir ?? 'dist/release/upload');
  if (!existsSync(join(directory, 'SHA256SUMS'))) throw new Error(`no SHA256SUMS in ${directory}`);
  if (!existsSync(join(directory, 'release.json'))) throw new Error(`no release.json in ${directory}`);
  if (!existsSync(join(directory, 'RELEASE-README.md'))) throw new Error(`no RELEASE-README.md in ${directory}`);
  const release = JSON.parse(readFileSync(join(directory, 'release.json'), 'utf8'));
  const version = versionOf(options);
  if (release.version !== version) throw new Error(`release.json says ${release.version}, expected ${version}`);
  if (release.commit !== gitCommit()) throw new Error(`release.json says commit ${release.commit}, expected ${gitCommit()}`);

  const allowed = new Set([...release.assets.map(asset => asset.name), 'SHA256SUMS', 'RELEASE-README.md', 'release.json']);
  for (const entry of readdirSync(directory)) {
    if (!allowed.has(entry)) throw new Error(`unexpected file in release output: ${entry}`);
  }
  const sums = new Map(readFileSync(join(directory, 'SHA256SUMS'), 'utf8').trim().split('\n').filter(Boolean)
    .map(line => {
      const match = line.match(/^([0-9a-f]{64})  (.+)$/);
      if (!match) throw new Error(`malformed SHA256SUMS line: ${line}`);
      return [match[2], match[1]];
    }));
  for (const asset of release.assets) {
    if (!existsSync(join(directory, asset.name))) throw new Error(`missing release asset ${asset.name}`);
    const digest = sha256(readFileSync(join(directory, asset.name)));
    if (digest !== asset.sha256) throw new Error(`${asset.name}: digest ${digest}, expected ${asset.sha256}`);
    if (sums.get(asset.name) !== asset.sha256) throw new Error(`${asset.name}: SHA256SUMS entry does not match release.json`);
  }
  if (sums.size !== release.assets.length) throw new Error('SHA256SUMS does not list every release asset');

  const covered = new Set(release.platforms.map(entry => entry.platform));
  const expected = PLATFORMS.filter(platform => platform.tier !== PLANNED).map(platform => platform.id);
  for (const id of expected) if (!covered.has(id)) throw new Error(`release does not cover ${id}`);
  for (const id of PLANNED_IDS) if (covered.has(id)) throw new Error(`release must not publish planned target ${id}`);

  const readme = readFileSync(join(directory, 'RELEASE-README.md'), 'utf8');
  for (const id of PLATFORM_IDS) {
    if (!readme.includes(id) && !release.notCovered.some(gap => gap.includes(id))) {
      throw new Error(`RELEASE-README.md does not mention ${id}`);
    }
  }
  for (const entry of release.platforms) {
    const target = platformById(entry.platform);
    if (target.tier === BUILD_ONLY && entry.runnable) throw new Error(`${entry.platform} is build-only but marked runnable`);
    if (target.tier === SUPPORTED && !entry.runnable) throw new Error(`${entry.platform} is supported but not marked runnable`);
    if (target.os === 'macos' && entry.assets.some(asset => /(^|\/)bin\/grail$|-compiler(\.s\.gz|\.build\.json)?$|\.dylib$/.test(asset.name))) {
      throw new Error(`${entry.platform} bundle must not contain a compiler or dylib`);
    }
    if (!release.notCovered.some(gap => /windows-aarch64/.test(gap))) throw new Error('release.json must say why windows-aarch64 is absent');
  }
  const result = {
    ok: true,
    version,
    commit: release.commit,
    assets: release.assets.length,
    platforms: release.platforms.map(entry => ({ platform: entry.platform, tier: entry.tier, runnable: entry.runnable })),
    notCovered: release.notCovered.length,
  };
  console.log(JSON.stringify(result, null, 2));
  return result;
}

// Unpack the archive a user downloads and build and run a program with it, with an empty HOME so
// nothing from a development tree or build store can stand in for a missing packaged file. The
// layout check alone missed a package without the platform module the compiler loads.
export function smokeInstalledPackage(artifact, platformId, version) {
  const work = mkdtempSync(join(tmpdir(), 'grail-package-smoke-'));
  try {
    const unpack = spawnSync('tar', ['-xzf', artifact, '-C', work], { encoding: 'utf8' });
    if (unpack.status !== 0) throw new Error(`${platformId}: cannot unpack ${basename(artifact)}: ${unpack.stderr}`);
    const grail = join(work, `grail-${version}-${platformId}`, 'bin', 'grail');
    const program = join(work, 'hello.grl');
    writeFileSync(program, 'fn main() { println("package smoke ok"); }\n');
    const home = join(work, 'home');
    mkdirSync(home);
    const env = { ...process.env, HOME: home, XDG_CACHE_HOME: join(home, '.cache') };
    delete env.GRAIL_HOME;
    const result = spawnSync(grail, ['run', program], { cwd: work, encoding: 'utf8', env, timeout: 600_000 });
    if (result.status !== 0 || !result.stdout.includes('package smoke ok')) {
      throw new Error(`${platformId}: the unpacked package cannot build and run a program (exit ${result.status})\n${result.stdout}${result.stderr}`);
    }
    console.log(`release: ${platformId}: unpacked package builds and runs a program`);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

export function dryRun(options = {}) {
  const version = versionOf(options);
  const base = resolve(root, options.out ?? 'dist/release');
  if (!insideRoot(base)) throw new Error(`dry-run output must stay inside the repository (${base})`);
  const summaries = [];
  for (const platform of PLATFORMS) {
    if (platform.tier === PLANNED) {
      console.log(`release: ${platform.id}: skipped (${platform.blocker})`);
      continue;
    }
    summaries.push(buildPlatform(platform.id, { version, out: join(base, platform.id) }));
  }
  const release = assembleRelease({ version, dir: base, out: join(base, 'upload') });
  const verified = verifyRelease({ version, dir: join(base, 'upload') });
  console.log(`release: dry run complete for ${version}: ${release.assets.length} assets, ${summaries.length} targets, verification ${verified.ok ? 'passed' : 'failed'}`);
  console.log('release: execution suites are not run by dry-run; the tag workflow runs them on the release runners.');
  return { version, targets: summaries.map(summary => summary.platform), assets: release.assets.map(asset => asset.name), verified: verified.ok };
}

function tagVersion(tag) {
  const match = String(tag).match(/^v(.+)$/);
  if (!match) throw new Error(`release tags are vMAJOR.MINOR.PATCH[-PRERELEASE], got ${JSON.stringify(tag)}`);
  const version = normalizeVersion(match[1]);
  const declared = normalizeVersion(readFileSync(join(root, 'VERSION'), 'utf8'));
  if (version !== declared) throw new Error(`tag ${tag} does not match VERSION ${declared}; bump VERSION before tagging`);
  return version;
}

function run(argv) {
  const options = parse(argv);
  const command = options._[0] ?? 'help';
  if (command === 'help' || options.help) {
    console.log(`usage: bun tools/release.mjs <command> [options]

  version --tag vX.Y.Z           validate a release tag against VERSION
  build --platform ID [--out DIR] build one target's release assets from the seed
  assemble --dir DIR [--out DIR]  merge built targets, write SHA256SUMS and the README
  verify --dir DIR                recompute checksums and check every published claim
  dry-run [--out DIR]             build every locally buildable target, assemble, verify

GRAIL_VERSION overrides VERSION. GRAIL_COMPILER is refused: releases start from
the checked-in compiler/bootstrap seed.`);
    return EXIT.ok;
  }
  if (command === 'version') {
    console.log(tagVersion(options.tag ?? ''));
    return EXIT.ok;
  }
  if (command === 'build') {
    if (!options.platform) throw new Error('build needs --platform ID');
    buildPlatform(options.platform, options);
    return EXIT.ok;
  }
  if (command === 'assemble') {
    assembleRelease(options);
    return EXIT.ok;
  }
  if (command === 'verify') {
    verifyRelease(options);
    return EXIT.ok;
  }
  if (command === 'dry-run') {
    dryRun(options);
    return EXIT.ok;
  }
  throw new Error(`unknown command ${command}; run bun tools/release.mjs help`);
}

if (import.meta.main) {
  try {
    process.exit(run(process.argv.slice(2)));
  } catch (error) {
    console.error(`release: ${error.message}`);
    process.exit(EXIT.failed);
  }
}
