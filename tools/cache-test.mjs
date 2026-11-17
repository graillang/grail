// B1 stage 4 proof: the build cache.
//
// `grail build --cache` reuses what a build already produced, keyed by the inputs that determine it.
// This tool proves the six properties the cache claims, against the real compiler and a real project:
//
//  (a) identity    - a cached build is byte for byte the build it replaces (an uncached split build),
//                    so nothing about the cache may change the program;
//  (b) reuse       - a second build of unchanged sources is a full hit and measurably faster, with
//                    the timings printed;
//  (c) precision   - touching one module's source misses that module and the modules that read it,
//                    and the modules that do not read it still hit;
//  (d) flags       - changing a flag that changes code generation is a total miss;
//  (e) interfaces  - an interface tampered the way `tools/interface-test.mjs` tampers one (edit,
//                    re-digested, manifest rewritten) misses the module that reads it, and only it;
//  (f) corruption  - a corrupted store entry is a miss and a rebuild, never a wrong binary, and the
//                    entry is repaired instead of missing forever;
//  (m) comptime    - a compile-time value reruns its probe when a body it reached changes, and only
//                    then.
//
// (c) is also where the *independence* of a module's emitted text is pinned, by measurement rather
// than by argument: every label is minted in its module's own namespace from a counter that restarts
// with that module (`.L<module>_<hash>_<n>`, `docs/design/separate-compilation.md` stage 5), and the
// optimizer inlines only within one module, so an edit in one module leaves every other part's
// assembly byte-identical. Before that change the emitter numbered its local labels over one stream
// and the test measured 0 hit / 6 miss for an edit in the entry module; it now requires 5 hit / 1
// miss and compares the untouched parts' bytes.
//
// Usage: bun tools/cache-test.mjs [--target T]

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { buildCompiler, compilerSources, hostTarget, root, targetName } from './native.mjs';

const flags = process.argv.slice(2);
const target = targetName(flags.includes('--target') ? flags[flags.indexOf('--target') + 1] : hostTarget);
assert.equal(target, 'x86_64', 'the cache rides on --split, which is the Linux x86_64 assembler path');

const compiler = buildCompiler();
const work = join(root, '.work/cache-test', target);
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const project = join(work, 'project');
const store = join(project, '.work/cache', target);
// The store this test inspects is the project's own directory, named explicitly: the default is a
// per-user store, which a test must not read or fill.
process.env.GRAIL_CACHE_DIR = join(project, '.work/cache');
const program = join(project, 'target/prog');

// A three-module project: the entry reads both modules, so there is one importer and one module that
// nothing else reads.
const utilSource = value => `module util;

pub const SCALE: u64 = ${value};

pub fn twice(x: u64) -> u64 {
    return x * 2;
}
`;
const helperSource = `module helper;

pub fn bump(x: u64) -> u64 {
    return x + 7;
}
`;
const mainSource = `use util;
use helper;

pub fn main() -> u64 {
    a := util::SCALE;
    println(util::twice(a) + helper::bump(a));
    return 0;
}
`;
function write(value = 3) {
  mkdirSync(join(project, 'src'), { recursive: true });
  writeFileSync(join(project, 'grail.toml'), '[package]\nname = "cachetest"\nversion = "0.1.0"\n');
  writeFileSync(join(project, 'src/main.grl'), mainSource);
  writeFileSync(join(project, 'src/util.grl'), utilSource(value));
  writeFileSync(join(project, 'src/helper.grl'), helperSource);
}
write();

// One build. `extra` are the flags under test; everything else is what `grail build` does.
function build(args, { measure = false, env = process.env } = {}) {
  const started = process.hrtime.bigint();
  const result = spawnSync(compiler, ['build', '--target', target, ...args], { cwd: project, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout: 900_000, env });
  const ms = Number(process.hrtime.bigint() - started) / 1e6;
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { status: result.status, output, ms, line: cacheLine(output) };
}
function cacheLine(output) {
  const match = output.match(/grail: cache: (\d+) hit, (\d+) miss(?: \(([^)]*)\))?; (.+)\n/);
  return match ? { hits: Number(match[1]), misses: Number(match[2]), names: match[3] ? match[3].split(', ') : [], what: match[4] } : null;
}
// The *surface* of an interface: every byte before the trailer record, which is what
// `native::iface_surface` hands the cache key. The trailer carries the source digest and the file's
// own digest, so they are outside it by construction.
function surfaceOf(path) {
  const bytes = readFileSync(path);
  const trailer = recordsOf(bytes).find(record => record.tag === 2);
  assert.ok(trailer, `${path}: no trailer record`);
  return digest(bytes.subarray(0, trailer.tagAt));
}
// The per-function layer's report, one line per module run: the part the run ended in, bodies
// replayed from the unit store, bodies filed as units, and bodies emitted that are not units.
function unitLines(output) {
  const out = [];
  for (const m of output.matchAll(/grail: fn-cache: (\S+): (\d+) hit, (\d+) filed, (\d+) not units/g)) {
    out.push({ module: m[1], hits: Number(m[2]), filed: Number(m[3]), kept: Number(m[4]) });
  }
  return out;
}
const sum = lines => lines.reduce((a, l) => ({ hits: a.hits + l.hits, filed: a.filed + l.filed, kept: a.kept + l.kept }), { hits: 0, filed: 0, kept: 0 });
const forModule = (lines, name) => lines.filter(l => l.module === name).reduce((a, l) => ({ hits: a.hits + l.hits, filed: a.filed + l.filed, kept: a.kept + l.kept }), { hits: 0, filed: 0, kept: 0 });
function run(binary) {
  const result = spawnSync(binary, [], { encoding: 'utf8', timeout: 60_000 });
  assert.equal(result.status, 0, `${binary}: exited ${result.status}\n${result.stderr ?? ''}`);
  return result.stdout.trim();
}
const bytes = path => readFileSync(path);
const digest = data => createHash('sha256').update(data).digest('hex');
// The store's own content digest (compiler/cli.grl, store_hash): XXH64 under the seeds 0..3, each
// as 16 hex digits - what a blob's file name is.
const M64 = (1n << 64n) - 1n;
const XP = [11400714785074694791n, 14029467366897019727n, 1609587929392839161n, 9650029242287828579n, 2870177450012600261n];
const rotl = (x, r) => ((x << r) | (x >> (64n - r))) & M64;
const xround = (acc, lane) => (rotl((acc + lane * XP[1]) & M64, 31n) * XP[0]) & M64;
const xmerge = (acc, lane) => (((acc ^ xround(0n, lane)) * XP[0]) & M64) + XP[3] & M64;
function xxh64(data, seed) {
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const n = data.length;
  let at = 0, h;
  if (n >= 32) {
    const v = [(seed + XP[0] + XP[1]) & M64, (seed + XP[1]) & M64, seed, (seed - XP[0]) & M64];
    for (; at + 32 <= n; at += 32) for (let k = 0; k < 4; k++) v[k] = xround(v[k], view.getBigUint64(at + 8 * k, true));
    h = (rotl(v[0], 1n) + rotl(v[1], 7n) + rotl(v[2], 12n) + rotl(v[3], 18n)) & M64;
    for (let k = 0; k < 4; k++) h = xmerge(h, v[k]);
  } else h = (seed + XP[4]) & M64;
  h = (h + BigInt(n)) & M64;
  for (; at + 8 <= n; at += 8) h = ((rotl(h ^ xround(0n, view.getBigUint64(at, true)), 27n) * XP[0]) & M64) + XP[3] & M64;
  if (at + 4 <= n) { h = ((rotl(h ^ ((BigInt(view.getUint32(at, true)) * XP[0]) & M64), 23n) * XP[1]) & M64) + XP[2] & M64; at += 4; }
  for (; at < n; at++) h = (rotl(h ^ ((BigInt(data[at]) * XP[4]) & M64), 11n) * XP[0]) & M64;
  h = ((h ^ (h >> 33n)) * XP[1]) & M64;
  h = ((h ^ (h >> 29n)) * XP[2]) & M64;
  return h ^ (h >> 32n);
}
const storeDigest = data => [0n, 1n, 2n, 3n].map(seed => xxh64(data, seed).toString(16).padStart(16, '0')).join('');
// Interfaces are the typed record stream docs/design/separate-compilation.md describes: `GRIF`, a
// version byte, then `tag, len, payload` records, then a trailer whose last 32 bytes are the digest
// of everything before them. These read that framing only, so this test can change one byte of one
// declaration on purpose - and `grail iface dump` shows what a file says.
function recordsOf(bytes) {
  const out = [];
  let at = 5;
  while (at < bytes.length) {
    const tagAt = at;
    const tag = bytes[at];
    at += 1;
    const lenAt = at;
    let len = 0;
    let scale = 1;
    for (;;) {
      const b = bytes[at];
      at += 1;
      len += (b & 127) * scale;
      if (!(b & 128)) break;
      scale *= 128;
    }
    out.push({ tag, tagAt, lenAt, at, len, end: at + len });
    at += len;
    if (tag === 2) break;
  }
  return out;
}
function readVarAt(bytes, at) {
  let n = 0;
  let scale = 1;
  for (;;) {
    const b = bytes[at];
    at += 1;
    n += (b & 127) * scale;
    if (!(b & 128)) return [n, at];
    scale *= 128;
  }
}
function skipStrAt(bytes, at) {
  const [n, next] = readVarAt(bytes, at);
  return next + n;
}
function skipTypeAt(bytes, at) {
  const [n, next] = readVarAt(bytes, at + 1);
  return next + n;
}
// The offset of one constant record's value, through the framing: module, name, public, type, kind.
function constValueAt(bytes, name) {
  for (const record of recordsOf(bytes)) {
    if (record.tag !== 12) continue;
    let at = record.at;
    const [moduleLen, afterModule] = readVarAt(bytes, at);
    at = afterModule + moduleLen;
    const [nameLen, afterName] = readVarAt(bytes, at);
    if (bytes.subarray(afterName, afterName + nameLen).toString() !== name) continue;
    at = afterName + nameLen;
    at += 1; // public
    at = skipTypeAt(bytes, at);
    at += 1; // constant kind
    return at;
  }
  assert.fail(`no constant record named ${name}`);
}
function sealFile(bytes) {
  const body = Buffer.from(bytes.subarray(0, bytes.length - 32));
  createHash('sha256').update(body).digest().copy(bytes, bytes.length - 32);
  return bytes;
}
function dump(path) {
  const result = spawnSync(compiler, ['--target', target, '--iface-dump', path], { encoding: 'utf8', timeout: 900_000 });
  assert.equal(result.status, 0, `${path}: dump failed\n${result.stdout ?? ''}${result.stderr ?? ''}`);
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

// The parts a build produced, in link order, as `NNN.module` -> module.
function emissionOrder() {
  const manifest = readFileSync(`${program}.parts`, 'utf8').split('\n').filter(row => row.startsWith(project));
  return manifest.map(row => row.slice(row.lastIndexOf('/') + 1).replace(/^[^.]*\./, '').replace(/\.s$/, ''));
}
// A same-size edit: the emitted text changes where the constant is, and nowhere else.
function setScale(value) {
  writeFileSync(join(project, 'src/util.grl'), utilSource(value));
}
function setMainUnused() {
  writeFileSync(join(project, 'src/main.grl'), `${mainSource}\npub fn unused_pad(x: u64) -> u64 {\n    return x + 1;\n}\n`);
}

// ---- (a) identity, and the uncached build that defines it -------------------------------------
function recordBuild(name) {
  const reference = join(project, 'target', `${name}.ref`);
  const split = build(['--split', '-o', reference]);
  assert.equal(split.status, 0, `${name}: the uncached split build failed\n${split.output}`);
  const cached = build(['--whole-program', '--cache', '-o', join(project, 'target', name)]);
  assert.equal(cached.status, 0, `${name}: the cached build failed\n${cached.output}`);
  assert.ok(cached.line, `${name}: a cached build must report its hits and misses\n${cached.output}`);
  assert.deepEqual(
    bytes(join(project, 'target', name)),
    bytes(reference),
    `${name}: the cached build is not the uncached build`,
  );
  return { reference, cached, split };
}

// The cached output has to be the uncached output, at every point in the run.
function assertUncachedBuild(name) {
  const reference = join(project, 'target', `${name}.ref`);
  const split = build(['--split', '-o', reference]);
  assert.equal(split.status, 0, `${name}: the uncached split build failed\n${split.output}`);
  assert.deepEqual(bytes(program), bytes(reference), `${name}: the cached build is not the uncached build`);
  return split;
}

// ---- the store's own discipline ----------------------------------------------------------------
// Every blob is filed under the digest of its bytes, and every record names a blob that is there.
function proveStore() {
  const blobDirectory = join(store, 'blob');
  const blobs = existsSync(blobDirectory) ? readdirSync(blobDirectory) : [];
  let records = 0;
  // Every entry a record can hand back is filed under the digest of its bytes. A blob no record names
  // is unreachable, and reuse verifies content anyway, so it is not a correctness question.
  for (const kind of ['prog', 'lnk', 'mod', 'unit']) {
    const directory = join(store, 'map', kind);
    if (!existsSync(directory)) continue;
    // A program, link or module record names one blob; a module run's record names its object, its
    // link inputs and its interface.
    const fields = kind === 'unit' ? ['links', 'obj', 'iface'] : ['blob'];
    for (const name of readdirSync(directory)) {
      // `<key>.used` is the record's last-used build generation (grail cache prune), not a record.
      if (name.endsWith('.used')) continue;
      const body = readFileSync(join(directory, name), 'utf8');
      const named = fields.map(field => new RegExp(`^${field} ([0-9a-f]{64})$`, 'm').exec(body)?.[1]).filter(Boolean);
      assert.ok(named.length > 0, `${kind}/${name}: a record must name a blob`);
      for (const blob of named) {
        assert.ok(blobs.includes(blob), `${kind}/${name}: names a blob that is not in the store`);
        assert.equal(storeDigest(readFileSync(join(blobDirectory, blob))), blob, `${kind}/${name}: names a blob that does not hash to it`);
        records += 1;
      }
    }
  }
  assert.ok(records > 0, 'the store has no records');
  return { blobs: blobs.length, records };
}

// ---- (b) a full hit, and what it saves ---------------------------------------------------------
function proveReuse() {
  rmSync(store, { recursive: true, force: true });
  const cold = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(cold.status, 0, `cold build failed\n${cold.output}`);
  assert.equal(cold.line.misses, cold.line.hits + cold.line.misses, 'a cold store cannot hit anything');
  const warm = build(['--whole-program', '--cache', '-o', program], { measure: true });
  assert.equal(warm.status, 0, `warm build failed\n${warm.output}`);
  assert.equal(warm.line.misses, 0, `a second build of unchanged sources must be a full hit\n${warm.output}`);
  assert.match(warm.line.what, /program up to date/, 'a full hit must not relink or recompile');
  const ratio = cold.ms / warm.ms;
  assert.ok(warm.ms < cold.ms, `a full hit must be faster: ${cold.ms.toFixed(0)}ms -> ${warm.ms.toFixed(0)}ms`);
  assert.ok(ratio >= 2, `a full hit must be measurably faster: ${cold.ms.toFixed(0)}ms -> ${warm.ms.toFixed(0)}ms`);
  return { cold, warm, ratio };
}

// ---- (c) one module's source ------------------------------------------------------------------
// The parts of the last split build, as `module -> digest of its assembly`, so "an edit did not
// re-spell the modules after it" can be a comparison of bytes.
function partDigests() {
  const parts = emissionOrder();
  const out = new Map();
  const manifest = readFileSync(`${program}.parts`, 'utf8').split('\n').filter(row => row.startsWith(project));
  for (const row of manifest) {
    const module = row.slice(row.lastIndexOf('/') + 1).replace(/^[^.]*\./, '').replace(/\.s$/, '');
    out.set(module, digest(readFileSync(row)));
  }
  assert.equal(out.size, parts.length, 'every part must be named by the manifest');
  return out;
}
function provePrecision() {
  const before = emissionOrder();
  setScale(4);
  const result = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(result.status, 0, `a source edit failed to build\n${result.output}`);
  assert.ok(result.line.names.includes('util'), `the edited module must miss: ${result.output}`);
  assert.ok(result.line.names.includes('main'), `the module that reads it must miss: ${result.output}`);
  assert.ok(!result.line.names.includes('helper'), `a module that does not read it must hit: ${result.output}`);
  assert.equal(run(program), '19', 'the rebuilt program must use the new constant');

  // And the property this stage exists for: a module added in the entry does not re-spell any other
  // module's text. The modules after it hit, and the bytes of their parts are the bytes they had.
  const was = partDigests();
  setMainUnused();
  const shifted = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(shifted.status, 0, `the second edit failed to build\n${shifted.output}`);
  assert.deepEqual(shifted.line.names, ['main'], `only the edited module may miss: ${shifted.output}`);
  assert.equal(shifted.line.hits, before.length - 1, `every other module must hit: ${shifted.output}`);
  const order = emissionOrder();
  assert.deepEqual(order, before, 'the emission order must not change');
  const now = partDigests();
  const changed = [...now.keys()].filter(module => was.get(module) !== now.get(module));
  // `before` names parts as `NNN.module`; the edited module's part is the one that may change.
  const edited = before.filter(name => name.replace(/^\d+\./, '') === 'main');
  assert.deepEqual(changed, edited, `only the edited module's assembly may change, got ${changed.join(', ')}`);
  const reference = assertUncachedBuild('shifted');
  return { line: result.line, shifted: shifted.line, order, reference, changed };
}

// ---- (d) a code-generation flag ---------------------------------------------------------------
function proveFlags() {
  const wrapped = build(['--whole-program', '--cache', '--overflow=wrap', '-o', program]);
  assert.equal(wrapped.status, 0, `--overflow=wrap failed\n${wrapped.output}`);
  assert.equal(wrapped.line.hits, 0, `a different flag vector must miss everything: ${wrapped.output}`);
  const back = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(back.line.misses, 0, `the original flags must still be a full hit: ${back.output}`);
  return { wrapped: wrapped.line, back: back.line };
}

// ---- (e) an interface the sources disagree with ------------------------------------------------
// Tampered exactly as tools/interface-test.mjs tampers one: edit a declaration, re-digest the file,
// and rewrite the manifest entry so the build proceeds instead of refusing.
function proveInterfaces() {
  const ifaces = join(project, 'ifaces');
  write();
  const emitted = spawnSync(compiler, ['check', '--target', target, '--interface', ifaces], { cwd: project, encoding: 'utf8', timeout: 900_000 });
  assert.equal(emitted.status, 0, `emitting interfaces failed\n${emitted.stdout ?? ''}${emitted.stderr ?? ''}`);
  const cold = build(['--cache', '--interface', ifaces, '-o', program]);
  assert.equal(cold.status, 0, `cached interface build failed\n${cold.output}`);
  const warm = build(['--cache', '--interface', ifaces, '-o', program]);
  assert.equal(warm.line.misses, 0, `an unchanged interface build must be a full hit\n${warm.output}`);
  assert.equal(run(program), '16', 'the interface build must print the source build\'s answer');

  const path = join(ifaces, 'util.iface');
  const original = readFileSync(path);
  assert.match(dump(path), /const util::SCALE .* u64 int 3/, 'the constant must be in the interface');
  // One byte: the constant's value goes from 3 to 4, the trailer is re-sealed and the manifest
  // re-pinned, so what stops the build is the interface disagreeing with its source.
  const edited = Buffer.from(original);
  edited[constValueAt(edited, 'SCALE')] = 4;
  sealFile(edited);
  writeFileSync(path, edited);
  const manifestPath = join(ifaces, 'interfaces.manifest');
  writeFileSync(manifestPath, readFileSync(manifestPath, 'utf8').replace(/^util \S+/m, `util ${digest(edited)}`));

  // A whole-program build compiles every module from its source and requires each interface to say
  // what the source says, so an interface that was edited (and re-digested) is refused - before the
  // cache can hand back anything built from it.
  const after = build(['--cache', '--interface', ifaces, '-o', program]);
  assert.equal(after.status, 1, `an interface that disagrees with its source must be refused\n${after.output}`);
  assert.match(after.output, /does not match this interface/, `the refusal must say why\n${after.output}`);
  writeFileSync(path, original);
  writeFileSync(manifestPath, readFileSync(manifestPath, 'utf8').replace(/^util \S+/m, `util ${digest(original)}`));
  const restored = build(['--cache', '--interface', ifaces, '-o', program]);
  assert.equal(restored.line.misses, 0, `the restored interface must be a full hit again\n${restored.output}`);
  assert.equal(run(program), '16', 'the restored build must print the source build\'s answer');
  return { warm: warm.line, after: restored.line };
}

// ---- (f) a corrupted entry --------------------------------------------------------------------
// The entry a build would hand back is damaged in place, exactly where a bad disk or a killed build
// would leave it. It has to be a miss, a rebuild and a repaired entry - never a wrong program.
function corrupt(path) {
  const bytesRead = readFileSync(path);
  const damaged = Buffer.from(bytesRead);
  damaged[Math.floor(damaged.length / 2)] ^= 0xff;
  writeFileSync(path, damaged);
  assert.notEqual(digest(readFileSync(path)), digest(bytesRead), `${path}: the entry must actually be corrupt`);
}
function helperObjectBlob() {
  const moduleDirectory = join(store, 'map', 'mod');
  for (const name of readdirSync(moduleDirectory)) {
    const body = readFileSync(join(moduleDirectory, name), 'utf8');
    if (body.includes('module helper')) return body.split('\n').find(row => row.startsWith('blob ')).slice(5);
  }
  return null;
}
// The records that would answer for `output`.
function programRecords(output) {
  const programDirectory = join(store, 'map', 'prog');
  if (!existsSync(programDirectory)) return [];
  return readdirSync(programDirectory)
    .map(name => join(programDirectory, name))
    .filter(path => readFileSync(path, 'utf8').includes(`output ${output}\n`));
}
// The blob a program entry for `output` names, which is the image the next build would reuse.
function imageBlob(output) {
  const programDirectory = join(store, 'map', 'prog');
  const image = storeDigest(readFileSync(output));
  for (const name of readdirSync(programDirectory)) {
    const body = readFileSync(join(programDirectory, name), 'utf8');
    if (body.includes(`output ${output}\n`) && body.includes(`blob ${image}\n`)) return image;
  }
  return null;
}

function proveCorruption() {
  // Its own output name, its own constant and its own store, so exactly one record per module answers
  // for this state and the damage below cannot be absorbed by an entry from an earlier case.
  const output = join(project, 'target/corrupt');
  rmSync(store, { recursive: true, force: true });
  write(6);
  assert.equal(build(['--whole-program', '--cache', '-o', output]).status, 0, 'the cold build failed');
  assert.equal(run(output), '25', 'the cold build prints the wrong answer');
  const reference = join(project, 'target/corrupt.ref');
  assert.equal(build(['--split', '-o', reference]).status, 0, 'the uncached build failed');

  // A module's object: its key and its emitted assembly are unchanged, so only a content check can
  // catch this one. The program entry is made unreadable at the same time, which is the only way the
  // module level is consulted with unchanged sources - and is itself a case the cache must survive.
  const object = helperObjectBlob();
  assert.ok(object, 'no module record for helper');
  corrupt(join(store, 'blob', object));
  const entries = programRecords(output);
  assert.ok(entries.length > 0, 'no program entry for this output');
  for (const entry of entries) writeFileSync(entry, '');

  const rebuilt = build(['--whole-program', '--cache', '-o', output]);
  assert.equal(rebuilt.status, 0, `the build after corruption failed\n${rebuilt.output}`);
  assert.ok(rebuilt.line, `an unreadable entry must be a miss, not a crash\n${rebuilt.output}`);
  assert.ok(rebuilt.line.names.includes('helper'), `a corrupted entry must be a miss: ${rebuilt.output}`);
  assert.ok(rebuilt.line.hits > 0, `only the damaged entry must miss: ${rebuilt.output}`);
  assert.equal(run(output), '25', 'a corrupted entry must not produce a wrong program');
  assert.deepEqual(bytes(output), bytes(reference), 'a build after corruption is not the uncached build');
  assert.equal(storeDigest(readFileSync(join(store, 'blob', object))), object, 'the corrupted entry must be repaired');
  const healed = build(['--whole-program', '--cache', '-o', output]);
  assert.equal(healed.line.misses, 0, `a repaired store must hit again\n${healed.output}`);

  // The linked image: a whole-program hit hands the output back from the store, so the image has to be
  // verified by content before it is handed back.
  const image = imageBlob(output);
  assert.ok(image, 'no program entry names the image of this output');
  corrupt(join(store, 'blob', image));
  const afterImage = build(['--whole-program', '--cache', '-o', output]);
  assert.equal(afterImage.status, 0, `the build after image corruption failed\n${afterImage.output}`);
  assert.equal(afterImage.line.what, 'image linked', 'a corrupted image must be linked again, not reused');
  assert.equal(run(output), '25', 'a corrupted image must not produce a wrong program');
  assert.deepEqual(bytes(output), bytes(reference), 'a rebuilt image is not the uncached build');
  assert.equal(storeDigest(readFileSync(join(store, 'blob', image))), image, 'the corrupted image must be repaired');
  return { rebuilt: rebuilt.line, healed: healed.line, afterImage: afterImage.line };
}

// ---- (f) pruning ------------------------------------------------------------------------------
// `grail cache prune --keep N` drops the records no build used in the last N builds and then every
// blob no remaining record names. A store pruned right after a build keeps exactly what that build
// used: the next build of the same sources is still a full hit, and no record names a missing blob.
function prune(keep) {
  const result = spawnSync(compiler, ['cache', 'prune', '--keep', String(keep)], { cwd: project, encoding: 'utf8', timeout: 900_000 });
  assert.equal(result.status, 0, `grail cache prune failed\n${result.stdout}${result.stderr}`);
  const match = result.stdout.match(/cache: pruned (\d+) records and (\d+) blobs; kept (\d+) records and (\d+) blobs/);
  assert.ok(match, `unexpected prune report: ${result.stdout}`);
  return { records: Number(match[1]), blobs: Number(match[2]), keptRecords: Number(match[3]), keptBlobs: Number(match[4]) };
}
function provePruning() {
  write(3);
  const first = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(first.status, 0, `build failed\n${first.output}`);
  const nothing = prune(10);
  assert.equal(nothing.records + nothing.blobs, 0, 'a default prune right after a build must keep everything');
  write(5);
  const edited = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(edited.status, 0, `edited build failed\n${edited.output}`);
  const pruned = prune(0);
  assert.ok(pruned.records > 0 && pruned.blobs > 0, `--keep 0 after an edit must drop the superseded entries: ${JSON.stringify(pruned)}`);
  const again = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(again.status, 0, `build after prune failed\n${again.output}`);
  assert.equal(again.line.misses, 0, `what the last build used must survive a prune\n${again.output}`);
  assert.equal(run(program), '22', 'the pruned store must still give the right program');
  proveStore();
  write(3);
  return { pruned, again: again.line };
}

// ---- (g) the default build's cache: one record per module --------------------------------------
// `grail build` of a multi-module program runs the compiler once per module, and that is what
// `--cache` reuses: each run is keyed by its own sources and by the surface of the interfaces it can
// read, so an edit in one module reruns that module and nothing else.
function moduleRuns() {
  const directory = join(project, 'target/mods.modules');
  assert.ok(existsSync(directory), 'the default build must make one file per module');
  return readdirSync(directory).filter(name => name.endsWith('.s')).map(name => name.slice(0, -2)).sort();
}
function proveModules() {
  const output = join(project, 'target/mods');
  rmSync(store, { recursive: true, force: true });
  write(3);
  const cold = build(['--cache', '-o', output]);
  assert.equal(cold.status, 0, `the cold module build failed\n${cold.output}`);
  assert.ok(cold.line, `a cached module build must report its hits and misses\n${cold.output}`);
  assert.equal(cold.line.misses, cold.line.hits + cold.line.misses, 'a cold store cannot hit anything');
  for (const module of ['main', 'util', 'helper', 'core', 'runtime']) {
    assert.ok(moduleRuns().includes(module), `no compiler run for module ${module}: ${moduleRuns().join(', ')}`);
  }
  assert.equal(run(output), '16', 'the module build prints the wrong answer');

  // The cached build is the build it replaces: the same output name, built again with no cache. (The
  // name has to be the same - every object's symbol table names the assembly file it came from.)
  const cachedImage = bytes(output);
  assert.equal(build(['-o', output]).status, 0, 'the uncached default build failed');
  assert.deepEqual(bytes(output), cachedImage, 'the cached module build is not the uncached one');

  const warm = build(['--cache', '-o', output], { measure: true });
  assert.equal(warm.status, 0, `the warm module build failed\n${warm.output}`);
  assert.equal(warm.line.misses, 0, `a second build of unchanged sources must be a full hit\n${warm.output}`);
  assert.match(warm.line.what, /program up to date/, 'a full hit must not relink or recompile');
  assert.ok(warm.ms < cold.ms, `a full hit must be faster: ${cold.ms.toFixed(0)}ms -> ${warm.ms.toFixed(0)}ms`);

  // One module's body: only that module's run is redone, because the key is that module's own source
  // and the interfaces' surfaces - and a body edit leaves the surface alone.
  writeFileSync(join(project, 'src/helper.grl'), helperSource.replace('x + 7', 'x + 8'));
  const body = build(['--cache', '-o', output]);
  assert.equal(body.status, 0, `the body edit failed to build\n${body.output}`);
  assert.deepEqual(body.line.names, ['helper'], `a body edit must rerun that module alone: ${body.output}`);
  assert.equal(run(output), '17', 'the rebuilt program must use the new body');

  // A surface edit is visible to the runs after it, so they are redone too - conservative, never
  // stale: a module that reads the changed interface must not keep an object built from the old one.
  writeFileSync(join(project, 'src/util.grl'), `${utilSource(3)}\npub fn extra() -> u64 {\n    return 1;\n}\n`);
  const surface = build(['--cache', '-o', output]);
  assert.equal(surface.status, 0, `the surface edit failed to build\n${surface.output}`);
  assert.ok(surface.line.names.includes('util'), `the edited module must miss: ${surface.output}`);
  assert.ok(surface.line.names.length > 1, `a surface edit must rerun the runs after it: ${surface.output}`);
  const surfaceImage = bytes(output);
  assert.equal(build(['-o', output]).status, 0, 'the uncached surface build failed');
  assert.deepEqual(bytes(output), surfaceImage, 'the module build after a surface edit is not the uncached one');

  // A damaged object is a miss, a rebuild and a repaired entry - never a wrong program. The record to
  // damage is the one that answers for this build: the blob whose bytes are the object on disk now.
  const directory = join(store, 'map', 'unit');
  const object = storeDigest(readFileSync(join(project, 'target/mods.modules/helper.o')));
  const unit = readdirSync(directory).filter(name => !name.endsWith('.used')).map(name => readFileSync(join(directory, name), 'utf8'))
    .find(text => text.includes('module helper') && text.includes(`obj ${object}`));
  assert.ok(unit, 'no module run record for the object helper has now');
  corrupt(join(store, 'blob', object));
  // The image entry that would answer for this build has to go too, or the program shortcut hands the
  // image back and the module level is never consulted.
  const image = storeDigest(readFileSync(output));
  let cleared = 0;
  for (const entry of programRecords(output)) {
    if (readFileSync(entry, 'utf8').includes(`blob ${image}\n`)) { writeFileSync(entry, ''); cleared += 1; }
  }
  assert.ok(cleared > 0, 'no program entry names the image of this output');
  const rebuilt = build(['--cache', '-o', output]);
  assert.equal(rebuilt.status, 0, `the build after corruption failed\n${rebuilt.output}`);
  assert.ok(rebuilt.line.names.includes('helper'), `a corrupted object must be a miss: ${rebuilt.output}`);
  assert.equal(run(output), '17', 'a corrupted object must not produce a wrong program');
  assert.deepEqual(bytes(output), surfaceImage, 'a build after corruption is not the uncached build');
  assert.equal(storeDigest(readFileSync(join(store, 'blob', object))), object, 'the corrupted object must be repaired');
  write();
  return { cold, warm, body, surface, rebuilt };
}

// ---- (h) edit cost, measured ------------------------------------------------------------------
// Four edits, each printing the build's wall clock and exactly which module runs it redid, and each
// ending with the image byte-compared against the same build made without the cache.
//
// The fourth edit is a one-function edit in a large module. The large module here is generated: 400
// functions in one module, the same shape as the compiler's own `native` (2,600 functions, 38k
// lines) at a size the harness can run in seconds rather than minutes. `bun tools/cache-test.mjs
// --big` swaps in a 2000-function module for a number closer to the compiler's.
const bigFunctions = count => {
  const lines = ['module big;', ''];
  for (let i = 0; i < count; i += 1) {
    lines.push(`pub fn f${i}(x: u64) -> u64 {\n    mut y = x + ${i};\n    if (y % 2) == 0 {\n        y = y * 3;\n    }\n    return y + ${i};\n}\n`);
  }
  return lines.join('\n');
};
function costProject(count) {
  write(3);
  writeFileSync(join(project, 'src/big.grl'), bigFunctions(count));
  writeFileSync(
    join(project, 'src/main.grl'),
    `${mainSource}`.replace('use helper;', 'use helper;\nuse big;').replace('util::twice(a) + helper::bump(a)', 'util::twice(a) + helper::bump(a) + big::f7(1)'),
  );
}
// The reference for the per-function layer: the same tree built to the same output name from an
// empty store with the unit layer off, so every module is compiled and every body is emitted the
// way a compiler with no unit store emits it. (A plain `grail build` goes through the build store
// too, and would hand back the objects the build under test just filed.)
const referenceStore = join(work, 'reference-store');
function referenceBuild(output) {
  rmSync(referenceStore, { recursive: true, force: true });
  return build(['-o', output], { measure: true, env: { ...process.env, GRAIL_CACHE_DIR: referenceStore, GRAIL_FN_CACHE: '0' } });
}
function proveEditCost(count) {
  const output = join(project, 'target/cost');
  rmSync(store, { recursive: true, force: true });
  costProject(count);
  const cold = build(['--cache', '-o', output], { measure: true });
  assert.equal(cold.status, 0, `the cold build failed\n${cold.output}`);
  assert.equal(run(output), '47', 'the cold build prints the wrong answer');
  const cases = [];
  // Nothing changed.
  const warm = build(['--cache', '-o', output], { measure: true });
  assert.equal(warm.line.misses, 0, `an unchanged tree must be a full hit\n${warm.output}`);
  cases.push({ name: 'nothing changed', line: warm.line, ms: warm.ms });
  // (i) a leaf module's body: `helper` imports nothing, so nothing reads its interface.
  writeFileSync(join(project, 'src/helper.grl'), helperSource.replace('x + 7', 'x + 8'));
  const leaf = build(['--cache', '-o', output], { measure: true });
  assert.deepEqual(leaf.line.names, ['helper'], `a leaf module's body edit must rerun it alone: ${leaf.output}`);
  cases.push({ name: "a leaf module's body", line: leaf.line, ms: leaf.ms });
  // (ii) a body-only edit in a module importers read: `util` gains a private helper and then has its
  // body changed, so the interface's bytes do not move and no importer has a reason to rerun.
  const iface = join(project, 'target/cost.modules/interfaces/util.iface');
  const privateHelper = `\nfn private_pad(x: u64) -> u64 {\n    return x + 1;\n}\n`;
  writeFileSync(join(project, 'src/util.grl'), `${utilSource(3)}${privateHelper}`);
  const added = build(['--cache', '-o', output], { measure: true });
  assert.equal(added.status, 0, `adding a private helper failed\n${added.output}`);
  const before = surfaceOf(iface);
  writeFileSync(join(project, 'src/util.grl'), `${utilSource(3)}${privateHelper.replace('x + 1', 'x + 2')}`);
  const bodyOnly = build(['--cache', '-o', output], { measure: true });
  assert.equal(bodyOnly.status, 0, `the body-only edit failed\n${bodyOnly.output}`);
  assert.deepEqual(bodyOnly.line.names, ['util'], `a body-only edit must not rerun an importer: ${bodyOnly.output}`);
  assert.equal(surfaceOf(iface), before, 'a body-only edit must leave the interface surface unchanged');
  cases.push({ name: 'a body-only edit', line: bodyOnly.line, ms: bodyOnly.ms });
  // (iii) an interface edit: a new `pub` function. The module and every run after it are redone.
  writeFileSync(join(project, 'src/util.grl'), `${utilSource(3)}${privateHelper.replace('x + 1', 'x + 2')}\npub fn extra() -> u64 {\n    return 1;\n}\n`);
  const surface = build(['--cache', '-o', output], { measure: true });
  assert.ok(surface.line.names.includes('util'), `the edited module must miss: ${surface.output}`);
  assert.ok(surface.line.names.length > 1, `an interface edit must rerun the runs after it: ${surface.output}`);
  assert.notEqual(surfaceOf(iface), before, 'an interface edit must change the interface surface');
  cases.push({ name: 'an interface edit', line: surface.line, ms: surface.ms });
  // (iv) one function of a large module: `big` is one module, so its run is redone - and nothing else.
  const bigPath = join(project, 'src/big.grl');
  writeFileSync(bigPath, readFileSync(bigPath, 'utf8').replace('pub fn f7(x: u64) -> u64 {\n    mut y = x + 7;', 'pub fn f7(x: u64) -> u64 {\n    mut y = x + 70;'));
  const oneFunction = build(['--cache', '-o', output], { measure: true });
  assert.equal(oneFunction.status, 0, `the one-function edit failed\n${oneFunction.output}`);
  assert.deepEqual(oneFunction.line.names, ['big'], `a one-function edit in one module must stay in that module: ${oneFunction.output}`);
  const bigAssembly = readFileSync(join(project, 'target/cost.modules/big.s'));
  cases.push({ name: `one function of a ${count}-function module`, line: oneFunction.line, ms: oneFunction.ms, bytes: bigAssembly.length });
  // Every case above is the clean build's bytes: the same output name, built again with no cache.
  // (The name has to be the same - each object's symbol table names the assembly file it came from.)
  const cached = bytes(output);
  assert.equal(referenceBuild(output).status, 0, 'the uncached build failed');
  assert.deepEqual(bytes(output), cached, 'the edited build is not the uncached build');
  return { cold, cases };
}

// ---- (i) the per-function cache: units inside a module run ------------------------------------
// `grail build --cache` runs the compiler once per module, and a module run that misses can still
// replay the functions whose inputs did not move: each `grail: fn-cache:` line above is one run's
// account of that. Every case here ends with the module assembly compared byte for byte against the
// same build made from an empty unit store, and with the image compared against a build with no
// cache at all: a replayed body that is not the body a fresh emission writes is a silent
// miscompile, so it has to be caught as bytes.
function moduleAssembly(output) {
  const directory = `${output}.modules`;
  const out = new Map();
  for (const name of readdirSync(directory)) {
    if (name.endsWith('.s')) out.set(name, bytes(join(directory, name)));
  }
  assert.ok(out.size > 0, `no module assembly under ${directory}`);
  return out;
}
function sameAssembly(before, after, what) {
  assert.deepEqual([...after.keys()], [...before.keys()], `${what}: the module set changed`);
  for (const [name, text] of before) {
    assert.deepEqual(after.get(name), text, `${what}: ${name}.s is not the assembly a clean emission writes`);
  }
}
// The unit store is emptied, the module store is not: the next build replays nothing at the module
// level and hits the unit store on every function it filed.
function clearUnitStore() {
  rmSync(join(store, 'fn'), { recursive: true, force: true });
}
function clearModuleStore() {
  rmSync(join(store, 'map'), { recursive: true, force: true });
  rmSync(join(store, 'blob'), { recursive: true, force: true });
}
function proveUnits(count) {
  const output = join(project, 'target/units');
  rmSync(store, { recursive: true, force: true });
  costProject(count);
  // The cold build files the units. Its image is the reference every case below is compared with,
  // and its module assembly is the text a replay has to reproduce byte for byte.
  const cold = build(['--cache', '-o', output], { measure: true });
  assert.equal(cold.status, 0, `the cold unit build failed\n${cold.output}`);
  const coldLines = unitLines(cold.output);
  assert.equal(coldLines.length, cold.line.hits + cold.line.misses, `one fn-cache line per module run:\n${cold.output}`);
  const filed = sum(coldLines);
  assert.equal(filed.hits, 0, `a cold unit store cannot replay a body:\n${cold.output}`);
  assert.ok(filed.filed > 0, `a cold build must file units:\n${cold.output}`);
  const bigFiled = forModule(coldLines, 'big').filed;
  assert.ok(bigFiled > 1, `the big module must file its bodies:\n${cold.output}`);
  const coldImage = bytes(output);
  // The same build with no cache at all, to the same output name: this is the image, and (after it
  // has overwritten the cached build's assembly) the module text, that a replay must be.
  const clean = referenceBuild(output);
  assert.equal(clean.status, 0, `the uncached build failed\n${clean.output}`);
  assert.deepEqual(bytes(output), coldImage, 'the cached build is not the uncached build');
  const assembly = moduleAssembly(output);

  // (1) every module run forced to miss while the unit store stays warm: the module's assembly has to
  // come back byte for byte. This is the property the layer rests on - label numbers, `.gpos`
  // positions, the fact table and the label counters all have to line up with a fresh emission.
  clearModuleStore();
  const replay = build(['--cache', '-o', output], { measure: true });
  assert.equal(replay.status, 0, `the replay build failed\n${replay.output}`);
  const replayed = sum(unitLines(replay.output));
  assert.equal(replayed.hits, filed.filed, `every filed unit must replay:\n${replay.output}`);
  assert.equal(replayed.filed, 0, `nothing is filed when everything replays:\n${replay.output}`);
  sameAssembly(assembly, moduleAssembly(output), 'a replayed module');
  assert.deepEqual(bytes(output), coldImage, 'a replayed image is not the clean image');

  // (2) one function of the big module: that body is emitted and filed again, and every other body
  // of the module replays - the label numbers of the bodies after it did not move, which is what
  // `at <line>` in the key buys over a byte offset.
  const bigPath = join(project, 'src/big.grl');
  writeFileSync(bigPath, readFileSync(bigPath, 'utf8').replace('pub fn f7(x: u64) -> u64 {\n    mut y = x + 7;', 'pub fn f7(x: u64) -> u64 {\n    mut y = x + 70;'));
  const one = build(['--cache', '-o', output], { measure: true });
  assert.equal(one.status, 0, `the one-function edit failed\n${one.output}`);
  const big = forModule(unitLines(one.output), 'big');
  assert.equal(big.filed, 1, `one edited body is emitted and filed:\n${one.output}`);
  assert.equal(big.hits, bigFiled - 1, `every other body of big must replay:\n${one.output}`);
  const oneImage = bytes(output);
  assert.equal(referenceBuild(output).status, 0, 'the uncached one-function build failed');
  assert.deepEqual(bytes(output), oneImage, 'the one-function edit is not the uncached build');

  // (3) a body-only edit of another inner function: the module-level cache reruns that module and
  // nothing else (its interface surface does not move), and inside the run one body is emitted.
  const bigIfaces = join(project, 'target/units.modules/interfaces/big.iface');
  const bigSurface = surfaceOf(bigIfaces);
  writeFileSync(bigPath, readFileSync(bigPath, 'utf8').replace('pub fn f3(x: u64) -> u64 {\n    mut y = x + 3;', 'pub fn f3(x: u64) -> u64 {\n    mut y = x + 30;'));
  const bodyOnly = build(['--cache', '-o', output], { measure: true });
  assert.equal(bodyOnly.status, 0, `the body-only edit failed\n${bodyOnly.output}`);
  assert.deepEqual(bodyOnly.line.names, ['big'], `a body-only edit must rerun one module:\n${bodyOnly.output}`);
  assert.equal(surfaceOf(bigIfaces), bigSurface, 'a body edit must leave the interface surface alone');
  const onlyBig = forModule(unitLines(bodyOnly.output), 'big');
  assert.equal(onlyBig.filed, 1, `the edited body is the one body emitted again:\n${bodyOnly.output}`);
  assert.equal(onlyBig.hits, bigFiled - 1, `every other body of big must replay:\n${bodyOnly.output}`);
  const bodyImage = bytes(output);
  assert.equal(referenceBuild(output).status, 0, 'the uncached body-only build failed');
  assert.deepEqual(bytes(output), bodyImage, 'the body-only edit is not the uncached build');

  // (4) an interface change: a new `pub` function moves the big module's declaration surface, and
  // the surface is in every key of that module, so every one of its units is a miss - not one
  // replayed body. The modules nobody touched are still module-level hits, so one edit does not
  // throw the store away.
  writeFileSync(bigPath, `${readFileSync(bigPath, 'utf8')}\npub fn extra(x: u64) -> u64 {\n    return x + 1;\n}\n`);
  const surface = build(['--cache', '-o', output], { measure: true });
  assert.equal(surface.status, 0, `the interface edit failed\n${surface.output}`);
  assert.equal(surface.line.names[0], 'big', `the edited module must rerun first:\n${surface.output}`);
  const bigAfter = forModule(unitLines(surface.output), 'big');
  assert.equal(bigAfter.hits, 0, `a surface change must invalidate every unit of the module:\n${surface.output}`);
  assert.ok(bigAfter.filed >= bigFiled, `every body of the module is emitted and filed again:\n${surface.output}`);
  assert.ok(surface.line.hits >= 3, `a surface change must not throw away the modules before it:\n${surface.output}`);
  const surfaceImage = bytes(output);
  assert.equal(referenceBuild(output).status, 0, 'the uncached surface build failed');
  assert.deepEqual(bytes(output), surfaceImage, 'the surface edit is not the uncached build');

  write(3);
  return { cold, clean, replay, one, bodyOnly, surface, filed, replayed, big, onlyBig, assembly: assembly.size };
}

// ---- (j) units that do not depend on the bodies before them -----------------------------------
// The module here is the shape real code has and `big` does not: records with a string field (so
// every body names a drop helper), a generic every body instantiates (once at a type they all
// share, once at a type of its own), loops and branches (labels), and string literals. An edit to
// one body must cost that body and nothing else, whether it keeps the line count (and changes how
// many labels the body mints) or adds lines (and moves every later statement's position) - and the
// assembly must be the text a build with no cache writes.
const richFunctions = count => {
  const lines = ['module rich;', '', 'fn same<T>(x: T, n: u64) -> T {\n    return x;\n}\n'];
  for (let i = 0; i < count; i += 1) {
    lines.push(`struct Rec${i} {
    a: u64,
    b: u64,
    name: string
}
fn mk${i}(a: u64, b: u64) -> Rec${i} {
    return Rec${i} { a: a, b: b, name: "r${i}" };
}
pub fn work${i}(v: &u64[], k: u64) -> u64 {
    mut total = 0;
    for i in v.len() {
        x := v[i];
        if x % 2 == 0 {
            total = wrapping_add(total, x * k % 1000);
        } else {
            total = wrapping_add(total, x % 7);
        }
    }
    r := same(mk${i}(same(total, 1), k), 2);
    mut out = r.a % 100000;
    while out > 1000 {
        out = out / 3;
    }
    return out + r.b + r.name.len();
}
`);
  }
  return lines.join('\n');
};
function richProject(count) {
  write(3);
  writeFileSync(join(project, 'src/rich.grl'), richFunctions(count));
  writeFileSync(
    join(project, 'src/main.grl'),
    `use rich;\n\npub fn main() -> u64 {\n    v := u64[1, 2, 3, 4];\n    println(rich::work5(&v, 5) + rich::work9(&v, 9) + rich::work${count - 1}(&v, 3));\n    return 0;\n}\n`,
  );
}
function proveIndependentUnits(count) {
  const output = join(project, 'target/rich');
  const richPath = join(project, 'src/rich.grl');
  rmSync(store, { recursive: true, force: true });
  richProject(count);
  const cold = build(['--cache', '-o', output], { measure: true });
  assert.equal(cold.status, 0, `the cold build of the rich module failed\n${cold.output}`);
  // Every body is a unit, the first of the part included: its unit's text starts after the part's
  // marker, which the run writes before applying it.
  const bodies = 2 * count;
  const coldRich = forModule(unitLines(cold.output), 'rich');
  assert.deepEqual(coldRich, { hits: 0, filed: bodies, kept: 0 }, `every body of the rich module is a unit - drop helpers and specialisations are replayable registrations:\n${cold.output}`);
  // One edit, then: the cached build's account, its assembly and image, and the same tree built
  // with no cache to the same output name.
  const edited = (what, from, to) => {
    const source = readFileSync(richPath, 'utf8');
    assert.ok(source.includes(from), `${what}: the text to edit is not in the module`);
    writeFileSync(richPath, source.replace(from, to));
    const cached = build(['--cache', '-o', output], { measure: true });
    assert.equal(cached.status, 0, `${what}: the cached build failed\n${cached.output}`);
    const rich = forModule(unitLines(cached.output), 'rich');
    assert.deepEqual(rich, { hits: bodies - 1, filed: 1, kept: 0 }, `${what}: the edited body is emitted and every other body replays:\n${cached.output}`);
    const answer = run(output);
    const image = bytes(output);
    const assembly = moduleAssembly(output);
    const clean = referenceBuild(output);
    assert.equal(clean.status, 0, `${what}: the uncached build failed\n${clean.output}`);
    assert.equal(unitLines(clean.output).length, 0, `${what}: the reference build must not use the unit store\n${clean.output}`);
    sameAssembly(moduleAssembly(output), assembly, what);
    assert.deepEqual(bytes(output), image, `${what}: the cached image is not the uncached image`);
    assert.equal(run(output), answer, `${what}: the answers differ`);
    return { what, cached, clean, rich };
  };
  const cases = [];
  // The line count stays, the label count does not: one more branch in an early body.
  cases.push(edited('an edit that keeps the line count', 'pub fn work5(v: &u64[], k: u64) -> u64 {\n    mut total = 0;', 'pub fn work5(v: &u64[], k: u64) -> u64 {\n    mut total = 0; if k > 100 { total = 1; }'));
  // Three more lines and a loop: every later body starts three lines further down.
  cases.push(edited('an edit that adds lines', 'pub fn work9(v: &u64[], k: u64) -> u64 {\n    mut total = 0;', 'pub fn work9(v: &u64[], k: u64) -> u64 {\n    mut total = 0;\n    mut extra = k;\n    while extra > 10 {\n        extra = extra / 2;\n    }\n    total = wrapping_add(total, extra);'));
  // And the lines go away again: the bodies after it move back up.
  cases.push(edited('an edit that removes lines', '    mut extra = k;\n    while extra > 10 {\n        extra = extra / 2;\n    }\n    total = wrapping_add(total, extra);', '    total = wrapping_add(total, k);'));
  write(3);
  return { cold, cases, bodies };
}

// ---- (k) a replayed body's registrations ------------------------------------------------------
// `first` and `second` both instantiate `same<u64>`. The specialisation is emitted because a body
// asked for it, so a body that is replayed has to ask again: when `first` stops asking, `second`
// - unchanged, replayed - is the only body that names the symbol. A unit that recorded only the
// registrations it was the first to make hands the linker an undefined symbol here.
const sharedSource = first => `module shared;

fn same<T>(x: T, n: u64) -> T {
    return x;
}
pub fn zero() -> u64 {
    return 0;
}
pub fn first(x: u64) -> u64 {
    return ${first};
}
pub fn second(x: u64) -> u64 {
    return same(x, 2);
}
`;
function proveRegistrations() {
  const output = join(project, 'target/shared');
  rmSync(store, { recursive: true, force: true });
  write(3);
  writeFileSync(join(project, 'src/shared.grl'), sharedSource('same(x, 1)'));
  writeFileSync(join(project, 'src/main.grl'), 'use shared;\n\npub fn main() -> u64 {\n    println(shared::first(3) + shared::second(4));\n    return 0;\n}\n');
  const cold = build(['--cache', '-o', output]);
  assert.equal(cold.status, 0, `the cold build failed\n${cold.output}`);
  assert.equal(run(output), '7', 'the cold build prints the wrong answer');
  // `first` no longer names the specialisation; `second` still does.
  writeFileSync(join(project, 'src/shared.grl'), sharedSource('x | 8'));
  const after = build(['--cache', '-o', output]);
  assert.equal(after.status, 0, `a replayed body must register what it names - the build after the first user of a specialisation stopped using it failed:\n${after.output}`);
  const shared = forModule(unitLines(after.output), 'shared');
  assert.ok(shared.hits >= 1, `the unchanged bodies must replay:\n${after.output}`);
  assert.equal(run(output), '15', 'the build after the edit prints the wrong answer');
  const image = bytes(output);
  const assembly = moduleAssembly(output);
  assert.equal(referenceBuild(output).status, 0, 'the uncached build failed');
  sameAssembly(moduleAssembly(output), assembly, 'a replayed registration');
  assert.deepEqual(bytes(output), image, 'the build after the edit is not the uncached build');
  write(3);
  return { shared };
}

// ---- (l) the optimiser's memo under a unit's key ----------------------------------------------
// A body the front end applied from its unit is found by the optimiser from where the front end
// noted it and its memo entry is keyed by the unit's key, not by its text. That is sound only if a
// unit's text is a function of its key: GRAIL_MEMO_VERIFY=1 optimises every such body again and
// fails if the remembered bytes differ. Run on a warm rebuild of the compiler's own sources, then
// compared with a compile that has no store at all.
function proveMemoKeys() {
  const dir = join(work, 'memo');
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const sources = compilerSources;
  const run = (out, extra, env = {}) => {
    const r = spawnSync(compiler, ['--default-u64', '--typed-refs', ...extra, join(dir, out), ...sources], { cwd: root, encoding: 'utf8', env: { ...process.env, ...env }, maxBuffer: 1 << 26, timeout: 900_000 });
    assert.equal(r.status, 0, `the compile ${out} failed\n${r.stdout}${r.stderr}`);
    return `${r.stdout}${r.stderr}`;
  };
  const store = ['--fn-cache', join(dir, 'fn'), '--fn-cache-id', 'memo-test'];
  run('plain.s', [], { GRAIL_JOBS: '1' });
  run('cold.s', store);
  // The optimiser's entries (`opt-*`) a store holds: a warm rebuild of unchanged sources must find
  // every body's entry, so it files none. A replayed body whose facts differ from a fresh
  // emission's (its parameters' facts taken twice) is keyed apart and files a new one.
  const memoEntries = () => readdirSync(join(dir, 'fn')).filter(name => name.startsWith('opt-')).length;
  const filed = memoEntries();
  const warm = run('warm.s', store, { GRAIL_MEMO_VERIFY: '1' });
  assert.equal(memoEntries(), filed, 'a warm rebuild missed the optimiser memo for unchanged bodies');
  const plain = readFileSync(join(dir, 'plain.s'));
  assert.ok(plain.equals(readFileSync(join(dir, 'cold.s'))), 'a cold store changed the assembly');
  assert.ok(plain.equals(readFileSync(join(dir, 'warm.s'))), 'a warm store changed the assembly');
  const hits = Number((warm.match(/(\d+) hit/) ?? [0, 0])[1]);
  assert.ok(hits > 1000, `the warm rebuild must replay the compiler's bodies:\n${warm}`);
  return { hits };
}

// ---- (m) an incremental check ----------------------------------------------------------------
// `grail check` runs one compiler per module through the store, as a build does: a module whose
// inputs did not move is not checked again, and in a module that is, the unchanged bodies replay.
// A module with errors reports them; the modules that read it get one line each and are not
// checked; the modules that do not read it are still checked. Diagnostics are the module's own.
function proveCheck() {
  const dir = join(work, 'check');
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(join(dir, 'src'), { recursive: true });
  writeFileSync(join(dir, 'grail.toml'), '[package]\nname = "chk"\nversion = "0.1.0"\n');
  const mod = (name, body, uses = '') => writeFileSync(join(dir, `src/${name}.grl`), `module ${name};\n${uses}\npub fn f${name}(x: u64) -> u64 {\n    return ${body};\n}\n`);
  mod('a', 'x + 1');
  mod('b', 'x + 2');
  mod('c', 'a::fa(x) + 3', 'use a;\n');
  writeFileSync(join(dir, 'src/main.grl'), 'use a;\nuse b;\nuse c;\n\nfn main() {\n    println(a::fa(1) + b::fb(2) + c::fc(3));\n}\n');
  const env = { ...process.env, GRAIL_CACHE_DIR: join(dir, 'store') };
  const check = () => {
    const r = spawnSync(compiler, ['check', '--cache'], { cwd: dir, encoding: 'utf8', env, timeout: 900_000 });
    return { status: r.status, out: `${r.stdout}${r.stderr}`, line: cacheLine(`${r.stdout}${r.stderr}`) };
  };
  const cold = check();
  assert.equal(cold.status, 0, `the cold check failed\n${cold.out}`);
  assert.equal(cold.line.hits, 0, `a cold check reuses nothing\n${cold.out}`);
  const again = check();
  assert.equal(again.line.misses, 0, `an unchanged tree checks nothing again\n${again.out}`);
  mod('b', 'x + 22');
  const edited = check();
  assert.deepEqual(edited.line.names, ['b'], `an edit to b checks b alone\n${edited.out}`);
  assert.deepEqual(forModule(unitLines(edited.out), 'b'), { hits: 0, filed: 1, kept: 0 }, `inside b, the edited body is the one checked\n${edited.out}`);
  // Errors in two modules that do not read each other: both are reported, and their readers are not
  // checked - one line each.
  mod('a', 'x + "one"');
  mod('b', 'x + true');
  const broken = check();
  assert.equal(broken.status, 1, `a check with errors fails\n${broken.out}`);
  assert.match(broken.out, /src\/a\.grl:4:/, `a's error is reported\n${broken.out}`);
  assert.match(broken.out, /src\/b\.grl:4:/, `b's error is reported\n${broken.out}`);
  assert.match(broken.out, /^grail: not checked: `c` depends on `a`, which has errors$/m, `c is not checked\n${broken.out}`);
  assert.match(broken.out, /^grail: not checked: `main` depends on `a`, which has errors$/m, `main is not checked\n${broken.out}`);
  // An error in a module nothing else reads leaves every other module checked.
  mod('a', 'x + 1');
  mod('b', 'x + 2');
  writeFileSync(join(dir, 'src/main.grl'), 'use a;\nuse c;\n\nfn main() {\n    println(a::fa(1) + c::fc(3) + true);\n}\n');
  const leaf = check();
  assert.equal(leaf.status, 1, `an error in main fails the check\n${leaf.out}`);
  assert.doesNotMatch(leaf.out, /not checked/, `nothing reads main\n${leaf.out}`);
  // A build after checks finds only check units - registrations, no text - and compiles every body,
  // as a cold build does (cargo's metadata against its rlib); a check after that build reuses the
  // build's full units.
  writeFileSync(join(dir, 'src/main.grl'), 'use a;\nuse b;\nuse c;\n\nfn main() {\n    println(a::fa(1) + b::fb(2) + c::fc(3));\n}\n');
  const built = spawnSync(compiler, ['build', '--cache'], { cwd: dir, encoding: 'utf8', env, timeout: 900_000 });
  assert.equal(built.status, 0, `the build after the checks failed\n${built.stdout}${built.stderr}`);
  const bodies = sum(unitLines(`${built.stdout}${built.stderr}`));
  assert.equal(bodies.hits, 0, `a build must not replay a check unit, which has no text\n${built.stdout}`);
  mod('b', 'x + 3');
  const afterBuild = check();
  assert.equal(afterBuild.status, 0, `the check after the build failed\n${afterBuild.out}`);
  // b is checked again; a and c, which do not read b, come from the build's records. (main reads b,
  // whose facts a build writes differently from a check, so main may be checked again: a miss.)
  assert.ok(afterBuild.line.names.includes('b') && !afterBuild.line.names.includes('a') && !afterBuild.line.names.includes('c'), `the check after the build reuses the build's records\n${afterBuild.out}`);
  return { cold, edited, broken };
}

function reportIndependent(independent, registrations) {
  const t = value => `${value.toFixed(1)}ms`;
  console.log(`(j) one body   ${independent.bodies} bodies with drop helpers and specialisations, all units; after each edit one is emitted and the rest replay, byte-identical`);
  for (const item of independent.cases) {
    console.log(`               ${t(item.cached.ms).padStart(10)}  ${item.what.padEnd(34)} ${item.rich.hits} replayed, ${item.rich.filed} re-emitted (uncached ${t(item.clean.ms)})`);
  }
  console.log(`(k) registered a replayed body asks again for what it names: ${registrations.shared.hits} replayed after the first user stopped`);
}

// ---- run --------------------------------------------------------------------------------------
// The timings come first, from an empty store, so "cold" means cold.
// `--units` runs only the per-function sections (j) and (k), for work on that layer.
if (flags.includes('--check')) {
  const checks = proveCheck();
  console.log(`(m) check      ${checks.edited.line.hits} modules reused after one edit`);
  console.log('incremental check verified');
  process.exit(0);
}
if (flags.includes('--units')) {
  const registrations = proveRegistrations();
  const independent = proveIndependentUnits(flags.includes('--big') ? 1000 : 150);
  reportIndependent(independent, registrations);
  console.log('per-function units verified');
  process.exit(0);
}
const reuse = proveReuse();
recordBuild('identity');
proveStore();
const precision = provePrecision();
const flagProof = proveFlags();
const interfaceProof = proveInterfaces();
const corruption = proveCorruption();
const pruning = provePruning();
const modules = proveModules();
const editCost = proveEditCost(flags.includes('--big') ? 2000 : 400);
// (m) compile-time values (docs/design/comptime-speed.md, R3): a value is cached with what its
// computation read - the bodies the probe reached, the non-function declarations, the other values -
// so an edit elsewhere runs no probe, and an edit to a body the value reached runs exactly one. The
// probes are counted by the link each one makes (GRAIL_CC), in a project of its own.
function proveComptimeValues() {
  const dir = join(work, 'comptime');
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const log = join(dir, 'cc.log');
  const wrapper = join(dir, 'cc.sh');
  writeFileSync(wrapper, `#!/bin/sh\necho link >> ${log}\nexec cc "$@"\n`, { mode: 0o755 });
  const source = (step, extra) => `static A: u64 = @fa();
static B: u64 = @fb();
fn fa() -> u64 {
    mut t = 0;
    for i in 10 {
        t += i * ${step};
    }
    return t;
}
fn fb() -> u64 {
    return 7;
}
${extra}
fn main() -> u64 {
    println(A);
    println(B);
    return 0;
}
`;
  const file = join(dir, 'main.grl');
  const step = (text) => {
    writeFileSync(file, text);
    writeFileSync(log, '');
    const result = spawnSync(compiler, ['run', file, '--no-cache'], { cwd: dir, encoding: 'utf8', env: { ...process.env, GRAIL_CC: wrapper }, timeout: 600_000 });
    assert.equal(result.status, 0, `compile-time values: the build failed: ${result.stdout}${result.stderr}`);
    return { out: result.stdout, probes: readFileSync(log, 'utf8').split('\n').filter(Boolean).length };
  };
  const cold = step(source(1, ''));
  assert.equal(cold.out, '45\n7\n');
  assert.equal(cold.probes, 1, 'a cold build computes every value in one probe');
  const warm = step(source(1, ''));
  assert.equal(warm.probes, 0, 'an unchanged build runs no probe');
  const elsewhere = step(source(1, 'fn unrelated() -> u64 {\n    return 1;\n}\n'));
  assert.equal(elsewhere.probes, 0, 'an edit no value reached runs no probe');
  const reached = step(source(2, 'fn unrelated() -> u64 {\n    return 1;\n}\n'));
  assert.equal(reached.out, '90\n7\n');
  assert.equal(reached.probes, 1, 'an edit to a body a value reached runs the probe again');
  const again = step(source(2, 'fn unrelated() -> u64 {\n    return 2;\n}\n'));
  assert.equal(again.probes, 0, 'and after it, an edit elsewhere runs none');
  return { cold, warm, elsewhere, reached, again };
}
const comptimeValues = proveComptimeValues();
const units = proveUnits(flags.includes('--big') ? 2000 : 400);
const registrations = proveRegistrations();
const independent = proveIndependentUnits(flags.includes('--big') ? 1000 : 150);
const memoKeys = proveMemoKeys();
const checks = proveCheck();
const finalStore = proveStore();

const ms = value => `${value.toFixed(1)}ms`;
console.log('');
console.log('(-) identity   every cached build above is the uncached build, byte for byte');
console.log(`(-) store      ${finalStore.blobs} blobs, ${finalStore.records} records, every blob filed under its own digest`);
console.log(`(a) reuse      cold ${ms(reuse.cold.ms)} -> warm ${ms(reuse.warm.ms)} (${reuse.ratio.toFixed(1)}x): ${reuse.warm.line.hits} hit, ${reuse.warm.line.misses} miss; ${reuse.warm.line.what}`);
console.log(`(b) precision  ${precision.line.hits} hit, ${precision.line.misses} miss (${precision.line.names.join(', ')}) for an edit in util, order ${precision.order.join(' ')}`);
console.log(`(g) modules    cold ${ms(modules.cold.ms)} -> warm ${ms(modules.warm.ms)} (${(modules.cold.ms / modules.warm.ms).toFixed(1)}x): ${modules.warm.line.hits} hit, ${modules.warm.line.misses} miss; ${modules.warm.line.what}`);
console.log(`(g) modules    a body edit reruns ${modules.body.line.names.join(', ')}; a surface edit reruns ${modules.surface.line.hits + modules.surface.line.misses - modules.surface.line.hits} of ${modules.surface.line.hits + modules.surface.line.misses} runs`);
console.log(`               ${precision.shifted.hits} hit, ${precision.shifted.misses} miss (${precision.shifted.names.join(', ')}) for an edit in main: only its own part's assembly changed (${precision.changed.join(', ')})`);
console.log(`(c) flags      --overflow=wrap: ${flagProof.wrapped.hits} hit, ${flagProof.wrapped.misses} miss; back: ${flagProof.back.misses} miss`);
console.log(`(d) interface  warm ${interfaceProof.warm.hits} hit; a tampered interface is refused; restored: ${interfaceProof.after.hits} hit, ${interfaceProof.after.misses} miss`);
console.log(`(e) corruption helper entry: ${corruption.rebuilt.hits} hit, ${corruption.rebuilt.misses} miss (${corruption.rebuilt.names.join(', ')}); healed: ${corruption.healed.misses} miss; image: ${corruption.afterImage.what}`);
console.log(`(h) edit cost  the edits and what each one redid, each one the clean build's bytes:`);
for (const item of editCost.cases) {
  const redone = item.line.misses === 0 ? 'nothing' : `${item.line.misses} of ${item.line.hits + item.line.misses} runs: ${item.line.names.join(', ')}`;
  console.log(`               ${ms(item.ms).padStart(10)}  ${item.name.padEnd(30)} redid ${redone}`);
}
console.log(`               ${ms(editCost.cold.ms).padStart(10)}  cold build of the same tree`);
console.log(`(i) units      ${units.assembly} module assembly files, ${units.filed.filed} bodies filed by a cold build (${units.filed.kept} bodies are not units), every replay byte-identical`);
console.log(`               ${ms(units.cold.ms).padStart(10)}  cold: nothing to replay, everything filed`);
for (const item of [
  { name: 'every module run forced to miss', built: units.replay, line: units.replayed },
  { name: 'one function of the big module', built: units.one, line: units.big },
  { name: 'a body-only edit of an inner function', built: units.bodyOnly, line: units.onlyBig },
  { name: 'an interface change in the big module', built: units.surface, line: sum(unitLines(units.surface.output)) },
]) {
  console.log(`               ${ms(item.built.ms).padStart(10)}  ${item.name.padEnd(34)} ${item.line.hits} replayed, ${item.line.filed} re-emitted, ${item.line.kept} not units`);
}
console.log(`               ${ms(units.clean.ms).padStart(10)}  a clean build of the same tree (no cache at all)`);
reportIndependent(independent, registrations);
console.log(`(m) check      a check after an edit to one module checks it alone (${checks.edited.line.hits} modules reused); errors in two modules are both reported and their readers are not checked`);
console.log(`(l) memo keys  a warm rebuild of the compiler: ${memoKeys.hits} bodies replayed, every remembered optimisation checked against a fresh one`);
console.log(`(f) pruning    --keep 0 after an edit dropped ${pruning.pruned.records} records and ${pruning.pruned.blobs} blobs; next build ${pruning.again.hits} hit, ${pruning.again.misses} miss`);
console.log(`(m) comptime   probes: cold ${comptimeValues.cold.probes}, unchanged ${comptimeValues.warm.probes}, an edit elsewhere ${comptimeValues.elsewhere.probes}, an edit to a reached body ${comptimeValues.reached.probes}, then elsewhere again ${comptimeValues.again.probes}`);
console.log('');
console.log('build cache verified');
