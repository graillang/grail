import { readFileSync, writeFileSync, mkdirSync, renameSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import {
  root, compilerSources, targets, hostTarget, targetName, buildCompiler, assemble, command, execute,
  digest, compressSeed, seedDirectory, seedFile, seedManifest, seedAssemblyPath, readSeedManifest,
  compilerEnvironment,
} from './native.mjs';
const sha = digest;
const sourceDigests = () => Object.fromEntries(compilerSources.map(p => [p.slice(root.length + 1), sha(readFileSync(p))]));
const mode = process.argv[2] ?? 'verify';
// `stage ARCH` verifies one target and parks its seed under .work, keyed by the compiler sources;
// `publish` installs every target's parked seed and the manifest, but only when all of them were
// built from the current sources. A reseed split this way survives an interruption one target at a
// time (tools/gate.sh), where `update all` is a single step of up to an hour and a half.
if (!['verify', 'update', 'stage', 'publish'].includes(mode)) throw new Error('usage: bun tools/bootstrap.mjs verify|update [ARCH|all] | stage ARCH | publish');
const selected = mode === 'publish' ? [] : process.argv[3] === 'all' ? targets : [targetName(process.argv[3] ?? hostTarget)];
const sources = sourceDigests();
const sourcesKey = sha(Buffer.from(JSON.stringify(sources))).slice(0, 16);
const parked = target => join(root, '.work/bootstrap/staged', `${target}.${sourcesKey}.seed`);
if (mode === 'publish') {
  for (const target of targets) assert.ok(existsSync(parked(target)), `${target}: no seed staged for the current compiler sources (bun tools/bootstrap.mjs stage ${target})`);
  for (const target of targets) writeFileSync(`${join(seedDirectory, seedFile(target))}.pending`, readFileSync(parked(target)));
  for (const target of targets) renameSync(`${join(seedDirectory, seedFile(target))}.pending`, join(seedDirectory, seedFile(target)));
  writeFileSync(join(seedDirectory, 'manifest.json'), `${JSON.stringify(seedManifest(sources), null, 2)}\n`);
  console.log(`published ${targets.length} staged seeds`);
  process.exit(0);
}
if (mode === 'update' && selected.length !== targets.length) {
  const recorded = readSeedManifest();
  assert.deepEqual(recorded.sources, sources, 'Compiler source changes require update all to preserve shared provenance');
}
const staged = [];
const compiler = buildCompiler();
for (const target of selected) {
  const work = join(root, '.work/bootstrap', target);
  mkdirSync(work, { recursive: true });
  const first = join(work, 'compiler.s'), second = join(work, 'self.s');
  command([compiler, '--target', target, first, ...compilerSources], { env: compilerEnvironment() });
  const executable = assemble(first, join(work, 'compiler'), target);
  // Emulated self-compilation of the whole compiler can take close to an hour (notably RV64 under qemu).
  const result = execute(executable, ['--target', target, second, ...compilerSources], target, { timeout: Number(process.env.GRAIL_BOOTSTRAP_TIMEOUT_MS ?? 7_200_000), env: compilerEnvironment() });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, `${target}: compiler execution failed (${result.signal})\n${result.stdout}${result.stderr}`);
  const expected = readFileSync(first);
  assert.deepEqual(readFileSync(second), expected, `${target}: self-hosted assembly differs`);
  // The seed is published compressed; `verify` decompresses the checked-in file (and holds it to the
  // manifest's digests) before comparing, so a reseed cannot silently change what a clone builds.
  if (mode === 'verify') assert.deepEqual(readFileSync(seedAssemblyPath(target)), expected, `${target}: checked-in bootstrap is stale`);
  else if (mode === 'stage') {
    mkdirSync(join(root, '.work/bootstrap/staged'), { recursive: true });
    writeFileSync(`${parked(target)}.pending`, compressSeed(expected));
    renameSync(`${parked(target)}.pending`, parked(target));
  }
  else staged.push({ file: join(seedDirectory, seedFile(target)), bytes: compressSeed(expected) });
  assert.deepEqual(sourceDigests(), sources, 'Compiler sources changed during verification; no bootstraps published');
  console.log(`${target}: direct self-hosting and assembly identity verified`);
}
assert.deepEqual(sourceDigests(), sources, 'Compiler sources changed during verification; no bootstraps published');
if (mode === 'update') {
  for (const { file, bytes } of staged) writeFileSync(`${file}.pending`, bytes);
  for (const { file } of staged) renameSync(`${file}.pending`, file);
  writeFileSync(join(seedDirectory, 'manifest.json'), `${JSON.stringify(seedManifest(sources), null, 2)}\n`);
}
else if (mode === 'verify') {
  // `verify` is held to what is published; `stage` must not be, because the whole reason it exists is
  // to park a seed for sources the manifest does not describe yet.
  const recorded = readSeedManifest();
  const actual = seedManifest(sources);
  assert.deepEqual(recorded.sources, actual.sources, 'bootstrap source manifest is stale');
  for (const target of selected) assert.deepEqual(recorded.targets[target], actual.targets[target], `${target}: bootstrap digest differs`);
}
