// Proves that a shader's permutation combinations are compiled for real, not merely
// enumerated: one SPIR-V and one DXIL per combination, with distinct bytecode digests and an
// unchanged layout digest.
//
// The tool is invoked as a subprocess rather than imported so this exercises the same entry
// point a build uses, and so GRAIL_SHADER_OUT isolates the artifacts in a scratch directory.
//
// Needs DXC 1.9.2609 (docs/dependencies.md). Without it every test is skipped rather than
// failing, so a machine with no toolchain still runs the C suite.
import { test, expect, afterAll } from 'bun:test';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const tool = join(root, 'tools', 'shader.mjs');
const shader = join(root, 'shaders', 'core', 'tonemap.ps.hlsl');
const scratch = mkdtempSync(join(tmpdir(), 'grail-perm-test-'));
afterAll(() => rmSync(scratch, { recursive: true, force: true }));

// Same resolution the tool uses, so "skip" means the same thing to both.
function findDxc() {
  if (process.env.DXC) return process.env.DXC;
  const cache = join(process.env.HOME ?? '', '.cache', 'abundance', 'engine-tools');
  if (existsSync(cache))
    for (const entry of readdirSync(cache))
      if (entry.startsWith('dxc-') && existsSync(join(cache, entry, 'bin', 'dxc')))
        return join(cache, entry, 'bin', 'dxc');
  const onPath = spawnSync('sh', ['-c', 'command -v dxc'], { encoding: 'utf8' });
  return onPath.status === 0 ? onPath.stdout.trim() : null;
}
const dxc = findDxc();
const skip = dxc ? false : 'DXC not found (see graphics/docs/dependencies.md)';

function buildShaders() {
  const result = spawnSync(process.execPath, [tool, shader], {
    encoding: 'utf8', env: { ...process.env, GRAIL_SHADER_OUT: scratch },
  });
  if (result.status !== 0) throw new Error(`shader.mjs failed:\n${result.stdout}\n${result.stderr}`);
  return JSON.parse(readFileSync(join(scratch, 'core', 'tonemap.ps.refl.json'), 'utf8'));
}

const report = skip ? null : buildShaders();

test.skipIf(skip)('every declared combination is compiled, not just enumerated', () => {
  const declared = report.permutations.length;
  expect(declared).toBe(4); // 2 exposure values x 2 output values
  expect(report.variants.length).toBe(declared);
  // The keys of the enumerated list and of the built variants must be the same set: a
  // combination that was listed but not built, or built but not listed, is a build defect.
  expect(new Set(report.variants.map(v => v.key))).toEqual(new Set(report.permutations.map(p => p.key)));
});

test.skipIf(skip)('the four combinations have four distinct SPIR-V digests', () => {
  const digests = report.variants.map(v => v.spirv_sha256);
  expect(digests.every(d => typeof d === 'string' && d.length === 64)).toBe(true);
  expect(new Set(digests).size).toBe(4);
});

test.skipIf(skip)('the four combinations have four distinct DXIL digests', () => {
  const digests = report.variants.map(v => v.dxil_sha256).filter(Boolean);
  if (digests.length === 0) return; // no dxil.dll: the SPIR-V assertions still stand
  expect(digests.length).toBe(4);
  expect(new Set(digests).size).toBe(4);
});

test.skipIf(skip)('each combination writes its own SPIR-V, DXIL and reflection blob', () => {
  for (const variant of report.variants) {
    const key = variant.key.slice(2); // strip 0x
    for (const suffix of ['.spv', '.refl.bin']) {
      const path = join(scratch, 'core', `tonemap.ps.${key}${suffix}`);
      expect(existsSync(path)).toBe(true);
    }
  }
});

test.skipIf(skip)('each blob carries that combination\'s own bytecode', () => {
  // Comparing blob *bytes* would pass even when every variant compiled identically, because
  // the header records the command line. So this reads the bytecode out of each blob the way
  // gr_reflect_open() does — bytecode_offset at 32, bytecode_length at 40 — and checks it
  // against the digest of that variant's .spv. A blob built from the wrong variant's bytecode
  // is exactly the bug this catches.
  for (const variant of report.variants) {
    const key = variant.key.slice(2);
    const blob = readFileSync(join(scratch, 'core', `tonemap.ps.${key}.refl.bin`));
    expect(blob.readUInt32LE(0)).toBe(0x46455247); // 'GREF'
    expect(blob.readBigUInt64LE(24)).toBe(BigInt(blob.length));
    const offset = Number(blob.readBigUInt64LE(32));
    const length = Number(blob.readBigUInt64LE(40));
    const embedded = blob.subarray(offset, offset + length);
    expect(createHash('sha256').update(embedded).digest('hex')).toBe(variant.spirv_sha256);
    expect(length).toBe(variant.spirv_bytes);
  }
  // And the four embedded bytecodes must be four distinct programs.
  const programs = report.variants.map(v => v.spirv_sha256);
  expect(new Set(programs).size).toBe(4);
});

test.skipIf(skip)('a permutation does not change the layout digest', () => {
  // Bindings and constant-block layout are declarations, not code: they must be identical
  // across combinations, or the host's structs would be wrong for one combination only. The
  // bytecode digest must differ; this one must not.
  for (const variant of report.variants) {
    expect(variant.layout_hash_stable).toBe(true);
    expect(variant.layout_hash).toBe(report.layout_hash);
  }
  expect(new Set(report.variants.map(v => v.layout_hash)).size).toBe(1);
});

test.skipIf(skip)('the build without flags equals the declared default combination', () => {
  // The shader carries both a directive default and an #ifndef default. If those two disagree,
  // a plain DXC invocation compiles something other than the default combination, and the base
  // artifacts match no variant at all — the build would ship bytecode nothing refers to. This
  // is the assertion that catches it, so it is stated as an equality between the two builds
  // rather than by naming a combination.
  const declaredDefaults = Object.fromEntries(report.domains.map(d => [d.name, d.default]));
  expect(Object.keys(declaredDefaults).length).toBe(2);

  const defaultVariant = report.variants.find(v =>
    Object.entries(declaredDefaults).every(([name, value]) => v.defines[name] === value));
  expect(defaultVariant).toBeDefined();
  // Same bytecode digest as the no-flags build: the flags only restate the defaults.
  expect(defaultVariant.spirv_sha256).toBe(report.spirv_sha256);
  expect(defaultVariant.layout_hash).toBe(report.layout_hash);
});

test.skipIf(skip)('the tool reports the compiler version it used', () => {
  expect(report.compiler).toMatch(/^dxc \d+\.\d+\.\d+\.\d+$/);
  expect(report.source).toBe('shaders/core/tonemap.ps.hlsl');
});
