// Whether a program is accepted must not depend on the overflow mode (docs/design/refinements.md,
// "Arithmetic in a predicate"): a proof is decided as if arithmetic could wrap and an effect as if
// it could trap, so `--overflow=checked` and `--overflow=wrap` accept exactly the same programs.
// This pass takes every corpus case whose source states a refinement (`where`, `ensures`) or an
// attribute the compiler has to prove (`@strict`, `@no_panic`, `@no_alloc`, `@bounded`), checks it
// under both modes with `--check`, and requires the same outcome and the same diagnostics.
//   bun tools/overflow-parity-test.mjs [regex]
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join, resolve, basename } from 'node:path';
import { root, buildCompiler, hostTarget } from './native.mjs';

const compiler = buildCompiler();
const work = join(root, '.work/overflow-parity');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const runtime = join(root, 'compiler/runtime.grl');
const osRuntime = join(root, 'compiler/os-linux.grl');
const cases = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
const filter = process.argv[2] ? new RegExp(process.argv[2]) : null;
const claims = /\b(where|ensures)\b|@(strict|no_panic|no_alloc|bounded)\b/;
const roots = ['--module-root', join(root, 'lib')];

let compared = 0;
const differences = [];
for (const test of cases) {
  if (filter && !filter.test(test.name)) continue;
  // A project or driver case is built by `grail build`, and an interface case compiles against
  // emitted interfaces: both go through other entry points than the one compared here.
  if (test.project || test.driver || test.interfaces || test.removedSyntax) continue;
  if (test.targets && !test.targets.includes(hostTarget)) continue;
  let text = test.source ?? '';
  for (const file of [...(test.files ?? []), ...(test.modules ?? [])]) text += readFileSync(resolve(root, file), 'utf8');
  if (!claims.test(text)) continue;
  const directory = join(work, test.name);
  mkdirSync(directory, { recursive: true });
  let files;
  if (test.files) files = [...test.files, ...(test.modules ?? [])].map(file => resolve(root, file));
  else { const input = join(directory, 'input.grl'); writeFileSync(input, test.source); files = [input, ...(test.modules ?? []).map(file => resolve(root, file))]; }
  // A case's `roots` are fixtures a `use NAME;` reaches, staged under their own names.
  const caseRoots = test.noRoots ? [] : [...roots];
  if (test.roots && !test.noRoots) {
    const byName = join(directory, 'root');
    mkdirSync(byName, { recursive: true });
    for (const file of test.roots) writeFileSync(join(byName, basename(file)), readFileSync(resolve(root, file)));
    caseRoots.push('--module-root', byName);
  }
  const flags = (test.flags ?? []).filter(flag => !flag.startsWith('--overflow='));
  const outcome = {};
  for (const mode of ['checked', 'wrap']) {
    const run = spawnSync(compiler, [...caseRoots, '--target', hostTarget, ...flags, `--overflow=${mode}`, '--check', join(directory, `${mode}.s`), ...files, runtime, osRuntime], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    if (run.error) throw run.error;
    outcome[mode] = { status: run.status, signal: run.signal, text: `${run.stdout}${run.stderr}` };
  }
  compared += 1;
  const a = outcome.checked;
  const b = outcome.wrap;
  if (a.signal || b.signal) differences.push(`${test.name}: the compiler crashed (checked ${a.signal}, wrap ${b.signal})`);
  else if (a.status !== b.status) differences.push(`${test.name}: checked exits ${a.status}, wrap exits ${b.status}\n  checked: ${a.text.trim().split('\n')[0] ?? ''}\n  wrap:    ${b.text.trim().split('\n')[0] ?? ''}`);
  else if (a.text !== b.text) differences.push(`${test.name}: same outcome, different diagnostics\n  checked: ${a.text.trim().split('\n')[0] ?? ''}\n  wrap:    ${b.text.trim().split('\n')[0] ?? ''}`);
}
for (const line of differences) console.log(`FAIL ${line}`);
console.log(`overflow parity: ${compared} cases checked in both modes, ${differences.length} differ`);
process.exit(differences.length === 0 ? 0 : 1);
