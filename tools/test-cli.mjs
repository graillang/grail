// Formatter and `grail` command-line tool regressions (host + cross-target formatter/builds).
import * as fs from 'node:fs';
import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync, copyFileSync, existsSync } from 'node:fs';
import { join, basename } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { root, compilerSources, hostTarget, buildCompiler, assemble, command, execute } from './native.mjs';

const grail = buildCompiler();
const work = join(root, '.work/cli-tests');
rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
const run = (args, cwd = work, ok = true) => {
  const r = spawnSync(grail, args, { cwd, encoding: 'utf8', timeout: 600_000 });
  if (ok) assert.equal(r.status, 0, `grail ${args.join(' ')}: ${r.stdout}${r.stderr}`);
  return r;
};
let checks = 0;

// 1. Golden layout.
const messy = join(work, 'messy.grl');
copyFileSync(join(root, 'tests/fmt/messy.grl'), messy);
// grail explain: an error code's explanation, and a refusal for a code that does not exist.
{
  const known = run(['explain', 'E0004']);
  assert.equal(known.status, 0, `grail explain E0004 failed: ${known.stderr ?? ''}`);
  assert.match(known.stdout, /^E0004: type mismatch/, 'grail explain prints the code and its title first'); checks++;
  const unknown = run(['explain', 'E9999'], undefined, false);
  assert.equal(unknown.status, 1, 'an unknown error code is refused'); checks++;
}
run(['fmt', messy]);
assert.equal(readFileSync(messy, 'utf8'), readFileSync(join(root, 'tests/fmt/messy.expected.grl'), 'utf8'), 'golden formatting');
assert.equal(run(['fmt', '--check', messy]).status, 0); checks++;

// 2. Idempotence on every Grail source, and formatting preserves meaning (identical assembly).
const sources = [];
for (const dir of ['compiler', 'lib', 'compiler/tests', 'book/examples', 'tests/fmt'])
  for (const f of readdirSync(join(root, dir))) if (f.endsWith('.grl')) sources.push(join(root, dir, f));
const formattedDir = join(work, 'formatted'); mkdirSync(formattedDir);
const formatted = new Map();
for (const [i, file] of sources.entries()) {
  const copy = join(formattedDir, `${i}-${basename(file)}`); copyFileSync(file, copy);
  run(['fmt', copy]); const once = readFileSync(copy, 'utf8');
  run(['fmt', copy]); assert.equal(readFileSync(copy, 'utf8'), once, `formatting is not idempotent: ${file}`);
  formatted.set(file, copy);
}
checks += sources.length;
const original = join(work, 'original.s'), reformatted = join(work, 'reformatted.s');
// Both builds are given the same module root: `lib/xxhash.grl` is one of the compiler's own sources,
// which makes `lib/` a module root by location, and the formatted copies live somewhere else - so
// without naming it here the two runs would compile two different programs (`use` resolution,
// docs/design/module-resolution.md).
command([grail, '--module-root', join(root, 'lib'), original, ...compilerSources]);
command([grail, '--module-root', join(root, 'lib'), reformatted, ...compilerSources.map(f => formatted.get(f))]);
// The runtime-error call-site table records source lines and file names, which formatting and the
// copies' paths change by design; everything else must be byte-identical.
const withoutSites = (text) => text.replace(/\n\.section grail_sites,"a"\n[\s\S]*?\n\.text\n/g, '\n');
assert.equal(withoutSites(readFileSync(original, 'utf8')), withoutSites(readFileSync(reformatted, 'utf8')), 'formatted compiler compiles to different assembly'); checks++;

// 3. Project workflow: new / run / test / fmt / add / fetch / build.
run(['new', 'demo']); const demo = join(work, 'demo');
assert.equal(run(['run'], demo).stdout.trim(), 'Hello, world!');
assert.match(run(['test'], demo).stdout, /passed 1 failed 0 skipped 0/);
writeFileSync(join(demo, 'src/main.grl'), 'use mathlib;\nfn main(){println(mathlib::triple(14));}\n');
assert.equal(run(['fmt', '--check'], demo, false).status, 1, 'fmt --check must fail on unformatted code');
run(['fmt'], demo); assert.equal(run(['fmt', '--check'], demo).status, 0);
const lib = join(work, 'mathlib'); mkdirSync(join(lib, 'src'), { recursive: true });
writeFileSync(join(lib, 'grail.toml'), '[package]\nname = "mathlib"\nversion = "0.1.0"\n');
writeFileSync(join(lib, 'src/mathlib.grl'), 'module mathlib;\npub fn triple(n: u64) -> u64 {\n    return n * 3;\n}\n');
const git = args => assert.equal(spawnSync('git', args, { cwd: lib }).status, 0, `git ${args.join(' ')}`);
git(['init', '-q']); git(['add', '.']); git(['commit', '-qm', 'init']);
const branch = spawnSync('git', ['symbolic-ref', '--short', 'HEAD'], { cwd: lib, encoding: 'utf8' }).stdout.trim();
run(['add', '--git', `file://${lib}`, '--branch', branch], demo);
assert.match(readFileSync(join(demo, 'grail.toml'), 'utf8'), /^mathlib = \{ git = "file:\/\/.*", rev = "[0-9a-f]{40}" \}$/m);
const lock = JSON.parse(readFileSync(join(demo, 'grail.lock'), 'utf8'));
assert.equal(lock.packages.find(p => p.name === 'mathlib').source, 'git');
assert.equal(run(['run'], demo).stdout.trim(), '42');
run(['fetch', '--force'], demo);
assert.equal(run(['run'], demo).stdout.trim(), '42');
writeFileSync(join(demo, 'tests/bad.grl'), 'fn main() {\n    assert(1 == 2);\n}\n');
const failing = run(['test'], demo, false); assert.equal(failing.status, 1); assert.match(failing.stdout, /passed 1 failed 1 skipped 0/);
// `grail test` ergonomics: selection is by name/path and by position, `--list` runs nothing, and a
// failing case is reported with its own path and what it printed. The tests' directory order is the
// filesystem's, so these assertions are about the report's shape, not about which test comes first.
writeFileSync(join(demo, 'tests/second.grl'), 'fn main() {\n    println("second");\n}\n');
const listed = run(['test', '--list'], demo).stdout;
for (const name of ['tests/smoke.grl', 'tests/bad.grl', 'tests/second.grl']) assert.ok(listed.includes(name), `--list names ${name}: ${listed}`);
assert.match(listed, /3 tests selected/);
assert.match(run(['test', '--filter', 'smoke'], demo).stdout, /passed 1 failed 0 skipped 0/);
assert.match(run(['test', '--shard', '1/2'], demo).stdout, /passed [0-9]+ failed [0-9]+ skipped 0/);
assert.match(run(['test', '--jobs', '2'], demo, false).stdout, /passed 2 failed 1 skipped 0/);
// --fail-fast stops the project run at the first failure: the tests after it never start, and they
// are reported as skipped rather than silently missing.
const stopped = run(['test', '--fail-fast', '--jobs', '1'], demo, false);
assert.equal(stopped.status, 1, 'a failing project test exits 1');
assert.match(stopped.stdout, /FAIL tests\/bad\.grl[\s\S]*assertion failed/, 'the failure block names the case and prints its output');
const counts = /passed ([0-9]+) failed ([0-9]+) skipped ([0-9]+)/.exec(stopped.stdout);
assert.ok(counts, `the summary line is stable: ${stopped.stdout}`);
assert.equal(Number(counts[2]), 1, 'exactly one failure');
assert.equal(Number(counts[1]) + Number(counts[3]), 2, 'every test after the failure is skipped, not lost');
writeFileSync(join(work, 'args.grl'), 'fn main(argument: &[u8]) -> u64 {\n    return argument.len();\n}\n');
assert.equal(run(['run', 'args.grl', '--', 'seven!!'], work, false).status, 7);
writeFileSync(join(work, 'bad.grl'), 'fn main() {\n    x := 1;\n    x = 2;\n}\n');
const badCheck = run(['check', 'bad.grl'], work, false);
assert.equal(badCheck.status, 1, 'grail check must fail on an error'); assert.match(badCheck.stdout, /assignment requires mut/); assert.match(badCheck.stdout, /\|\s+\^/);
assert.match(run(['check', 'args.grl']).stdout, /^ok/m);
checks += 10;

// 3b. `grail doc`: the standard library documents itself, the same sources produce byte-identical
// pages, and a doc body links the declarations it names.
{
  const outA = join(work, 'api-a'), outB = join(work, 'api-b');
  run(['doc', '--out', outA, join(root, 'lib')]);
  run(['doc', '--out', outB, join(root, 'lib')]);
  const index = JSON.parse(readFileSync(join(outA, 'index.json'), 'utf8'));
  assert.equal(index.schema, 1, 'the index carries a schema number');
  assert.ok(index.modules.length >= 25, `every stdlib module is documented: ${index.modules.length}`);
  const module = name => index.modules.find(entry => entry.name === name);
  const item = (name, kind, itemName) => module(name)?.items.find(entry => entry.kind === kind && entry.name === itemName);
  assert.ok(module('strings')?.doc.includes('Byte-oriented text helpers'), 'a module carries the comment block below `module X;`');
  // The standard library is written as methods, so a module's functions are an impl block's members.
  const bytes = item('strings', 'impl', '[u8]');
  assert.ok(bytes?.members.find(member => member.name === 'find')?.doc.includes('first occurrence'), 'a method carries the block above it');
  assert.match(bytes?.members.find(member => member.name === 'find')?.type ?? '', /^pub fn find\(&self, needle: \(&\[u8\]\)\) -> u64\?$/, 'a method\'s signature is the text up to its body');
  assert.equal(bytes?.doc, '', 'the module block is not also the first declaration\'s doc');
  const fields = item('hashmap', 'struct', 'Map')?.members ?? [];
  assert.ok(fields.some(field => field.name === 'entries' && field.type === 'Slot<K, V>[]'), `a record lists its fields: ${JSON.stringify(fields)}`);
  assert.ok((item('io', 'enum', 'Error')?.members ?? []).some(variant => variant.name === 'Other' && variant.type === 'u64'), 'an enum lists its variants and payloads');
  assert.ok(module('hashmap')?.items.some(entry => entry.kind === 'impl' && entry.name.startsWith('Map')), 'an implementation is listed');
  assert.ok(fs.readdirSync(outA).filter(name => name.endsWith('.html')).length >= 25, 'one page per module');
  for (const name of fs.readdirSync(outA)) if (name.endsWith('.html') || name === 'index.json')
    assert.equal(fs.readFileSync(join(outA, name), 'utf8'), fs.readFileSync(join(outB, name), 'utf8'), `documentation is deterministic: ${name}`);
  assert.match(fs.readFileSync(join(outA, 'hashmap.html'), 'utf8'), /href="hashmap\.html#struct-Entry"/, 'a doc body links a uniquely named declaration');
  assert.match(fs.readFileSync(join(outA, 'index.html'), 'utf8'), /data-name="hashmap Map"/, 'the index carries the search data');
  checks += 7;
}
// 4. Cross targets: the grail tool itself (formatter) and programs it builds.
writeFileSync(join(work, 'hello.grl'), 'fn main() {\n    println(42);\n}\n');
for (const target of ['x86_64', 'aarch64', 'riscv64']) {
  if (target === hostTarget) continue;
  const out = join(work, `hello-${target}`);
  run(['build', 'hello.grl', '--target', target, '-o', out]);
  const r = execute(out, [], target); assert.equal(String(r.stdout), '42\n', `${target} program`);
  const asm = join(work, `grail-${target}.s`);
  command([grail, '--target', target, asm, ...compilerSources]);
  const tool = assemble(asm, join(work, `grail-${target}`), target);
  const sample = join(work, `messy-${target}.grl`); copyFileSync(join(root, 'tests/fmt/messy.grl'), sample);
  const f = execute(tool, ['fmt', sample], target); assert.equal(f.status, 0, `${target} grail fmt: ${f.stderr}`);
  assert.equal(readFileSync(sample, 'utf8'), readFileSync(join(root, 'tests/fmt/messy.expected.grl'), 'utf8'), `${target} formatter output`);
  checks += 2;
}
// 5. Foreign link inputs: `grail run` links a shared library (libc's strlen, so the executable
// needs the dynamic loader) and a C object named relative to the entry file.
const clink = join(work, 'clink'); mkdirSync(join(clink, 'src'), { recursive: true });
writeFileSync(join(clink, 'grail.toml'), '[package]\nname = "clink"\nversion = "0.1.0"\n');
writeFileSync(join(clink, 'src/add.c'), 'long long c_add3(long long a, long long b, long long c) { return a + b + c; }\n');
command(['clang', '-c', join(clink, 'src/add.c'), '-o', join(clink, 'src/add.o')]);
writeFileSync(join(clink, 'src/main.grl'), [
  'extern "C" lib "c" fn strlen(s: CStr) -> i64;',
  'extern "C" lib "add.o" fn c_add3(a: i64, b: i64, c: i64) -> i64;',
  'fn main() {',
  '    unsafe {',
  '        println(strlen(cstr("seven!!\\0")) + c_add3(1, 2, 3));',
  '    }',
  '}',
  '',
].join('\n'));
assert.equal(run(['run'], clink).stdout.trim(), '13', 'grail run links a shared library and a relative C object');
checks++;
// 6. Watch mode: `grail check --watch` and `grail build --watch`. A warm process re-runs the cycle
// when an input changes. Every wait below is on the process's own output, not on a sleep: a cycle
// prints exactly one summary line, so "cycle N arrived" and "no further cycle arrived" are both
// assertions about lines. The poll and quiet periods are made short through the flags, and the
// settle window is a generous multiple of them.
// A text cycle prints its diagnostics and then one summary line, so a cycle is counted by its
// summary; a `--json` cycle is one line, and every line of it is a summary.
const textSummary = line => /^(check ok|built \S+) \d+ ms$/.test(line) || /^error (\d+ diagnostics? )?\d+ ms$/.test(line);
const jsonSummary = line => { try { return JSON.parse(line).cycle !== undefined; } catch { return false; } };
// Every watcher this file starts, so that none can outlive the case that started it. A `grail
// check --watch` process only ends on a signal, so a suite that threw before reaching its own
// `stop()` used to leave one watching a tree with nothing left to read it (one ran for 100 minutes,
// reparented to systemd after the runner exited).
const watchers = [];
async function reapWatchers() {
  const left = [];
  for (const watcher of watchers) {
    if (!watcher.live) continue;
    left.push(`grail ${watcher.args.join(' ')}`);
    watcher.child.kill('SIGKILL');
    await watcher.exited;
  }
  watchers.length = 0;
  return left;
}
class Watcher {
  constructor(args, cwd, isSummary = textSummary) {
    this.args = args;
    this.isSummary = isSummary;
    this.lines = [];
    this.summaries = [];
    this.errors = '';
    this.buffer = '';
    this.child = spawn(grail, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
    this.child.stdout.setEncoding('utf8');
    this.child.stdout.on('data', chunk => {
      this.buffer += chunk;
      for (;;) {
        const at = this.buffer.indexOf('\n');
        if (at === -1) break;
        const line = this.buffer.slice(0, at);
        this.lines.push(line);
        if (this.isSummary(line)) this.summaries.push(line);
        this.buffer = this.buffer.slice(at + 1);
      }
    });
    this.child.stderr.on('data', chunk => { this.errors += chunk; });
    this.exited = new Promise(resolve => this.child.on('exit', (code, signal) => resolve({ code, signal })));
    watchers.push(this);
  }
  // Still running: no exit and no death signal yet.
  get live() {
    return this.child.exitCode === null && this.child.signalCode === null;
  }
  // The n-th cycle's summary line, waiting for the process to print it.
  async at(count, what) {
    const deadline = Date.now() + 60_000;
    while (this.summaries.length < count) {
      if (this.child.exitCode !== null) throw new Error(`grail ${this.args.join(' ')} exited during ${what}: ${JSON.stringify(this.lines)}${this.errors}`);
      if (Date.now() > deadline) throw new Error(`grail ${this.args.join(' ')}: waited for ${what} (cycle ${count}) and saw ${JSON.stringify(this.summaries)}${this.errors}`);
      await new Promise(resolve => setTimeout(resolve, 25));
    }
    return this.summaries[count - 1];
  }
  // A window several quiet periods wide in which nothing new is printed: one change, one cycle.
  async settled(what, window = 900) {
    const summaries = this.summaries.length;
    const lines = this.lines.length;
    await new Promise(resolve => setTimeout(resolve, window));
    assert.equal(this.summaries.length, summaries, `${what}: a change produced more than one cycle, or an unchanged tree did: ${JSON.stringify(this.summaries.slice(summaries))}`);
    assert.equal(this.lines.length, lines, `${what}: the process printed between cycles: ${JSON.stringify(this.lines.slice(lines))}`);
  }
  // SIGINT first, as the user would. A watcher that does not end within the deadline is killed, and
  // the ending it reports then fails the SIGINT assertion rather than hanging the suite.
  async stop() {
    const started = Date.now();
    this.child.kill('SIGINT');
    const ended = await Promise.race([this.exited, settle(10_000).then(() => null)]);
    if (ended !== null) return { ...ended, ms: Date.now() - started };
    this.child.kill('SIGKILL');
    const forced = await this.exited;
    return { ...forced, ms: Date.now() - started };
  }
}
const settle = (ms) => new Promise(resolve => setTimeout(resolve, ms));
const fast = ['--interval', '40', '--debounce', '60'];
{
  const dir = join(work, 'watch'); mkdirSync(dir, { recursive: true });
  const ok = 'fn main() {\n    println(42);\n}\n';
  const broken = 'fn main() {\n    x := 1;\n    x = 2;\n}\n';
  const file = join(dir, 'main.grl');
  writeFileSync(file, ok);
  // Pass or fail, nothing this case started is left running: the `finally` kills what the explicit
  // `stop()` calls did not reach, and a watcher that was still alive there fails the case.
  const stragglers = [];
  try {
  const watching = new Watcher(['check', '--watch', ...fast, 'main.grl'], dir);
  assert.match(await watching.at(1, 'the first cycle'), /^check ok \d+ ms$/, 'the first cycle runs before any change, and is one line'); checks++;
  writeFileSync(file, broken);
  const failed = await watching.at(2, 'the cycle after one change');
  assert.match(failed, /^error 1 diagnostic \d+ ms$/, `one summary line per error cycle: ${failed}`); checks++;
  assert.equal(watching.child.exitCode, null, 'an error keeps the watch process alive'); checks++;
  assert.match(watching.lines.join('\n'), /assignment requires mut[\s\S]*\|\s+\^/, "the cycle prints the compiler's own diagnostic, caret and all"); checks++;
  await watching.settled('one change');
  writeFileSync(file, ok);
  assert.match(await watching.at(3, 'the cycle after the fix'), /^check ok \d+ ms$/, 'fixing the file clears the error'); checks++;
  assert.equal(watching.child.exitCode, null, 'the process is still alive after an error and a fix');
  // A concurrent `grail build` in the same directory: no lock is held between cycles.
  const beside = spawnSync(grail, ['build', 'main.grl', '-o', 'target/beside'], { cwd: dir, encoding: 'utf8', timeout: 300_000 });
  assert.equal(beside.status, 0, `a build beside a watching process: ${beside.stdout}${beside.stderr}`); checks++;
  // A burst of writes is one cycle, not one per write.
  const settledAt = watching.summaries.length;
  for (let i = 0; i < 5; i++) { writeFileSync(file, `${ok}// write ${i}\n`); await settle(15); }
  assert.match(await watching.at(settledAt + 1, 'the cycle after a burst'), /^check ok \d+ ms$/, 'a burst of writes settles into a cycle'); checks++;
  await watching.settled('a burst of writes');
  // Every cycle removes its structured-diagnostics file: nothing accumulates in target/.
  const litter = readdirSync(join(dir, 'target')).filter(name => name.startsWith('watch-'));
  assert.deepEqual(litter, [], 'a cycle removes the diagnostics file it read'); checks++;

  // Content, not timestamps: a file written back with the same bytes is not a change (an mtime
  // comparison would spend a cycle here), and one whose bytes do change is.
  const unchangedAt = watching.summaries.length;
  writeFileSync(file, `${ok}// write 4\n`);
  await watching.settled('a rewrite with the same bytes');
  assert.equal(watching.summaries.length, unchangedAt, 'a rewrite with the same bytes spends no cycle'); checks++;
  writeFileSync(file, `${ok}// write 5\n`);
  assert.match(await watching.at(unchangedAt + 1, 'the cycle after the bytes changed'), /^check ok \d+ ms$/, 'a change of bytes is a cycle'); checks++;

  // Project mode: the entry, `src/` and a fetched dependency's sources are the input set.
  const demoDir = join(work, 'demo');
  const project = new Watcher(['check', '--watch', ...fast], demoDir);
  assert.match(await project.at(1, 'the first project cycle'), /^check ok \d+ ms$/); checks++;
  writeFileSync(join(demoDir, 'src/main.grl'), 'use mathlib;\nfn main() {\n    println(mathlib::triple(15));\n}\n');
  assert.match(await project.at(2, 'the cycle after a project source changed'), /^check ok \d+ ms$/, 'a project cycle watches the project sources'); checks++;
  await project.stop();

  // `--json`: one JSON object per line per cycle, and nothing else on that stream.
  writeFileSync(file, broken);
  const stream = new Watcher(['check', '--watch', '--json', ...fast, 'main.grl'], dir, jsonSummary);
  const record = JSON.parse(await stream.at(1, 'the first json cycle'));
  assert.equal(record.cycle, 1); assert.equal(record.status, 'error'); assert.equal(typeof record.ms, 'number');
  assert.equal(record.diagnostics.length, 1, 'one diagnostic, from the compiler\'s structured record');
  assert.equal(record.diagnostics[0].file, 'main.grl');
  assert.equal(record.diagnostics[0].line, 3);
  assert.equal(record.diagnostics[0].col, 5);
  assert.match(record.diagnostics[0].message, /assignment requires mut/);
  checks += 6;
  await stream.settled('the json stream');
  writeFileSync(file, ok);
  const fixed = JSON.parse(await stream.at(2, 'the json cycle after the fix'));
  assert.equal(fixed.cycle, 2); assert.equal(fixed.status, 'ok'); assert.deepEqual(fixed.diagnostics, []);
  assert.ok(stream.lines.every(line => { try { JSON.parse(line); return true; } catch { return false; } }), 'every line of the stream is one JSON object');
  checks += 3;
  await stream.stop();

  // The channel itself: the compiler writes one record per diagnostic to the file and prints
  // nothing, so a driver never reads the caret form back.
  writeFileSync(file, broken);
  const channel = join(dir, 'target/channel.jsonl');
  const compiled = spawnSync(grail, ['--diagnostics-json', channel, join(dir, 'target/channel.s'), file], { cwd: dir, encoding: 'utf8' });
  assert.equal(compiled.status, 1, `a rejected program keeps status 1: ${compiled.stdout}${compiled.stderr}`);
  assert.equal(compiled.stdout.trim(), '', 'a listener means the compiler prints no caret form');
  const records = readFileSync(channel, 'utf8').trim().split('\n').map(line => JSON.parse(line));
  assert.equal(records.length, 1, 'one record per diagnostic');
  assert.deepEqual({ file: records[0].file, line: records[0].line, col: records[0].col, code: records[0].code }, { file, line: 3, col: 5, code: 'E0005' });
  assert.match(records[0].message, /assignment requires mut/);
  assert.match(records[0].rendered, /^error\[E0005\][\s\S]*\^/, 'the record carries the caret form for a human');
  checks += 5;

  // `grail build --watch`: one summary line naming the image, and a rebuilt one on change. `-o` keeps
  // this watcher's assembly out of `target/main.s`, which is the file the `check --watch` above
  // compiles and then removes (a check writes no artefact): two watchers on one entry in one
  // directory otherwise race, and the build assembles a file the check has just deleted. That race
  // is what made this case fail as `error N ms` with `no such file or directory: target/main.s`.
  writeFileSync(file, ok);
  const building = new Watcher(['build', '--watch', ...fast, 'main.grl', '-o', 'target/watched'], dir);
  assert.match(await building.at(1, 'the first build cycle'), /^built target\/watched \d+ ms$/, 'a build cycle names what it built'); checks++;
  assert.equal(String(execute(join(dir, 'target/watched'), [], hostTarget).stdout), '42\n', 'the first cycle wrote a runnable image'); checks++;
  writeFileSync(file, 'fn main() {\n    println(43);\n}\n');
  assert.match(await building.at(2, 'the build cycle after a change'), /^built target\/watched \d+ ms$/); checks++;
  assert.equal(String(execute(join(dir, 'target/watched'), [], hostTarget).stdout), '43\n', 'the rebuild replaced the image'); checks++;

  // SIGINT ends every watcher promptly. A signal has no handler to catch it (the runtime installs
  // none, and a builtin cannot be added without breaking the published bootstrap), so the process
  // ends on the signal and the status on termination is the signal's, not the last cycle's; that
  // limit is written down in docs/design/incremental-compilation.md.
  const endings = await Promise.all([watching.stop(), building.stop()]);
  for (const ending of endings) {
    assert.ok(ending.signal === 'SIGINT' || ending.code === 130, `a watcher ends on SIGINT, not on an abort: ${JSON.stringify(ending)}`);
    assert.ok(ending.ms < 10_000, `a watcher ends promptly on SIGINT: ${ending.ms} ms`);
  }
  checks += 2;
  // `--watch` on a command with no cycle to repeat is refused, not silently ignored.
  const refused = spawnSync(grail, ['run', '--watch', 'main.grl'], { cwd: dir, encoding: 'utf8' });
  assert.equal(refused.status, 1); assert.match(refused.stdout, /watch mode is `grail build --watch`/); checks++;
  } finally {
    stragglers.push(...await reapWatchers());
  }
  assert.deepEqual(stragglers, [], `a watcher outlived its case (killed it, but the case leaked it): ${stragglers.join(', ')}`);
  checks++;
}
// A `--word` the driver does not have is refused, by name, before anything is built: it used to fall
// into the input list, where `grail build` ignored it, so a misspelt flag compiled without the flag.
{
  const dir = join(work, 'flags'); mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'main.grl'), 'fn take(n: u64 where n % 2 == 0) -> u64 {\n    return n;\n}\nfn main() {\n    println(take(host::argc()));\n}\n');
  const typo = run(['build', 'main.grl', '--strict-refinments'], dir, false);
  assert.equal(typo.status, 1, 'a misspelt flag is refused');
  assert.match(typo.stdout + typo.stderr, /unknown option `--strict-refinments`\n\s+did you mean `--strict-refinements`\?/); checks++;
  assert.ok(!existsSync(join(dir, 'target/main')), 'nothing is built when a flag is refused'); checks++;
  const bogus = run(['check', '--bogus', 'main.grl'], dir, false);
  assert.equal(bogus.status, 1); assert.match(bogus.stdout + bogus.stderr, /unknown option `--bogus`/);
  assert.doesNotMatch(bogus.stdout + bogus.stderr, /did you mean/, 'no suggestion when nothing is close'); checks++;
  const llvm = run(['build', 'main.grl', '--backend=llvm'], dir, false);
  assert.equal(llvm.status, 1); assert.match(llvm.stdout + llvm.stderr, /option of the compiler proper/); checks++;
  // The flag itself reaches the compiler: the obligation `n % 2 == 0` has no proof, so the strict
  // build is refused and the plain one is not.
  assert.equal(run(['build', 'main.grl'], dir).status, 0); checks++;
  const strict = run(['build', 'main.grl', '--strict-refinements'], dir, false);
  assert.equal(strict.status, 1); assert.match(strict.stdout + strict.stderr, /cannot prove the refinement `n % 2 == 0`/); checks++;
  // `--emit-ir` writes the typed IR beside the assembly, and the file holds units.
  rmSync(join(dir, 'target'), { recursive: true, force: true });
  assert.equal(run(['build', 'main.grl', '--emit-ir'], dir).status, 0);
  const ir = readFileSync(join(dir, 'target/main.s.tir'), 'utf8');
  assert.ok(ir.startsWith('ssair 1\n') && ir.length > 1000, `--emit-ir wrote ${ir.length} bytes of IR`); checks++;
  // After `--` every word is the program's, a `--word` included.
  writeFileSync(join(dir, 'args.grl'), 'fn main() {\n    println(host::argc());\n}\n');
  const passed = run(['run', 'args.grl', '--', '--bogus', 'x'], dir);
  assert.equal(passed.stdout.trim().split('\n').pop(), '3', 'the program sees its own name and both words'); checks++;
}
// An effect claim no longer makes a build one compiler run: each module's run proves the claims on
// its own bodies against the summaries of the modules it reads (docs/design/effects.md,
// "Summaries"). A mention in a comment or a string was never a claim, and still builds per module.
{
  const dir = join(work, 'effect-words'); mkdirSync(dir, { recursive: true });
  const store = { ...process.env, GRAIL_CACHE_DIR: join(dir, 'store') };
  const build = (file, extra = []) => spawnSync(grail, ['build', file, '--cache', '--module-root', '.', ...extra, '-o', 'target/out'], { cwd: dir, encoding: 'utf8', env: store });
  writeFileSync(join(dir, 'words.grl'), '// @no_alloc is only mentioned here\nfn main() {\n    println("@no_panic in a string");\n}\n');
  const words = build('words.grl');
  assert.equal(words.status, 0, words.stdout + words.stderr);
  assert.match(words.stdout + words.stderr, /grail: cache: /, 'a mention in a comment or a string leaves the build per module'); checks++;
  // Three modules and a claim in the last: util <- mid <- main. The claim reaches util through mid,
  // and the runtime through util (an overflow check), and is proved without one whole-program run.
  writeFileSync(join(dir, 'util.grl'), 'module util;\npub fn add(a: u64, b: u64) -> u64 {\n    return a + b;\n}\npub fn grow(v: &mut u64[]) {\n    v.push(1);\n    return ();\n}\n');
  writeFileSync(join(dir, 'mid.grl'), 'module mid;\nuse util;\npub fn sum3(a: u64, b: u64, c: u64) -> u64 {\n    return util::add(util::add(a, b), c);\n}\npub fn push_one(v: &mut u64[]) {\n    util::grow(v);\n    return ();\n}\n');
  writeFileSync(join(dir, 'claim.grl'), 'use mid;\n@no_alloc\nfn quiet(x: u64) -> u64 {\n    return mid::sum3(x, 1, 2);\n}\nfn main() {\n    println(quiet(4));\n}\n');
  const claim = build('claim.grl');
  assert.equal(claim.status, 0, claim.stdout + claim.stderr);
  // The store is the one the build above filled, so the runtime and the standard modules may be hits.
  const runs = /grail: cache: (\d+) hit, (\d+) miss \(([^)]*)\)/.exec(claim.stdout + claim.stderr);
  assert.ok(runs, `a claimed effect builds through the per-module store\n${claim.stdout}${claim.stderr}`); checks++;
  const names = runs[3].split(', ');
  for (const m of ['util', 'mid', 'main']) assert.ok(names.includes(m), `module \`${m}\` is a run of its own: ${runs[3]}`);
  assert.ok(Number(runs[1]) + Number(runs[2]) >= 4, `one run per module, not one for the program: ${runs[0]}`); checks++;
  const again = build('claim.grl');
  assert.equal(again.status, 0, again.stdout + again.stderr);
  assert.match(again.stdout + again.stderr, /grail: cache: \d+ hit, 0 miss/, 'the claiming program is up to date from the store'); checks++;
  // The same claim over a callee that allocates two modules away: refused per module with the chain
  // the whole-program build names.
  writeFileSync(join(dir, 'loud.grl'), 'use mid;\n@no_alloc\nfn loud(v: &mut u64[]) {\n    mid::push_one(v);\n    return ();\n}\nfn main() {\n    mut v = u64[];\n    loud(&mut v);\n    println(v.len());\n}\n');
  const per = build('loud.grl');
  const whole = build('loud.grl', ['--whole-program']);
  assert.equal(per.status, 1, 'an allocating callee in another module refuses the claim');
  assert.equal(whole.status, 1, 'the whole-program build refuses it too');
  const first = (r) => (r.stdout + r.stderr).split('\n').find((l) => l.startsWith('error:')) ?? '';
  assert.match(first(per), /`@no_alloc` function `loud` performs a heap allocation: it calls loud -> push_one -> grow -> rt_push/, first(per)); checks++;
  assert.equal(first(per), first(whole), 'the per-module refusal names the chain the whole-program one does'); checks++;
}
console.log(`cli: ${checks} formatter/tool checks passed`);
