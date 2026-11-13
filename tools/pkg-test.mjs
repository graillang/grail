// The package manager end to end: grail.toml, resolution, grail.lock, the store, and the ways all
// four are supposed to fail. Runs `grail` in .work/pkg-tests with a store of its own, over
// file:// git repositories and a local index repository it builds itself, so no network is used.
import { existsSync, mkdirSync, readFileSync, writeFileSync, rmSync, readdirSync, copyFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { root, buildCompiler } from './native.mjs';

// One summary line either way, so the suite is usable standalone and from a gate: the assertion
// that failed has already named itself on stderr.
process.on('exit', (code) => {
  if (code !== 0) console.log('FAIL');
});

const grail = buildCompiler();
const work = join(root, '.work/pkg-tests');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const store = join(work, 'store');
let checks = 0;
const ok = (condition, message) => { assert.ok(condition, message); checks++; };

// Every invocation gets its own store, so a stale cache can never make a check pass.
const run = (args, cwd = work, expect = 0, extraEnv = {}) => {
  const env = { ...process.env, GRAIL_PKG_STORE: store, ...extraEnv };
  delete env.GRAIL_REGISTRY;
  const r = spawnSync(grail, args, { cwd, encoding: 'utf8', timeout: 600_000, env });
  const text = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  if (expect !== null) assert.equal(r.status, expect, `grail ${args.join(' ')} in ${cwd}: expected exit ${expect}\n${text}`);
  return { ...r, text };
};
const git = (args, cwd) => {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8' });
  assert.equal(r.status, 0, `git ${args.join(' ')}: ${r.stdout}${r.stderr}`);
  return r.stdout.trim();
};
const mkdirs = (dir) => mkdirSync(dir, { recursive: true });
const write = (path, text) => { mkdirs(join(path, '..')); writeFileSync(path, text); };

// A package: a manifest and a module.
const makePackage = (dir, name, version, source) => {
  mkdirs(join(dir, 'src'));
  writeFileSync(join(dir, 'grail.toml'), `[package]\nname = "${name}"\nversion = "${version}"\n`);
  writeFileSync(join(dir, 'src', `${name}.grl`), source);
  return dir;
};
const lockOf = (project) => readFileSync(join(project, 'grail.lock'), 'utf8');

// 1. New project, no dependencies: it builds without a lockfile, because there is nothing to lock.
{
  run(['new', 'demo']);
  const demo = join(work, 'demo');
  ok(/^\[package\]\nname = "demo"\nversion = "0\.1\.0"\n$/.test(readFileSync(join(demo, 'grail.toml'), 'utf8')), 'grail new writes a grail.toml');
  ok(!existsSync(join(demo, 'grail.lock')), 'a fresh project has no lockfile');
  ok(!existsSync(join(demo, 'grail.pkg')), 'the old grail.pkg format is gone');
  assert.equal(run(['run'], demo).stdout.trim(), 'Hello, world!');
  checks++;
}

// 2. A path dependency: add, lock, build, run and tree.
const libs = join(work, 'libs');
makePackage(join(libs, 'mathlib'), 'mathlib', '0.2.0', 'module mathlib;\npub fn triple(x: u64) -> u64 {\n    return x * 3;\n}\n');
const demo = join(work, 'demo');
{
  const added = run(['add', '--path', '../libs/mathlib'], demo);
  ok(/added mathlib 0\.2\.0/.test(added.text), 'grail add --path reports what it added');
  const manifest = readFileSync(join(demo, 'grail.toml'), 'utf8');
  ok(manifest.includes('mathlib = { path = "../libs/mathlib" }'), 'the path dependency is written to grail.toml');
  const lock = lockOf(demo);
  ok(lock.includes('"source": "path"') && lock.includes('"path": "../libs/mathlib"'), 'the lock records the path source');
  ok(!lock.includes(work), 'the lockfile holds no absolute paths');
  writeFileSync(join(demo, 'src/main.grl'), 'use mathlib;\nfn main() {\n    println(mathlib::triple(14));\n}\n');
  assert.equal(run(['run'], demo).stdout.trim(), '42', 'a program using a path dependency runs');
  checks++;
  const tree = run(['tree'], demo).stdout;
  ok(/^demo 0\.1\.0\n  mathlib 0\.2\.0 \(path \.\.\/libs\/mathlib\)\n$/.test(tree), `grail tree prints the graph: ${JSON.stringify(tree)}`);
}

// 3. A git dependency against a local bare repository, pinned by tag.
const marksRemote = join(work, 'git/marks.git');
{
  const source = makePackage(join(work, 'git/marks-src'), 'marks', '2.0.0', 'module marks;\npub fn tag() -> u64 {\n    return 7;\n}\n');
  git(['init', '-q', '.'], source);
  git(['add', '-A'], source);
  git(['-c', 'user.email=test@example', '-c', 'user.name=test', 'commit', '-qm', 'one'], source);
  git(['tag', 'v2.0.0'], source);
  mkdirs(join(work, 'git'));
  git(['clone', '-q', '--bare', source, marksRemote], work);

  const added = run(['add', '--git', `file://${marksRemote}`, '--tag', 'v2.0.0'], demo);
  ok(/added marks 2\.0\.0/.test(added.text), 'grail add --git reports the package it found in the repository');
  const manifest = readFileSync(join(demo, 'grail.toml'), 'utf8');
  ok(/marks = \{ git = "file:\/\/.*marks\.git", rev = "[0-9a-f]{40}" \}/.test(manifest), 'a tag is locked to the commit it named');
  const lock = lockOf(demo);
  ok(/"source": "git"/.test(lock) && /"url": "file:\/\//.test(lock), 'the lock records the git source and its URL');
  ok(/"checksum": "[0-9a-f]{64}"/.test(lock), 'the lock records the checksum of the unpacked tree');
  writeFileSync(
    join(demo, 'src/main.grl'),
    'use marks;\nuse mathlib;\nfn main() {\n    println(marks::tag() + mathlib::triple(1));\n}\n',
  );
  assert.equal(run(['run'], demo).stdout.trim(), '10', 'a program using a git dependency runs');
  checks++;
  ok(readdirSync(join(store, 'git')).length === 1, 'the clone lives in the store, not in the project');
}

// 4. Two resolutions of the same manifest produce byte-identical lockfiles, and so does a
// resolution with an empty store: nothing machine-specific reaches the file.
{
  const before = lockOf(demo);
  run(['update'], demo);
  ok(lockOf(demo) === before, 'grail update rewrites the same bytes for the same resolution');
  rmSync(store, { recursive: true, force: true });
  run(['update'], demo);
  ok(lockOf(demo) === before, 'a resolution from an empty store produces the same lockfile');
}

// 5. The registry: a static git index, per-package files, tarball URLs from config.json.
const indexDir = join(work, 'index');
const distDir = join(work, 'dist');
{
  const stage = join(work, 'stage');
  makePackage(join(stage, 'logging-1.0.0'), 'logging', '1.0.0', 'module logging;\npub fn level() -> u64 {\n    return 1;\n}\n');
  makePackage(
    join(stage, 'logging-1.1.0'),
    'logging',
    '1.1.0',
    'module logging;\npub fn level() -> u64 {\n    return 2;\n}\n',
  );
  mkdirs(distDir);
  for (const version of ['1.0.0', '1.1.0']) {
    const tar = spawnSync('tar', ['-czf', join(distDir, `logging-${version}.tar.gz`), '-C', stage, `logging-${version}`], { encoding: 'utf8' });
    assert.equal(tar.status, 0, `tar: ${tar.stderr}`);
  }
  const sha = (file) => spawnSync('sha256sum', [file], { encoding: 'utf8' }).stdout.trim().split(' ')[0];
  const line = (version) =>
    JSON.stringify({ name: 'logging', vers: version, deps: [], cksum: sha(join(distDir, `logging-${version}.tar.gz`)) });
  mkdirs(indexDir);
  writeFileSync(join(indexDir, 'config.json'), `${JSON.stringify({ dl: `file://${distDir}/{name}-{version}.tar.gz` })}\n`);
  writeFileSync(join(indexDir, 'logging'), `${line('1.0.0')}\n${line('1.1.0')}\n`);
  git(['init', '-q', '.'], indexDir);
  git(['add', '-A'], indexDir);
  git(['-c', 'user.email=test@example', '-c', 'user.name=test', 'commit', '-qm', 'index'], indexDir);

  const withRegistry = join(work, 'with-registry');
  mkdirs(join(withRegistry, 'src'));
  writeFileSync(
    join(withRegistry, 'grail.toml'),
    `[package]\nname = "with-registry"\nversion = "0.1.0"\n\n[registry]\nindex = "file://${indexDir}"\n`,
  );
  writeFileSync(join(withRegistry, 'src/main.grl'), 'fn main() {\n    println(1);\n}\n');
  const added = run(['add', 'logging'], withRegistry);
  ok(/added logging 1\.1\.0/.test(added.text), 'grail add picks the highest version that satisfies');
  ok(readFileSync(join(withRegistry, 'grail.toml'), 'utf8').includes('logging = "1.1.0"'), 'the chosen version is written to the manifest');
  const lock = lockOf(withRegistry);
  ok(/"source": "registry"/.test(lock) && /"tarball": "[0-9a-f]{64}"/.test(lock), 'the lock records the archive checksum as well as the tree');
  writeFileSync(join(withRegistry, 'src/main.grl'), 'use logging;\nfn main() {\n    println(logging::level());\n}\n');
  assert.equal(run(['run'], withRegistry).stdout.trim(), '2', 'a program using a registry package runs');
  checks++;
  ok(existsSync(join(store, 'tar')), 'the archive is cached in the store');
}

// 6. A version conflict names both requirements and both requirers.
{
  const stage = join(work, 'conflict-stage');
  const conflictIndex = join(work, 'conflict-index');
  const conflictDist = join(work, 'conflict-dist');
  mkdirs(conflictDist);
  const sha = (file) => spawnSync('sha256sum', [file], { encoding: 'utf8' }).stdout.trim().split(' ')[0];
  const publish = (name, version, deps) => {
    const dir = join(stage, `${name}-${version}`);
    makePackage(dir, name, version, `module ${name};\npub fn v() -> u64 {\n    return 1;\n}\n`);
    const tar = spawnSync('tar', ['-czf', join(conflictDist, `${name}-${version}.tar.gz`), '-C', stage, `${name}-${version}`], { encoding: 'utf8' });
    assert.equal(tar.status, 0, `tar: ${tar.stderr}`);
    const line = JSON.stringify({ name, vers: version, deps, cksum: sha(join(conflictDist, `${name}-${version}.tar.gz`)) });
    const file = join(conflictIndex, name);
    writeFileSync(file, existsSync(file) ? `${readFileSync(file, 'utf8')}${line}\n` : `${line}\n`);
  };
  mkdirs(conflictIndex);
  writeFileSync(join(conflictIndex, 'config.json'), `${JSON.stringify({ dl: `file://${conflictDist}/{name}-{version}.tar.gz` })}\n`);
  publish('aaa', '1.0.0', [{ name: 'log', req: '^1.0' }]);
  publish('bbb', '1.0.0', [{ name: 'log', req: '^2.0' }]);
  publish('log', '1.0.0', []);
  publish('log', '2.0.0', []);
  git(['init', '-q', '.'], conflictIndex);
  git(['add', '-A'], conflictIndex);
  git(['-c', 'user.email=test@example', '-c', 'user.name=test', 'commit', '-qm', 'index'], conflictIndex);

  const project = join(work, 'conflict');
  mkdirs(join(project, 'src'));
  writeFileSync(
    join(project, 'grail.toml'),
    `[package]\nname = "conflict"\nversion = "0.1.0"\n\n[registry]\nindex = "file://${conflictIndex}"\n\n[dependencies]\naaa = "1.0"\nbbb = "1.0"\n`,
  );
  writeFileSync(join(project, 'src/main.grl'), 'fn main() {\n    println(0);\n}\n');
  const failed = run(['update'], project, 1);
  ok(/no version of log satisfies all requirements/.test(failed.text), `the conflict is diagnosed: ${failed.text}`);
  ok(/\^1\.0 \(from aaa 1\.0\.0\)/.test(failed.text) && /\^2\.0 \(from bbb 1\.0\.0\)/.test(failed.text), 'both requirements and both requirers are named');
  ok(!existsSync(join(project, 'grail.lock')), 'a failed resolution writes no lockfile');
}

// 7. Offline mode: a build never networks, `fetch --offline` reports what it cannot do.
{
  run(['fetch', '--offline'], demo);
  checks++;
  const brokenRemote = join(work, 'elsewhere');
  mkdirs(brokenRemote);
  // The remote is gone and the store is empty: only this can force the network.
  rmSync(store, { recursive: true, force: true });
  const offline = run(['fetch', '--offline'], demo, 1);
  ok(/offline/.test(offline.text) && /network/.test(offline.text), `offline says what needs the network: ${offline.text}`);
  const needsNetwork = run(['fetch'], demo, 0);
  ok(/fetched/.test(needsNetwork.text), 'plain fetch fills the store again');
  // With the store filled, a build works even though the remotes are unreachable: it never networks.
  rmSync(marksRemote, { recursive: true, force: true });
  ok(existsSync(join(store, 'git')), 'the git clone stayed in the store');
  assert.equal(run(['run', '--offline'], demo).stdout.trim(), '10', 'an offline build reuses the store');
  checks++;
}

// 8. A stale lock is refused by the build; the manifest and the lock must agree.
{
  const manifest = readFileSync(join(demo, 'grail.toml'), 'utf8');
  writeFileSync(join(demo, 'grail.toml'), manifest.replace('mathlib = { path = "../libs/mathlib" }', 'mathlib = { path = "../libs/mathlib" }\nmissing = "1.0"'));
  const stale = run(['build'], join(work, 'demo'), 1);
  ok(/missing/.test(stale.text) && /grail update/.test(stale.text), `a stale lock is refused: ${stale.text}`);
  writeFileSync(join(demo, 'grail.toml'), manifest);
  run(['build'], demo);
  checks++;
}

// 9. `grl-version` is checked before anything else.
{
  const manifest = readFileSync(join(demo, 'grail.toml'), 'utf8');
  writeFileSync(join(demo, 'grail.toml'), manifest.replace('version = "0.1.0"', 'version = "0.1.0"\ngrl-version = ">=9"'));
  const refused = run(['build'], demo, 1);
  ok(/needs grail/.test(refused.text) && /0\.1\.0/.test(refused.text), `grl-version is checked: ${refused.text}`);
  writeFileSync(join(demo, 'grail.toml'), manifest);
  run(['build'], demo);
  checks++;
}

// 10. A tree that no longer matches its checksum is refused, not compiled.
{
  const lock = lockOf(demo);
  const gitNode = JSON.parse(lock).packages.find((p) => p.source === 'git');
  const rev = gitNode.rev.slice(0, 12);
  const tree = join(store, 'src', `git-${rev}`, 'src', 'marks.grl');
  ok(existsSync(tree), 'the git package is unpacked in the store');
  writeFileSync(tree, 'module marks;\npub fn tag() -> u64 {\n    return 99;\n}\n');
  const refused = run(['build'], demo, 1);
  ok(/checksum mismatch for marks/.test(refused.text), `a tampered store is refused: ${refused.text}`);
  ok(/grail fetch/.test(refused.text), 'the refusal says how to repair it');
  run(['fetch', '--force'], demo);
  assert.equal(run(['run'], demo).stdout.trim(), '10', 'grail fetch --force repairs the store');
  checks++;
}

// 11. A tarball that does not hash to the index's checksum is dropped and refused.
{
  const indexFile = join(indexDir, 'logging');
  const original = readFileSync(indexFile, 'utf8');
  const lines = original.trim().split('\n').map((line) => JSON.parse(line));
  for (const line of lines) line.cksum = 'f'.repeat(64);
  writeFileSync(indexFile, `${lines.map((line) => JSON.stringify(line)).join('\n')}\n`);
  git(['add', '-A'], indexDir);
  git(['-c', 'user.email=test@example', '-c', 'user.name=test', 'commit', '-qm', 'tampered'], indexDir);
  // `fetch` trusts the lock and verifies the archive against the checksum recorded there; it is
  // `update`, which reads the index, that has to refuse an archive the index lies about.
  const project = join(work, 'with-registry');
  rmSync(store, { recursive: true, force: true });
  const refused = run(['update'], project, 1);
  ok(/checksum mismatch/.test(refused.text), `a tarball that is not what the index says is refused: ${refused.text}`);
  ok(!existsSync(join(store, 'tar', `${'f'.repeat(64)}.tgz`)), 'the archive that failed its checksum was dropped');
  writeFileSync(indexFile, original);
  git(['add', '-A'], indexDir);
  git(['-c', 'user.email=test@example', '-c', 'user.name=test', 'commit', '-qm', 'restored'], indexDir);
  run(['update'], project);
  assert.equal(run(['run'], project).stdout.trim(), '2', 'the restored index resolves, fetches and builds');
  checks++;
}

// 12. remove drops the requirement, its exclusive packages and the store entry's lock lines.
{
  const before = lockOf(demo);
  ok(before.includes('"marks"'), 'marks is in the lock before removal');
  run(['remove', 'marks'], demo);
  const manifest = readFileSync(join(demo, 'grail.toml'), 'utf8');
  ok(!manifest.includes('marks'), 'remove takes the line out of grail.toml');
  ok(!lockOf(demo).includes('"marks"'), 'remove re-resolves, so marks leaves the lock');
  const refused = run(['remove', 'marks'], demo, 1);
  ok(/is not a dependency/.test(refused.text), 'removing an absent dependency is an error');
  writeFileSync(join(demo, 'src/main.grl'), 'use mathlib;\nfn main() {\n    println(mathlib::triple(14));\n}\n');
  assert.equal(run(['run'], demo).stdout.trim(), '42', 'the project still builds after remove');
  checks++;
}

// 13. Two packages that define the same module are refused before the compiler sees them.
{
  const project = join(work, 'dup');
  makePackage(join(work, 'dup-libs', 'one'), 'one', '1.0.0', 'module shared;\npub fn a() -> u64 {\n    return 1;\n}\n');
  makePackage(join(work, 'dup-libs', 'two'), 'two', '1.0.0', 'module shared;\npub fn b() -> u64 {\n    return 2;\n}\n');
  mkdirs(join(project, 'src'));
  writeFileSync(
    join(project, 'grail.toml'),
    `[package]\nname = "dup"\nversion = "0.1.0"\n\n[dependencies]\none = { path = "../dup-libs/one" }\ntwo = { path = "../dup-libs/two" }\n`,
  );
  writeFileSync(join(project, 'src/main.grl'), 'fn main() {\n    println(0);\n}\n');
  run(['update'], project);
  const refused = run(['build'], project, 1);
  ok(/module <shared> is defined twice/.test(refused.text), `a duplicate module name is refused: ${refused.text}`);
}

// 14. `grail add` on a package that is already there refuses instead of rewriting.
{
  const refused = run(['add', '--path', '../libs/mathlib'], demo, 1);
  ok(/already a dependency/.test(refused.text), 'adding an existing dependency is an error');
}

// 15. dev-dependencies are locked, marked, and seen by `grail test` only.
{
  const project = join(work, 'devtest');
  makePackage(join(work, 'dev-libs', 'kit'), 'kit', '0.1.0', 'module kit;\npub fn answer() -> u64 {\n    return 41;\n}\n');
  mkdirs(join(project, 'src'));
  mkdirs(join(project, 'tests'));
  writeFileSync(
    join(project, 'grail.toml'),
    '[package]\nname = "devtest"\nversion = "0.1.0"\n\n[dev-dependencies]\nkit = { path = "../dev-libs/kit" }\n',
  );
  writeFileSync(join(project, 'src/main.grl'), 'fn main() {\n    println(1);\n}\n');
  writeFileSync(join(project, 'tests/smoke.grl'), 'use kit;\nfn main() {\n    assert(kit::answer() + 1 == 42);\n}\n');
  run(['update'], project);
  const node = JSON.parse(lockOf(project)).packages.find((p) => p.name === 'kit');
  ok(node.dev === true, 'a package only the root dev-depends on is marked dev in the lock');
  ok(run(['build'], project).status === 0, 'a plain build does not need the dev-dependency');
  ok(/1 passed, 0 failed/.test(run(['test'], project).stdout), 'grail test sees the dev-dependency');
  checks++;
}

console.log(`pkg: ${checks} package-manager checks passed`);
console.log('ok');
