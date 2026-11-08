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
command([grail, '--default-u64', original, ...compilerSources]);
command([grail, '--default-u64', reformatted, ...compilerSources.map(f => formatted.get(f))]);
assert.ok(readFileSync(original).equals(readFileSync(reformatted)), 'formatted compiler compiles to different assembly'); checks++;

// 3. Project workflow: new / run / test / fmt / add / fetch / build.
run(['new', 'demo']); const demo = join(work, 'demo');
assert.equal(run(['run'], demo).stdout.trim(), 'Hello, world!');
assert.match(run(['test'], demo).stdout, /1 passed, 0 failed/);
writeFileSync(join(demo, 'src/main.grl'), 'use mathlib;\nfn main(){println(mathlib::triple(14));}\n');
assert.equal(run(['fmt', '--check'], demo, false).status, 1, 'fmt --check must fail on unformatted code');
run(['fmt'], demo); assert.equal(run(['fmt', '--check'], demo).status, 0);
const lib = join(work, 'mathlib'); mkdirSync(join(lib, 'src'), { recursive: true });
writeFileSync(join(lib, 'src/mathlib.grl'), 'module mathlib;\npub fn triple(n: u64) -> u64 {\n    return n * 3;\n}\n');
const git = args => assert.equal(spawnSync('git', args, { cwd: lib }).status, 0, `git ${args.join(' ')}`);
git(['init', '-q']); git(['add', '.']); git(['-c', 'user.name=grail', '-c', 'user.email=grail@localhost', 'commit', '-qm', 'init']);
run(['add', 'mathlib', lib], demo);
assert.match(readFileSync(join(demo, 'grail.pkg'), 'utf8'), /^dep mathlib /m);
assert.match(readFileSync(join(demo, 'grail.lock'), 'utf8'), /^mathlib [0-9a-f]{40}$/m);
assert.equal(run(['run'], demo).stdout.trim(), '42');
rmSync(join(demo, '.grail'), { recursive: true }); run(['fetch'], demo);
assert.equal(run(['run'], demo).stdout.trim(), '42');
writeFileSync(join(demo, 'tests/bad.grl'), 'fn main() {\n    assert(1 == 2);\n}\n');
const failing = run(['test'], demo, false); assert.equal(failing.status, 1); assert.match(failing.stdout, /1 passed, 1 failed/);
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
  command([grail, '--default-u64', '--target', target, asm, ...compilerSources]);
  const tool = assemble(asm, join(work, `grail-${target}`), target);
  const sample = join(work, `messy-${target}.grl`); copyFileSync(join(root, 'tests/fmt/messy.grl'), sample);
  const f = execute(tool, ['fmt', sample], target); assert.equal(f.status, 0, `${target} grail fmt: ${f.stderr}`);
  assert.equal(readFileSync(sample, 'utf8'), readFileSync(join(root, 'tests/fmt/messy.expected.grl'), 'utf8'), `${target} formatter output`);
  checks += 2;
}
console.log(`cli: ${checks} formatter/tool checks passed`);
