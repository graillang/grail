// Formatter and `grail` command-line tool regressions (host + cross-target formatter/builds).
import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync, copyFileSync, existsSync } from 'node:fs';
import { join, basename } from 'node:path';
import { spawnSync } from 'node:child_process';
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
command([grail, original, ...compilerSources]);
command([grail, reformatted, ...compilerSources.map(f => formatted.get(f))]);
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
writeFileSync(join(lib, 'src/mathlib.grl'), 'module mathlib;\npub fn triple(n: u64) -> u64 {\n    return n * 3;\n}\n');
const git = args => assert.equal(spawnSync('git', args, { cwd: lib }).status, 0, `git ${args.join(' ')}`);
git(['init', '-q']); git(['add', '.']); git(['commit', '-qm', 'init']);
run(['add', 'mathlib', lib], demo);
assert.match(readFileSync(join(demo, 'grail.pkg'), 'utf8'), /^dep mathlib /m);
assert.match(readFileSync(join(demo, 'grail.lock'), 'utf8'), /^mathlib [0-9a-f]{40}$/m);
assert.equal(run(['run'], demo).stdout.trim(), '42');
rmSync(join(demo, '.grail'), { recursive: true }); run(['fetch'], demo);
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
writeFileSync(join(clink, 'grail.pkg'), 'name clink\n');
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
console.log(`cli: ${checks} formatter/tool checks passed`);
