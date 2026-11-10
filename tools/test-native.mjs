import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync } from 'node:fs';
import { join, basename, resolve, dirname } from 'node:path';
import assert from 'node:assert/strict';
import { root, compilerSources, hostTarget, targetName, buildCompiler, compileProgram, execute } from './native.mjs';

const legacyReferenceSyntax = /\b(?:borrow|borrow_mut)\s*\(|\b(?:read|mut)\s*</;

// Keep internal source on the modern dialect, including comments and diagnostics.
for (const file of [...compilerSources, ...readdirSync(join(root, 'lib')).filter(f => f.endsWith('.grl')).map(f => join(root, 'lib', f))]) {
  assert.doesNotMatch(readFileSync(file, 'utf8'), legacyReferenceSyntax, `${file}: legacy internal reference syntax`);
}

const target = targetName(process.argv[2] ?? hostTarget);
const compiler = buildCompiler();
const work = join(root, '.work/native-tests', target);
mkdirSync(work, { recursive: true });
const cases = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
const legacyFiles = new Set();
for (const test of cases) {
  if (test.removedSyntax !== undefined) assert.ok(test.removedSyntax === true && test.reject, `${test.name}: removedSyntax requires an intentional rejection`);
  if (test.legacyRefs !== undefined) {
    assert.ok(typeof test.legacyRefs === 'string' && test.legacyRefs.trim(), `${test.name}: legacyRefs requires an explanation`);
    for (const file of [...(test.files ?? []), ...(test.modules ?? [])]) legacyFiles.add(resolve(root, file));
  } else if (test.source && legacyReferenceSyntax.test(test.source)) {
    assert.ok(test.reject && test.removedSyntax === true, `${test.name}: legacy syntax is only allowed as intentional removed-syntax rejection input`);
  }
}
for (const directory of ['compiler/tests', 'book/examples', 'abundance/src', 'abundance/tests']) {
  for (const file of readdirSync(join(root, directory)).filter(f => f.endsWith('.grl'))) {
    const path = join(root, directory, file);
    if (!legacyFiles.has(path)) assert.doesNotMatch(readFileSync(path, 'utf8'), legacyReferenceSyntax, `${path}: legacy fixture reference syntax`);
  }
}

// A long cross run must not combine source revisions while development continues.
const snapshot = join(work, 'inputs');
mkdirSync(snapshot, { recursive: true });
const runtime = join(snapshot, 'runtime.grl');
writeFileSync(runtime, readFileSync(join(root, 'compiler/runtime.grl')));
const osRuntime = join(snapshot, 'os-linux.grl');
writeFileSync(osRuntime, readFileSync(join(root, 'compiler/os-linux.grl')));
// The standard library keeps its layout (a directory holding core.grl), because the compiler
// recognises stdlib modules by location and compiles them in the stdlib's own modes.
const stdSnapshot = join(snapshot, 'lib');
mkdirSync(stdSnapshot, { recursive: true });
for (const file of readdirSync(join(root, 'lib')).filter(f => f.endsWith('.grl'))) {
  writeFileSync(join(stdSnapshot, file), readFileSync(join(root, 'lib', file)));
}
for (let i = 0; i < cases.length; i++) {
  for (const field of ['files', 'modules']) if (cases[i][field]) cases[i][field] = cases[i][field].map((file, j) => {
    const source = resolve(root, file);
    if (dirname(source) === join(root, 'lib')) return join(stdSnapshot, basename(source));
    const path = join(snapshot, `${i}-${field}-${j}-${basename(file)}`);
    writeFileSync(path, readFileSync(source));
    return path;
  });
}
let passed = 0;
let skipped = 0;
for (const test of cases) {
  // A case may name the targets it applies to (`"targets": ["x86_64"]`), for fixtures that link a
  // host C library or exercise a host-only facility.
  if (test.targets && !test.targets.includes(target)) { skipped++; continue; }
  // Only a documented, explicit legacyRefs reason may opt a fixture out of typed mode.
  const typedRefs = test.legacyRefs === undefined;
  const directory = join(work, test.name);
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  // A case's own files (or its inline source) come first, then the modules it lists.
  let files;
  if (test.files) files = [...test.files, ...(test.modules ?? [])];
  else { const input = join(directory, 'input.grl'); writeFileSync(input, test.source); files = [input, ...(test.modules ?? [])]; }
  if (test.reject) {
    const assembly = join(directory, 'prior.s');
    writeFileSync(assembly, 'prior valid artifact');
    const numeric = [...(test.defaultU64 === false ? [] : ['--default-u64']), ...(typedRefs ? ['--typed-refs'] : [])];
    const result = execute(compiler, [...numeric, '--target', target, assembly, ...files, runtime, osRuntime]);
    assert.equal(result.signal, null, `${test.name}: compiler crashed (${result.signal}): ${result.stdout}${result.stderr}`);
    assert.equal(result.status, 1, `${test.name}: a rejected program must exit 1: ${result.stdout}${result.stderr}`);
    if (test.diagnostic) assert.ok(`${result.stdout}${result.stderr}`.includes(test.diagnostic), `${test.name}: expected diagnostic ${test.diagnostic}: ${result.stdout}${result.stderr}`);
    assert.equal(readFileSync(assembly, 'utf8'), 'prior valid artifact', `${test.name}: invalid program overwrote prior output`);
  } else {
    const executable = compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', defaultU64: test.defaultU64 !== false, typedRefs, runtime, osRuntime });
    if (test.compileOnly) { passed++; continue; }
    const result = execute(executable, test.args ?? [], target, { cwd: directory });
    if (result.error) throw result.error;
    // A case that dies by signal can still pin its output: an abort must not resume the foreign or
    // Grail code that ran before it, so what was printed up to the abort is part of the contract.
    // A diagnostic the runtime promises (once per process) is part of the observable contract.
    if (test.stderr !== undefined) {
      const errors = result.stderr.toString();
      const occurrences = errors.split(test.stderr).length - 1;
      assert.equal(occurrences, test.stderrCount ?? 1, `${test.name}: expected ${test.stderrCount ?? 1} x ${JSON.stringify(test.stderr)} in ${JSON.stringify(errors)}`);
    }
    if (test.signal) {
      assert.equal(result.signal, test.signal, `${test.name}: ${result.status}: ${result.stderr}`);
      if (test.stdout !== undefined) assert.equal(result.stdout.toString(), test.stdout, test.name);
    } else { assert.equal(result.status, test.status ?? 0, `${test.name}: ${result.signal}: ${result.stderr}`); assert.equal(result.stdout.toString(), test.stdout, test.name); }
  }
  passed++;
}
console.log(`${target}: ${passed} native execution/rejection regressions passed` + (skipped ? `, ${skipped} skipped (host-only)` : ''));
