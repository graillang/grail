import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync, existsSync } from 'node:fs';
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
const cases = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));

// A full run is minutes per backend, so the runner is sliceable. All three knobs are opt-in and a
// plain invocation behaves exactly as before:
//   GRAIL_TEST_FILTER=<regex>   only cases whose name matches (iterate on one area)
//   GRAIL_TEST_SHARD=<i>/<n>     run shard i of n, chosen by position (parallel gates)
//   GRAIL_TEST_RESUME=1          skip cases that already passed for this compiler + backend
const filterArg = process.env.GRAIL_TEST_FILTER;
const filter = filterArg ? new RegExp(filterArg) : null;
const shardArg = process.env.GRAIL_TEST_SHARD;
let shard = null;
if (shardArg) {
  const match = /^(\d+)\/(\d+)$/.exec(shardArg);
  assert.ok(match, `GRAIL_TEST_SHARD must be i/n, got ${shardArg}`);
  const [index, count] = [Number(match[1]), Number(match[2])];
  assert.ok(count >= 1 && index >= 1 && index <= count, `GRAIL_TEST_SHARD ${shardArg}: index must be 1..${count}`);
  shard = { index: index - 1, count };
}
const resume = process.env.GRAIL_TEST_RESUME === '1';
// The marker names the compiler (its path is a content hash) and the backend, so a rebuilt compiler
// or a different --backend never reuses another run's passes.
const backend = `${process.env.GRAIL_BACKEND ?? 'native'}${process.env.GRAIL_VERIFY_FACTS === '1' ? '+facts' : ''}`;
// The backend also names the work directory, so a native and an LLVM run of one target can overlap.
const work = join(root, '.work/native-tests', backend === 'native' ? target : `${target}-${backend}`);
mkdirSync(work, { recursive: true });
// Key by the compiler's content-addressed directory, not its file name: every build is named `grail`.
const markers = join(work, 'pass', basename(dirname(compiler)) + '-' + backend);
if (resume) mkdirSync(markers, { recursive: true });
for (const test of cases) {
  if (test.removedSyntax !== undefined) assert.ok(test.removedSyntax === true && test.reject, `${test.name}: removedSyntax requires an intentional rejection`);
  if (test.source && legacyReferenceSyntax.test(test.source)) {
    assert.ok(test.reject && test.removedSyntax === true, `${test.name}: legacy syntax is only allowed as intentional removed-syntax rejection input`);
  }
}
for (const directory of ['compiler/tests', 'book/examples', 'abundance/src', 'abundance/tests']) {
  for (const file of readdirSync(join(root, directory)).filter(f => f.endsWith('.grl'))) {
    const path = join(root, directory, file);
    assert.doesNotMatch(readFileSync(path, 'utf8'), legacyReferenceSyntax, `${path}: legacy fixture reference syntax`);
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
  for (const field of ['files', 'modules', 'interfaceFiles']) if (cases[i][field]) cases[i][field] = cases[i][field].map((file, j) => {
    const source = resolve(root, file);
    if (dirname(source) === join(root, 'lib')) return join(stdSnapshot, basename(source));
    const path = join(snapshot, `${i}-${field}-${j}-${basename(file)}`);
    writeFileSync(path, readFileSync(source));
    return path;
  });
}
// A case's `data` files (what an `@embed` reads) are staged under their own names beside its
// sources, so a path relative to the source resolves as it does in a project.
for (const test of cases) for (const file of test.data ?? []) writeFileSync(join(snapshot, basename(file)), readFileSync(resolve(root, file)));
let passed = 0;
let skipped = 0;
let filtered = 0;
let resumed = 0;
for (const [position, test] of cases.entries()) {
  // A case may name the targets it applies to (`"targets": ["x86_64"]`), for fixtures that link a
  // host C library or exercise a host-only facility.
  if (test.targets && !test.targets.includes(target)) { skipped++; continue; }
  // A case that pins native-backend output (runtime error locations) names its backends.
  if (test.backends && !test.backends.includes(process.env.GRAIL_BACKEND ?? 'native')) { skipped++; continue; }
  if (filter && !filter.test(test.name)) { filtered++; continue; }
  if (shard && position % shard.count !== shard.index) { filtered++; continue; }
  if (resume && existsSync(join(markers, test.name))) { resumed++; continue; }
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
    const result = execute(compiler, ['--target', target, ...(test.flags ?? []), assembly, ...files, runtime, osRuntime]);
    assert.equal(result.signal, null, `${test.name}: compiler crashed (${result.signal}): ${result.stdout}${result.stderr}`);
    assert.equal(result.status, 1, `${test.name}: a rejected program must exit 1: ${result.stdout}${result.stderr}`);
    // `diagnostic` is one required fragment of the error output, or a list of them (the message and
    // its location are on different lines of a rendered error).
    const diagnostics = [test.diagnostic ?? []].flat();
    for (const fragment of diagnostics) {
      assert.ok(`${result.stdout}${result.stderr}`.includes(fragment), `${test.name}: expected diagnostic ${fragment}: ${result.stdout}${result.stderr}`);
    }
    // A rejection may pin how many times its diagnostic is printed, exactly as `stderrCount` does for
    // runtime output: a replayed generic body reaches the same source line again, and it has to be
    // reported - and counted - once (docs/diagnostics.md).
    if (test.diagnosticCount !== undefined) {
      assert.equal(diagnostics.length, 1, `${test.name}: diagnosticCount needs exactly one diagnostic`);
      const occurrences = `${result.stdout}${result.stderr}`.split(diagnostics[0]).length - 1;
      assert.equal(occurrences, test.diagnosticCount, `${test.name}: expected ${test.diagnosticCount} x ${JSON.stringify(diagnostics[0])} in ${JSON.stringify(`${result.stdout}${result.stderr}`)}`);
    }
    assert.equal(readFileSync(assembly, 'utf8'), 'prior valid artifact', `${test.name}: invalid program overwrote prior output`);
    // A rejection that must also hold when the modules are read from their interfaces: the
    // interface has to carry everything the refusal rests on.
    if (test.interfaces) {
      const ifaces = join(directory, 'ifaces');
      // The interface comes from the library modules alone: the entry may be the very thing the
      // rejection is about.
      const modules = test.modules ?? [];
      assert.ok(modules.length !== 0, `${test.name}: an interface rejection needs module sources`);
      const emit = execute(compiler, ['--target', target, '--emit-interface', ifaces, join(directory, 'emit.s'), ...modules, ...(test.interfaceFiles ?? []), runtime, osRuntime]);
      assert.equal(emit.status, 0, `${test.name}: emitting interfaces failed: ${emit.stdout}${emit.stderr}`);
      const viaInterface = execute(compiler, ['--target', target, '--interface', ifaces, join(directory, 'iface.s'), ...files, runtime, osRuntime]);
      assert.equal(viaInterface.status, 1, `${test.name}: the interface build must refuse it too: ${viaInterface.stdout}${viaInterface.stderr}`);
      for (const fragment of diagnostics) {
        assert.ok(`${viaInterface.stdout}${viaInterface.stderr}`.includes(fragment), `${test.name}: expected diagnostic ${fragment} from the interface build: ${viaInterface.stdout}${viaInterface.stderr}`);
      }
    }
  } else {
    // Interface-first: emit one interface per module, then compile the same program against them.
    // The interface build is the build this case's behaviour is asserted on when the case asks for
    // it, so a gap in an interface is a test failure rather than a silent difference.
    let viaInterface;
    if (test.interfaces) {
      const ifaces = join(directory, 'ifaces');
      const emit = execute(compiler, ['--target', target, '--overflow=' + (test.overflow ?? 'checked'), '--emit-interface', ifaces, join(directory, 'emit.s'), ...files, runtime, osRuntime]);
      assert.equal(emit.status, 0, `${test.name}: emitting interfaces failed: ${emit.stdout}${emit.stderr}`);
      const verify = execute(compiler, ['--target', target, '--interface', ifaces, '--verify-interface', join(directory, 'verify.s'), ...files, runtime, osRuntime]);
      assert.equal(verify.status, 0, `${test.name}: interfaces disagree with their sources: ${verify.stdout}${verify.stderr}`);
      viaInterface = { ifaces };
    }
    const executable = compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, extra: test.flags ?? [] });
    // A codegen case pins what a build must (and must not) find in the assembly it emitted: a proved
    // entry point, or a bounds check the refinements removed. `compileProgram` leaves the `.s` beside
    // the program.
    // `asm` pins describe the default build; --verify-facts deliberately keeps the checks a proof
    // removed, so that build is not what they describe.
    if ((test.asm || test.asmAbsent) && process.env.GRAIL_VERIFY_FACTS !== '1') {
      const text = readFileSync(join(directory, 'program.s'), 'utf8');
      for (const pin of test.asm ?? []) assert.ok(text.includes(pin), `${test.name}: expected assembly to contain ${JSON.stringify(pin)}`);
      for (const pin of test.asmAbsent ?? []) assert.ok(!text.includes(pin), `${test.name}: expected assembly not to contain ${JSON.stringify(pin)}`);
    }
    // The interface build is a second program from the same sources; it has to behave the same.
    const interfaceExecutable = viaInterface ? compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, name: 'program-interface', interfaces: viaInterface.ifaces }) : null;
    if (test.compileOnly) { passed++; continue; }
    // A case may pin the environment it needs (`"env": {"GRAIL_POOL_WORKERS": "1"}`), which is how a
    // test proves a pool size the host would not otherwise choose. Everything else is inherited.
    const options = test.env ? { cwd: directory, env: { ...process.env, ...test.env } } : { cwd: directory };
    const result = execute(executable, test.args ?? [], target, options);
    if (result.error) throw result.error;
    // A case that dies by signal can still pin its output: an abort must not resume the foreign or
    // Grail code that ran before it, so what was printed up to the abort is part of the contract.
    // A diagnostic the runtime promises (once per process) is part of the observable contract.
    if (test.stderr !== undefined) {
      const errors = result.stderr.toString();
      // One substring, carried `stderrCount` times (once by default), or a list of substrings, each
      // carried once: a backtrace pins its frames apart because a file's absolute path sits between
      // them, and on qemu targets the emulator appends a line of its own.
      for (const pin of [test.stderr].flat()) {
        const wanted = Array.isArray(test.stderr) ? 1 : (test.stderrCount ?? 1);
        const occurrences = errors.split(pin).length - 1;
        assert.equal(occurrences, wanted, `${test.name}: expected ${wanted} x ${JSON.stringify(pin)} in ${JSON.stringify(errors)}`);
      }
    }
    if (interfaceExecutable) {
      const ifaceResult = execute(interfaceExecutable, test.args ?? [], target, options);
      assert.equal(ifaceResult.status, result.status, `${test.name}: the interface build exits differently: ${ifaceResult.stderr}`);
      assert.equal(ifaceResult.stdout.toString(), result.stdout.toString(), `${test.name}: the interface build prints something else`);
    }
    if (test.signal) {
      assert.equal(result.signal, test.signal, `${test.name}: ${result.status}: ${result.stderr}`);
      if (test.stdout !== undefined) assert.equal(result.stdout.toString(), test.stdout, test.name);
    } else { assert.equal(result.status, test.status ?? 0, `${test.name}: ${result.signal}: ${result.stderr}`); assert.equal(result.stdout.toString(), test.stdout, test.name); }
  }
  if (resume) writeFileSync(join(markers, test.name), '');
  passed++;
}
console.log(`${target}: ${passed} native execution/rejection regressions passed`
  + (skipped ? `, ${skipped} skipped (host-only)` : '')
  + (filtered ? `, ${filtered} not selected (filter/shard)` : '')
  + (resumed ? `, ${resumed} already passed (resumed)` : ''));
