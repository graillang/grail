// The native regression corpus (tests/native-cases.json) against a freshly built compiler.
//
// `grail test` at the repository root forwards to this file, so the flags documented here are the
// ones `grail test` takes there (docs/testing.md says which command owns which semantics). A project
// outside this repository runs its own tests/ programs instead; that is `grail test` in
// compiler/cli.grl.
//
// Selection: --filter REGEX, --shard i/n, positional literal name fragments, --list, --jobs N.
// Reporting: one block per failing case (source path, expected vs actual stdout/stderr, exit
// status and signal, the failed assertion), then a stable summary line
// `passed X failed Y skipped Z`. `--update` rewrites the expectations of the selected cases that
// differ, and only when it is asked for.
import { assertNoDuplicateKeys } from './case-keys.mjs';
import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync, existsSync, copyFileSync } from 'node:fs';
import { join, basename, resolve, dirname } from 'node:path';
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';
import { root, compilerSources, hostTarget, targetName, buildCompiler, compileProgram, execute, useAssemblerOf } from './native.mjs';

const legacyReferenceSyntax = /\b(?:borrow|borrow_mut)\s*\(|(?<!\bfn )\b(?:read|mut)\s*</;
const targetNames = ['x86_64', 'aarch64', 'riscv64', 'macos-x86_64', 'macos-aarch64'];
const usage = `usage: bun tools/test-native.mjs [TARGET] [PATHS...] [--filter REGEX] [--shard i/n]
                                  [--jobs N] [--list] [--fail-fast] [--update]

A case is selected when TARGET and its "targets"/"backends" admit this run, its name matches every
--filter and every positional PATH fragment (plain substrings, so no escaping), and its position
falls in --shard. --list prints the selected names instead of running them. --jobs N runs the
selection in N child processes, one stripe each, and merges the reports in case order; --fail-fast
then stops each stripe, not the whole run.

Environment (kept for the gates that predate the flags): GRAIL_TEST_FILTER, GRAIL_TEST_SHARD,
GRAIL_TEST_RESUME=1, GRAIL_TEST_JOBS, GRAIL_BACKEND, GRAIL_VERIFY_FACTS, GRAIL_TIMING (1: also run
the "timing" cases, whose verdict is a wall-clock measurement).

--unit-identity (x86_64, native backend) does not run the programs: it compiles every case that
compiles three times - with no unit store, with an empty one, with the one the second compile
filled - and requires the three assemblies to be byte-identical and every filed unit to replay; and
once more with --shift-declarations 3, and with the bodies compiled by two processes cut two ways
(GRAIL_BODY_SLICE) and with a worker that dies, none of which may change the assembly either
(docs/design/incremental-compilation.md, "Per-function units").`;

function parseArguments(argv) {
  const options = {
    target: process.env.GRAIL_TEST_TARGET ?? null,
    filter: process.env.GRAIL_TEST_FILTER ?? null,
    shard: process.env.GRAIL_TEST_SHARD ?? null,
    jobs: process.env.GRAIL_TEST_JOBS ?? '1',
    stripe: process.env.GRAIL_TEST_STRIPE ?? null,
    resume: process.env.GRAIL_TEST_RESUME === '1',
    resultFile: process.env.GRAIL_TEST_RESULT_FILE ?? null,
    list: false,
    failFast: false,
    update: false,
    unitIdentity: process.env.GRAIL_UNIT_IDENTITY === '1',
    paths: [],
  };
  const value = (flag, i) => {
    if (i + 1 >= argv.length) throw new Error(`${flag} needs a value\n${usage}`);
    return argv[i + 1];
  };
  let targetSeen = false;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--list') options.list = true;
    else if (arg === '--fail-fast') options.failFast = true;
    else if (arg === '--update') options.update = true;
    else if (arg === '--unit-identity') options.unitIdentity = true;
    else if (arg === '--filter') { options.filter = value(arg, i); i++; }
    else if (arg.startsWith('--filter=')) options.filter = arg.slice('--filter='.length);
    else if (arg === '--shard') { options.shard = value(arg, i); i++; }
    else if (arg.startsWith('--shard=')) options.shard = arg.slice('--shard='.length);
    else if (arg === '--jobs') { options.jobs = value(arg, i); i++; }
    else if (arg.startsWith('--jobs=')) options.jobs = arg.slice('--jobs='.length);
    else if (arg === '--target') { options.target = value(arg, i); i++; }
    else if (arg.startsWith('--target=')) options.target = arg.slice('--target='.length);
    else if (arg === '--help' || arg === '-h') { console.log(usage); process.exit(0); }
    else if (arg.startsWith('-')) throw new Error(`unknown flag ${arg}\n${usage}`);
    // A positional that names a target is the target, exactly as `test-native.mjs x86_64` always
    // meant; only then do the remaining positionals name cases.
    else if (targetNames.includes(arg) && !targetSeen) { options.target = arg; targetSeen = true; }
    else options.paths.push(arg);
  }
  if (options.target === null) options.target = hostTarget;
  if (!targetNames.includes(options.target)) throw new Error(`unknown target ${options.target}\n${usage}`);
  options.filter = options.filter ? new RegExp(options.filter) : null;
  if (options.shard) {
    const match = /^(\d+)\/(\d+)$/.exec(options.shard);
    if (!match) throw new Error(`--shard must be i/n, got ${options.shard}`);
    const [index, count] = [Number(match[1]), Number(match[2])];
    if (!(count >= 1 && index >= 1 && index <= count)) throw new Error(`--shard ${options.shard}: index must be 1..${count}`);
    options.shard = { index: index - 1, count };
  }
  if (options.stripe) {
    const match = /^(\d+)\/(\d+)$/.exec(options.stripe);
    if (!match) throw new Error(`GRAIL_TEST_STRIPE must be i/n, got ${options.stripe}`);
    const [index, count] = [Number(match[1]), Number(match[2])];
    if (!(count >= 1 && index >= 1 && index <= count)) throw new Error(`GRAIL_TEST_STRIPE ${options.stripe}: index must be 1..${count}`);
    options.stripe = { index: index - 1, count };
  }
  options.jobs = Number(options.jobs);
  if (!Number.isInteger(options.jobs) || options.jobs < 1) throw new Error(`--jobs must be a positive integer, got ${options.jobs}`);
  return options;
}

// A case's arguments. One that climbs out of the case's directory to the repository
// (`../../../../tests/lib/zlib`) was written for the unstriped layout, where a case directory is four
// levels down; a striped run (`--jobs N`) is one level deeper, so the path is made absolute here
// instead of meaning a different place depending on how the run was split.
function caseArgs(test) {
  return (test.args ?? []).map(arg => arg.startsWith('../../../../') ? join(root, arg.slice('../../../../'.length)) : arg);
}

// ---- the corpus's own invariants -------------------------------------------------------------
// Kept internal source on the modern dialect, including comments and diagnostics.
function checkSources(cases) {
  for (const file of [...compilerSources, ...readdirSync(join(root, 'lib')).filter(f => f.endsWith('.grl')).map(f => join(root, 'lib', f))]) {
    assert.doesNotMatch(readFileSync(file, 'utf8'), legacyReferenceSyntax, `${file}: legacy internal reference syntax`);
  }
  for (const test of cases) {
    if (test.removedSyntax !== undefined) assert.ok(test.removedSyntax === true && test.reject, `${test.name}: removedSyntax requires an intentional rejection`);
    if (test.source && legacyReferenceSyntax.test(test.source)) {
      assert.ok(test.reject && test.removedSyntax === true, `${test.name}: legacy syntax is only allowed as intentional removed-syntax rejection input`);
    }
  }
  for (const directory of ['compiler/tests', 'book/examples', 'abundance/src', 'abundance/tests']) {
    for (const file of readdirSync(join(root, directory)).filter(f => f.endsWith('.grl'))) {
      const path = join(root, directory, file);
      // Line comments are prose, not syntax: `read through a borrow (` is not a legacy reference.
      assert.doesNotMatch(readFileSync(path, 'utf8').replace(/\/\/.*$/gm, ''), legacyReferenceSyntax, `${path}: legacy fixture reference syntax`);
    }
  }
}

// ---- selection -------------------------------------------------------------------------------
// A case is skipped (not a failure) when it names another host or backend, and not selected at all
// when a filter, a positional fragment, a shard or a job stripe excludes it.
function selected(test, position, options) {
  for (const path of options.paths) if (!test.name.includes(path)) return false;
  if (options.filter && !options.filter.test(test.name)) return false;
  if (options.shard && position % options.shard.count !== options.shard.index) return false;
  if (options.stripe && position % options.stripe.count !== options.stripe.index) return false;
  return true;
}
function hostOnly(test, target) {
  // `pending` names the work a case waits for: it states the behaviour that work must produce,
  // fails until then, and is skipped rather than weakened. Removing the field is how it is armed.
  if (test.pending) return true;
  // A case whose verdict is a wall-clock measurement runs only when asked (GRAIL_TIMING=1, as the
  // quiet-window runs set it): under load it fails without anything being wrong. Each such case has
  // a correctness twin that asserts the result without the clock.
  if (test.timing && process.env.GRAIL_TIMING !== '1') return true;
  if (test.targets && !test.targets.includes(target)) return true;
  if (test.backends && !test.backends.includes(process.env.GRAIL_BACKEND ?? 'native')) return true;
  return false;
}

// ---- reporting -------------------------------------------------------------------------------
const clip = (text, limit = 4000) => (text.length > limit ? `${text.slice(0, limit)}\n    [... ${text.length - limit} more bytes; the run's own directory has the full output]` : text);
function indent(text) {
  return text.replace(/\n$/, '').split('\n').map(line => `    ${line}`).join('\n');
}
// What this case claims about its program: the expectation side of the report below.
function expectations(test) {
  if (test.reject) {
    const diagnostics = [test.diagnostic ?? []].flat().filter(Boolean);
    return diagnostics.length ? diagnostics.map(fragment => `diagnostic contains ${JSON.stringify(fragment)}`).join(', ') : 'the compiler exits 1';
  }
  const parts = [];
  if (test.driver) parts.push('grail build: one run and one interface per module');
  parts.push(`status ${test.signal ? `(no status; signal ${test.signal})` : (test.status ?? 0)}`);
  if (test.stdout !== undefined) parts.push(`stdout ${JSON.stringify(test.stdout)}`);
  for (const pin of [test.stderr ?? []].flat().filter(Boolean)) {
    parts.push(`stderr carries ${JSON.stringify(pin)} ${Array.isArray(test.stderr) ? 1 : (test.stderrCount ?? 1)}x`);
  }
  for (const pin of [test.stderrAbsent ?? []].flat().filter(Boolean)) parts.push(`stderr never carries ${JSON.stringify(pin)}`);
  return parts.join('\n    ');
}
function failureBlock(result) {
  const lines = [`FAIL ${result.name}`, `  source: ${result.observed.source}`];
  lines.push(`  exit:   status ${result.observed.status}, signal ${result.observed.signal}`);
  lines.push(`  wanted: ${expectations(result.test)}`);
  if (result.observed.stdout !== null && !result.test.reject) lines.push(`  stdout: ${JSON.stringify(clip(result.observed.stdout))}`);
  if (result.observed.stderr !== null && result.observed.stderr !== '') lines.push(`  stderr: ${JSON.stringify(clip(result.observed.stderr))}`);
  lines.push(`  why:    ${indent(result.message).trim()}`);
  return lines.join('\n');
}

// A codegen pin is a string the emitted assembly must (or must not) contain, or an object
// `{"in": "SYMBOL", "text": "..."}` that looks only at that function's body. The scoped form is what
// a pin about one function means: every program compiles the standard library, whose own checked
// arithmetic contains the traps a pin about the program's code is trying to see or not see.
function pinnedAssembly(text, pin) {
  if (typeof pin === 'string') return text;
  const head = `\n${pin.in}:`;
  const at = text.indexOf(head);
  if (at < 0) throw new Error(`the emitted assembly has no function \`${pin.in}\``);
  const lines = text.slice(at + 1).split('\n');
  const body = [lines[0]];
  for (const line of lines.slice(1)) {
    // The next symbol at column 0 ends the body; `SYMBOL.suffix:` (a refinement's proved entry) and
    // `.L` local labels stay in it.
    if (/^[^\s.][^\s]*:$/.test(line) && !line.startsWith(`${pin.in}.`)) break;
    body.push(line);
  }
  return body.join('\n');
}
function pinText(pin) {
  return typeof pin === 'string' ? pin : pin.text;
}

// ---- one case --------------------------------------------------------------------------------
// `observed` is filled in as the case runs, so a failure report can show the actual values even
// when the assertion that failed only named one of them.
// The body edits of the identity mode (see its use): the text of the last function whose body has
// a statement, edited, or nothing when the file has none.
function mutations(text) {
  const bodies = [...text.matchAll(/\n[ \t]*(?:pub )?fn [A-Za-z_]\w*[^{;]*\{\n/g)];
  if (bodies.length < 2) return [];
  const last = bodies[bodies.length - 1];
  const at = last.index + last[0].length;
  const rest = text.slice(at);
  const out = [];
  const literal = rest.match(/(?<![\w.])(\d+)(?![\w.])/);
  if (literal && literal.index < rest.indexOf('\n}')) {
    out.push(['a literal', text.slice(0, at) + rest.slice(0, literal.index) + String(Number(literal[1]) + 1) + rest.slice(literal.index + literal[1].length)]);
  }
  out.push(['an added statement', `${text.slice(0, at)}    zz_added := 3;\n${rest}`]);
  out.push(['an error', `${text.slice(0, at)}    zz_not_a_name_anywhere();\n${rest}`]);
  return out;
}
function proveMutations(test, files, directory, options) {
  const first = files[0];
  if (!first || !first.endsWith('.grl')) return 0;
  const original = readFileSync(first, 'utf8');
  const edits = mutations(original);
  if (edits.length === 0) return 0;
  const edit = join(directory, 'edit.grl');
  const list = [edit, ...files.slice(1)];
  const store = join(directory, 'units-edit');
  const run = withStore => {
    const extra = [...options.extra, ...(withStore ? ['--fn-cache', store, '--fn-cache-id', 'unit-identity', '--fn-pack', 'pk-unit-identity'] : [])];
    try {
      compileProgram(compiler, list, directory, { ...options, name: 'edit', extra });
      return { ok: true, text: readFileSync(join(directory, 'edit.s')) };
    } catch (error) {
      const said = String(error?.message ?? error).split('\n').slice(1).filter(line => !line.startsWith('grail: fn-cache')).join('\n');
      return { ok: false, text: Buffer.from(said) };
    }
  };
  writeFileSync(edit, original);
  run(true);
  let done = 0;
  for (const [what, text] of edits) {
    writeFileSync(edit, text);
    const viaRecord = run(true);
    const fresh = run(false);
    assert.equal(viaRecord.ok, fresh.ok, `${test.name}: ${what}: through the body record the compile ${viaRecord.ok ? 'succeeds' : 'fails'}, without it it ${fresh.ok ? 'succeeds' : 'fails'}\n${viaRecord.text}\n---\n${fresh.text}`);
    assert.ok(viaRecord.text.equals(fresh.text), `${test.name}: ${what}: through the body record the ${fresh.ok ? 'assembly' : 'diagnostics'} differ (${describeDifference(fresh.text, viaRecord.text)})`);
    done += 1;
  }
  return done;
}
// Where two assemblies first differ, as the two lines there.
function describeDifference(a, b) {
  let at = 0;
  while (at < a.length && at < b.length && a[at] === b[at]) at++;
  const line = bytes => { const from = bytes.lastIndexOf(10, at - 1) + 1; let to = bytes.indexOf(10, at); if (to < 0) to = bytes.length; return JSON.stringify(bytes.subarray(from, to).toString()); };
  return `first difference at byte ${at}: ${line(a)} / ${line(b)}`;
}
function runCase(test, position, context) {
  const { compiler, target, work, snapshot, runtime, osRuntime, roots } = context;
  // `noRoots` is the compile the compiler's own diagnostic is about: no module root at all.
  const caseRoots = test.noRoots ? [] : [...roots, ...(test.moduleRoots ?? [])];
  const observed = { source: context.sources[position], stdout: null, stderr: null, status: null, signal: null };
  const result = { position, name: test.name, test, observed, message: '' };
  try {
    const directory = join(work, test.name);
    rmSync(directory, { recursive: true, force: true });
    mkdirSync(directory, { recursive: true });
    // A `driver` case is a project, not one compiler invocation: `grail build` compiles one module
    // per run and writes one interface per module, so what it pins is the set of interfaces against
    // the set of modules the build compiled (docs/design/separate-compilation.md, "What a run
    // compiles"). The entry is the case's `source`; `project` fixtures keep their own names,
    // because the driver resolves `use pair;` to `src/pair.grl`.
    if (test.driver) {
      const project = join(directory, 'project');
      mkdirSync(join(project, 'src'), { recursive: true });
      writeFileSync(join(project, 'grail.toml'), '[package]\nname = "drivercase"\nversion = "0.1.0"\n');
      writeFileSync(join(project, 'src/main.grl'), test.source);
      for (const name of readdirSync(test.projectDir)) copyFileSync(join(test.projectDir, name), join(project, 'src', name));
      // A file the case places somewhere other than `src/`: a module root that is not the project's
      // own source directory is exactly what `--module-root` is for, and a fixture that can only
      // live in `src/` cannot test it.
      for (const [at, text] of Object.entries(test.projectExtra ?? {})) {
        const target = join(project, at);
        mkdirSync(dirname(target), { recursive: true });
        writeFileSync(target, text);
      }
      const output = join(project, 'target/prog');
      // `--print-inputs FILE` is the oracle for what the build resolved: the same root list must
      // reach the resolution probe and the compile, so the file names every module it compiled.
      const inputs = join(directory, 'inputs.txt');
      const buildFlags = [...(test.flags ?? [])];
      if (test.printInputs) buildFlags.push('--print-inputs', inputs);
      // `driverFile` names the entry explicitly, which is the shape that resolves `use` through the
      // module roots the command line gives (`--module-root DIR`), rather than through `src/`.
      const entryArgs = test.driverFile ? [test.driverFile] : [];
      const built = execute(compiler, ['build', '--target', target, ...buildFlags, ...entryArgs, '-o', output], target, { cwd: project, env: { ...process.env, GRAIL_HOME: root } });
      assert.equal(built.status, 0, `${test.name}: grail build failed\n${built.stdout}${built.stderr}`);
      assert.equal(built.signal, null, `${test.name}: grail build crashed (${built.signal})`);
      // One run per module, one interface per module: runtime is the trusted base and has none. A
      // case that builds a single module (`driverNoModules`) has no split to inspect: it pins that
      // the build resolved and ran, which is what `--module-root` was failing to do.
      // One run per module, one interface per module: runtime is the trusted base and has none.
      // A case with `driverNoModules` builds a single module, so there is no `.modules` split to
      // inspect: what it pins is that the build resolved `use` through the module roots the command
      // line gives and produced a program that runs. That is the shape `--module-root` was failing
      // to serve, and the reason this mode exists at all.
      if (!test.driverNoModules) {
      const modules = join(`${output}.modules`);
      const ran = readdirSync(modules).filter(name => name.endsWith('.s')).map(name => name.slice(0, -2)).sort();
      const written = readdirSync(join(modules, 'interfaces')).filter(name => name.endsWith('.iface')).map(name => name.slice(0, -6)).sort();
      assert.ok(ran.length > 1, `${test.name}: the default build must compile one module per run (${ran.join(', ')})`);
      assert.deepEqual(written, ran.filter(name => name !== 'runtime'), `${test.name}: every module a run compiles from source must get its interface written`);
      for (const module of test.driverModules ?? []) assert.ok(ran.includes(module), `${test.name}: no compiler run for module ${module} (${ran.join(', ')})`);
      if (test.printInputs) {
        const listed = readFileSync(inputs, 'utf8').split('\n').filter(Boolean).map(row => row.split('\t')[0]);
        for (const module of test.driverModules ?? []) assert.ok(listed.includes(module), `${test.name}: --print-inputs does not name ${module} (${listed.join(', ')})`);
      }
      }
      const image = execute(output, test.args ?? [], target, { cwd: project, env: { ...process.env, ...(test.env ?? {}) } });
      observed.stdout = image.stdout.toString();
      observed.stderr = image.stderr.toString();
      observed.status = image.status;
      observed.signal = image.signal;
      assert.equal(image.signal, null, `${test.name}: the program crashed (${image.signal})`);
      if (test.stdout !== undefined) assert.equal(observed.stdout, test.stdout, `${test.name}: unexpected output`);
      result.outcome = 'pass';
      return result;
    }
    // A case's own files (or its inline source) come first, then the modules it lists.
    let files;
    if (test.files) files = [...test.files, ...(test.modules ?? [])];
    else { const input = join(directory, 'input.grl'); writeFileSync(input, test.source); files = [input, ...(test.modules ?? [])]; }
    if (test.reject) {
      const assembly = join(directory, 'prior.s');
      writeFileSync(assembly, 'prior valid artifact');
      const rejected = execute(compiler, [...caseRoots, '--target', target, ...(test.flags ?? []), assembly, ...files, runtime, osRuntime]);
      observed.status = rejected.status;
      observed.signal = rejected.signal;
      observed.stdout = `${rejected.stdout}${rejected.stderr}`;
      observed.stderr = rejected.stderr.toString();
      assert.equal(rejected.signal, null, `${test.name}: compiler crashed (${rejected.signal}): ${rejected.stdout}${rejected.stderr}`);
      assert.equal(rejected.status, 1, `${test.name}: a rejected program must exit 1: ${rejected.stdout}${rejected.stderr}`);
      // `diagnostic` is one required fragment of the error output, or a list of them (the message and
      // its location are on different lines of a rendered error).
      const diagnostics = [test.diagnostic ?? []].flat();
      for (const fragment of diagnostics) {
        assert.ok(`${rejected.stdout}${rejected.stderr}`.includes(fragment), `${test.name}: expected diagnostic ${fragment}: ${rejected.stdout}${rejected.stderr}`);
      }
      // A rejection may pin how many times its diagnostic is printed, exactly as `stderrCount` does for
      // runtime output: a replayed generic body reaches the same source line again, and it has to be
      // reported - and counted - once (docs/diagnostics.md).
      if (test.diagnosticCount !== undefined) {
        assert.equal(diagnostics.length, 1, `${test.name}: diagnosticCount needs exactly one diagnostic`);
        const occurrences = `${rejected.stdout}${rejected.stderr}`.split(diagnostics[0]).length - 1;
        assert.equal(occurrences, test.diagnosticCount, `${test.name}: expected ${test.diagnosticCount} x ${JSON.stringify(diagnostics[0])} in ${JSON.stringify(`${rejected.stdout}${rejected.stderr}`)}`);
      }
      assert.equal(readFileSync(assembly, 'utf8'), 'prior valid artifact', `${test.name}: invalid program overwrote prior output`);
      // A rejection that must also hold when the modules are read from their interfaces: the
      // interface has to carry everything the refusal rests on.
      if (test.interfaces) {
        const ifaces = join(directory, 'ifaces');
        // The interface comes from the library modules alone: the entry may be the very thing the
        // rejection is about, so it cannot be what the emit run compiles. `interfaceFiles` is the
        // stand-in entry for that run, and it changes the second leg too: a program whose own entry
        // is refused has no `main.iface` to check it against, so that leg builds with `--use` - the
        // entry from its source, the modules' declarations and generic bodies from the interfaces.
        // `--interface DIR` is the verification mode: it compares every module given as source with
        // its interface, the entry included, which is exactly the file that cannot be emitted here.
        const modules = test.modules ?? [];
        assert.ok(modules.length !== 0, `${test.name}: an interface rejection needs module sources`);
        const stand = test.interfaceFiles ?? [];
        // The interface files come first: the first source after OUT.s is the entry of the emit run,
        // and a reject case's own entry is the thing the rejection is about - so the interface is
        // emitted from these files, which pull in the modules they use.
        const emit = execute(compiler, [...caseRoots, '--target', target, '--emit-interface', ifaces, join(directory, 'emit.s'), ...stand, ...modules, runtime, osRuntime]);
        assert.equal(emit.status, 0, `${test.name}: emitting interfaces failed: ${emit.stdout}${emit.stderr}`);
        const separate = stand.length !== 0;
        const mode = separate ? ['--use', ifaces] : ['--interface', ifaces];
        const entry = separate ? (test.files ?? []) : files;
        assert.ok(entry.length !== 0, `${test.name}: an interface build needs an entry file`);
        const viaInterface = execute(compiler, [...caseRoots, '--target', target, ...mode, join(directory, 'iface.s'), ...entry, runtime, osRuntime]);
        assert.equal(viaInterface.status, 1, `${test.name}: the interface build must refuse it too: ${viaInterface.stdout}${viaInterface.stderr}`);
        for (const fragment of diagnostics) {
          assert.ok(`${viaInterface.stdout}${viaInterface.stderr}`.includes(fragment), `${test.name}: expected diagnostic ${fragment} from the interface build: ${viaInterface.stdout}${viaInterface.stderr}`);
        }
      }
      result.outcome = 'pass';
      return result;
    }
    // Interface-first: emit one interface per module, then compile the same program against them.
    // The interface build is the build this case's behaviour is asserted on when the case asks for
    // it, so a gap in an interface is a test failure rather than a silent difference.
    let viaInterface;
    if (test.interfaces) {
      const ifaces = join(directory, 'ifaces');
      const emit = execute(compiler, [...caseRoots, '--target', target, '--overflow=' + (test.overflow ?? 'checked'), '--emit-interface', ifaces, join(directory, 'emit.s'), ...files, runtime, osRuntime]);
      assert.equal(emit.status, 0, `${test.name}: emitting interfaces failed: ${emit.stdout}${emit.stderr}`);
      const verify = execute(compiler, [...caseRoots, '--target', target, '--interface', ifaces, '--verify-interface', join(directory, 'verify.s'), ...files, runtime, osRuntime]);
      assert.equal(verify.status, 0, `${test.name}: interfaces disagree with their sources: ${verify.stdout}${verify.stderr}`);
      viaInterface = { ifaces };
    }
    const executable = compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, extra: [...caseRoots, ...(test.flags ?? [])] });
    if (context.unitIdentity) {
      // The per-function unit store against this case: the assembly above was written with no store.
      // Twice more to the same path - an empty store, which files every unit and puts each one into
      // the run the way a replay does, then that store warm, which replays them - and all three
      // have to be the same bytes: a unit that is not the body a fresh emission writes is a silent
      // miscompile, and a registration a replay does not make again is a missing symbol.
      const assembly = join(directory, 'program.s');
      const plain = readFileSync(assembly);
      const store = join(directory, 'units');
      const withStore = () => {
        const output = [];
        compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, extra: [...caseRoots, ...(test.flags ?? []), '--fn-cache', store, '--fn-cache-id', 'unit-identity', '--fn-pack', 'pk-unit-identity'], output });
        // `why` is the compiler's own account of the rules that kept bodies out, summed per rule.
        const account = { hits: 0, filed: 0, kept: 0, why: {} };
        for (const m of output.join('').matchAll(/grail: fn-cache: \S+: (\d+) hit, (\d+) filed, (\d+) not units(?: \(([^)]*)\))?/g)) {
          account.hits += Number(m[1]); account.filed += Number(m[2]); account.kept += Number(m[3]);
          for (const item of (m[4] ?? '').split(', ').filter(Boolean)) { const at = item.lastIndexOf(' '); account.why[item.slice(0, at)] = (account.why[item.slice(0, at)] ?? 0) + Number(item.slice(at + 1)); }
        }
        return { bytes: readFileSync(assembly), account };
      };
      // The declaration count is not in a unit's key because no body's text depends on it: with
      // three tuple declarations synthesised before the first body, every later declaration index
      // moves and the assembly must not.
      compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, extra: [...caseRoots, ...(test.flags ?? []), '--shift-declarations', '3'] });
      const shifted = readFileSync(assembly);
      assert.ok(plain.equals(shifted), `${test.name}: with the declaration indices shifted the assembly changed (${describeDifference(plain, shifted)})`);
      // Parallel bodies: two processes with the bodies cut in two, then two processes dealing the
      // bodies out in turn - no process compiles two bodies in a row - and a worker that dies at
      // once, whose bodies the parent compiles itself. Each must write the bytes one process writes.
      const withEnv = (vars, extra = []) => {
        const saved = {};
        for (const [k, v] of Object.entries(vars)) { saved[k] = process.env[k]; process.env[k] = v; }
        try {
          compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, extra: [...caseRoots, ...(test.flags ?? []), ...extra] });
        } finally {
          for (const [k, v] of Object.entries(saved)) { if (v === undefined) delete process.env[k]; else process.env[k] = v; }
        }
        return readFileSync(assembly);
      };
      for (const [what, vars] of [
        ['two body workers, the bodies cut in two', { GRAIL_JOBS: '2', GRAIL_BODY_SLICE: '2' }],
        ['two body workers, the bodies dealt out in turn', { GRAIL_JOBS: '2', GRAIL_BODY_SLICE: '1' }],
        ['a body worker that dies', { GRAIL_JOBS: '3', GRAIL_BODY_SLICE: '1', GRAIL_TEST_BODY_WORKER_DIE: '1' }],
      ]) {
        const got = withEnv(vars);
        assert.ok(plain.equals(got), `${test.name}: ${what}: the assembly is not the one-process assembly (${describeDifference(plain, got)})`);
      }
      const empty = withStore();
      const warm = withStore();
      assert.ok(plain.equals(empty.bytes), `${test.name}: with an empty unit store the assembly is not the assembly a compile with no store writes (${describeDifference(plain, empty.bytes)})`);
      assert.ok(plain.equals(warm.bytes), `${test.name}: with a warm unit store the assembly is not the assembly a compile with no store writes (${describeDifference(plain, warm.bytes)})`);
      assert.equal(empty.account.hits, 0, `${test.name}: an empty unit store replayed a body`);
      assert.equal(warm.account.hits, empty.account.filed, `${test.name}: every unit the first compile filed must replay in the second`);
      assert.equal(warm.account.filed, 0, `${test.name}: a warm unit store filed a unit again`);
      // And the same three ways with `--debug`: a debug build names its functions' labels and builds
      // its line table from positions, so it is the build that notices a label or a position the
      // unit layer spells differently - and `compileProgram` assembles it, which is what refuses a
      // table that names a label no body defines. A case some other flag keeps from `--debug` is
      // left to its own flags.
      let debugChecked = 0;
      if (!(test.flags ?? []).includes('--debug')) {
        const debugAssembly = join(directory, 'program-debug.s');
        const debug = more => { compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, name: 'program-debug', extra: [...caseRoots, ...(test.flags ?? []), '--debug', ...more] }); return readFileSync(debugAssembly); };
        const plainDebug = debug([]);
        {
          const debugStore = join(directory, 'units-debug');
          const unitFlags = ['--fn-cache', debugStore, '--fn-cache-id', 'unit-identity', '--fn-pack', 'pk-unit-identity'];
          const emptyDebug = debug(unitFlags);
          const warmDebug = debug(unitFlags);
          assert.ok(plainDebug.equals(emptyDebug), `${test.name}: --debug with an empty unit store is not --debug with no store (${describeDifference(plainDebug, emptyDebug)})`);
          assert.ok(plainDebug.equals(warmDebug), `${test.name}: --debug with a warm unit store is not --debug with no store (${describeDifference(plainDebug, warmDebug)})`);
          debugChecked = 1;
        }
      }
      // An edited body through the module's body record (docs/design/incremental-compilation.md,
      // "Reusing a module's run"): the case's first file is copied, compiled into a store of its own,
      // and then one body is edited three ways - a literal, an added statement, an error. Each edit
      // is compiled with the store, where every other body comes from the record, and without one,
      // and the two must agree: the same assembly, or the same diagnostics and the same status.
      const mutated = proveMutations(test, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, extra: [...caseRoots, ...(test.flags ?? [])] });
      result.units = { ...empty.account, debug: debugChecked, mutated };
      result.outcome = 'pass';
      return result;
    }
    // A codegen case pins what a build must (and must not) find in the assembly it emitted: a proved
    // entry point, or a bounds check the refinements removed. `compileProgram` leaves the `.s` beside
    // the program.
    // `asm` pins describe the default build; --verify-facts deliberately keeps the checks a proof
    // removed, so that build is not what they describe.
    if ((test.asm || test.asmAbsent) && process.env.GRAIL_VERIFY_FACTS !== '1') {
      const text = readFileSync(join(directory, 'program.s'), 'utf8');
      // Under the LLVM backend a lifted function leaves the `.s` (its code is in `program.s.ll`), so a
      // pin naming one describes nothing there: the pins describe the native backend's assembly.
      const lifted = pin => (process.env.GRAIL_BACKEND ?? 'native') === 'llvm' && typeof pin !== 'string' && !text.includes(`\n${pin.in}:`);
      for (const pin of test.asm ?? []) if (!lifted(pin)) assert.ok(pinnedAssembly(text, pin).includes(pinText(pin)), `${test.name}: expected assembly to contain ${JSON.stringify(pin)}`);
      for (const pin of test.asmAbsent ?? []) if (!lifted(pin)) assert.ok(!pinnedAssembly(text, pin).includes(pinText(pin)), `${test.name}: expected assembly not to contain ${JSON.stringify(pin)}`);
    }
    // The interface build is a second program from the same sources; it has to behave the same.
    const interfaceExecutable = viaInterface ? compileProgram(compiler, files, directory, { target, overflow: test.overflow ?? 'checked', runtime, osRuntime, name: 'program-interface', interfaces: viaInterface.ifaces, extra: caseRoots }) : null;
    if (test.compileOnly) { result.outcome = 'pass'; return result; }
    // A case may pin the environment it needs (`"env": {"GRAIL_WORKERS": "1"}`), which is how a
    // test proves a worker count the host would not otherwise choose. Everything else is inherited.
    const options = test.env ? { cwd: directory, env: { ...process.env, ...test.env } } : { cwd: directory };
    const ran = execute(executable, caseArgs(test), target, options);
    if (ran.error) throw ran.error;
    observed.stdout = ran.stdout.toString();
    observed.stderr = ran.stderr.toString();
    observed.status = ran.status;
    observed.signal = ran.signal;
    // A case that dies by signal can still pin its output: an abort must not resume the foreign or
    // Grail code that ran before it, so what was printed up to the abort is part of the contract.
    // A diagnostic the runtime promises (once per process) is part of the observable contract.
    if (test.stderr !== undefined || test.stderrAbsent !== undefined) {
      const errors = ran.stderr.toString();
      // One substring, carried `stderrCount` times (once by default), or a list of substrings, each
      // carried once: a backtrace pins its frames apart because a file's absolute path sits between
      // them, and on qemu targets the emulator appends a line of its own.
      for (const pin of [test.stderr ?? []].flat()) {
        const wanted = Array.isArray(test.stderr) ? 1 : (test.stderrCount ?? 1);
        const occurrences = errors.split(pin).length - 1;
        assert.equal(occurrences, wanted, `${test.name}: expected ${wanted} x ${JSON.stringify(pin)} in ${JSON.stringify(errors)}`);
      }
      // And what must never appear: a failure report names the program's frames, never the runtime's.
      for (const pin of [test.stderrAbsent ?? []].flat()) {
        assert.ok(!errors.includes(pin), `${test.name}: unexpected ${JSON.stringify(pin)} in ${JSON.stringify(errors)}`);
      }
    }
    if (interfaceExecutable) {
      const ifaceResult = execute(interfaceExecutable, caseArgs(test), target, options);
      assert.equal(ifaceResult.status, ran.status, `${test.name}: the interface build exits differently: ${ifaceResult.stderr}`);
      assert.equal(ifaceResult.stdout.toString(), ran.stdout.toString(), `${test.name}: the interface build prints something else`);
    }
    if (test.signal) {
      assert.equal(ran.signal, test.signal, `${test.name}: ${ran.status}: ${ran.stderr}`);
      if (test.stdout !== undefined) assert.equal(ran.stdout.toString(), test.stdout, test.name);
    } else {
      assert.equal(ran.status, test.status ?? 0, `${test.name}: ${ran.signal}: ${ran.stderr}`);
      assert.equal(ran.stdout.toString(), test.stdout, test.name);
    }
    result.outcome = 'pass';
    return result;
  } catch (error) {
    result.outcome = 'fail';
    result.message = error?.message ?? String(error);
    return result;
  }
}

// ---- --update ---------------------------------------------------------------------------------
// Only the fields a run can observe exactly are rewritten: `stdout`, and `status` when the case pins
// one. A `signal` pin and a `stderr` pin are contracts in their own right - a rejection's diagnostic
// above all - so a case whose other pins still disagree is reported instead of rewritten, and
// docs/testing.md says why.
function updateCase(result) {
  const test = result.test;
  if (test.reject) return { fields: {}, reason: 'a rejection pins its own diagnostic; edit it by hand' };
  const fields = {};
  if (result.observed.stdout !== test.stdout) fields.stdout = result.observed.stdout;
  if (test.signal === undefined && result.observed.signal === null && result.observed.status !== (test.status ?? 0)) fields.status = result.observed.status;
  const pins = [test.stderr ?? []].flat().filter(Boolean);
  const stderrAgrees = pins.every(pin => (result.observed.stderr ?? '').split(pin).length - 1 === (Array.isArray(test.stderr) ? 1 : (test.stderrCount ?? 1)))
    && [test.stderrAbsent ?? []].flat().every(pin => !(result.observed.stderr ?? '').includes(pin));
  const stdout = fields.stdout !== undefined ? fields.stdout : test.stdout;
  const status = fields.status !== undefined ? fields.status : (test.status ?? 0);
  const statusAgrees = test.signal !== undefined ? test.signal === result.observed.signal : (status === result.observed.status && result.observed.signal === null);
  if (stdout === result.observed.stdout && statusAgrees && stderrAgrees) {
    return { fields, reason: Object.keys(fields).length ? '' : 'no expectation changed' };
  }
  const left = [];
  if (!stderrAgrees) left.push('stderr pins');
  if (!statusAgrees) left.push(test.signal !== undefined ? 'signal pin' : 'exit status');
  return { fields, reason: `not rewritten: ${left.join(', ')} still disagree; edit by hand` };
}
function applyUpdates(failures) {
  const updates = [];
  for (const failure of failures) {
    const update = updateCase(failure);
    Object.assign(failure.test, update.fields);
    updates.push({ position: failure.position, name: failure.name, fields: update.fields, reason: update.reason });
  }
  return updates;
}

// ---- the run ----------------------------------------------------------------------------------
// Every path in a case is rewritten to a staged copy, so a run in progress cannot mix source
// revisions; the report still names the case's own path, captured here before staging.
function stage(context) {
  mkdirSync(context.work, { recursive: true });
  const snapshot = join(context.work, 'inputs');
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
  for (let i = 0; i < context.cases.length; i++) {
    for (const field of ['files', 'modules', 'interfaceFiles']) if (context.cases[i][field]) context.cases[i][field] = context.cases[i][field].map((file, j) => {
      const source = resolve(root, file);
      if (dirname(source) === join(root, 'lib')) return join(stdSnapshot, basename(source));
      const path = join(snapshot, `${i}-${field}-${j}-${basename(file)}`);
      writeFileSync(path, readFileSync(source));
      return path;
    });
  }
  // A case's `roots` are fixtures a `use NAME;` reaches: staged under their own names in a directory
  // of their own, which the compiler is given as a module root (docs/design/module-resolution.md).
  // This is the one staging that must keep a fixture's name - `modules` and `files` are named on the
  // command line, so their staged names do not matter.
  for (const [i, test] of context.cases.entries()) {
    if (!test.roots) continue;
    const byName = join(snapshot, `${i}-root`);
    mkdirSync(byName, { recursive: true });
    for (const file of test.roots) writeFileSync(join(byName, basename(file)), readFileSync(resolve(root, file)));
    test.moduleRoots = ['--module-root', byName];
  }
  // A `driver` case's project fixtures are staged under their own names, for the same reason `roots`
  // are: the driver resolves `use util;` to the file `src/util.grl`, so the name is the interface.
  for (const [i, test] of context.cases.entries()) {
    if (!test.driver) continue;
    const byName = join(snapshot, `${i}-project`);
    mkdirSync(byName, { recursive: true });
    for (const file of test.project ?? []) writeFileSync(join(byName, basename(file)), readFileSync(resolve(root, file)));
    test.projectDir = byName;
  }
  // A case's `data` files (what an `@embed` reads) are staged under their own names beside its
  // sources, so a path relative to the source resolves as it does in a project.
  for (const test of context.cases) for (const file of test.data ?? []) writeFileSync(join(snapshot, basename(file)), readFileSync(resolve(root, file)));
  // The compiler resolves `use NAME;` through its module roots, so a case's stdlib modules are
  // reached by name from the staged std snapshot (docs/design/module-resolution.md).
  return { ...context, snapshot, runtime, osRuntime, roots: ['--module-root', stdSnapshot] };
}


// Runs the selection in this process. The report is a value: a --jobs parent merges one per stripe.
function runSelection(options, context) {
  const report = { passed: 0, failed: 0, skipped: 0, resumed: 0, failures: [], units: { hits: 0, filed: 0, kept: 0, debug: 0, mutated: 0, programs: 0, why: {} } };
  for (const [position, test] of context.cases.entries()) {
    if (hostOnly(test, options.target)) { report.skipped++; continue; }
    if (!selected(test, position, options)) continue;
    const marker = join(context.markers, test.name);
    if (options.resume && existsSync(marker)) { report.resumed++; continue; }
    const result = runCase(test, position, context);
    if (result.units) { report.units.programs++; for (const field of ['hits', 'filed', 'kept', 'debug', 'mutated']) report.units[field] += result.units[field] ?? 0; for (const [rule, n] of Object.entries(result.units.why ?? {})) report.units.why[rule] = (report.units.why[rule] ?? 0) + n; }
    if (result.outcome === 'pass') {
      report.passed++;
      if (options.resume) writeFileSync(marker, '');
    } else {
      report.failed++;
      report.failures.push(result);
      if (options.failFast) break;
    }
  }
  return report;
}

function summaryLine(options, report, updated, filtered) {
  const parts = [`passed ${report.passed} failed ${report.failed} skipped ${report.skipped}`];
  if (updated) parts.push(`updated ${updated}`);
  if (report.resumed) parts.push(`resumed ${report.resumed}`);
  if (filtered) parts.push(`not-selected ${filtered}`);
  if (report.units?.programs) parts.push(`unit-identity: ${report.units.programs} programs compiled three ways, ${report.units.filed} units filed and replayed, ${report.units.kept} bodies not units, ${report.units.debug} also with --debug, ${report.units.mutated} body edits through the body record; rules that kept a body out: ${Object.entries(report.units.why).map(([rule, n]) => `${rule} ${n}`).join(', ') || 'none'}`);
  return `${options.target}: ${parts.join(' ')}`;
}

// The corpus file is generated with JSON escapes for every non-ASCII byte (unicode-escape output, as
// Python's json.dump(ensure_ascii=True) writes it), so an --update rewrites only the lines it changed.
function writeCases(cases) {
  const file = join(root, 'tests/native-cases.json');
  const text = JSON.stringify(cases, null, 2).replace(/[\u0080-\uffff]/g, ch => `\\u${ch.charCodeAt(0).toString(16).padStart(4, '0')}`);
  writeFileSync(file, `${text}\n`);
  return file;
}

function printUpdates(updates) {
  for (const update of updates) {
    console.log(`UPDATE ${update.name}: ${Object.keys(update.fields).length ? Object.keys(update.fields).join(', ') : update.reason}`);
  }
}

// One child per stripe, all started together, each writing its report to a file the parent reads.
// The parent built the compiler first and names it in the environment, so no two children race to
// build the same content-addressed directory.
function spawnStripe(options, argv, stripe, compiler) {
  return new Promise((settle) => {
    mkdirSync(join(root, '.work/native-tests'), { recursive: true });
    const resultFile = join(root, `.work/native-tests/stripe-${stripe}-${process.pid}.json`);
    const env = {
      ...process.env,
      // The stripe runs exactly this compiler. It used to receive it only as GRAIL_COMPILER, which
      // buildCompiler() reads as the *base* to build with, so every stripe built a second compiler
      // from it into one shared directory at once, and each finished build replaced the file the
      // other stripes were already running - their /proc/self/exe went "(deleted)" and a
      // compile-time probe, which re-runs the compiler by that path, failed.
      GRAIL_COMPILER: compiler,
      GRAIL_TEST_COMPILER: compiler,
      GRAIL_TEST_JOBS: '1',
      GRAIL_TEST_STRIPE: `${stripe}/${options.jobs}`,
      GRAIL_TEST_RESULT_FILE: resultFile,
      GRAIL_TEST_TARGET: options.target,
    };
    const child = spawn(process.execPath, [process.argv[1], ...argv], { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('close', (code, signal) => {
      let report = null;
      try { report = JSON.parse(readFileSync(resultFile, 'utf8')); } catch (error) { report = null; }
      rmSync(resultFile, { force: true });
      settle({ stripe, code, signal, stdout, stderr, report });
    });
  });
}

const argv = process.argv.slice(2);
let options;
try {
  options = parseArguments(argv);
} catch (error) {
  // A bad invocation is not a test failure: say what is wrong and which line the run did not reach.
  console.error(`test-native: ${error?.message ?? error}`);
  process.exit(2);
}
// A repeated key would silently fuse two cases (JSON.parse keeps the last): refuse the file instead.
assertNoDuplicateKeys(join(root, 'tests/native-cases.json'));
const cases = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
// Two cases with one name would run one and silently shadow the other: a clean git merge can add the
// same case on both sides at different places, which merge-cases never sees.
{
  const seen = new Set(), twice = [];
  for (const c of cases) { if (seen.has(c.name)) twice.push(c.name); seen.add(c.name); }
  if (twice.length) throw new Error(`tests/native-cases.json names a case more than once: ${twice.join(', ')}`);
}
// --update writes this copy: staging rewrites a case's paths to snapshot files, and those must never
// reach the corpus file.
const pristine = JSON.parse(JSON.stringify(cases));
const isChild = options.stripe !== null;
if (!isChild) checkSources(cases);
// The report names a case's own source, before staging rewrites the paths to snapshot copies.
const sources = cases.map(test => test.files?.[0] ?? 'inline source');
// The backend names the work directory, so a native and an LLVM run of one target can overlap; a
// stripe gets its own subdirectory, so two children never share a case directory or a snapshot.
if (options.unitIdentity && (options.target !== 'x86_64' || (process.env.GRAIL_BACKEND ?? 'native') !== 'native')) {
  console.error('test-native: --unit-identity is the per-function unit store, which is the Linux x86_64 native backend');
  process.exit(2);
}
// The reference of the identity mode is one process; the parallel variants set their own count.
if (options.unitIdentity) process.env.GRAIL_JOBS = '1';
// A work directory and pass markers of its own for each kind of run: two can be in flight at once.
const backend = `${process.env.GRAIL_BACKEND ?? 'native'}${process.env.GRAIL_VERIFY_FACTS === '1' ? '+facts' : ''}${options.unitIdentity ? '+units' : ''}`;
const backendLabel = backend === 'native' ? options.target : `${options.target}-${backend}`;
const baseWork = join(root, '.work/native-tests', backendLabel);
const work = options.stripe ? join(baseWork, `stripe-${options.stripe.index + 1}-${options.stripe.count}`) : baseWork;

if (options.list) {
  if (!isChild) {
    const names = [];
    for (const [position, test] of cases.entries()) if (!hostOnly(test, options.target) && selected(test, position, options)) names.push(test.name);
    for (const name of names) console.log(name);
    console.error(`${options.target}: ${names.length} cases selected`);
  }
  process.exit(0);
}

// --jobs N: N children, one stripe each, merged and printed here so the report is identical to a
// sequential run of the same selection, in case order.
if (!isChild && options.jobs > 1) {
  const compiler = buildCompiler();
  const childArgv = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--jobs') { i++; continue; }
    if (argv[i].startsWith('--jobs=')) continue;
    childArgv.push(argv[i]);
  }
  const stripes = await Promise.all(Array.from({ length: options.jobs }, (_, index) => spawnStripe(options, childArgv, index + 1, compiler)));
  const merged = { passed: 0, failed: 0, skipped: 0, resumed: 0, failures: [], units: { hits: 0, filed: 0, kept: 0, debug: 0, mutated: 0, programs: 0, why: {} } };
  const updates = [];
  let crashed = 0;
  for (const stripe of stripes) {
    if (!stripe.report) {
      crashed++;
      console.log(`FAIL worker ${stripe.stripe}/${options.jobs} (${stripe.signal ?? `exit ${stripe.code}`})\n${indent(clip(stripe.stderr || stripe.stdout, 2000)).trim()}`);
      continue;
    }
    for (const field of ['passed', 'failed', 'skipped', 'resumed']) merged[field] += stripe.report[field];
    for (const field of ['hits', 'filed', 'kept', 'debug', 'mutated', 'programs']) merged.units[field] += stripe.report.units?.[field] ?? 0;
    for (const [rule, n] of Object.entries(stripe.report.units?.why ?? {})) merged.units.why[rule] = (merged.units.why[rule] ?? 0) + n;
    merged.failures.push(...stripe.report.failures);
    updates.push(...(stripe.report.updates ?? []));
  }
  merged.failures.sort((a, b) => a.position - b.position);
  for (const failure of merged.failures) console.log(failureBlock(failure));
  let updated = 0;
  if (options.update && updates.length) {
    printUpdates(updates);
    for (const stripe of stripes) for (const change of stripe.report?.changes ?? []) Object.assign(pristine[change.position], change.fields);
    updated = updates.filter(update => Object.keys(update.fields).length).length;
    if (updated) console.log(`updated ${updated} cases in ${writeCases(pristine)}`);
  }
  const filtered = cases.length - merged.passed - merged.failed - merged.skipped - merged.resumed;
  console.log(summaryLine(options, merged, updated, filtered));
  const unresolved = updates.filter(update => update.reason !== '').length;
  process.exit(crashed || (options.update ? unresolved : merged.failed) ? 1 : 0);
}

const compiler = process.env.GRAIL_TEST_COMPILER ?? buildCompiler();
useAssemblerOf(compiler);
// Key by the compiler's content-addressed directory, not its file name: every build is named
// `grail`. The markers are shared by every stripe: a pass is a property of the compiler, not of the
// process that observed it.
const markers = join(baseWork, 'pass', `${basename(dirname(compiler))}-${backend}`);
mkdirSync(markers, { recursive: true });
const context = { ...stage({ cases, compiler, target: options.target, work, markers, sources }), unitIdentity: options.unitIdentity };
const report = runSelection(options, context);
const updates = options.update ? applyUpdates(report.failures) : [];
const changes = updates.filter(update => Object.keys(update.fields).length).map(update => ({ position: update.position, fields: update.fields }));
if (isChild) {
  // A child runs no corpora policy of its own: the parent prints, writes the corpus file and exits.
  writeFileSync(options.resultFile, JSON.stringify({ ...report, updates, changes }));
  process.exit(report.failed ? 1 : 0);
}
for (const failure of report.failures) console.log(failureBlock(failure));
let updated = 0;
if (options.update && updates.length) {
  printUpdates(updates);
  updated = changes.length;
  for (const change of changes) Object.assign(pristine[change.position], change.fields);
  if (updated) console.log(`updated ${updated} cases in ${writeCases(pristine)}`);
}
const filtered = cases.length - report.passed - report.failed - report.skipped - report.resumed;
console.log(summaryLine(options, report, updated, filtered));
const unresolved = updates.filter(update => update.reason !== '').length;
process.exit(options.update ? (unresolved ? 1 : 0) : (report.failed ? 1 : 0));
