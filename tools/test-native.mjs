import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, basename, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { root, hostTarget, targetName, buildCompiler, compileProgram, execute } from './native.mjs';

const target = targetName(process.argv[2] ?? hostTarget);
const compiler = buildCompiler();
const work = join(root, '.work/native-tests', target);
mkdirSync(work, { recursive: true });
const cases = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
// A long cross run must not combine source revisions while development continues.
const snapshot = join(work, 'inputs');
mkdirSync(snapshot, { recursive: true });
const runtime = join(snapshot, 'runtime.grl');
writeFileSync(runtime, readFileSync(join(root, 'compiler/runtime.grl')));
for (let i = 0; i < cases.length; i++) {
  for (const field of ['files', 'modules']) if (cases[i][field]) cases[i][field] = cases[i][field].map((file, j) => {
    const path = join(snapshot, `${i}-${field}-${j}-${basename(file)}`);
    writeFileSync(path, readFileSync(resolve(root, file)));
    return path;
  });
}
let passed = 0;
for (const test of cases) {
  const directory = join(work, test.name);
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  let files = test.files;
  if (!files) { const input = join(directory, 'input.grl'); writeFileSync(input, test.source); files = [input, ...(test.modules ?? [])]; }
  if (test.reject) {
    const assembly = join(directory, 'prior.s');
    writeFileSync(assembly, 'prior valid artifact');
    const numeric = test.defaultU64 === false ? [] : ['--default-u64'];
    const result = execute(compiler, [...numeric, '--target', target, assembly, ...files, runtime]);
    assert.notEqual(result.status, 0, `${test.name}: unsafe/invalid program was accepted`);
    if (test.diagnostic) assert.ok(`${result.stdout}${result.stderr}`.includes(test.diagnostic), `${test.name}: expected diagnostic ${test.diagnostic}: ${result.stdout}${result.stderr}`);
    assert.equal(readFileSync(assembly, 'utf8'), 'prior valid artifact', `${test.name}: invalid program overwrote prior output`);
  } else {
    const executable = compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', defaultU64: test.defaultU64 !== false, runtime });
    if (test.compileOnly) { passed++; continue; }
    const result = execute(executable, test.args ?? [], target, { cwd: directory });
    if (result.error) throw result.error;
    if (test.signal) assert.equal(result.signal, test.signal, `${test.name}: ${result.status}: ${result.stderr}`);
    else { assert.equal(result.status, test.status ?? 0, `${test.name}: ${result.signal}: ${result.stderr}`); assert.equal(result.stdout.toString(), test.stdout, test.name); }
  }
  passed++;
}
console.log(`${target}: ${passed} native execution/rejection regressions passed`);
