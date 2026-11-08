import { readFileSync, writeFileSync, mkdirSync, renameSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { gzipSync, gunzipSync } from 'node:zlib';
import assert from 'node:assert/strict';
import { root, compilerSources, targets, hostTarget, targetName, buildCompiler, assemble, command, execute } from './native.mjs';
const directory = join(root, 'compiler/bootstrap');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
function assembly(target) {
  const path = join(directory, target === 'x86_64' ? 'native.s' : `${target}.s.gz`);
  const bytes = readFileSync(path);
  return path.endsWith('.gz') ? gunzipSync(bytes) : bytes;
}
const sourceDigests = () => Object.fromEntries(compilerSources.map(p => [p.slice(root.length + 1), sha(readFileSync(p))]));
function manifest(sources = sourceDigests()) {
  const targetEntries = {};
  for (const target of targets) {
    const file = target === 'x86_64' ? 'native.s' : `${target}.s.gz`;
    if (existsSync(join(directory, file))) targetEntries[target] = { file, sha256: sha(assembly(target)) };
  }
  return { schema: 1, sources, targets: targetEntries };
}
const mode = process.argv[2] ?? 'verify';
if (!['verify', 'update'].includes(mode)) throw new Error('usage: bun tools/bootstrap.mjs verify|update [ARCH|all]');
const selected = process.argv[3] === 'all' ? targets : [targetName(process.argv[3] ?? hostTarget)];
const sources = sourceDigests();
if (mode === 'update' && selected.length !== targets.length) {
  const recorded = JSON.parse(readFileSync(join(directory, 'manifest.json'), 'utf8'));
  assert.deepEqual(recorded.sources, sources, 'Compiler source changes require update all to preserve shared provenance');
}
const staged = [];
const compiler = buildCompiler();
for (const target of selected) {
  const work = join(root, '.work/bootstrap', target);
  mkdirSync(work, { recursive: true });
  const first = join(work, 'compiler.s'), second = join(work, 'self.s');
  command([compiler, '--default-u64', '--target', target, first, ...compilerSources]);
  const executable = assemble(first, join(work, 'compiler'), target);
  // Emulated self-compilation of the whole compiler can take close to an hour (notably RV64 under qemu).
  const result = execute(executable, ['--default-u64', '--target', target, second, ...compilerSources], target, { timeout: Number(process.env.GRAIL_BOOTSTRAP_TIMEOUT_MS ?? 7_200_000) });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, `${target}: compiler execution failed (${result.signal})\n${result.stdout}${result.stderr}`);
  const expected = readFileSync(first);
  assert.deepEqual(readFileSync(second), expected, `${target}: self-hosted assembly differs`);
  const file = join(directory, target === 'x86_64' ? 'native.s' : `${target}.s.gz`);
  if (mode === 'verify') assert.deepEqual(assembly(target), expected, `${target}: checked-in bootstrap is stale`);
  else staged.push({ file, bytes: target === 'x86_64' ? expected : gzipSync(expected, { level: 9 }) });
  assert.deepEqual(sourceDigests(), sources, 'Compiler sources changed during verification; no bootstraps published');
  console.log(`${target}: direct self-hosting and assembly identity verified`);
}
assert.deepEqual(sourceDigests(), sources, 'Compiler sources changed during verification; no bootstraps published');
if (mode === 'update') {
  for (const { file, bytes } of staged) writeFileSync(`${file}.pending`, bytes);
  for (const { file } of staged) renameSync(`${file}.pending`, file);
  writeFileSync(join(directory, 'manifest.json'), `${JSON.stringify(manifest(sources), null, 2)}\n`);
}
else {
  const recorded = JSON.parse(readFileSync(join(directory, 'manifest.json'), 'utf8'));
  const actual = manifest();
  assert.deepEqual(recorded.sources, actual.sources, 'bootstrap source manifest is stale');
  for (const target of selected) assert.deepEqual(recorded.targets[target], actual.targets[target], `${target}: bootstrap digest differs`);
}
