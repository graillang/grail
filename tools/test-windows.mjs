// Cross-build regression checks for the Windows x86-64 backend. Nothing here executes guest code:
// every case is validated by inspecting the emitted assembly, the COFF object and the PE image, so
// the suite is meaningful even on hosts without Wine.
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { command, compileProgram as compileElf, execute, root } from './native.mjs';
import { compileProgram, headers, inspectImage, inspectObject, kernel32, windowsTarget } from './windows.mjs';

const elfTarget = 'x86_64';

function executableImports(image) {
  const names = [];
  for (const line of inspectImage(image).split('\n')) {
    const match = line.match(/^\s+Symbol: (\S+)/);
    if (match) names.push(match[1]);
  }
  return names;
}

function importSlots(object) {
  // `__imp_` slots stay undefined in the object; the short import library defines them.
  return inspectObject(object).split('\n')
    .filter(line => /^\s+Name: __imp_/.test(line))
    .map(line => line.trim().split(' ')[1]);
}

export async function check(compiler) {
  const cases = JSON.parse(readFileSync(join(root, 'tests/windows-cases.json'), 'utf8'));
  const work = join(root, '.work/windows-tests');
  let passed = 0;

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
    assert.ok(assembly.includes('call __imp_ExitProcess'), `${test.name}: process exit is not an import call`);

    // Object-level evidence: a real x86-64 COFF object with the entry symbol and import slots.
    const object = inspectObject(built.object);
    assert.match(object, /Format: COFF-x86-64/, `${test.name}: object is not COFF x86-64`);
    assert.match(object, /Machine: IMAGE_FILE_MACHINE_AMD64 \(0x8664\)/, `${test.name}: wrong COFF machine`);
    assert.match(object, /Name: grail_entry\n\s+Value: \d+\n\s+Section: \.text/, `${test.name}: grail_entry is not defined in .text`);
    const imports = importSlots(built.object);
    for (const symbol of imports) assert.ok(kernel32.includes(symbol.replace('__imp_', '')), `${test.name}: no short import for ${symbol}`);

    // Image-level evidence: PE32+, console subsystem, kernel32 imports, entry point mapping.
    const image = headers(built.executable);
    assert.match(inspectImage(built.executable), /Name: kernel32\.dll/, `${test.name}: kernel32 import descriptor missing`);
    assert.match(image, /Magic\s+020b\t\(PE32\+\)/, `${test.name}: not a PE32+ image`);
    assert.match(image, /Subsystem\s+00000003\t\(Windows CUI\)/, `${test.name}: not a console image`);
    const entry = image.match(/AddressOfEntryPoint\s+([0-9a-f]+)/)[1];
    assert.notEqual(Number.parseInt(entry, 16), 0, `${test.name}: image has no entry point`);
    const expected = executableImports(built.executable).sort();
    assert.deepEqual(expected, ['ExitProcess', 'VirtualAlloc'], `${test.name}: unexpected import set ${expected}`);
    for (const name of expected) assert.ok(kernel32.includes(name), `${test.name}: no short import object for ${name}`);
    passed++;
    console.log(`windows-x86_64 ${test.name}: COFF object + PE image verified (entry RVA 0x${entry})`);
  }

  // The PE target must reject unknown targets without clobbering an existing artifact.
  const directory = join(work, 'reject-unknown-target');
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, 'prior.s');
  writeFileSync(assembly, 'prior valid artifact');
  const rejected = execute(compiler, ['--target', 'windows-arm64', assembly, join(root, 'book/examples/hello.grl'), join(root, 'compiler/runtime.grl')]);
  assert.notEqual(rejected.status, 0, 'windows-arm64 was accepted');
  assert.match(`${rejected.stdout}${rejected.stderr}`, /unsupported target/, 'missing target diagnostic');
  assert.equal(readFileSync(assembly, 'utf8'), 'prior valid artifact', 'rejected target overwrote the output');
  passed++;

  // The shared x86-64 emitter must still produce a working ELF program.
  const elfDirectory = join(work, 'linux-regression');
  rmSync(elfDirectory, { recursive: true, force: true });
  const elf = compileElf(compiler, ['book/examples/hello.grl'], elfDirectory, { target: elfTarget, name: 'hello' });
  const run = execute(elf, [], elfTarget, { cwd: elfDirectory });
  assert.equal(run.status, 0, `linux regression failed: ${run.stderr}`);
  assert.equal(run.stdout.toString(), 'Hello, world!\n', 'linux regression output changed');
  passed++;
  console.log(`windows-x86_64: target rejection and linux ${elfTarget} regression verified`);
  console.log(`windows-x86_64: ${passed} cross-build checks passed`);
  return 0;
}
