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
//
// The corpus part runs in GRAIL_JOBS processes (default 8), each taking every Nth case and writing to
// its own directories, while this one runs the other proofs; the cases and their verdicts are the
// same in any number of processes. GRAIL_TEST_FILTER=REGEX runs only the corpus cases whose name
// matches, and none of the other proofs - the retry of a failed corpus case.

import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { assemble, buildCompiler, command, compilerSources, emulations, hostTarget, linkInputs, root, targetName, triples } from './native.mjs';

const flags = process.argv.slice(2);
const target = targetName(flags.includes('--target') ? flags[flags.indexOf('--target') + 1] : hostTarget);
const full = flags.includes('--full');
const compiler = buildCompiler();
// `--corpus-stripe K/N`: a corpus worker of the run that started it (proveCorpusParallel).
const stripeAt = flags.indexOf('--corpus-stripe');
const stripe = stripeAt >= 0 ? flags[stripeAt + 1].split('/').map(Number) : null;
const filter = process.env.GRAIL_TEST_FILTER ? new RegExp(process.env.GRAIL_TEST_FILTER) : null;
const work = join(root, '.work/interface-test', target);
if (!stripe) rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const runtime = join(root, 'compiler/runtime.grl');
const platform = join(root, 'compiler/os-linux.grl');

const sha256 = data => createHash('sha256').update(data).digest('hex');
const numeric = ['--target', target];

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

const clip = (text, limit = 400) => (typeof text === 'string' && text.length > limit ? `${text.slice(0, limit)}...` : text);
function run(executable, args = [], options = {}) {
  // A generous output buffer: a program that prints more than node's 1 MB default is killed by the
  // spawn, which looks like a null status and a signal rather than like the program's own answer.
  const result = spawnSync(executable, args, { encoding: 'utf8', timeout: 900_000, maxBuffer: 64 * 1024 * 1024, ...options });
  return { status: result.status, signal: result.signal, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

// Describing a module is not making a program: `--no-entry` lets a run emit the interfaces of the
// modules it has without also needing the entry module among them.
function emit(files, directory) {
  const result = compile(files, directory, ['--emit-interface', join(directory, 'ifaces'), '--no-entry']);
  assert.equal(result.status, 0, `${directory}: emitting interfaces failed\n${result.output}`);
  return join(directory, 'ifaces');
}

function interfaceFiles(directory) {
  return readdirSync(directory).filter(name => name.endsWith('.iface')).sort().map(name => join(directory, name));
}

// The typed record tree, as `grail iface dump` renders it: what the reader read, field by field.
// The dump is the inspector - there is no second parser behind it, so what this test asserts about a
// declaration is exactly what the compiler installed from that declaration.
function dump(path) {
  const result = spawnSync(compiler, [...numeric, '--iface-dump', path], { encoding: 'utf8', timeout: 900_000 });
  assert.equal(result.status, 0, `${path}: dump failed\n${result.stdout ?? ''}${result.stderr ?? ''}`);
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

// The module a file describes, from its own header record.
function moduleOf(path) {
  const line = dump(path).split('\n').find(row => row.startsWith('module '));
  assert.ok(line, `${path}: no module record`);
  return line.slice('module '.length).trim();
}

// The format, as docs/design/separate-compilation.md states it: `GRIF`, one version byte, then
// `tag, length, payload` records, then a trailer whose last 32 bytes are the SHA-256 of everything
// before them. This reads that framing - nothing else - so a test can tamper with one field on
// purpose and prove the compiler refuses the file rather than honouring or misreading it.
function frame(bytes) {
  const records = [];
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
    records.push({ tag, tagAt, lenAt, at, len, end: at + len });
    at += len;
    if (tag === 2) break;
  }
  return records;
}

// A cursor over one record payload: a length-prefixed string, one byte, and LEB128.
function payload(bytes, record) {
  let at = record.at;
  const varint = () => {
    let n = 0;
    let scale = 1;
    for (;;) {
      const b = bytes[at];
      at += 1;
      n += (b & 127) * scale;
      if (!(b & 128)) return n;
      scale *= 128;
    }
  };
  return {
    var: varint,
    byte: () => bytes[at++],
    str: () => {
      const n = varint();
      const out = bytes.subarray(at, at + n);
      at += n;
      return out;
    },
    get at() { return at; },
  };
}

// Recompute the trailer's digest, so an edit reaches the reader instead of stopping at the seal.
function seal(bytes) {
  const body = Buffer.from(bytes.subarray(0, bytes.length - 32));
  createHash('sha256').update(body).digest().copy(bytes, bytes.length - 32);
  return bytes;
}

// A cursor just past the identity of the `type` record that declares `module::name`.
function typeRecord(bytes, module, name) {
  for (const record of frame(bytes)) {
    if (record.tag !== 10) continue;
    const r = payload(bytes, record);
    if (r.str().toString() !== module) continue;
    if (r.str().toString() !== name) continue;
    r.byte();
    r.byte();
    r.var();
    r.var();
    return r;
  }
  assert.fail(`${module}::${name}: no type record`);
}

// A cursor that skips the length-counted fields the record stream is made of, so a test can reach
// one field (the effects row) and change it. This is the same framing `frame` reads, nothing more.
function skipVar(bytes, at) {
  for (;;) {
    const b = bytes[at];
    at += 1;
    if (!(b & 128)) return at;
  }
}
function readVar(bytes, at) {
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
function skipStr(bytes, at) {
  const [n, next] = readVar(bytes, at);
  return next + n;
}
function skipType(bytes, at) {
  const [n, next] = readVar(bytes, at + 1);
  return next + n;
}
function writeVar(n) {
  const out = [];
  let v = n;
  while (v > 127) {
    out.push((v & 127) | 128);
    v >>>= 7;
  }
  out.push(v);
  return Buffer.from(out);
}
// Replace one record's payload with `body`, re-encoding the tag and the length around it: how a test
// builds the file a slightly different writer would have produced.
function replacePayload(bytes, record, body) {
  return Buffer.concat([
    bytes.subarray(0, record.tagAt),
    Buffer.from([record.tag]),
    writeVar(body.length),
    body,
    bytes.subarray(record.end),
  ]);
}
// The payload offsets of one function record: its effects bytes and the start of its body field.
function fnLayout(bytes, name) {
  for (const record of frame(bytes)) {
    if (record.tag !== 13) continue;
    const p = payload(bytes, record);
    if (p.str().toString() !== name) continue;
    const at = effectsAt(bytes, p.at);
    return { record, noAlloc: at.noAlloc, noPanic: at.noPanic, body: at.noPanic + 1 };
  }
  assert.fail(`no function record named ${name}`);
}
// Where the `no_alloc` and `no_panic` bytes of one function's record are.
function effectsAt(bytes, from) {
  let at = from;
  at += 1; // public
  at = skipVar(bytes, at); // generic parameters
  at = skipVar(bytes, at); // lifetimes
  at = skipVar(bytes, at); // extern kind
  at = skipStr(bytes, at); // extern symbol
  at += 1; // @strict
  const [params, afterParams] = readVar(bytes, at);
  at = afterParams;
  for (let i = 0; i < params; i += 1) at = skipType(bytes, at);
  at = skipType(bytes, at); // result
  const [bounds, afterBounds] = readVar(bytes, at);
  at = afterBounds;
  for (let i = 0; i < bounds; i += 1) {
    at = skipVar(bytes, at);
    at = skipVar(bytes, at);
  }
  const [required, afterReqs] = readVar(bytes, at);
  at = afterReqs;
  for (let i = 0; i < required; i += 1) {
    at = skipVar(bytes, at);
    const [refs, afterRefs] = readVar(bytes, at);
    at = afterRefs;
    for (let j = 0; j < refs; j += 1) {
      at = skipStr(bytes, at);
      at = skipStr(bytes, at);
    }
  }
  const [wheres, afterWhere] = readVar(bytes, at);
  at = afterWhere;
  for (let i = 0; i < wheres; i += 1) {
    at = skipVar(bytes, at);
    at = skipStr(bytes, at);
    at = skipStr(bytes, at);
  }
  // The sparse parameter rows: index, name, default text.
  const [args, afterArgs] = readVar(bytes, at);
  at = afterArgs;
  for (let i = 0; i < args; i += 1) {
    at = skipVar(bytes, at);
    at = skipStr(bytes, at);
    at = skipStr(bytes, at);
  }
  at = skipStr(bytes, at); // ensures
  return { noAlloc: at, noPanic: at + 1 };
}

// (0) Every digest an interface records is the real SHA-256 of what it covers, checked with the
// host's own implementation rather than the compiler's: the source the header names, the trailer's
// digest over every byte before it, and - through the compiler's own reader - byte-identical
// round-trip equality.
function proveDigests(directory) {
  let checked = 0;
  for (const path of interfaceFiles(directory)) {
    const text = dump(path);
    const source = /^source "(.*)"$/m.exec(text);
    const digest = /^sha256 "(.*)"$/m.exec(text);
    assert.ok(source && digest, `${path}: missing source or sha256 record`);
    const file = resolve(dirname(dirname(path)), source[1]);
    assert.ok(existsSync(file), `${path}: names a source that does not exist: ${source[1]}`);
    assert.equal(digest[1], sha256(readFileSync(file)), `${path}: sha256 record is not the SHA-256 of ${source[1]}`);
    // The trailer's digest covers every byte before it.
    const bytes = readFileSync(path);
    assert.ok(bytes.length > 32, `${path}: too short to carry a trailer`);
    const body = Buffer.from(bytes.subarray(0, bytes.length - 32));
    assert.equal(bytes.subarray(bytes.length - 32).toString('hex'), sha256(body), `${path}: the trailer's digest does not cover the file`);
    // Every interface states the ABI a `&dyn I` is built for, in dynfat's spelling, so a module
    // built against another layout cannot link: the pair one writes would be the pair the other
    // dereferences wrongly.
    assert.match(
      text,
      /^abi dyn pair size = 16 align = 8 word0 = data word1 = vtable drop = 0 ref record = address record plain = inline plain record = frame args = 6 registers then stack$/m,
      `${path}: the header does not state the \`dyn\` ABI`,
    );
    // Write, read, write again: the reader rebuilds the model the writer started from.
    const round = spawnSync(compiler, [...numeric, '--iface-roundtrip', path], { encoding: 'utf8', timeout: 900_000 });
    assert.equal(round.status, 0, `${path}: does not round-trip\n${round.stdout ?? ''}${round.stderr ?? ''}`);
    assert.match(round.stdout ?? '', /^identical \d+ bytes$/m, `${path}: round-trip did not report equality`);
    checked += 1;
  }
  return checked;
}

// (d0) the manifest is the set, not only a checksum list: a source module the manifest does not
// describe is refused by name. This is the guard against the class of bug where an emitting run's
// source list and the set it wrote disagreed - the module then had no interface file at all, and the
// disagreement only surfaced one module later as an unknown name in somebody else's module (the
// compiler built against its own modules, `lexer.iface` missing).
function proveManifestCoverage() {
  const directory = join(work, 'coverage');
  const project = join(directory, 'project');
  mkdirSync(join(project, 'src'), { recursive: true });
  writeFileSync(join(project, 'src/util.grl'), 'module util;\n\npub fn twice(x: u64) -> u64 {\n    return x * 2;\n}\n');
  writeFileSync(join(project, 'src/helper.grl'), 'module helper;\n\npub fn bump(x: u64) -> u64 {\n    return x + 7;\n}\n');
  writeFileSync(join(project, 'src/main.grl'), 'use util;\nuse helper;\n\npub fn main() -> u64 {\n    println(util::twice(helper::bump(3)));\n    return 0;\n}\n');
  const files = [join(project, 'src/main.grl'), join(project, 'src/util.grl'), join(project, 'src/helper.grl'), runtime, platform];
  const ifaces = emit(files, directory);
  const manifestPath = join(ifaces, 'interfaces.manifest');
  const original = readFileSync(manifestPath, 'utf8');
  const rows = original.split('\n').filter(row => row.length !== 0 && !row.startsWith('//'));
  assert.equal(rows.length, 3, `the emitting run must list every source module of the program: ${original}`);
  // Delete one module's row - the interface file stays, so only the manifest can catch it - and the
  // consuming run must name the module it can no longer account for.
  const dropped = rows.find(row => row.startsWith('util '));
  assert.ok(dropped, `no util row in the manifest: ${original}`);
  writeFileSync(manifestPath, `// grail-interfaces 1\n${rows.filter(row => row !== dropped).join('\n')}\n`);
  const refused = compile(files, join(directory, 'build'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(refused.status, 1, `a manifest missing a source module must be refused\n${refused.output}`);
  assert.match(refused.output, /has no interface for module `util`/, `the refusal must name the missing module: ${refused.output}`);
  assert.match(refused.output, /util\.iface/, 'the refusal must name the file it expected');
  // `--interface DIR` is a verification build (`--verify-interface` only says so explicitly), so the
  // reading is the same for the directory's last row: a manifest that does not describe a source
  // module of the run is refused by name, never silently filled in from the module's source.
  const entryRow = rows.find(row => row.startsWith('main '));
  assert.ok(entryRow, `no main row in the manifest: ${original}`);
  writeFileSync(manifestPath, `// grail-interfaces 1\n${rows.filter(row => row !== entryRow).join('\n')}\n`);
  const entryRefused = compile(files, join(directory, 'entry'), ['--interface', ifaces]);
  assert.equal(entryRefused.status, 1, `a manifest without the entry module is refused too\n${entryRefused.output}`);
  assert.match(entryRefused.output, /has no interface for module `main`/, `the refusal must name the entry: ${entryRefused.output}`);
  // Restored, the same sources build: the refusals above are about the missing rows.
  writeFileSync(manifestPath, original);
  const restored = compile(files, join(directory, 'restored'), ['--interface', ifaces]);
  assert.equal(restored.status, 0, `an untouched manifest must build\n${restored.output}`);
  return refused.output.trim().split('\n')[0];
}

// (d) No leakage, and the one thing stage 3 does add: a generic template's own body, as `|` rows
// under the `fn` record that carries its signature. The claim is asserted on the dump - the record
// tree as the reader read it - so it is the engine's view of the file that is checked: a
// *declaration* line carries no body, no local name and no other module's declaration, and a body
// appears only under a template that declares type parameters. The fixture names its locals and its
// helper with distinctive identifiers, so "the interface does not carry a body" is checked by looking
// for them rather than by scanning for any short word.
function proveNoLeakage(directory, module) {
  const synthetic = ['.impl_', '.inherent_', '.interface_', '.union', '.result', '__start'];
  for (const path of interfaceFiles(directory)) {
    const owner = moduleOf(path);
    const text = dump(path);
    const rows = text.split('\n');
    const declaration = rows.filter(row => !row.trimStart().startsWith('|')).join('\n');
    for (const line of rows) {
      if (line.length === 0) continue;
      if (/^(grail-interface|module|source|mode|sha256|digest) /.test(line)) continue;
      if (/^(std|unsafe|host) \d+$/.test(line)) continue;
      // A body row: the template's own text, one `|` row per source line and nothing else.
      if (line.trimStart().startsWith('|')) continue;
      // A declaration or field line never carries a statement or a block.
      assert.doesNotMatch(line, /[{};]/, `${path}: a declaration line carries a statement: ${line}`);
      for (const marker of synthetic) {
        assert.ok(!line.includes(marker), `${path}: leaks the synthetic module ${marker}: ${line}`);
      }
      // Every nominal reference belongs to this module or to `.closure` (an environment record).
      for (const [, referenced] of line.matchAll(/([A-Za-z_.][A-Za-z0-9_.]*)::[A-Za-z_][A-Za-z0-9_]*/g)) {
        assert.ok(referenced === owner || referenced === '.closure', `${path}: names ${referenced}::, another module's declaration: ${line}`);
      }
    }
    // No binding, no local and no function body crosses. Grail has no cross-module visibility rule
    // yet (`pub` marks the entry candidate and `--export`), so a non-pub *declaration* does appear -
    // its signature is what an importer can call anyway. What this pins is the rule that holds
    // today: a declaration, and nothing from inside it.
    const bytes = readFileSync(path);
    for (const secret of ['zzprivatemessage', 'zzprivatecounter', 'zzprivatevalue']) {
      assert.ok(!text.includes(secret), `${path}: leaks the local binding ${secret}`);
      assert.ok(!bytes.includes(secret), `${path}: the file carries the local binding ${secret}`);
    }
    assert.ok(!/zzprivatehelper\(.*\)[^{]*\{/.test(declaration), `${path}: leaks a function body`);
    assert.ok(!/\breturn\b/.test(declaration), `${path}: an interface carries a return statement on a declaration line`);
    // Bodies belong to templates and are the only place a `{` may appear.
    for (let i = 0; i < rows.length; i += 1) {
      if (rows[i].trim() !== 'body') continue;
      let at = i - 1;
      while (at >= 0 && !/^\s*fn /.test(rows[at])) at -= 1;
      assert.ok(at >= 0, `${path}: a body section that follows no function`);
      assert.match(rows[at], /^\s*fn \S+ <\d+>/, `${path}: a body section on a declaration that is not a template: ${rows[at]}`);
      let rows2 = 0;
      while (i + 1 + rows2 < rows.length && rows[i + 1 + rows2].trimStart().startsWith('|')) rows2 += 1;
      assert.ok(rows2 > 0, `${path}: a template with an empty body section`);
      i += rows2;
    }
  }
  return module;
}

// (a) Equivalence for one program: source build, interface build, verify build.
function proveEquivalent(name, files, directory, { stdout: expected, args = [], env = {} } = {}) {
  mkdirSync(directory, { recursive: true });
  const source = compile(files, join(directory, 'source'));
  assert.equal(source.status, 0, `${name}: source build failed\n${source.output}`);
  const sourceExe = link(files, join(directory, 'source'));

  const ifaces = emit(files, directory);
  proveDigests(ifaces);

  const viaInterface = compile(files, join(directory, 'interface'), ['--interface', ifaces]);
  assert.equal(viaInterface.status, 0, `${name}: interface build failed\n${viaInterface.output}`);
  const interfaceExe = link(files, join(directory, 'interface'));

  // The interface build generates the same program: code, data and symbol order, byte for byte. An
  // interface stands in for a module's declarations, and nothing else about the run changes.
  assert.equal(
    readFileSync(join(directory, 'interface', 'out.s'), 'utf8'),
    readFileSync(join(directory, 'source', 'out.s'), 'utf8'),
    `${name}: the interface build emits different assembly from the source build`,
  );
  const verified = compile(files, join(directory, 'verify'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(verified.status, 0, `${name}: interfaces disagree with their sources\n${verified.output}`);
  assert.equal(
    readFileSync(join(directory, 'verify', 'out.s'), 'utf8'),
    readFileSync(join(directory, 'source', 'out.s'), 'utf8'),
    `${name}: the --verify build emits different assembly from the source build`,
  );
  const verifyExe = link(files, join(directory, 'verify'));

  // A case's arguments and its working directory are part of what it tests (a fixture path, for
  // example), so both builds run exactly the way tests/native-cases.json runs them.
  const runOptions = { cwd: directory, env: env && Object.keys(env).length ? { ...process.env, ...env } : process.env };
  const a = run(sourceExe, args, runOptions);
  const b = run(interfaceExe, args, runOptions);
  const c = run(verifyExe, args, runOptions);
  assert.equal(b.status, a.status, `${name}: exit status ${b.status} != ${a.status} (signal ${b.signal})`);
  assert.equal(b.stdout, a.stdout, `${name}: interface build prints something else`);
  assert.equal(c.status, a.status, `${name}: verify build exit status (signal ${c.signal}, stderr ${JSON.stringify(clip(c.stderr))})`);
  assert.equal(c.stdout, a.stdout, `${name}: verify build prints something else`);
  if (expected !== undefined) assert.equal(a.stdout, expected, `${name}: source build output`);
  return ifaces;
}

// (a) Equivalence for a rejected program: both builds must reject it. Interfaces can only be
// emitted from a program that compiles, so a rejected program is split in two: its modules, which
// emit, and its call site, which must be rejected against them.
function proveRejected(name, files, directory) {
  mkdirSync(directory, { recursive: true });
  const source = compile(files, join(directory, 'source'));
  assert.equal(source.status, 1, `${name}: the source build must reject this program\n${source.output}`);
  // The emitting run may fail before it writes anything (a case rejected in its headers) or after
  // (one rejected in a body); either way the build against the interfaces has to reject as well,
  // rather than quietly compile something the source build refuses.
  const ifaces = join(directory, 'emit', 'ifaces');
  compile(files, join(directory, 'emit'), ['--emit-interface', ifaces]);
  const viaInterface = compile(files, join(directory, 'interface'), ['--interface', ifaces]);
  assert.equal(viaInterface.status, 1, `${name}: the interface build must reject it too\n${viaInterface.output}`);
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
    // The corpus case names no std file: `use vecs;` is resolved through the stdlib module root, the
    // same one `grail build` passes (docs/design/module-resolution.md).
    const result = spawnSync(compilerPath, ['--module-root', join(root, 'lib'), '--target', target, asm, ...sampleFiles], { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024 });
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
  writeFileSync(join(project, 'grail.toml'), '[package]\nname = "stale"\nversion = "0.1.0"\n');
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
// The interface is a typed record stream, so a tamper is a changed byte and the refusal is what the
// *reader* makes of it. Six layers, one limit stated rather than hidden:
//   (c0) the manifest is consulted at all;
//   (c1) an edit that was not re-sealed is refused by the file's own digest in the trailer;
//   (c2) re-sealing it does not launder it - the manifest pins the bytes that were written;
//   (c3) re-sealing *and* re-pinning the manifest gets past both, and `--verify` then refuses that
//        edit by declaration: an audit result is never silently honoured while the sources exist;
//   (c4) an old version, a truncated file and an unknown record are each refused by name;
//   (c5) a record one field longer - what a newer writer emitting a new field would produce - is
//        refused by length rather than misread, which is what the format needs to evolve at all.
function proveTampering() {
  const directory = join(work, 'tamper');
  const project = join(directory, 'project');
  mkdirSync(join(project, 'src'), { recursive: true });
  writeFileSync(join(project, 'grail.toml'), '[package]\nname = "tamper"\nversion = "0.1.0"\n');
  writeFileSync(join(project, 'src/util.grl'), `module util;

pub handle Stream: transferable;

pub extern "C" lib "c" fn fopen(path: CStr, mode: CStr) -> Stream;

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
  const original = readFileSync(util);
  // The audited handle contract travels, and the dump is where a reviewer reads it.
  assert.match(dump(util), /type util::Stream handle params=0 lifetimes=0 transfer=1 share=0/, 'the audited handle contract must travel');
  const manifestPath = join(ifaces, 'interfaces.manifest');
  const originalManifest = readFileSync(manifestPath, 'utf8');
  const pin = (text, digest) => text.replace(/^util \S+/m, `util ${digest}`);
  const repin = bytes => {
    writeFileSync(util, bytes);
    writeFileSync(manifestPath, pin(originalManifest, sha256(bytes)));
  };
  const restore = () => {
    writeFileSync(util, original);
    writeFileSync(manifestPath, originalManifest);
  };

  // (c0) the manifest is consulted at all: corrupt only its recorded digest, leave the interface
  // untouched, and the build must refuse. Without this, a tamper test can pass for the wrong reason
  // (the file's own digest catching an edit before the manifest is ever read).
  writeFileSync(manifestPath, pin(originalManifest, '0'.repeat(64)));
  const uncatalogued = compile(files, join(directory, 'uncatalogued'), ['--interface', ifaces]);
  assert.equal(uncatalogued.status, 1, 'the manifest must be consulted, not decorative');
  assert.match(uncatalogued.output, /module `util`: the interface file does not match the manifest/, `the manifest refusal must name the module: ${uncatalogued.output}`);
  writeFileSync(manifestPath, originalManifest);
  const recatalogued = compile(files, join(directory, 'recatalogued'), ['--interface', ifaces]);
  assert.equal(recatalogued.status, 0, `an interface matching its manifest must build\n${recatalogued.output}`);

  // (c1) a changed `transfer`, and nothing else: the file's own trailer digest refuses it, because
  // the manifest was pinned to the edited bytes so the manifest check cannot be what catches it.
  const edited = Buffer.from(original);
  const transfer = typeRecord(edited, 'util', 'Stream');
  assert.equal(edited[transfer.at], 1, 'the transfer byte must be where the format says it is');
  edited[transfer.at] = 0;
  repin(edited);
  const unsealed = compile(files, join(directory, 'unsealed'), ['--interface', ifaces]);
  assert.equal(unsealed.status, 1, 'an edited interface must be refused by its own digest');
  assert.match(unsealed.output, /changed after it was written/, `the seal refusal must say the file changed: ${unsealed.output}`);

  // (c2) re-sealing the edit does not launder it: the manifest still pins the written bytes.
  writeFileSync(util, seal(Buffer.from(edited)));
  writeFileSync(manifestPath, originalManifest);
  const laundered = compile(files, join(directory, 'laundered'), ['--interface', ifaces]);
  assert.equal(laundered.status, 1, 'a re-digested tamper must still be refused');
  assert.match(laundered.output, /module `util`: the interface file does not match the manifest/, `the manifest refusal must name the module: ${laundered.output}`);
  assert.match(laundered.output, /manifest says \S+, the file is \S+/, 'the refusal must show both digests');

  // (c3) with the manifest re-pinned too, `--verify` still refuses and names the declaration.
  const sealedEdit = seal(Buffer.from(edited));
  repin(sealedEdit);
  const verified = compile(files, join(directory, 'verify'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(verified.status, 1, '`--verify` must refuse a tampered transfer');
  assert.match(verified.output, /module `util` does not match this interface/, `the refusal must name the module: ${verified.output}`);
  assert.match(verified.output, /transfer=0/, 'the refusal must show the interface line that differs');
  assert.match(verified.output, /transfer=1/, 'the refusal must show what the sources give');
  // ... and the dump shows the tampered declaration, so the reader really did install it.
  assert.match(dump(util), /type util::Stream handle params=0 lifetimes=0 transfer=0 share=0/, 'the dump must show what the reader read');

  // (c4) an old version is refused by number, before anything else is read.
  const old = Buffer.from(original);
  old[4] = 3;
  repin(old);
  const version = compile(files, join(directory, 'version'), ['--interface', ifaces]);
  assert.equal(version.status, 1, 'an interface written by another compiler must be refused');
  assert.match(version.output, /was written in interface format 3/, `the version refusal must name the version it found: ${version.output}`);
  assert.match(version.output, /this compiler reads format 9/, 'the version refusal must name the version this compiler reads');

  // ... and a file from a *newer* compiler is refused by name as well: a version this compiler
  // does not know is never half-read.
  const future = Buffer.from(original);
  future[4] = 10;
  repin(future);
  const ahead = compile(files, join(directory, 'future'), ['--interface', ifaces]);
  assert.equal(ahead.status, 1, 'an interface written by a newer compiler must be refused');
  assert.match(ahead.output, /was written in interface format 10 by a newer compiler/, `the future-version refusal must name the version it found: ${ahead.output}`);
  assert.match(ahead.output, /this one reads format 9/, 'the future-version refusal must name the version this compiler reads');

  // ... a truncated file is refused as truncated.
  repin(Buffer.from(original.subarray(0, Math.floor(original.length * 0.6))));
  const cut = compile(files, join(directory, 'truncated'), ['--interface', ifaces]);
  assert.equal(cut.status, 1, 'a truncated interface must be refused');
  assert.match(cut.output, /truncated|no trailer/, `the truncation refusal must say what is missing: ${cut.output}`);

  // ... and an unknown record is refused by tag, not skipped.
  const unknown = Buffer.from(original);
  const firstType = frame(unknown).find(record => record.tag === 10);
  unknown[firstType.tagAt] = 99;
  repin(seal(unknown));
  const alien = compile(files, join(directory, 'unknown'), ['--interface', ifaces]);
  assert.equal(alien.status, 1, 'an unknown record must be refused');
  assert.match(alien.output, /unknown record \(tag 99\)/, `the unknown-record refusal must name the tag: ${alien.output}`);

  // (c4d) another `dyn` ABI: one digit of the header's ABI string, re-sealed and re-pinned, so the
  // refusal is the ABI comparison and not the digest.
  const abi = Buffer.from(original);
  const abiAt = abi.indexOf('abi dyn pair size = 16');
  assert.ok(abiAt > 0, 'the header must state the `dyn` ABI');
  abi[abiAt + 'abi dyn pair size = 1'.length] = '5'.charCodeAt(0);
  repin(seal(abi));
  const layout = compile(files, join(directory, 'abi'), ['--interface', ifaces]);
  assert.equal(layout.status, 1, 'an interface written for another `dyn` ABI must be refused');
  assert.match(layout.output, /does not match this interface/, `the ABI refusal must name the module: ${layout.output}`);
  assert.match(layout.output, /abi dyn pair size = 15/, 'the ABI refusal must show the ABI the file states');
  // ... and the loader refuses it by itself, without the sources to compare against: `--use` reads a
  // module whose source this build does not have, so the header's ABI is all there is to check.
  const loaded = compile(
    [join(project, 'src/main.grl'), runtime, platform],
    join(directory, 'abi-use'),
    ['--use', ifaces],
  );
  assert.equal(loaded.status, 1, 'loading an interface written for another `dyn` ABI must be refused');
  assert.match(loaded.output, /was written for another `dyn` ABI/, `the ABI refusal must name the ABI: ${loaded.output}`);
  assert.match(loaded.output, /this compiler builds/, 'the ABI refusal must show the ABI this compiler builds');

  // (c5) a record one field longer than this compiler reads: refused by length, never skipped.
  const grown = Buffer.from(original);
  const target = frame(grown).find(record => record.tag === 10);
  assert.ok(grown[target.lenAt] < 128, 'the test needs a one-byte length to extend in place');
  grown[target.lenAt] += 1;
  const spliced = Buffer.concat([grown.subarray(0, target.end), Buffer.from([0]), grown.subarray(target.end)]);
  repin(seal(spliced));
  const longer = compile(files, join(directory, 'longer'), ['--interface', ifaces]);
  assert.equal(longer.status, 1, 'a record with an unread field must be refused');
  assert.match(longer.output, /bytes? this compiler does not read/, `the length refusal must say so: ${longer.output}`);

  // (c6) a renamed field: manifest and seal are both re-pinned, so `--verify` is what catches it,
  // and it names the declaration that differs.
  const renamed = Buffer.from(original);
  const point = typeRecord(renamed, 'util', 'Point');
  point.var();
  point.var();
  point.var();
  point.var();
  const fields = point.var();
  assert.equal(fields, 2, 'Point has two fields');
  const nameStart = point.at + 1;
  assert.equal(String.fromCharCode(renamed[nameStart]), 'x', 'the first field of Point is x');
  renamed[nameStart] = 'y'.charCodeAt(0);
  repin(seal(renamed));
  const field = compile(files, join(directory, 'field'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(field.status, 1, 'a renamed field must be refused by --verify');
  assert.match(field.output, /module `util` does not match this interface/, `the field refusal must name the module: ${field.output}`);
  assert.match(field.output, /field y/, 'the field refusal must show the renamed field');

  // Restore and prove the interface still builds, so the refusals above are about the edit.
  restore();
  const restored = compile(files, join(directory, 'restored'), ['--interface', ifaces]);
  assert.equal(restored.status, 0, `an untouched interface must still build\n${restored.output}`);
  return {
    future: ahead.output.trim().split('\n')[0],
    abi: layout.output.trim().split('\n')[0],
    edited: unsealed.output.trim().split('\n')[0],
    manifest: laundered.output.trim().split('\n')[0],
    verify: verified.output.trim().split('\n')[0],
    version: version.output.trim().split('\n')[0],
    truncated: cut.output.trim().split('\n')[0],
    unknown: alien.output.trim().split('\n')[0],
    longer: longer.output.trim().split('\n')[0],
    field: field.output.trim().split('\n')[0],
  };
}

// (d) no leakage, on a module whose source has a distinctive helper and distinctive locals.
function proveLeakage() {
  const directory = join(work, 'leak');
  const project = join(directory, 'project');
  mkdirSync(join(project, 'src'), { recursive: true });
  writeFileSync(join(project, 'grail.toml'), '[package]\nname = "leak"\nversion = "0.1.0"\n');
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

// A type-generic template, so the interface carries a body and the leak check has something to
// exclude from the declared surface.
pub fn keep<T>(value: T) -> T {
    return value;
}
`);
  writeFileSync(join(project, 'src/main.grl'), 'use util;\n\npub fn main() -> u64 {\n    zzprivatemessage := util::twice(2);\n    println(zzprivatemessage);\n    return 0;\n}\n');
  const files = [join(project, 'src/main.grl'), join(project, 'src/util.grl'), runtime, platform];
  const ifaces = emit(files, directory);
  proveNoLeakage(ifaces, 'util');
  return interfaceFiles(ifaces).length;
}

// ---- the corpus -------------------------------------------------------------
function corpusCases() {
  const cases = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
  const selected = [];
  for (let i = 0; i < cases.length; i += 1) {
    const test = cases[i];
    if (test.targets && !test.targets.includes(target)) continue;
    if (test.removedSyntax) continue;
    // A pending case states behaviour another piece of work must produce (tools/test-native.mjs).
    if (test.pending) continue;
    const modules = (test.modules ?? []).map(file => resolve(root, file));
    // A case with no second module has nothing to read from an interface; its own interface is
    // still emitted and checked when `--full` asks for every case.
    if (modules.length === 0 && !full) continue;
    if (test.compileOnly && test.reject) continue;
    if (filter && !filter.test(test.name)) continue;
    selected.push({ index: i, test, modules });
  }
  return selected;
}

function proveCorpus() {
  let selected = corpusCases();
  if (stripe) selected = selected.filter((_, k) => k % stripe[1] === stripe[0]);
  let passed = 0;
  for (const { index, test, modules } of selected) {
    const directory = join(work, `${index}-${test.name.replace(/[^A-Za-z0-9_-]/g, '_')}`);
    mkdirSync(directory, { recursive: true });
    let files;
    if (test.files) files = [...test.files.map(file => resolve(root, file)), ...modules];
    else {
      const input = join(directory, 'input.grl');
      writeFileSync(input, test.source);
      files = [input, ...modules];
    }
    files = [...files, runtime, platform];
    if (test.reject) proveRejected(test.name, files, directory);
    // A case whose verdict is a wall-clock measurement (`timing`) proves nothing about interfaces when
    // it runs on a loaded machine, so its builds are compared but not run.
    else if (test.compileOnly || test.timing) {
      const source = compile(files, join(directory, 'source'));
      assert.equal(source.status, 0, `${test.name}: source build failed\n${source.output}`);
      const ifaces = emit(files, join(directory, 'emit'));
      proveDigests(ifaces);
      const viaInterface = compile(files, join(directory, 'interface'), ['--interface', ifaces]);
      assert.equal(viaInterface.status, 0, `${test.name}: interface build failed\n${viaInterface.output}`);
    } else {
      // The format expresses every type the corpus uses (format 3); a program it refuses is a
      // failure, so a new store kind cannot land without an interface spelling.
      proveEquivalent(test.name, files, directory, { stdout: test.stdout, args: test.args ?? [], env: test.env ?? {} });
    }
    passed += 1;
  }
  return passed;
}

// The corpus in GRAIL_JOBS worker processes, started now and waited for at the end: every case's
// builds are its own, in its own directory, so the stripes do not touch each other. A worker's
// output goes to a file, so a full pipe cannot stall it while this process runs the other proofs.
function startCorpus() {
  const jobs = Math.max(1, Number(process.env.GRAIL_JOBS || 8));
  mkdirSync(work, { recursive: true });
  const workers = [];
  for (let k = 0; k < jobs; k += 1) {
    const log = join(work, `corpus-${k}.log`);
    const out = openSync(log, 'w');
    const args = [process.argv[1], ...flags.filter(f => f !== '--corpus-stripe'), '--corpus-stripe', `${k}/${jobs}`];
    const child = spawn(process.execPath, args, { stdio: ['ignore', out, out], env: { ...process.env, GRAIL_JOBS: '1' } });
    workers.push({ log, done: new Promise(resolveDone => child.on('close', status => { closeSync(out); resolveDone(status); })) });
  }
  return workers;
}
async function finishCorpus(workers) {
  let passed = 0;
  let failed = false;
  for (const w of workers) {
    const status = await w.done;
    const text = readFileSync(w.log, 'utf8');
    const m = text.match(/^corpus-stripe: (\d+) passed$/m);
    if (status !== 0 || !m) {
      console.error(text);
      failed = true;
    } else passed += Number(m[1]);
  }
  if (failed) {
    console.error('interface-test: a corpus case failed (above)');
    process.exit(1);
  }
  return passed;
}
if (stripe) {
  console.log(`corpus-stripe: ${proveCorpus()} passed`);
  process.exit(0);
}
const corpusWorkers = startCorpus();
if (filter) {
  const corpus = await finishCorpus(corpusWorkers);
  console.log(`interface: corpus agrees with source builds: ${corpus} programs matching ${filter}`);
  process.exit(0);
}

// ---- the proofs -------------------------------------------------------------
const results = [];
function report(label, detail) {
  results.push({ label, detail });
  console.log(`interface: ${label}: ${detail}`);
}

const leaked = proveLeakage();
report('no body, local or synthetic declaration in an interface', `${leaked} interfaces checked`);

// A caller that disagrees with an interface is rejected in an interface build, in its own file.
function proveCallerRejected() {
  const directory = join(work, 'caller');
  const files = [join(root, 'tests/interfaces/reject_user.grl'), join(root, 'tests/interfaces/pair.grl'), runtime, platform];
  // The fixture is rejected in its body, so the emitting run exits 1 after it has written the
  // interfaces (they describe declarations, which are fine); the interface build is what has to
  // reject the caller.
  const ifaces = join(directory, 'ifaces');
  compile(files, directory, ['--emit-interface', ifaces]);
  assert.ok(existsSync(join(ifaces, 'interfaces.manifest')), 'the emitting run wrote no interfaces');
  const rejected = compile(files, join(directory, 'build'), ['--interface', ifaces]);
  assert.equal(rejected.status, 1, 'a caller that disagrees with the interface must be rejected');
  // The message names the callee and the parameter it leaves empty (the argument list is resolved
  // per parameter), and the caret line is the caller's file, not the defining module's.
  const rows = rejected.output.split('\n');
  const at = rows.findIndex(row => row.includes('call to `make` leaves `right` without an argument'));
  assert.ok(at >= 0, `the rejection must name the parameter it leaves empty: ${rejected.output}`);
  assert.match(rows[at + 1] ?? '', /--> .*reject_user\.grl:\d+:\d+/, `the rejection must be in the caller's file: ${rejected.output}`);
  return rejected.output.trim().split('\n')[0];
}

const caller = proveCallerRejected();
report('caller rejected against an interface', caller);

const self = proveSelfHosting();
report('compiler compiled against its own interfaces', `${self.modules} interfaces, ${self.digests} digests, same assembly`);

const stale = proveStale();
report('stale interface refused', stale);

const coverage = proveManifestCoverage();
report('a source module missing from the manifest refused', coverage);

const tamper = proveTampering();
report('edited transfer refused (seal)', tamper.edited);
report('re-digested transfer refused (manifest)', tamper.manifest);
report('edited transfer refused (--verify)', tamper.verify);
report('old version refused', tamper.version);
report('future version refused', tamper.future);
report('truncation refused', tamper.truncated);
report('unknown record refused', tamper.unknown);
report('another `dyn` ABI refused', tamper.abi);
report('a record one field longer refused', tamper.longer);
report('renamed field refused (--verify)', tamper.field);


// ---- (e) generic bodies across a module boundary (stage 3) -------------------
// A generic body used to be a source dependency: an importer that instantiated a foreign template
// needed that module's source on its command line. Stage 3 puts the body in the interface and moves
// the *code* to the module that defines the template, so two importers instantiate it and neither
// emits it. This section proves the four claims on the real compiler:
//
//  (e1) an importer needs no source   - `main`, `generic_a` and `generic_b` are compiled with only
//                                       `DIR/*.iface`; `generic.grl` is not on any command line;
//  (e2) the body is emitted once      - across the objects that are linked, `generic::twice<u64>`
//                                       has exactly one definition, in the defining module's part,
//                                       and both importers' parts reference it;
//  (e3) behaviour is unchanged        - the linked program prints and exits exactly as the
//                                       source-built one;
//  (e4) capability metadata survives  - instantiating a `T: Share` template on a handle that is
//                                       transferable but not shareable is refused by name, from the
//                                       interface as well as from the source.

const specPattern = /^f_generic_twice\$[0-9a-f]{16}:$/;

function parts(directory) {
  const manifest = readFileSync(join(directory, 'out.parts'), 'utf8');
  return { files: manifest.split('\n').filter(line => line.length > 0 && !line.startsWith('//')), manifest };
}

// The parts that carry one module's own code (plus its private helper part).
function partsOfModule(directory, module) {
  return parts(directory).files.filter(file => file.endsWith(`.${module}.s`) || file.endsWith('._helpers.s'));
}

function definitions(files, pattern) {
  return files.reduce((total, file) => total + readFileSync(file, 'utf8').split('\n').filter(line => pattern.test(line)).length, 0);
}

// Assemble and link a chosen set of part files as one program: one object per part - they come from
// different runs, so their local labels overlap and must not share an object - then one link. This
// is the shape a per-module build has; `grail build --split` assembles the parts of a single run the
// same way.
function linkParts(files, directory, name, manifestFrom) {
  const objects = files.map((file, index) => {
    const object = join(directory, `${name}-${index}.o`);
    command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[target]}`, '-c', file, '-o', object]);
    return object;
  });
  // The `// grail-link:` inputs travel in the manifest of the run that holds the entry.
  const linkArgs = linkInputs(parts(manifestFrom).manifest, manifestFrom);
  const exe = join(directory, name);
  command([process.env.GRAIL_LINKER ?? 'ld.lld', '-m', emulations[target], ...objects, ...linkArgs, '-o', exe]);
  return exe;
}

function proveGenericBodies() {
  const directory = join(work, 'generics');
  mkdirSync(directory, { recursive: true });
  const fixtures = name => join(root, 'tests/interfaces', name);
  const all = [fixtures('generic_main.grl'), fixtures('generic_a.grl'), fixtures('generic_b.grl'), fixtures('generic.grl'), runtime, platform];

  // The program built the ordinary way: one compile, every source present. This is what the split
  // build has to reproduce.
  const source = compile(all, join(directory, 'source'));
  assert.equal(source.status, 0, `generics: source build failed\n${source.output}`);
  const sourceExe = link(all, join(directory, 'source'));
  const expected = run(sourceExe);
  assert.equal(expected.stdout, '33\n', `generics: the source build prints ${JSON.stringify(expected.stdout)}`);

  // (e1) Emit the interfaces, then never mention the modules' sources again.
  const ifaces = emit(all, directory);
  const generic = join(ifaces, 'generic.iface');
  const text = dump(generic);
  assert.match(text, /^grail-interface 9$/m, 'generics: the interface does not carry the current format version');
  assert.match(text, /^fn generic::twice <1> /m, 'generics: generic.iface does not declare the template');
  assert.match(text, /^\s*body$/m, 'generics: generic.iface carries no body section');
  // The body is the template's own source text, one `|` row per line, readable in a diff.
  assert.ok(text.includes('|    return value;'), 'generics: the body section does not carry the template text');
  // Nothing carries a source position: a body is text, not a pointer into a file.
  assert.doesNotMatch(text, /\bpos /, 'generics: a body is still a source position, not carried text');

  // Three separate compiles, each with only the interface directory: the entry module, the two
  // importers, and the module that defines the template. `generic.grl` is on none of them.
  const mainDir = join(directory, 'build-main');
  const aDir = join(directory, 'build-a');
  const bDir = join(directory, 'build-b');
  const genericDir = join(directory, 'build-generic');
  const main = compile([fixtures('generic_main.grl'), runtime, platform], mainDir, ['--use', ifaces, '--split', '--emit-interface', ifaces]);
  assert.equal(main.status, 0, `generics: the entry module does not compile against interfaces\n${main.output}`);
  const a = compile([fixtures('generic_a.grl'), runtime, platform], aDir, ['--use', ifaces, '--split', '--no-entry', '--emit-interface', ifaces]);
  assert.equal(a.status, 0, `generics: the first importer does not compile against interfaces\n${a.output}`);
  const b = compile([fixtures('generic_b.grl'), runtime, platform], bDir, ['--use', ifaces, '--split', '--no-entry', '--emit-interface', ifaces]);
  assert.equal(b.status, 0, `generics: the second importer does not compile against interfaces\n${b.output}`);

  // (e2) Each importer emits the body itself, replayed from the interface, weak and under the one
  // content-addressed name: three objects, three copies the linker merges, no request protocol.
  const bodyNames = new Set();
  for (const [label, dir, module] of [['entry', mainDir, 'main'], ['generic_a', aDir, 'generic_a'], ['generic_b', bDir, 'generic_b']]) {
    const own = module === 'main' ? parts(dir).files : partsOfModule(dir, module);
    assert.equal(definitions(own, specPattern), 1, `generics: ${label} did not emit the instantiation its code calls`);
    for (const file of own) {
      for (const line of readFileSync(file, 'utf8').split('\n')) {
        if (specPattern.test(line)) bodyNames.add(line);
      }
    }
    assert.ok(own.some(file => /^\.weak f_generic_twice\$[0-9a-f]{16}$/m.test(readFileSync(file, 'utf8'))),
      `generics: ${label} emitted the instantiation without a weak binding`);
  }
  assert.equal(bodyNames.size, 1, `generics: the importers named one instantiation differently: ${[...bodyNames].join(', ')}`);
  // The defining module compiles on its own like any other: nothing asks it for anything.
  const served = compile([fixtures('generic.grl'), runtime, platform], genericDir, ['--use', ifaces, '--split', '--no-entry']);
  assert.equal(served.status, 0, `generics: the defining module does not compile against interfaces\n${served.output}`);

  // (e3) Link one object per module and compare with the source build.
  const linked = [
    ...parts(mainDir).files,
    ...partsOfModule(aDir, 'generic_a'),
    ...partsOfModule(bDir, 'generic_b'),
    ...partsOfModule(genericDir, 'generic'),
  ];
  assert.equal(definitions(linked, specPattern), 3, 'generics: the linked objects do not hold the three importers\' weak copies');
  const exe = linkParts(linked, directory, 'program', mainDir);
  const ran = run(exe);
  assert.equal(ran.status, expected.status, `generics: the separately compiled program exits ${ran.status}, the source build ${expected.status}`);
  assert.equal(ran.stdout, expected.stdout, 'generics: the separately compiled program prints something else');

  // (e4) The interface is checked, not trusted: a template without its body is refused by name. The
  // body is the last field of the template's record, so emptying it is one byte: the record is
  // rebuilt with its payload cut at the body, the length re-encoded, the file re-sealed.
  const edited = join(work, 'generics-nobody');
  mkdirSync(edited, { recursive: true });
  for (const file of interfaceFiles(ifaces)) writeFileSync(join(edited, file.split('/').pop()), readFileSync(file));
  const whole = readFileSync(generic);
  const layout = fnLayout(whole, 'twice');
  const cut = Buffer.concat([whole.subarray(layout.record.at, layout.body), Buffer.from([0])]);
  writeFileSync(join(edited, 'generic.iface'), seal(replacePayload(whole, layout.record, cut)));
  const refused = compile([fixtures('generic_a.grl'), runtime, platform], join(directory, 'nobody'), ['--use', edited]);
  assert.equal(refused.status, 1, 'generics: a template without a body must be refused');
  assert.match(refused.output, /carries no body for the generic template `twice`/, `generics: the refusal must name the template: ${refused.output}`);

  return {
    body: definitions(linked, specPattern),
    importers: 2,
    stdout: JSON.stringify(ran.stdout),
  };
}

function proveCapabilityAcrossInstantiation() {
  const directory = join(work, 'capability');
  mkdirSync(directory, { recursive: true });
  const fixtures = name => join(root, 'tests/interfaces', name);
  const ok = [fixtures('handle_ok.grl'), fixtures('handles.grl'), runtime, platform];
  const bad = [fixtures('handle_bad.grl'), fixtures('handles.grl'), runtime, platform];
  const expected = /type does not satisfy Share: handles::Lock is thread-affine \(declared transferable, not shareable\)/;

  // From source: the audited classification refuses the instantiation, naming the type.
  const sourceBad = compile(bad, join(directory, 'source-bad'));
  assert.equal(sourceBad.status, 1, 'capability: the source build must refuse `fan<Lock>`');
  assert.match(sourceBad.output, expected, `capability: the source refusal must name the handle and its audit: ${sourceBad.output}`);

  // From interfaces only: `handles.grl` is on neither command line, so the bound and both
  // classifications can only have come from `handles.iface`.
  const ifaces = emit(ok, directory);
  const handleIface = dump(join(ifaces, 'handles.iface'));
  assert.match(handleIface, / bound=0:2( |$)/m, 'capability: the template lost its `Share` bound in the interface');
  assert.match(handleIface, /type handles::File handle params=0 lifetimes=0 transfer=1 share=1/, 'capability: the shareable handle lost its audit');
  assert.match(handleIface, /type handles::Lock handle params=0 lifetimes=0 transfer=1 share=0/, 'capability: the unshareable handle lost its audit');

  const viaInterfaceBad = compile([fixtures('handle_bad.grl'), runtime, platform], join(directory, 'interface-bad'), ['--use', ifaces]);
  assert.equal(viaInterfaceBad.status, 1, 'capability: the interface build must refuse `fan<Lock>` too');
  assert.match(viaInterfaceBad.output, expected, `capability: the interface refusal must name the handle and its audit: ${viaInterfaceBad.output}`);

  // And the audited-shareable case still compiles and behaves: the refusal is about the handle, not
  // about generics on handles in general.
  const viaInterfaceOk = compile([fixtures('handle_ok.grl'), runtime, platform], join(directory, 'interface-ok'), ['--use', ifaces]);
  assert.equal(viaInterfaceOk.status, 0, `capability: `+"`fan<File>`"+` must be accepted through the interface\n${viaInterfaceOk.output}`);
  const sourceOk = compile(ok, join(directory, 'source-ok'));
  assert.equal(sourceOk.status, 0, `capability: `+"`fan<File>`"+` must be accepted from source\n${sourceOk.output}`);
  const sourceOkExe = link(ok, join(directory, 'source-ok'));
  const ran = run(sourceOkExe);
  assert.equal(ran.stdout, '4\n', `capability: the accepted instantiation prints ${JSON.stringify(ran.stdout)}`);

  return { refusal: viaInterfaceBad.output.trim().split('\n')[0] };
}

// ---- (f) naming a type must never be able to fail a build -------------------
// A drop helper is referenced from every scope exit and a specialisation from every call, so both
// want a name in the middle of an ordinary build. If that name were derived from the *interface
// spelling* of the type, then any type the format cannot express - a store extension another
// branch adds, today - would abort a build that has nothing to do with interfaces at all.
//
// Two claims, one static and one dynamic:
//   1. the naming functions do not call the interface writer, so its refusal is unreachable from
//      them (checked in the source, which is the only place the absence of a call is visible);
//   2. a key is a function of the type, so two runs agree on it: the same instantiation compiled
//      twice, in different orders, gets the same symbol - including one whose type argument is a
//      closure, whose environment record is synthesised and named per program.
function proveNamingIsTotal() {
  const source = readFileSync(join(root, 'compiler/native.grl'), 'utf8');
  const body = name => {
    const at = source.indexOf(`fn ${name}<`);
    assert.ok(at >= 0, `compiler/native.grl: no ${name}`);
    let depth = 0;
    let i = source.indexOf('{', at);
    const from = i;
    for (; i < source.length; i += 1) {
      if (source[i] === '{') depth += 1;
      else if (source[i] === '}') {
        depth -= 1;
        if (depth === 0) return source.slice(from, i);
      }
    }
    throw new Error(`compiler/native.grl: unterminated ${name}`);
  };
  for (const name of ['type_key', 'drop_symbol', 'special_key', 'special_name']) {
    assert.ok(
      !body(name).includes('iface_type_raw'),
      `compiler/native.grl: ${name} uses the interface writer, so a spelling it cannot provide would fail a build`,
    );
  }
  // The writer keeps its refusal: it is the interface's own, and the format still may not silently
  // write something it cannot read back.
  assert.ok(body('iface_type_raw').includes('iface_refuse'), 'compiler/native.grl: iface_type_raw lost its refusal');

  // (2) the same instantiation, twice, in two orders, with a closure-typed argument.
  const directory = join(work, 'naming');
  mkdirSync(directory, { recursive: true });
  const program = join(directory, 'naming.grl');
  writeFileSync(program, `fn keep<T>(value: T) -> T {
    return value;
}
fn twice<T>(value: T) -> T {
    return keep<T>(keep<T>(value));
}
fn main() {
    base := 7;
    printer := |x: u64| -> u64 x + base;
    println(twice<u64>(1) + printer(2));
    chosen := keep(printer);
    println(chosen(3));
}
`);
  const files = [program, runtime, platform];
  const first = compile(files, join(directory, 'a'));
  assert.equal(first.status, 0, `naming: the program does not compile\n${first.output}`);
  const secondDir = join(directory, 'b');
  const second = compile(files, secondDir);
  assert.equal(second.status, 0, `naming: the same program does not compile twice\n${second.output}`);
  const symbols = text => [...text.matchAll(/f_[a-z_]+_?[a-z]*\$[0-9a-z]+/g)].map(m => m[0]).sort();
  const a = symbols(readFileSync(first.asm, 'utf8'));
  const b = symbols(readFileSync(second.asm, 'utf8'));
  assert.ok(a.length > 0, 'naming: the program produced no specialisation symbols to compare');
  assert.deepEqual(b, a, 'naming: the same program in another directory produced different specialisation symbols');
  // Every one of them is the hex form: nothing here needed the run-local fallback.
  for (const symbol of a) {
    assert.match(symbol, /\$[0-9a-f]{16}$/, `naming: ${symbol} is not content-addressed`);
  }
  const exe = link(files, join(directory, 'a'));
  const ran = run(exe);
  assert.equal(ran.status, 0, 'naming: the program does not run');
  // twice(1) + printer(2) = 1 + (2 + 7); chosen(3) = 3 + 7.
  assert.equal(ran.stdout, `${1 + (2 + 7)}\n${3 + 7}\n`, `naming: the program prints ${JSON.stringify(ran.stdout)}`);
  return { symbols: a.length };
}

// ---- (g) two modules, one type whose identity is not a name -----------------
// The case that decides whether the key is right. `closure_a` and `closure_b` both instantiate
// `closure_gen::keep<T>` on a *capturing closure*: a type with no name at all, whose environment
// record is synthesised per program and numbered by registration order. A key built from that name
// would differ between the two modules, each would emit its own body, and a valid program would
// either duplicate the body or fail to link. The key describes the captures instead, so both
// modules ask for the same instantiation and exactly one body serves them.
function proveStructuralKeyAcrossModules() {
  const directory = join(work, 'closure-key');
  mkdirSync(directory, { recursive: true });
  const fixtures = name => join(root, 'tests/interfaces', name);
  const all = [
    fixtures('closure_main.grl'),
    fixtures('closure_a.grl'),
    fixtures('closure_b.grl'),
    fixtures('closure_gen.grl'),
    runtime,
    platform,
  ];
  const source = compile(all, join(directory, 'source'));
  assert.equal(source.status, 0, `closure-key: source build failed\n${source.output}`);
  const expected = run(link(all, join(directory, 'source')));

  const ifaces = emit(all, directory);
  const dirs = { main: join(directory, 'main'), closure_a: join(directory, 'a'), closure_b: join(directory, 'b') };
  const main = compile([fixtures('closure_main.grl'), runtime, platform], dirs.main, ['--use', ifaces, '--split', '--emit-interface', ifaces]);
  assert.equal(main.status, 0, `closure-key: the entry module does not compile against interfaces\n${main.output}`);
  for (const [module, fixture] of [['closure_a', 'closure_a.grl'], ['closure_b', 'closure_b.grl']]) {
    const built = compile([fixtures(fixture), runtime, platform], dirs[module], ['--use', ifaces, '--split', '--no-entry', '--emit-interface', ifaces]);
    assert.equal(built.status, 0, `closure-key: ${module} does not compile against interfaces\n${built.output}`);
  }

  const pattern = /^f_closure_gen_keep\$[0-9a-f]{16}:$/;
  // Both importers emit the instantiation on a capturing closure themselves, and the structural key
  // gives it one name in both objects although each run synthesised its own environment record.
  const names = ['closure_a', 'closure_b'].map(module => {
    const own = partsOfModule(dirs[module], module);
    assert.equal(definitions(own, pattern), 1, `closure-key: ${module} did not emit the instantiation it calls`);
    const line = own.flatMap(file => readFileSync(file, 'utf8').split('\n')).find(row => pattern.test(row));
    return line;
  });
  assert.equal(names[1], names[0], 'closure-key: the two modules named the instantiation differently');
  const genericDir = join(directory, 'gen');
  const served = compile([fixtures('closure_gen.grl'), runtime, platform], genericDir, ['--use', ifaces, '--split', '--no-entry']);
  assert.equal(served.status, 0, `closure-key: the defining module does not compile against interfaces\n${served.output}`);

  const linked = [
    ...parts(dirs.main).files,
    ...partsOfModule(dirs.closure_a, 'closure_a'),
    ...partsOfModule(dirs.closure_b, 'closure_b'),
    ...partsOfModule(genericDir, 'closure_gen'),
  ];
  assert.equal(definitions(linked, pattern), 2, 'closure-key: the linked objects do not hold the two importers\' weak copies');
  const ran = run(linkParts(linked, directory, 'program', dirs.main));
  assert.equal(ran.status, expected.status, 'closure-key: the separately compiled program exits differently');
  assert.equal(ran.stdout, expected.stdout, 'closure-key: the separately compiled program prints something else');
  return { key: names[0].replace(/:$/, ''), stdout: JSON.stringify(ran.stdout) };
}

// Separately compiled modules calling each other's inherent methods, interface implementations and
// a generic that instantiates another generic: each module compiled alone against interfaces, only
// its own part linked. Symbols name declarations, not this run's table positions, and a nested
// instantiation is emitted by the module that asked for the outer one.
function proveUnitsAcrossModules() {
  const directory = join(work, 'units');
  mkdirSync(directory, { recursive: true });
  const fixtures = name => join(root, 'tests/interfaces', name);
  const all = [fixtures('units_main.grl'), fixtures('units_shapes.grl'), runtime, platform];
  const source = compile(all, join(directory, 'source'));
  assert.equal(source.status, 0, `units: source build failed\n${source.output}`);
  const expected = run(link(all, join(directory, 'source')));
  const ifaces = emit(all, directory);
  const mainDir = join(directory, 'main');
  const shapesDir = join(directory, 'shapes');
  const main = compile([fixtures('units_main.grl'), runtime, platform], mainDir, ['--use', ifaces, '--split']);
  assert.equal(main.status, 0, `units: the entry module does not compile against interfaces\n${main.output}`);
  const shapes = compile([fixtures('units_shapes.grl'), runtime, platform], shapesDir, ['--use', ifaces, '--split', '--no-entry']);
  assert.equal(shapes.status, 0, `units: units_shapes does not compile against interfaces\n${shapes.output}`);
  const linked = [...parts(mainDir).files, ...partsOfModule(shapesDir, 'units_shapes')];
  const text = linked.map(file => readFileSync(file, 'utf8')).join('\n');
  assert.doesNotMatch(text, /\.(inherent|impl|interface)_\d/, 'units: a symbol still spells a table index');
  const ran = run(linkParts(linked, directory, 'program', mainDir));
  assert.equal(ran.status, expected.status, `units: the separately compiled program exits ${ran.status}`);
  assert.equal(ran.stdout, expected.stdout, `units: the separately compiled program prints ${JSON.stringify(ran.stdout)}`);
  return JSON.stringify(ran.stdout);
}

const generics = proveGenericBodies();
report(
  'imported generic: each importer emits it weak, one name, no source needed',
  `${generics.body} weak copies across ${generics.importers} importers, linked as one, output ${generics.stdout} as built from source`,
);

const capability = proveCapabilityAcrossInstantiation();
report('capability metadata survives an instantiation', capability.refusal);

const closureKey = proveStructuralKeyAcrossModules();
report(
  'two modules, one unnameable type: one name',
  `${closureKey.key} emitted by both under one name, output ${closureKey.stdout} as built from source`,
);

const units = proveUnitsAcrossModules();
report('methods, implementations and nested generics across separately compiled modules', `output ${units} as built from source`);

const naming = proveNamingIsTotal();
report(
  'naming a type cannot fail a build, and is the same in every run',
  `${naming.symbols} content-addressed symbols, identical across runs`,
);

// ---- (h) checked effects travel, and only when they were claimed -----------------
// An `effects` row is the definition module's own proof of an `@no_alloc`/`@no_panic` claim: an
// importer trusts it instead of re-deriving it. Three claims, on real compiles:
//   1. a claimed function publishes `effects 1 0 0`, and building the importer against the
//      interface accepts the claim;
//   2. a function that claims nothing publishes no row, so no importer can trust it;
//   3. a row edited out is refused by the manifest rather than silently honoured as "proved".
function proveEffectsTravel() {
  const directory = join(work, 'effects');
  mkdirSync(directory, { recursive: true });
  const entry = join(root, 'tests/interfaces/fx_eff_lib_user.grl');
  const lib = join(root, 'tests/interfaces/fx_eff_lib.grl');
  const plain = join(root, 'tests/interfaces/fx_eff_plain.grl');
  const ifaces = join(directory, 'ifaces');
  mkdirSync(ifaces, { recursive: true });
  const files = [entry, lib, runtime, platform];
  const emit = compile(files, join(directory, 'emit'), ['--emit-interface', ifaces]);
  assert.equal(emit.status, 0, `effects: the claimed program does not compile\n${emit.output}`);
  const claimedPath = join(ifaces, 'fx_eff_lib.iface');
  assert.match(dump(claimedPath), /^\s*effects 1 0 0$/m, 'effects: the claim did not travel in the interface');
  // The summary is a computed fact, carried for every function the interface lists, claimed or not.
  assert.match(dump(claimedPath), /^\s*facts \S+ [01] [01] [01]/m, 'effects: the summary did not travel in the interface');
  const viaInterface = compile(files, join(directory, 'via'), ['--interface', ifaces]);
  assert.equal(viaInterface.status, 0, `effects: an interface build refused the claim its own interface records\n${viaInterface.output}`);
  const plainIfaces = join(directory, 'plain');
  mkdirSync(plainIfaces, { recursive: true });
  const plainEmit = compile([plain, runtime, platform], join(directory, 'plain_emit'), ['--emit-interface', plainIfaces]);
  assert.equal(plainEmit.status, 0, `effects: the unclaimed module does not compile\n${plainEmit.output}`);
  assert.ok(
    !/^\s*effects [^0]|^\s*effects 0 [^0]/m.test(dump(join(plainIfaces, 'fx_eff_plain.iface'))),
    'effects: an unclaimed function published an `effects` row',
  );
  assert.match(dump(join(plainIfaces, 'fx_eff_plain.iface')), /^\s*facts /m, 'effects: an unclaimed function has no summary');
  // (c) A claimed effect is a byte in the record stream, so a false claim is one changed byte -
  // re-sealed and re-pinned, `--verify` is what has to refuse it, and it names the declaration.
  const original = readFileSync(claimedPath);
  const edited = Buffer.from(original);
  const effects = fnLayout(edited, 'total');
  assert.equal(edited[effects.noAlloc], 1, 'effects: the claim is not where the format says it is');
  edited[effects.noAlloc] = 0;
  writeFileSync(claimedPath, seal(edited));
  const manifest = join(ifaces, 'interfaces.manifest');
  const pinned = readFileSync(manifest, 'utf8');
  writeFileSync(manifest, pinned.replace(/^fx_eff_lib \S+/m, `fx_eff_lib ${sha256(seal(Buffer.from(edited)))}`));
  const tampered = compile(files, join(directory, 'tampered'), ['--interface', ifaces, '--verify-interface']);
  assert.equal(tampered.status, 1, 'effects: an interface whose `effects` row was removed was accepted');
  assert.match(tampered.output, /does not match this interface/, `effects: the refusal must name the interface\n${tampered.output}`);
  assert.match(tampered.output, /effects 0 0 0/, 'effects: the refusal must show the row it read');
  assert.match(tampered.output, /effects 1 0 0/, 'effects: the refusal must show what the sources give');
  writeFileSync(claimedPath, original);
  writeFileSync(manifest, pinned);
  return 'claims recorded when claimed, absent when not, refused once edited; summaries for every listed function';
}

// Inherent methods on a type no module declares (`impl u8[] { ... }`, `impl [u64] { ... }`,
// `impl<T> T[] { ... }`) are part of a module's public surface, so its interface must carry them or
// an importer compiled against the interface cannot call a method the module publishes - a `pub`
// method silently lost to separate compilation, which reads as the importer's own mistake.
function proveWrittenInherent() {
  const directory = join(work, 'written_inherent');
  mkdirSync(directory, { recursive: true });
  const ifaces = join(directory, 'ifaces');
  mkdirSync(ifaces, { recursive: true });
  const lib = join(root, 'tests/interfaces/arithmetic.grl');
  const user = join(root, 'tests/interfaces/written_inherent_user.grl');
  const libFiles = [lib, runtime, platform];
  // The emitting run has no entry: a library module has no `main`.
  const emitRun = compile(libFiles, join(directory, 'emit'), ['--emit-interface', ifaces, '--no-entry']);
  assert.equal(emitRun.status, 0, `written inherent: emitting the library interface failed\n${emitRun.output}`);
  // The file is a record stream; the dump is its text form, written by the same reader a build uses.
  const text = dump(join(ifaces, 'arithmetic.iface'));
  for (const line of ['inherent_type bytes params=0 lifetimes=0\n', 'inherent_type (slice u64) params=0 lifetimes=0\n', 'inherent_type (vec (tparam 0 0 [])) params=1 lifetimes=0\n']) {
    assert.ok(text.includes(line), `written inherent: the interface has no \`${line.trim()}\` section\n${text}`);
  }
  assert.match(text, /^  fn first_byte \(\(ref \[1\] bytes\)\) -> \(int 8u\) /m, 'written inherent: the method signature is not in the interface');
  // The importer is compiled against the interface with the library's source absent.
  const viaInterface = compile([user, runtime, platform], join(directory, 'via'), ['--use', ifaces]);
  assert.equal(
    viaInterface.status,
    0,
    `written inherent: a consumer compiled against the interface cannot call the method\n${viaInterface.output}`,
  );
  // ... and it is the section that carries it: the same module with the `impl u8[]` block removed
  // emits an interface the consumer cannot call that method through. (Editing the section out of
  // the file by hand is refused earlier, by its digest - which is the right answer, so this asks the
  // question with a legitimately emitted interface instead.)
  const without = join(directory, 'without');
  mkdirSync(without, { recursive: true });
  const withoutLib = join(without, 'arithmetic.grl');
  writeFileSync(withoutLib, readFileSync(lib, 'utf8').replace(/impl u8\[\] \{[\s\S]*?\n\}\n/, ''));
  const withoutIfaces = join(without, 'ifaces');
  mkdirSync(withoutIfaces, { recursive: true });
  const emitWithout = compile([withoutLib, runtime, platform], join(without, 'emit'), ['--emit-interface', withoutIfaces, '--no-entry']);
  assert.equal(emitWithout.status, 0, `written inherent: emitting the reduced library failed\n${emitWithout.output}`);
  assert.ok(
    !dump(join(withoutIfaces, 'arithmetic.iface')).includes('inherent_type bytes '),
    'written inherent: the reduced library still published an `inherent_type bytes` section',
  );
  const stripped = compile([user, runtime, platform], join(without, 'build'), ['--use', withoutIfaces]);
  assert.equal(stripped.status, 1, 'written inherent: the consumer built against an interface with no such section');
  assert.match(
    stripped.output,
    /has no method `first_byte`/,
    `written inherent: the refusal does not name the missing method\n${stripped.output}`,
  );
  // The same importer, from source, still builds: this is about the interface, not the method.
  const fromSource = compile([user, lib, runtime, platform], join(directory, 'source'));
  assert.equal(fromSource.status, 0, `written inherent: the source build failed\n${fromSource.output}`);
  return 'pub methods on written types travel, and the section is what carries them';
}

const writtenInherent = proveWrittenInherent();
report('inherent methods on a written type travel in an interface', writtenInherent);

const effects = proveEffectsTravel();
report('checked effects travel in an interface, and only when claimed', effects);

const corpus = await finishCorpus(corpusWorkers);
report('corpus agrees with source builds', `${corpus} programs (interface build, verify build and source build agree)` + (full ? ' - full corpus' : ''));

console.log(`\ninterface-test: ${results.length} checks passed`);
