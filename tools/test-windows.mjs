// Cross-build regression checks for the Windows x86-64 backend. Static checks always run and
// inspect the emitted assembly, the COFF object and the PE image; when Wine is installed the same
// cases also execute, so the Windows OS layer is covered by real stdout and exit codes.
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { command, compileProgram as compileElf, execute, root } from './native.mjs';
import { compileProgram, headers, inspectImage, inspectObject, inspectRelocations, inspectUnwind, kernel32, windowsAarch64, windowsTarget } from './windows.mjs';

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

    // Unwind evidence: every .def function carries .seh_* directives and the object has records.
    assert.equal((assembly.match(/^\.seh_proc /gm) ?? []).length, (assembly.match(/^\.def /gm) ?? []).length,
      `${test.name}: not every function has an unwind prologue`);
    for (const match of assembly.matchAll(/^\.seh_stackalloc (\d+)$/gm)) {
      const size = Number(match[1]);
      assert.ok(size > 0 && size % 8 === 0, `${test.name}: invalid stack allocation ${size}`);
    }
    assert.match(inspectUnwind(built.object), /RuntimeFunction/, `${test.name}: object has no .pdata records`);

    // Image-level evidence: PE32+, console subsystem, kernel32 imports, entry point mapping.
    const image = headers(built.executable);
    assert.match(inspectImage(built.executable), /Name: kernel32\.dll/, `${test.name}: kernel32 import descriptor missing`);
    assert.match(image, /Magic\s+020b\t\(PE32\+\)/, `${test.name}: not a PE32+ image`);
    assert.match(image, /Subsystem\s+00000003\t\(Windows CUI\)/, `${test.name}: not a console image`);
    const pdata = image.match(/Entry 3 ([0-9a-f]+) ([0-9a-f]+)\s+Exception Directory \[\.pdata\]/);
    assert.ok(pdata, `${test.name}: image has no .pdata directory`);
    assert.ok(Number.parseInt(pdata[1], 16) !== 0 && Number.parseInt(pdata[2], 16) !== 0,
      `${test.name}: empty .pdata directory`);
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

  // windows-aarch64: PE/COFF for ARM64. There is no ARM64 Windows runner on this host, so these
  // cases are validated statically: assembly shape, COFF machine, relocations and the image.
  const armCases = ['hello', 'integer-print', 'file-write-read', 'argument-list'];
  for (const name of armCases) {
    const test = cases.find(c => c.name === name);
    const directory = join(work, `arm64-${name}`);
    rmSync(directory, { recursive: true, force: true });
    mkdirSync(directory, { recursive: true });
    let inputs;
    if (test.file) inputs = [test.file];
    else {
      const input = join(directory, 'input.grl');
      writeFileSync(input, test.source);
      inputs = [input];
    }
    const built = compileProgram(compiler, inputs, directory, { name, target: windowsAarch64 });
    const assembly = readFileSync(built.assembly, 'utf8');

    // ARM64 instructions and PE import sequences, with no x86 or ELF spelling left behind.
    assert.ok(assembly.includes('.globl grail_entry\ngrail_entry:'), `${name}/${windowsAarch64}: missing PE entry`);
    assert.match(assembly, /^\.def f_main_main$/m, `${name}/${windowsAarch64}: missing COFF function record`);
    assert.ok(assembly.includes('adrp x16,__imp_ExitProcess'), `${name}/${windowsAarch64}: exit is not an IAT load`);
    assert.ok(assembly.includes('ldr x16,[x16,:lo12:__imp_ExitProcess]'), `${name}/${windowsAarch64}: IAT load is not page-relative`);
    assert.ok(assembly.includes('blr x16'), `${name}/${windowsAarch64}: import is not an indirect call`);
    assert.ok(!assembly.includes('pushq '), `${name}/${windowsAarch64}: x86 instruction leaked into ARM64 output`);
    assert.ok(!assembly.includes(',@function'), `${name}/${windowsAarch64}: ELF symbol type leaked`);
    assert.ok(!assembly.includes('.note.GNU-stack'), `${name}/${windowsAarch64}: ELF note section leaked`);
    assert.ok(!assembly.includes('\n_start:'), `${name}/${windowsAarch64}: Linux entry point emitted`);

    const object = inspectObject(built.object);
    assert.match(object, /Format: COFF-ARM64/, `${name}/${windowsAarch64}: object is not COFF ARM64`);
    assert.match(object, /Machine: IMAGE_FILE_MACHINE_ARM64 \(0xAA64\)/, `${name}/${windowsAarch64}: wrong COFF machine`);
    assert.match(object, /Name: grail_entry\n\s+Value: \d+\n\s+Section: \.text/, `${name}/${windowsAarch64}: grail_entry is not in .text`);
    for (const symbol of importSlots(built.object)) {
      assert.ok(kernel32.includes(symbol.replace('__imp_', '')), `${name}/${windowsAarch64}: no short import for ${symbol}`);
    }
    const relocations = inspectRelocations(built.object);
    for (const kind of ['IMAGE_REL_ARM64_PAGEBASE_REL21', 'IMAGE_REL_ARM64_PAGEOFFSET_12L', 'IMAGE_REL_ARM64_BRANCH26']) {
      assert.ok(relocations.includes(kind), `${name}/${windowsAarch64}: missing ${kind}`);
    }

    const imageHeaders = inspectImage(built.executable);
    assert.match(imageHeaders, /Format: COFF-ARM64/, `${name}/${windowsAarch64}: image is not ARM64`);
    assert.match(imageHeaders, /Machine: IMAGE_FILE_MACHINE_ARM64 \(0xAA64\)/, `${name}/${windowsAarch64}: wrong image machine`);
    const image = headers(built.executable);
    assert.match(image, /Magic\s+020b\t\(PE32\+\)/, `${name}/${windowsAarch64}: not a PE32+ image`);
    assert.match(image, /Subsystem\s+00000003\t\(Windows CUI\)/, `${name}/${windowsAarch64}: not a console image`);
    assert.notEqual(Number.parseInt(image.match(/AddressOfEntryPoint\s+([0-9a-f]+)/)[1], 16), 0, `${name}/${windowsAarch64}: no entry point`);
    const imported = [...imageHeaders.matchAll(/^\s+Symbol: (\S+)/gm)].map(m => m[1]);
    assert.ok(imported.includes('ExitProcess') && imported.includes('WriteFile'), `${name}/${windowsAarch64}: kernel32 imports missing`);
    passed++;
    console.log(`windows-aarch64 ${name}: COFF-ARM64 object + ARM64 PE image verified (static, no ARM64 runner)`);
  }

  // The PE targets must reject unknown targets without clobbering an existing artifact.
  const directory = join(work, 'reject-unknown-target');
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const assembly = join(directory, 'prior.s');
  writeFileSync(assembly, 'prior valid artifact');
  const rejected = execute(compiler, ['--target', 'windows-riscv64', assembly, join(root, 'book/examples/hello.grl'), join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')]);
  assert.notEqual(rejected.status, 0, 'windows-riscv64 was accepted');
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
  // The shared lowerer also serves the Linux cross targets; a machine change must not break them.
  for (const [crossTarget, marker] of [['aarch64', /ELF 64-bit LSB executable, ARM aarch64/], ['riscv64', /ELF 64-bit LSB executable, UCB RISC-V/]]) {
    const directory = join(work, `linux-${crossTarget}`);
    rmSync(directory, { recursive: true, force: true });
    const image = compileElf(compiler, ['book/examples/hello.grl'], directory, { target: crossTarget, name: 'hello' });
    const kind = spawnSync('file', [image], { timeout: 60_000 });
    assert.equal(kind.status, 0, `${crossTarget}: file failed`);
    assert.match(kind.stdout.toString(), marker, `${crossTarget}: not the expected ELF image`);
    passed++;
  }
  console.log(`windows-x86_64: target rejection and linux x86_64/aarch64/riscv64 builds verified`);
  console.log(`windows-x86_64: ${passed} cross-build checks passed (${executed} executed under wine${wine ? '' : '; wine unavailable'})`);
  return 0;
}
