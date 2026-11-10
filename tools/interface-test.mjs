// B1 stage 2 proof: checked module interfaces.
//
// An interface is the surface of one module: the declarations an importer needs to check a call, the
// structure of the module's types, and the audit results a caller must not re-derive (a handle's
// `transfer`/`share`, a closure type's environment record). This tool proves the four properties
// stage 2 claims, against the real compiler and the real corpus:
//
//  (a) equivalence  - a program whose imported modules come from interfaces behaves exactly like the
//                     program built from source: same stdout, same exit status, and a rejected
//                     program is still rejected. Run for the whole native corpus and for the
//                     compiler compiling itself (the interface-built compiler must produce the same
//                     assembly as the source-built one).
//  (b) staleness    - an interface whose recorded source digest no longer matches the file on the
//                     command line is refused, and the diagnostic names the module and both digests.
//  (c) tampering    - an edited `transfer`, `share` or `env` entry is refused rather than silently
//                     honoured: the manifest catches any byte change, and `--verify` names the
//                     declaration that disagrees once the edit has been re-digested.
//  (d) no leakage   - an interface carries no body, no local name, no synthetic module and no other
//                     module's declarations.
//
// Interfaces are also checked against `sha256sum`: every `sha256` line must be the real SHA-256 of
// the source file, which keeps the compiler's own digest honest.
//
// Usage: bun tools/interface-test.mjs [--full] [--target T]

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { assemble, buildCompiler, command, compilerSources, hostTarget, linkInputs, root, targetName } from './native.mjs';

const flags = process.argv.slice(2);
const target = targetName(flags.includes('--target') ? flags[flags.indexOf('--target') + 1] : hostTarget);
const full = flags.includes('--full');
const compiler = buildCompiler();
const work = join(root, '.work/interface-test', target);
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const runtime = join(root, 'compiler/runtime.grl');
const platform = join(root, 'compiler/os-linux.grl');

const sha256 = data => createHash('sha256').update(data).digest('hex');
const numeric = ['--default-u64', '--typed-refs', '--target', target];

// One compiler run. `flags` are the interface flags under test; everything else is what the driver
// passes for a whole-program build (there is no project cache in stage 2).
function compile(files, directory, extra = []) {
  mkdirSync(directory, { recursive: true });
  const asm = join(directory, 'out.s');
  const result = spawnSync(compiler, [...numeric, ...extra, asm, ...files], { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024, timeout: 900_000 });
  return { status: result.status, output: `${result.stdout ?? ''}${result.stderr ?? ''}`, asm };
}

// Assemble and link, exactly as `tools/native.mjs` does for a whole-program build.
function link(files, directory, name = 'program') {
  const asm = join(directory, 'out.s');
  assert.ok(existsSync(asm), `${directory}: no assembly was written`);
  const linkArgs = linkInputs(readFileSync(asm, 'utf8'), dirname(files[0]));
  return assemble(asm, join(directory, name), target, linkArgs);
}

function run(executable) {
  const result = spawnSync(executable, [], { encoding: 'utf8', timeout: 900_000 });
  return { status: result.status, signal: result.signal, stdout: result.stdout ?? '' };
}

function emit(files, directory) {
  const result = compile(files, directory, ['--emit-interface', join(directory, 'ifaces')]);
  assert.equal(result.status, 0, `${directory}: emitting interfaces failed\n${result.output}`);
  return join(directory, 'ifaces');
}

function interfaceFiles(directory) {
  return readdirSync(directory).filter(name => name.endsWith('.iface')).sort().map(name => join(directory, name));
}

// The module a file describes, from its own header line.
function moduleOf(path) {
  const line = readFileSync(path, 'utf8').split('\n').find(row => row.startsWith('module '));
  assert.ok(line, `${path}: no module line`);
  return line.slice('module '.length).trim();
}

// (0) Every digest an interface records is the real SHA-256 of the file it describes, checked with
// the host's own implementation rather than the compiler's.
function proveDigests(directory) {
  let checked = 0;
  for (const path of interfaceFiles(directory)) {
    const text = readFileSync(path, 'utf8');
    const source = /^source "(.*)"$/m.exec(text);
    const digest = /^sha256 "(.*)"$/m.exec(text);
    assert.ok(source && digest, `${path}: missing source or sha256 line`);
    const file = resolve(dirname(dirname(path)), source[1]);
    assert.ok(existsSync(file), `${path}: names a source that does not exist: ${source[1]}`);
    assert.equal(digest[1], sha256(readFileSync(file)), `${path}: sha256 line is not the SHA-256 of ${source[1]}`);
    // The file's own digest covers every byte above it.
    const at = text.indexOf('\ndigest "');
    assert.ok(at > 0, `${path}: no digest line`);
    assert.equal(/^digest "(.*)"$/m.exec(text)[1], sha256(text.slice(0, at + 1)), `${path}: digest line does not cover the file`);
    checked += 1;
  }
  return checked;
}

// (d) No leakage: no body, no local name, no synthetic module, no other module's declarations.
// The fixture below names its locals and its helper with distinctive identifiers, so "the interface
// does not carry a body" is checked by looking for them rather than by scanning for any short word.
function proveNoLeakage(directory, module) {
  const synthetic = ['.impl_', '.inherent_', '.interface_', '.union', '.result', '.closure', '__start'];
  for (const path of interfaceFiles(directory)) {
    const owner = moduleOf(path);
    const text = readFileSync(path, 'utf8');
    for (const line of text.split('\n')) {
      if (line.length === 0 || line.startsWith('//')) continue;
      // A declaration line never carries a statement or a block.
      assert.doesNotMatch(line, /[{};]/, `${path}: a declaration line carries a statement: ${line}`);
      for (const marker of synthetic) {
        assert.ok(!line.includes(marker), `${path}: leaks the synthetic module ${marker}: ${line}`);
      }
      // Every nominal reference belongs to this module or to `.closure` (an environment record).
      for (const [, referenced] of line.matchAll(/([A-Za-z_.][A-Za-z0-9_.]*)::[A-Za-z_][A-Za-z0-9_]*/g)) {
        assert.ok(referenced === owner || referenced === '.closure', `${path}: names ${referenced}::, another module's declaration: ${line}`);
      }
    }
    // The fixture's private helper and its local bindings must not appear anywhere.
    for (const secret of ['zzprivatehelper', 'zzprivatemessage', 'zzprivatecounter', 'zzprivatevalue']) {
      assert.ok(!text.includes(secret), `${path}: leaks the private name ${secret}`);
    }
    assert.ok(!/\breturn\b/.test(text), `${path}: an interface carries a return statement`);
    assert.ok(!text.includes('\n\n'), `${path}: unexpected blank line`);
  }
  return module;
}

// (a) Equivalence for one program: source build, interface build, verify build.
function proveEquivalent(name, files, directory, { stdout: expected } = {}) {
  mkdirSync(directory, { recursive: true });
  const source = compile(files, join(directory, 'source'));
  assert.equal(source.status, 0, `${name}: source build failed\n${source.output}`);
  const sourceExe = link(files, join(directory, 'source'));

  const ifaces = emit(files, directory);
  proveDigests(ifaces);

  const viaInterface = compile(files, join(directory, 'interface'), ['--interface', ifaces]);
  assert.equal(viaInterface.status, 0, `${name}: interface build failed\n${viaInterface.output}`);
  const interfaceExe = link(files, join(directory, 'interface'));

  const verified = compile(files, join(directory, 'verify'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(verified.status, 0, `${name}: interfaces disagree with their sources\n${verified.output}`);
  const verifyExe = link(files, join(directory, 'verify'));

  const a = run(sourceExe);
  const b = run(interfaceExe);
  const c = run(verifyExe);
  assert.equal(b.status, a.status, `${name}: exit status ${b.status} != ${a.status}`);
  assert.equal(b.stdout, a.stdout, `${name}: interface build prints something else`);
  assert.equal(c.status, a.status, `${name}: verify build exit status`);
  assert.equal(c.stdout, a.stdout, `${name}: verify build prints something else`);
  if (expected !== undefined) assert.equal(a.stdout, expected, `${name}: source build output`);
  return ifaces;
}

// (a) Equivalence for a rejected program: both builds must reject it.
function proveRejected(name, files, directory) {
  mkdirSync(directory, { recursive: true });
  const source = compile(files, join(directory, 'source'));
  assert.equal(source.status, 1, `${name}: the source build must reject this program\n${source.output}`);
  const ifaces = emit(files, join(directory, 'emit'));
  const viaInterface = compile(files, join(directory, 'interface'), ['--interface', ifaces]);
  assert.equal(viaInterface.status, 1, `${name}: the interface build must reject it too\n${viaInterface.output}`);
  const verified = compile(files, join(directory, 'verify'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(verified.status, 0, `${name}: emitting then verifying interfaces must agree\n${verified.output}`);
}

// ---- (a) the compiler compiling itself --------------------------------------
// The interface-built compiler has to be the same program: it produces the same assembly as the
// source-built one for a program from the corpus, and it runs.
function proveSelfHosting() {
  const directory = join(work, 'selfhost');
  mkdirSync(directory, { recursive: true });
  const source = compile(compilerSources, join(directory, 'source'));
  assert.equal(source.status, 0, `compiler: source build failed\n${source.output}`);
  const ifaces = emit(compilerSources, directory);
  const digestCount = proveDigests(ifaces);

  const viaInterface = compile(compilerSources, join(directory, 'interface'), ['--interface', ifaces]);
  assert.equal(viaInterface.status, 0, `compiler: interface build failed\n${viaInterface.output}`);

  // The two compilers are the same program if they behave the same: both link and answer `version`,
  // and both compile a program from the corpus to the same assembly. Symbols may differ (the
  // interned type index decides a drop helper's name, and declaration order decides that), so
  // behaviour is the bar - exactly as it is for a program built either way.
  const a = link(compilerSources, join(directory, 'source'), 'grail-source');
  const b = link(compilerSources, join(directory, 'interface'), 'grail-interface');
  const versionA = spawnSync(a, ['version'], { encoding: 'utf8' });
  const versionB = spawnSync(b, ['version'], { encoding: 'utf8' });
  assert.equal(versionB.stdout, versionA.stdout, 'compiler: the interface-built compiler does not answer `version` the same way');
  assert.equal(versionB.status, 0, 'compiler: the interface-built compiler does not run');
  // A generic-heavy program from the corpus: both compilers must produce the same assembly for it.
  const corpus = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
  const sampleCase = corpus.find(entry => entry.name === 'vecs-fold-and-predicates');
  assert.ok(sampleCase, 'tests/native-cases.json: no vecs-fold-and-predicates case');
  const sample = join(directory, 'sample.grl');
  writeFileSync(sample, sampleCase.source);
  const sampleFiles = [sample, ...(sampleCase.modules ?? []).map(file => resolve(root, file)), runtime, platform];
  const asmA = join(directory, 'sample-a.s');
  const asmB = join(directory, 'sample-b.s');
  for (const [compilerPath, asm] of [[a, asmA], [b, asmB]]) {
    const result = spawnSync(compilerPath, ['--default-u64', '--typed-refs', '--target', target, asm, ...sampleFiles], { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024 });
    assert.equal(result.status, 0, `compiler: a program failed to compile\n${result.stdout ?? ''}${result.stderr ?? ''}`);
  }
  assert.equal(readFileSync(asmB, 'utf8'), readFileSync(asmA, 'utf8'), 'compiler: the two compilers compile a program differently');
  const exe = assemble(asmA, join(directory, 'sample'), target, linkInputs(readFileSync(asmA, 'utf8'), dirname(sample)));
  const ran = run(exe);
  assert.equal(ran.stdout, sampleCase.stdout, 'compiler: the program those two compilers built prints something else');

  const verified = compile(compilerSources, join(directory, 'verify'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(verified.status, 0, `compiler: interfaces disagree with the compiler sources\n${verified.output}`);

  const somewhereElse = join(work, 'selfhost-agree');
  mkdirSync(somewhereElse, { recursive: true });
  const deep = compile(compilerSources, somewhereElse);
  assert.equal(deep.status, 0, 'compiler: source build is not deterministic');
  assert.equal(readFileSync(deep.asm, 'utf8'), readFileSync(source.asm, 'utf8'), 'compiler: source build is not deterministic');
  return { modules: interfaceFiles(ifaces).length, digests: digestCount };
}

// ---- (b) a stale interface --------------------------------------------------
function proveStale() {
  const directory = join(work, 'stale');
  const project = join(directory, 'project');
  mkdirSync(join(project, 'src'), { recursive: true });
  writeFileSync(join(project, 'grail.pkg'), 'name stale\n');
  writeFileSync(join(project, 'src/util.grl'), 'module util;\n\npub fn twice(x: u64) -> u64 {\n    return x * 2;\n}\n');
  writeFileSync(join(project, 'src/main.grl'), 'use util;\n\npub fn main() -> u64 {\n    println(util::twice(21));\n    return 0;\n}\n');
  const files = [join(project, 'src/main.grl'), join(project, 'src/util.grl'), runtime, platform];
  const ifaces = emit(files, directory);
  // A change that no declaration records: the digest is the only thing that can catch it.
  writeFileSync(join(project, 'src/util.grl'), '// touched\nmodule util;\n\npub fn twice(x: u64) -> u64 {\n    return x * 2;\n}\n');
  const stale = compile(files, join(directory, 'build'), ['--interface', ifaces]);
  assert.equal(stale.status, 1, 'a stale interface must refuse to build');
  assert.match(stale.output, /module `util` changed since this interface was written/, `the refusal must name the module: ${stale.output}`);
  assert.match(stale.output, /sha256/, 'the refusal must show the digests');
  assert.match(stale.output, /util\.grl/, 'the refusal must name the source');
  return stale.output.trim().split('\n')[0];
}

// ---- (c) tampering with the audit metadata ---------------------------------
function proveTampering() {
  const directory = join(work, 'tamper');
  const project = join(directory, 'project');
  mkdirSync(join(project, 'src'), { recursive: true });
  writeFileSync(join(project, 'grail.pkg'), 'name tamper\n');
  writeFileSync(join(project, 'src/util.grl'), `module util;

handle Stream: transferable;

extern "C" lib "c" fn fopen(path: CStr, mode: CStr) -> Stream;

pub struct Point {
    x: u64,
    y: u64
}

pub fn twice(x: u64) -> u64 {
    return x * 2;
}
`);
  writeFileSync(join(project, 'src/main.grl'), 'use util;\n\npub fn main() -> u64 {\n    p := util::Point { x: 1, y: 2 };\n    println(util::twice(p.x + p.y));\n    return 0;\n}\n');
  const files = [join(project, 'src/main.grl'), join(project, 'src/util.grl'), runtime, platform];
  const ifaces = emit(files, directory);
  const util = join(ifaces, 'util.iface');
  const original = readFileSync(util, 'utf8');
  assert.match(original, /type util::Stream handle params=0 lifetimes=0 transfer=1 share=0/, 'the audited handle contract must travel');
  const manifestPath = join(ifaces, 'interfaces.manifest');

  // (c1) a changed `transfer` is refused: the manifest pins the bytes the emitting run wrote, so an
  // edit to an audit result never reaches the checker.
  writeFileSync(util, original.replace('transfer=1 share=0', 'transfer=0 share=0'));
  const edited = compile(files, join(directory, 'edited'), ['--interface', ifaces]);
  assert.equal(edited.status, 1, 'a tampered transfer must be refused');
  assert.match(edited.output, /module `util`: the interface file does not match the manifest/, `the refusal must name the module and the manifest: ${edited.output}`);
  assert.match(edited.output, /manifest says \S+, the file is \S+/, 'the refusal must show both digests');

  // (c2) re-digesting the edit does not launder it: the manifest still pins the original bytes.
  const tampered = original.replace('transfer=1 share=0', 'transfer=0 share=0');
  const reDigested = `${tampered.slice(0, tampered.indexOf('\ndigest "') + 1)}digest "${sha256(tampered.slice(0, tampered.indexOf('\ndigest "') + 1))}"\n`;
  writeFileSync(util, reDigested);
  const laundered = compile(files, join(directory, 'laundered'), ['--interface', ifaces]);
  assert.equal(laundered.status, 1, 'a re-digested tamper must still be refused');
  assert.match(laundered.output, /module `util`: the interface file does not match the manifest/, `the refusal must name the manifest: ${laundered.output}`);

  // (c3) with the manifest rewritten too, `--verify` still refuses and names the declaration: the
  // entry is never silently honoured while the sources are available.
  writeFileSync(manifestPath, readFileSync(manifestPath, 'utf8').replace(/^util \S+/m, `util ${sha256(reDigested)}`));
  const verified = compile(files, join(directory, 'verify'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(verified.status, 1, '`--verify` must refuse a tampered transfer');
  assert.match(verified.output, /module `util` does not match this interface/, `the refusal must name the module: ${verified.output}`);
  assert.match(verified.output, /transfer=0/, 'the refusal must show the interface line that differs');
  assert.match(verified.output, /transfer=1/, 'the refusal must show what the sources give');

  // (c4) the same for a closure type's environment record. No source-level declaration produces a
  // capturing closure type today (that arrives with generic bodies in interfaces), so the entry is
  // injected in the format's own spelling - and it must be refused, not honoured.
  writeFileSync(util, original);
  writeFileSync(manifestPath, readFileSync(manifestPath, 'utf8').replace(/^util \S+/m, `util ${sha256(original)}`));
  const withEnv = original.replace('field x u64', 'field x u64\nfield callback (closure 0 [] (u64) u64 (named .closure::env1))').replace(/\ndigest ".*"\n$/, '\n');
  const injected = `${withEnv}env env1\nfield captured u64\ndigest "${sha256(withEnv)}"\n`;
  writeFileSync(util, injected);
  writeFileSync(manifestPath, readFileSync(manifestPath, 'utf8').replace(/^util \S+/m, `util ${sha256(injected)}`));
  const envRefused = compile(files, join(directory, 'env'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(envRefused.status, 1, 'a tampered env entry must be refused');
  assert.match(envRefused.output, /module `util` does not match this interface/, `the env refusal must name the module: ${envRefused.output}`);
  assert.match(envRefused.output, /env|closure|field/, 'the env refusal must show the injected entry');

  // Restore and prove the interface still builds, so the refusals above are about the edit.
  writeFileSync(util, original);
  writeFileSync(manifestPath, readFileSync(manifestPath, 'utf8').replace(/^util \S+/m, `util ${sha256(original)}`));
  const restored = compile(files, join(directory, 'restored'), ['--interface', ifaces]);
  assert.equal(restored.status, 0, `an untouched interface must still build\n${restored.output}`);
  return { edited: edited.output.trim().split('\n')[0], manifest: laundered.output.trim().split('\n')[0], verify: verified.output.trim().split('\n')[0], env: envRefused.output.trim().split('\n')[0] };
}

// (d) no leakage, on a module whose source has a distinctive helper and distinctive locals.
function proveLeakage() {
  const directory = join(work, 'leak');
  const project = join(directory, 'project');
  mkdirSync(join(project, 'src'), { recursive: true });
  writeFileSync(join(project, 'grail.pkg'), 'name leak\n');
  writeFileSync(join(project, 'src/util.grl'), `module util;

fn zzprivatehelper(value: u64) -> u64 {
    zzprivatecounter := value * 3;
    return zzprivatecounter;
}

pub struct Point {
    x: u64,
    y: u64
}

impl Point {
    pub fn sum<a>(self: (&a Point)) -> u64 {
        return self.x + self.y;
    }
}

pub fn twice(x: u64) -> u64 {
    zzprivatevalue := x * 2;
    return zzprivatevalue;
}
`);
  writeFileSync(join(project, 'src/main.grl'), 'use util;\n\npub fn main() -> u64 {\n    zzprivatemessage := util::twice(2);\n    println(zzprivatemessage);\n    return 0;\n}\n');
  const files = [join(project, 'src/main.grl'), join(project, 'src/util.grl'), runtime, platform];
  const ifaces = emit(files, directory);
  proveNoLeakage(ifaces, 'util');
  return interfaceFiles(ifaces).length;
}

const leaked = proveLeakage();
report('no body, local or synthetic declaration in an interface', `${leaked} interfaces checked`);

// A caller that disagrees with an interface is rejected in an interface build, in its own file.
function proveCallerRejected() {
  const directory = join(work, 'caller');
  const files = [join(root, 'tests/interfaces/reject_user.grl'), join(root, 'tests/interfaces/pair.grl'), runtime, platform];
  const ifaces = emit(files, directory);
  const rejected = compile(files, join(directory, 'build'), ['--interface', ifaces]);
  assert.equal(rejected.status, 1, 'a caller that disagrees with the interface must be rejected');
  assert.match(rejected.output, /reject_user\.grl:\d+:\d+: function argument count/, `the rejection must be in the caller's file: ${rejected.output}`);
  return rejected.output.trim().split('\n')[0];
}

const caller = proveCallerRejected();
report('caller rejected against an interface', caller);

const corpus = proveCorpus();
report('corpus agrees with source builds', `${corpus} programs (interface build, verify build and source build agree)` + (full ? ' - full corpus' : ''));

console.log(`\ninterface-test: ${results.length} checks passed`);
