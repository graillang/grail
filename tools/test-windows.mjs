// Cross-build regression checks for the Windows x86-64 backend. Static checks always run and
// inspect the emitted assembly, the COFF object and the PE image; when Wine is installed the same
// cases also execute, so the Windows OS layer is covered by real stdout and exit codes.
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { command, compileProgram as compileElf, execute, root } from './native.mjs';
import { compileProgram, headers, inspectImage, inspectObject, kernel32, windowsTarget } from './windows.mjs';

const elfTarget = 'x86_64';

function importSlots(object) {
  // `__imp_` slots stay undefined in the object; the short import library defines them.
  return inspectObject(object).split('\n')
    .filter(line => /^\s+Name: __imp_/.test(line))
    .map(line => line.trim().split(' ')[1]);
}

function wineAvailable() {
  const probe = spawnSync(process.env.GRAIL_WINE ?? 'wine', ['--version'], { timeout: 60_000 });
  return probe.status === 0 ? (process.env.GRAIL_WINE ?? 'wine') : null;
}

function winePrefix() {
  // A repository-local prefix keeps the suite reproducible and never touches the user's Wine.
  return process.env.WINEPREFIX ?? join(root, '.work/wine-prefix');
}

function runWine(wine, executable, args, cwd) {
  return spawnSync(wine, [executable, ...args], {
    cwd,
    timeout: 300_000,
    maxBuffer: 8 * 1024 * 1024,
    env: { ...process.env, WINEPREFIX: winePrefix(), WINEDEBUG: '-all' },
  });
}

// The compiler's import table and the generated library must stay in step.
function compilerImports() {
  const source = readFileSync(join(root, 'compiler/native.grl'), 'utf8');
  const table = source.slice(source.indexOf('fn win32_arity'), source.indexOf('fn raw_arguments'));
  return [...table.matchAll(/view\("([A-Za-z0-9_]+)"\)/g)].map(m => m[1]).sort();
}

export async function check(compiler) {
  const declared = compilerImports();
  assert.deepEqual(declared, [...kernel32].sort(), 'compiler Win32 import table and kernel32.lib disagree');
  const cases = JSON.parse(readFileSync(join(root, 'tests/windows-cases.json'), 'utf8'));
  const work = join(root, '.work/windows-tests');
  const wine = wineAvailable();
  let passed = 0;
  let executed = 0;

  for (const test of cases) {
    const directory = join(work, test.name);
    rmSync(directory, { recursive: true, force: true });
    mkdirSync(directory, { recursive: true });
    let inputs = test.file ? [test.file] : null;
    if (!inputs) {
      const input = join(directory, 'input.grl');
      writeFileSync(input, test.source);
      inputs = [input];
    }
    const built = compileProgram(compiler, inputs, directory, { name: test.name });
    const assembly = readFileSync(built.assembly, 'utf8');

    // Source-level evidence: COFF directives only, no ELF-only directives or Linux entry.
    assert.ok(assembly.includes('.globl grail_entry\ngrail_entry:'), `${test.name}: missing PE entry`);
    assert.match(assembly, /^\.def f_main_main\n\.scl 2\n\.type 32\n\.endef\n/m, `${test.name}: missing COFF function directive`);
    assert.ok(!assembly.includes(',@function'), `${test.name}: ELF symbol type leaked into COFF output`);
    assert.ok(!assembly.includes('.note.GNU-stack'), `${test.name}: ELF note section leaked into COFF output`);
    assert.ok(!assembly.includes('\n_start:'), `${test.name}: Linux entry point emitted for PE target`);
    assert.ok(assembly.includes('call *__imp_ExitProcess(%rip)'), `${test.name}: process exit is not an IAT call`);

    // Object-level evidence: a real x86-64 COFF object with the entry symbol and import slots.
    const object = inspectObject(built.object);
    assert.match(object, /Format: COFF-x86-64/, `${test.name}: object is not COFF x86-64`);
    assert.match(object, /Machine: IMAGE_FILE_MACHINE_AMD64 \(0x8664\)/, `${test.name}: wrong COFF machine`);
    assert.match(object, /Name: grail_entry\n\s+Value: \d+\n\s+Section: \.text/, `${test.name}: grail_entry is not defined in .text`);
    for (const symbol of importSlots(built.object)) {
      assert.ok(kernel32.includes(symbol.replace('__imp_', '')), `${test.name}: no short import for ${symbol}`);
    }

    // Image-level evidence: PE32+, console subsystem, kernel32 imports, entry point mapping.
    const image = headers(built.executable);
    assert.match(inspectImage(built.executable), /Name: kernel32\.dll/, `${test.name}: kernel32 import descriptor missing`);
    assert.match(image, /Magic\s+020b\t\(PE32\+\)/, `${test.name}: not a PE32+ image`);
    assert.match(image, /Subsystem\s+00000003\t\(Windows CUI\)/, `${test.name}: not a console image`);
    const entry = image.match(/AddressOfEntryPoint\s+([0-9a-f]+)/)[1];
    assert.notEqual(Number.parseInt(entry, 16), 0, `${test.name}: image has no entry point`);
    const imported = [...inspectImage(built.executable).matchAll(/^\s+Symbol: (\S+)/gm)].map(m => m[1]);
    for (const name of ['ExitProcess', 'WriteFile', 'GetCommandLineA', 'CreateFileA']) {
      if (test.name === 'hello' || test.name === 'file-write-read') {
        assert.ok(imported.includes(name), `${test.name}: expected ${name} in the import table`);
      }
    }

    if (wine) {
      const run = runWine(wine, built.executable, test.args ?? [], directory);
      assert.equal(run.status, test.status ?? 0, `${test.name}: wine exit ${run.status}: ${run.stderr}`);
      assert.equal(run.stdout.toString(), test.stdout, `${test.name}: wine stdout`);
      executed++;
    }
    passed++;
    console.log(`windows-x86_64 ${test.name}: COFF object + PE image verified (entry RVA 0x${entry})${wine ? ', executed' : ''}`);
  }

  // The PE target must reject unknown targets without clobbering an existing artifact.
  const directory = join(work, 'reject-unknown-target');
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, 'prior.s');
  writeFileSync(assembly, 'prior valid artifact');
  const rejected = execute(compiler, ['--target', 'windows-arm64', assembly, join(root, 'book/examples/hello.grl'), join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')]);
  assert.notEqual(rejected.status, 0, 'windows-arm64 was accepted');
  assert.match(`${rejected.stdout}${rejected.stderr}`, /unsupported target/, 'missing target diagnostic');
  assert.equal(readFileSync(assembly, 'utf8'), 'prior valid artifact', 'rejected target overwrote the output');
  passed++;

  // The shared x86-64 path and the portable runtime must still produce and run ELF programs.
  const elfDirectory = join(work, 'linux-regression');
  rmSync(elfDirectory, { recursive: true, force: true });
  const elf = compileElf(compiler, ['book/examples/hello.grl'], elfDirectory, { target: elfTarget, name: 'hello' });
  const run = execute(elf, [], elfTarget, { cwd: elfDirectory });
  assert.equal(run.status, 0, `linux regression failed: ${run.stderr}`);
  assert.equal(run.stdout.toString(), 'Hello, world!\n', 'linux regression output changed');
  // The portable argv contract must agree between the Linux entry stub and the Win32 command line.
  const argvCase = cases.find(c => c.name === 'argument-list');
  const argvSource = join(elfDirectory, 'argument-list.grl');
  writeFileSync(argvSource, argvCase.source);
  const elfArgs = compileElf(compiler, [argvSource], elfDirectory, { target: elfTarget, name: 'argument-list' });
  const argsRun = execute(elfArgs, argvCase.args, elfTarget, { cwd: elfDirectory });
  assert.equal(argsRun.status, 0, `linux argv regression failed: ${argsRun.stderr}`);
  assert.equal(argsRun.stdout.toString(), argvCase.stdout, 'linux and PE argv handling disagree');
  passed++;
  console.log(`windows-x86_64: target rejection and linux ${elfTarget} regression verified`);
  console.log(`windows-x86_64: ${passed} cross-build checks passed (${executed} executed under wine${wine ? '' : '; wine unavailable'})`);
  return 0;
}
