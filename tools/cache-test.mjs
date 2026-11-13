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
//                    entry is repaired instead of missing forever.
//
// What the module level cannot do yet is also pinned here: the emitter numbers its local labels over
// one stream, so a change in one module re-spells the text of every module emitted after it. Those
// modules miss by the emitted-text guard, not by their own keys - which is why a stale object is
// impossible, and why an edit in a big program still reassembles the modules after it.
//
// Usage: bun tools/cache-test.mjs [--target T]

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { buildCompiler, hostTarget, root, targetName } from './native.mjs';

const flags = process.argv.slice(2);
const target = targetName(flags.includes('--target') ? flags[flags.indexOf('--target') + 1] : hostTarget);
assert.equal(target, 'x86_64', 'the cache rides on --split, which is the Linux x86_64 assembler path');

const compiler = buildCompiler();
const work = join(root, '.work/cache-test', target);
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const project = join(work, 'project');
const store = join(project, '.work/cache', target);
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
  writeFileSync(join(project, 'grail.toml'), '[package]\nname = "cachetest\n"\nversion = "0.1.0"\n');
  writeFileSync(join(project, 'src/main.grl'), mainSource);
  writeFileSync(join(project, 'src/util.grl'), utilSource(value));
  writeFileSync(join(project, 'src/helper.grl'), helperSource);
}
write();

// One build. `extra` are the flags under test; everything else is what `grail build` does.
function build(args, { measure = false } = {}) {
  const started = process.hrtime.bigint();
  const result = spawnSync(compiler, ['build', '--target', target, ...args], { cwd: project, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout: 900_000 });
  const ms = Number(process.hrtime.bigint() - started) / 1e6;
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { status: result.status, output, ms, line: cacheLine(output) };
}
function cacheLine(output) {
  const match = output.match(/grail: cache: (\d+) hit, (\d+) miss(?: \(([^)]*)\))?; (.+)\n/);
  return match ? { hits: Number(match[1]), misses: Number(match[2]), names: match[3] ? match[3].split(', ') : [], what: match[4] } : null;
}
function run(binary) {
  const result = spawnSync(binary, [], { encoding: 'utf8', timeout: 60_000 });
  assert.equal(result.status, 0, `${binary}: exited ${result.status}\n${result.stderr ?? ''}`);
  return result.stdout.trim();
}
const bytes = path => readFileSync(path);
const digest = data => createHash('sha256').update(data).digest('hex');

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
        assert.equal(digest(readFileSync(join(blobDirectory, blob))), blob, `${kind}/${name}: names a blob that does not hash to it`);
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
function provePrecision() {
  const before = emissionOrder();
  setScale(4);
  const result = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(result.status, 0, `a source edit failed to build\n${result.output}`);
  assert.ok(result.line.names.includes('util'), `the edited module must miss: ${result.output}`);
  assert.ok(result.line.names.includes('main'), `the module that reads it must miss: ${result.output}`);
  assert.ok(!result.line.names.includes('helper'), `a module that does not read it must hit: ${result.output}`);
  assert.equal(run(program), '19', 'the rebuilt program must use the new constant');

  // And the thing the module key cannot see: the emitted text of every later module is re-spelled,
  // so those modules miss through the emitted-text guard even though nothing they declare changed.
  setMainUnused();
  const shifted = build(['--whole-program', '--cache', '-o', program]);
  assert.equal(shifted.status, 0, `the second edit failed to build\n${shifted.output}`);
  assert.ok(shifted.line.names.includes('main'), `the edited module must miss: ${shifted.output}`);
  const order = emissionOrder();
  assert.deepEqual(order, before, 'the emission order must not change');
  const reference = assertUncachedBuild('shifted');
  return { line: result.line, shifted: shifted.line, order, reference };
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
  const original = readFileSync(path, 'utf8');
  assert.match(original, /const util::SCALE u64 int 3/, 'the constant must be in the interface');
  const edited = original.replace('const util::SCALE u64 int 3', 'const util::SCALE u64 int 4');
  const body = edited.slice(0, edited.indexOf('\ndigest "') + 1);
  const tampered = `${body}digest "${digest(body)}"\n`;
  writeFileSync(path, tampered);
  const manifestPath = join(ifaces, 'interfaces.manifest');
  writeFileSync(manifestPath, readFileSync(manifestPath, 'utf8').replace(/^util \S+/m, `util ${digest(tampered)}`));

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
  const image = digest(readFileSync(output));
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
  assert.equal(digest(readFileSync(join(store, 'blob', object))), object, 'the corrupted entry must be repaired');
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
  assert.equal(digest(readFileSync(join(store, 'blob', image))), image, 'the corrupted image must be repaired');
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
  const object = digest(readFileSync(join(project, 'target/mods.modules/helper.o')));
  const unit = readdirSync(directory).filter(name => !name.endsWith('.used')).map(name => readFileSync(join(directory, name), 'utf8'))
    .find(text => text.includes('module helper') && text.includes(`obj ${object}`));
  assert.ok(unit, 'no module run record for the object helper has now');
  corrupt(join(store, 'blob', object));
  // The image entry that would answer for this build has to go too, or the program shortcut hands the
  // image back and the module level is never consulted.
  const image = digest(readFileSync(output));
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
  assert.equal(digest(readFileSync(join(store, 'blob', object))), object, 'the corrupted object must be repaired');
  write();
  return { cold, warm, body, surface, rebuilt };
}

// ---- run --------------------------------------------------------------------------------------
// The timings come first, from an empty store, so "cold" means cold.
const reuse = proveReuse();
recordBuild('identity');
proveStore();
const precision = provePrecision();
const flagProof = proveFlags();
const interfaceProof = proveInterfaces();
const corruption = proveCorruption();
const pruning = provePruning();
const modules = proveModules();
const finalStore = proveStore();

const ms = value => `${value.toFixed(1)}ms`;
console.log('');
console.log('(-) identity   every cached build above is the uncached build, byte for byte');
console.log(`(-) store      ${finalStore.blobs} blobs, ${finalStore.records} records, every blob filed under its own digest`);
console.log(`(a) reuse      cold ${ms(reuse.cold.ms)} -> warm ${ms(reuse.warm.ms)} (${reuse.ratio.toFixed(1)}x): ${reuse.warm.line.hits} hit, ${reuse.warm.line.misses} miss; ${reuse.warm.line.what}`);
console.log(`(b) precision  ${precision.line.hits} hit, ${precision.line.misses} miss (${precision.line.names.join(', ')}) for an edit in util, order ${precision.order.join(' ')}`);
console.log(`(g) modules    cold ${ms(modules.cold.ms)} -> warm ${ms(modules.warm.ms)} (${(modules.cold.ms / modules.warm.ms).toFixed(1)}x): ${modules.warm.line.hits} hit, ${modules.warm.line.misses} miss; ${modules.warm.line.what}`);
console.log(`(g) modules    a body edit reruns ${modules.body.line.names.join(', ')}; a surface edit reruns ${modules.surface.line.hits + modules.surface.line.misses - modules.surface.line.hits} of ${modules.surface.line.hits + modules.surface.line.misses} runs`);
console.log(`               ${precision.shifted.hits} hit, ${precision.shifted.misses} miss (${precision.shifted.names.join(', ')}) for an edit in main: the modules after it are re-spelled`);
console.log(`(c) flags      --overflow=wrap: ${flagProof.wrapped.hits} hit, ${flagProof.wrapped.misses} miss; back: ${flagProof.back.misses} miss`);
console.log(`(d) interface  warm ${interfaceProof.warm.hits} hit; a tampered interface is refused; restored: ${interfaceProof.after.hits} hit, ${interfaceProof.after.misses} miss`);
console.log(`(e) corruption helper entry: ${corruption.rebuilt.hits} hit, ${corruption.rebuilt.misses} miss (${corruption.rebuilt.names.join(', ')}); healed: ${corruption.healed.misses} miss; image: ${corruption.afterImage.what}`);
console.log(`(f) pruning    --keep 0 after an edit dropped ${pruning.pruned.records} records and ${pruning.pruned.blobs} blobs; next build ${pruning.again.hits} hit, ${pruning.again.misses} miss`);
console.log('');
console.log('build cache verified');
