// Authority/capability model: path containment, gated read/write/spawn round trips, and the
// --deny-ambient-host compiler switch. Run: bun tools/test-authority.mjs [TARGET]
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { root, hostTarget, targetName, buildCompiler, assemble, execute } from './native.mjs';

const target = targetName(process.argv[2] ?? hostTarget);
const compiler = buildCompiler();
const work = join(root, '.work/authority-tests', target);
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

const fixtures = join(root, 'tests/authority');
const runtime = join(root, 'compiler/runtime.grl');
const osRuntime = join(root, 'compiler/os-linux.grl');
// The compiler recognises standard-library modules by location (a directory holding core.grl),
// so these are passed from lib/ rather than copied.
const standard = ['authority', 'core', 'io', 'fs'].map(name => join(root, 'lib', `${name}.grl`));
const denial = 'ambient host access is denied';

function runCompiler(args, cwd = root) {
  const result = execute(compiler, args, target, { cwd });
  if (result.error) throw result.error;
  return result;
}
function compile(name, entry, { deny = false, prior = false } = {}) {
  const directory = join(work, name);
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, 'program.s');
  if (prior) writeFileSync(assembly, 'prior valid artifact\n');
  const args = ['--target', target];
  if (deny) args.push('--deny-ambient-host');
  args.push(assembly, entry, ...standard, runtime, osRuntime);
  return { directory, assembly, result: runCompiler(args) };
}
function build(compiled, name) {
  const executable = join(compiled.directory, name);
  return assemble(compiled.assembly, executable, target);
}
function run(executable, cwd) {
  const result = execute(executable, [], target, { cwd });
  if (result.error) throw result.error;
  return result;
}
let checks = 0;
function ok(label, condition, detail) {
  assert.ok(condition, `${label}: ${detail ?? ''}`);
  checks += 1;
}

// ---- 1. path containment and normalisation (57 lexical cases) ----
{
  const compiled = compile('containment', join(fixtures, 'containment.grl'));
  assert.equal(compiled.result.status, 0, `containment: compilation failed\n${compiled.result.stdout}${compiled.result.stderr}`);
  const result = run(build(compiled, 'containment'), compiled.directory);
  assert.equal(result.status, 0, `containment: ${result.signal}: ${result.stdout}${result.stderr}`);
  assert.equal(result.stdout.toString(), '57\ncontainment ok\n', 'containment: case count or a verdict changed');
  checks += 57;
}

// ---- 2. gated read/write/spawn/socket round trip in a scratch directory ----
{
  const compiled = compile('round-trip', join(fixtures, 'round_trip.grl'), { deny: true });
  assert.equal(compiled.result.status, 0, `round trip: compilation under --deny-ambient-host failed\n${compiled.result.stdout}${compiled.result.stderr}`);
  mkdirSync(join(compiled.directory, 'scratch'), { recursive: true });
  const result = run(build(compiled, 'round-trip'), compiled.directory);
  assert.equal(result.status, 0, `round trip: ${result.signal}: ${result.stdout}${result.stderr}`);
  assert.equal(
    result.stdout.toString(),
    '6\n2\n3\n6\n4\nnot found\n0\n1\n0\n1\ntrue\nround trip ok\n',
    'round trip: stdout changed',
  );
  assert.equal(readFileSync(join(compiled.directory, 'scratch/note.txt'), 'utf8'), 'Grail\n', 'round trip: written bytes differ');
  ok('round trip', !existsSync(join(compiled.directory, '../escape.txt')), 'a denied write created a file outside the root');
  ok('round trip', !existsSync(join(compiled.directory, 'scratch/other.txt')), 'a read-only grant wrote a file');
  checks += 2;
}

// ---- 3. --deny-ambient-host: direct host:: calls need a module opt-in ----
{
  // Ambient host access stays the default.
  const ambient = compile('ambient-default', join(fixtures, 'ambient_denied.grl'));
  assert.equal(ambient.result.status, 0, `ambient default: expected the direct host:: call to compile\n${ambient.result.stdout}${ambient.result.stderr}`);
  checks += 1;

  // With the switch, the same file is rejected and the prior artifact is untouched.
  const rejected = compile('ambient-denied', join(fixtures, 'ambient_denied.grl'), { deny: true, prior: true });
  assert.equal(rejected.result.status, 1, `ambient denied: expected rejection, got ${rejected.result.status}\n${rejected.result.stdout}${rejected.result.stderr}`);
  assert.equal(rejected.result.signal, null, `ambient denied: compiler crashed (${rejected.result.signal})`);
  ok('ambient denied', `${rejected.result.stdout}${rejected.result.stderr}`.includes(denial), 'diagnostic does not name the denial');
  assert.equal(readFileSync(rejected.assembly, 'utf8'), 'prior valid artifact\n', 'a rejected program overwrote the prior assembly');
  checks += 1;

  // `use host;` is the module-level opt-in.
  const opted = compile('ambient-opted-in', join(fixtures, 'ambient_opted_in.grl'), { deny: true });
  assert.equal(opted.result.status, 0, `ambient opt-in: expected the opted-in file to compile\n${opted.result.stdout}${opted.result.stderr}`);
  checks += 1;

  // A host:: function value is still a reference to the ambient interface.
  const value = compile('ambient-function-value', join(fixtures, 'ambient_function_value.grl'), { deny: true });
  assert.equal(value.result.status, 1, `ambient function value: expected rejection, got ${value.result.status}\n${value.result.stdout}${value.result.stderr}`);
  ok('ambient function value', `${value.result.stdout}${value.result.stderr}`.includes(denial), 'diagnostic does not name the denial');
  checks += 1;

  // A generic body is compiled in a replay pass after every module is read: the check must use
  // the defining module's opt-in, not the last module parsed.
  const genericOpted = compile('generic-opted-in', join(fixtures, 'generic_opted_in.grl'), { deny: true });
  assert.equal(genericOpted.result.status, 0, `generic opt-in: expected the opted-in generic to compile\n${genericOpted.result.stdout}${genericOpted.result.stderr}`);
  checks += 1;
  const genericAmbient = compile('generic-ambient', join(fixtures, 'generic_ambient.grl'), { deny: true });
  assert.equal(genericAmbient.result.status, 1, `generic ambient: expected rejection, got ${genericAmbient.result.status}\n${genericAmbient.result.stdout}${genericAmbient.result.stderr}`);
  ok('generic ambient', `${genericAmbient.result.stdout}${genericAmbient.result.stderr}`.includes(denial), 'diagnostic does not name the denial');
  checks += 1;

  // The gated route needs no opt-in and compiles with or without the switch.
  for (const deny of [false, true]) {
    const gated = compile(`gated-${deny}`, join(fixtures, 'gated.grl'), { deny });
    assert.equal(gated.result.status, 0, `gated (deny=${deny}): expected the gated call to compile\n${gated.result.stdout}${gated.result.stderr}`);
    checks += 1;
  }

  // The user-facing `grail check` path forwards the switch.
  const cli = join(work, 'cli');
  mkdirSync(cli, { recursive: true });
  const viaCli = runCompiler(['check', '--deny-ambient-host', join(fixtures, 'ambient_denied.grl')], cli);
  assert.equal(viaCli.status, 1, `grail check: expected rejection, got ${viaCli.status}\n${viaCli.stdout}${viaCli.stderr}`);
  ok('grail check', `${viaCli.stdout}${viaCli.stderr}`.includes(denial), 'diagnostic does not name the denial');
  const gatedCli = runCompiler(['check', '--deny-ambient-host', join(fixtures, 'gated.grl')], cli);
  assert.equal(gatedCli.status, 0, `grail check gated: expected success, got ${gatedCli.status}\n${gatedCli.stdout}${gatedCli.stderr}`);
  checks += 1;
}

console.log(`${target}: ${checks} authority checks passed (containment, gated round trip, --deny-ambient-host)`);
