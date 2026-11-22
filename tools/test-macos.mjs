// Static macOS backend checks: Mach-O objects and linked executables. Nothing is executed.
// Set GRAIL_COMPILER=<grail> when the checked-in bootstrap seed is older than the compiler sources.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { copyFileSync, existsSync, rmSync } from 'node:fs';
import { root, buildCompiler, compileProgram, compileOnly, assembleDylib, command, machoTargets, frameworkInstallName, machoArchitectures } from './native.mjs';
import { dylibs, verifyCodeSignature, LC_CODE_SIGNATURE, loadCommands, dylibId, exportedSymbols, undefinedSymbols, rpaths } from './macos.mjs';

const compiler = buildCompiler();
const work = join(root, '.work/macos-tests');
mkdirSync(work, { recursive: true });

// Assertion messages stay short: a whole assembly file is not useful in a failure report.
function check(condition, message) {
  assert.ok(condition, message);
}
function has(text, pattern, message) {
  check(pattern.test(text), message);
}
function lacks(text, pattern, message) {
  check(!pattern.test(text), message);
}
function tool(name, argv) {
  const result = spawnSync(name, argv, { cwd: root, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, `${name} ${argv.join(' ')} failed\n${result.stdout}${result.stderr}`);
  return result.stdout;
}

// The libSystem entry points the runtime and the darwin module are allowed to import.
const libSystem = new Set([
  // _NSGetExecutablePath is dyld's, re-exported through libSystem: the running image's own path,
  // which is what lets the driver re-invoke itself for `grail build`.
  '__NSGetExecutablePath',
  '_access', '_chmod', '_flock', '_fchmod', '_umask', '_clock_gettime', '_close', '___error', '_execve', '_exit', '_fork', '___getdirentries64',
  '_getpid', '_kill', '_mkdir', '_mmap', '_mprotect', '_munmap', '_nanosleep', '_open', '_pipe',
  // The portable scheduler parks a worker on this thread's address with libsystem_pthread's
  // private ulock entry points; they are real libSystem exports, so an object that calls them is
  // not importing something the link cannot resolve.
  '___ulock_wait', '___ulock_wake',
  '_poll', '_read', '_readlink', '_rmdir', '_sched_yield', '_sysconf', '_unlink', '_wait4', '_write',
  // Called by the runtime now that files, processes and the reactor exist (stdutil, reactor).
  '_dup2',
  '_getcwd',
  '_kevent',
  '_kqueue',
  '_lstat',
  '_rename',
  '_sigaction',
  '_sigaltstack',
  '_signal',
  '_stat',
  '_symlink',
]);
const programs = [
  { name: 'hello', source: 'fn main() {\n    println("Hello, macOS!");\n}\n', literal: true },
  { name: 'numbers', source: 'fn main() {\n    mut total = 0;\n    for i in 5 {\n        total += i * i;\n    }\n    println(total);\n}\n', literal: false },
];
const cputypes = { 'macos-x86_64': 'X86_64', 'macos-aarch64': 'ARM64' };
const files = { 'macos-x86_64': 'x86_64', 'macos-aarch64': 'arm64' };
// Every section a Grail Mach-O object may carry: code, read-only data (constants and the runtime's
// diagnostic strings), C strings and zero-fill. A section outside this set means an ELF name or a
// typo reached the assembler.
const machoSections = new Set(['__text', '__const', '__cstring', '__bss', '__DATA', '__data']);
let objects = 0, executables = 0;

for (const target of machoTargets) {
  for (const program of programs) {
    const label = `${target}/${program.name}`;
    const directory = join(work, target, program.name);
    mkdirSync(directory, { recursive: true });
    const source = join(directory, `${program.name}.grl`);
    writeFileSync(source, program.source);
    const executable = compileProgram(compiler, [source], directory, { target, name: program.name });
    const object = `${executable}.o`;
    const assembly = readFileSync(join(directory, `${program.name}.s`), 'utf8');

    // Assembly: Darwin directives, Mach-O sections, underscored symbols, no ELF leftovers.
    has(assembly, /^\.build_version macos, 11, 0$/m, `${label}: missing .build_version`);
    has(assembly, /^\.globl _main$/m, `${label}: entry is not _main`);
    has(assembly, /^_main:$/m, `${label}: missing _main label`);
    has(assembly, /^_rt_state:$/m, `${label}: rt_state is not a Mach-O symbol`);
    has(assembly, /^\.section __DATA,__bss$/m, `${label}: rt_state is not in __DATA,__bss`);
    lacks(assembly, /(^|[^_A-Za-z0-9])rt_state/m, `${label}: unprefixed rt_state reference`);
    lacks(assembly, /\.note\.GNU-stack|@progbits|,@function|^\.type /m, `${label}: ELF directive in Mach-O output`);
    lacks(assembly, /\.pushsection \.rodata/, `${label}: ELF .rodata in Mach-O output`);
    if (program.literal) {
      has(assembly, /\.pushsection __TEXT,__const/, `${label}: literals are not in __TEXT,__const`);
      has(assembly, /^\.byte 72$/m, `${label}: literal bytes missing from __TEXT,__const`);
    }

    // Object format: cputype, sections and symbol table.
    const headers = tool('llvm-objdump', ['--macho', '--private-headers', object]);
    has(headers, /MH_MAGIC_64/, `${label}: not a 64-bit Mach-O object`);
    has(headers, new RegExp(`MH_MAGIC_64\\s+${cputypes[target]}\\b`), `${label}: wrong Mach-O cputype`);
    has(headers, /LC_BUILD_VERSION[\s\S]*platform macos[\s\S]*minos 11\.0/, `${label}: object lacks a macOS build version`);
    const sections = tool('llvm-objdump', ['--macho', '--section-headers', object]);
    const expectedSections = program.literal ? ['__text', '__const', '__bss'] : ['__text', '__bss'];
    for (const section of expectedSections) {
      has(sections, new RegExp(`${section}\\s+[0-9a-f]{8}`), `${label}: missing section ${section}`);
    }
    // The runtime's own diagnostic strings are read-only data in every program, so the object's
    // sections are checked against the whole set a Mach-O Grail image may have rather than against
    // the program's own literals.
    for (const found of sections.matchAll(/^\s*\d+\s+(__\w+)/gm)) {
      check(machoSections.has(found[1]), `${label}: unexpected Mach-O section ${found[1]}`);
    }
    const symbols = tool('llvm-nm', [object]);
    has(symbols, /T _main$/m, `${label}: _main is not a defined text symbol`);
    has(symbols, / b _rt_state$/m, `${label}: _rt_state is not zero-fill storage`);
    lacks(symbols, /(^|\s)rt_state$/m, `${label}: unprefixed rt_state symbol`);
    const undefinedSymbols = tool('llvm-nm', ['-u', object]).split('\n').map(line => line.trim()).filter(Boolean);
    check(undefinedSymbols.length > 0, `${label}: expected libSystem imports`);
    for (const symbol of undefinedSymbols) {
      check(libSystem.has(symbol), `${label}: unexpected undefined symbol ${symbol}`);
    }
    objects += 1;

    // Linked executable: platform, entry point, dylib dependency, no undefined imports.
    const kind = tool('file', [executable]);
    has(kind, new RegExp(`Mach-O 64-bit ${files[target]} executable`), `${label}: not a Mach-O executable`);
    has(kind, /NOUNDEFS/, `${label}: executable keeps undefined imports`);
    const loadCommands = tool('llvm-objdump', ['--macho', '--private-headers', executable]);
    has(loadCommands, /platform macos/, `${label}: missing LC_BUILD_VERSION`);
    has(loadCommands, /minos 11\.0/, `${label}: wrong minimum macOS version`);
    has(loadCommands, /cmd LC_MAIN/, `${label}: missing LC_MAIN entry point`);
    has(loadCommands, /cmd LC_LOAD_DYLIB/, `${label}: missing dylib dependency`);
    has(loadCommands, /name \/usr\/lib\/libSystem\.B\.dylib/, `${label}: not linked against libSystem`);
    executables += 1;
  }
}

// Entry and exit follow the Apple C calling convention of the two ISAs.
const entry86 = readFileSync(join(work, 'macos-x86_64', 'hello', 'hello.s'), 'utf8');
has(entry86, /_main:\npushq %rbp\nmovq %rsp,%rbp\nmovq %rdi,_rt_state\(%rip\)\nmovq %rsi,_rt_state\+8\(%rip\)\nmovq %rdx,_rt_state\+16\(%rip\)\ncall _rt_thread_init/, 'x86-64 entry does not take argc/argv/envp through the C ABI');
has(entry86, /call _exit\n/, 'x86-64 exit does not call libSystem _exit');
const entryArm = readFileSync(join(work, 'macos-aarch64', 'hello', 'hello.s'), 'utf8');
has(entryArm, /_main:\nstp x29,x30,\[sp,#-16\]!\n/, 'arm64 entry does not build a 16-byte-aligned frame');
has(entryArm, /adrp x13,_rt_state@PAGE/, 'arm64 does not use Mach-O page relocations');
has(entryArm, /@PAGEOFF/, 'arm64 is missing the page-offset relocation');

// ELF output is untouched: no underscores, no Mach-O sections, GNU-stack note present.
const elfDirectory = join(work, 'elf');
mkdirSync(elfDirectory, { recursive: true });
writeFileSync(join(elfDirectory, 'hello.grl'), programs[0].source);
compileProgram(compiler, [join(elfDirectory, 'hello.grl')], elfDirectory, { target: 'x86_64', name: 'hello' });
const elf = readFileSync(join(elfDirectory, 'hello.s'), 'utf8');
has(elf, /^_start:$/m, 'ELF entry point changed');
has(elf, /\.note\.GNU-stack/, 'ELF lost its GNU-stack note');
has(elf, /^\.type f_/m, 'ELF lost its .type directives');
lacks(elf, /^\.globl f_/m, 'an ELF build exported a module function without --export');
lacks(elf, /\.build_version|rt_state@|\.pushsection __TEXT/, 'Mach-O output leaked into ELF');

// A target has exactly one platform module: darwin.grl and os-linux.grl define the same
// rt_syscall* set, so compiling both must be rejected rather than silently picking one.
// The compiler reports diagnostics on stdout; accept either stream.
function rejection(argv, pattern, message) {
  const result = spawnSync(compiler, argv, { cwd: root, encoding: 'utf8' });
  check(result.status !== 0, message);
  has(`${result.stdout ?? ''}${result.stderr ?? ''}`, pattern, `${message} (wrong diagnostic)`);
}
rejection(['--target', 'x86_64', join(work, 'reject.s'), join(elfDirectory, 'hello.grl'), join(root, 'compiler/os-linux.grl'), join(root, 'compiler/darwin.grl'), join(root, 'compiler/runtime.grl')],
  /duplicate function|declared twice/, 'darwin.grl compiled alongside os-linux.grl for an ELF target');
rejection(['--target', 'macos-riscv64', join(work, 'reject2.s'), join(elfDirectory, 'hello.grl'), join(root, 'compiler/runtime.grl')],
  /unsupported target/, 'macos-riscv64 was accepted');

// Platform linkage beyond libSystem: a framework stub must reach the linked image as a real
// LC_LOAD_DYLIB entry, and an unknown framework must fail the link instead of being ignored.
let frameworkLinks = 0;
for (const target of machoTargets) {
  const directory = join(work, target, 'frameworks');
  // Start clean: a stub left by an earlier run would make an "unknown" framework resolvable.
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const source = join(directory, 'hello.grl');
  writeFileSync(source, programs[0].source);
  const executable = compileProgram(compiler, [source], directory, {
    target,
    name: 'hello_framework',
    frameworks: [{ name: 'Foundation', symbols: ['_NSLog', '_grail_framework_probe'] }],
  });
  const dependency = frameworkInstallName('Foundation');
  const loaded = dylibs(executable);
  check(loaded.includes(dependency), `${target}: factory stub did not become an LC_LOAD_DYLIB (${loaded.join(', ')})`);
  check(loaded.some(name => name === '/usr/lib/libSystem.B.dylib'), `${target}: libSystem dependency lost`);
  has(readFileSync(join(directory, 'Foundation.framework', 'Foundation.tbd'), 'utf8'),
    new RegExp(`install-name: '${dependency.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}'`),
    `${target}: framework stub has the wrong install name`);
  frameworkLinks += 1;

  // A framework name without an SDK and without an export list is unverifiable: the driver must
  // refuse it rather than invent a stub that satisfies the linker.
  let failed = null;
  try {
    compileProgram(compiler, [source], directory, { target, name: 'unknown_framework', frameworks: ['NoSuchFramework'] });
  } catch (error) {
    failed = error;
  }
  check(failed !== null, `${target}: unknown framework was accepted without an SDK or export list`);
  has(String(failed && failed.message), /framework NoSuchFramework needs a macOS SDK \(GRAIL_SDK\) or an explicit export list/,
    `${target}: unknown framework produced the wrong error`);

  // And the linker itself must reject a framework it cannot find, so the stub path is not a way to
  // silence arbitrary -framework names.
  const linkError = spawnSync(process.env.GRAIL_LINKER ?? 'ld64.lld', [
    '-arch', target === 'macos-x86_64' ? 'x86_64' : 'arm64',
    '-platform_version', 'macos', '11.0', '11.0',
    '-L', directory, '-lSystem',
    '-F', directory, '-framework', 'NoSuchFramework',
    '-e', '_main', `${executable}.o`, '-o', join(directory, 'unknown_framework.out'),
  ], { cwd: root, encoding: 'utf8' });
  check(linkError.status !== 0, `${target}: ld64.lld linked an unknown framework`);
  has(`${linkError.stdout ?? ''}${linkError.stderr ?? ''}`, /framework not found for -framework NoSuchFramework/,
    `${target}: ld64.lld did not report the missing framework`);

  // Ad-hoc signature: lld writes it on x86-64 only when asked, and the CodeDirectory must hash
  // every page of the image.
  const signed = compileProgram(compiler, [source], directory, { target, name: 'signed', sign: true });
  const signature = verifyCodeSignature(signed);
  check(signature.present, `${target}: no LC_CODE_SIGNATURE after requesting an ad-hoc signature`);
  check(signature.valid, `${target}: ad-hoc signature invalid: ${signature.problems.join('; ')}`);
  check(signature.adhoc, `${target}: CS_ADHOC flag missing`);
  check(signature.pages > 0 && signature.pageSize > 0, `${target}: signature covers no pages`);
  has(signature.cdhash, /^[0-9a-f]{64}$/, `${target}: cdhash is not a SHA-256 digest`);
  check(loadCommands(signed).commands.some(c => c.cmd === LC_CODE_SIGNATURE), `${target}: load command list lost LC_CODE_SIGNATURE`);

  // Control: without the request (and without the arm64 default) there is no signature at all, so
  // a present-but-empty verdict can never be mistaken for a valid one.
  const unsigned = compileProgram(compiler, [source], directory, { target, name: 'unsigned' });
  const expectedPresent = target === 'macos-aarch64';
  check(verifyCodeSignature(unsigned).present === expectedPresent,
    `${target}: signature presence ${verifyCodeSignature(unsigned).present} does not match the link defaults`);

  // Tampering must be detected: flip a byte inside the signed region and re-validate.
  const tampered = join(directory, 'signed_tampered');
  copyFileSync(signed, tampered);
  const bytes = readFileSync(tampered);
  bytes[0x100] ^= 0xff;
  writeFileSync(tampered, bytes);
  const broken = verifyCodeSignature(tampered);
  check(!broken.valid, `${target}: a modified page still validated`);
  has(broken.problems.join('; '), /page 1 hash mismatch/, `${target}: tampering was not reported as a page hash mismatch`);
}

// Shared Mach-O libraries: the dylib must advertise its install name, export exactly the requested
// symbols (the program entry stub stays local), and an executable must pick it up as LC_LOAD_DYLIB.
let dylibsBuilt = 0;
for (const target of machoTargets) {
  const directory = join(work, target, 'dylib');
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const source = join(directory, 'greet.grl');
  writeFileSync(source, 'module greet;\n\npub fn add(a: u64, b: u64) -> u64 {\n    return a + b;\n}\n\nfn main() {\n    println("lib");\n}\n');
  // --export promotes exactly the named definition to a global symbol in the compiler itself.
  const assembly = compileOnly(compiler, [source], directory, { target, name: 'greet', exports: ['add'] });
  const installName = '/usr/local/lib/libgreet.dylib';
  const library = assembleDylib(assembly, join(directory, 'libgreet.dylib'), target, { installName, exports: ['_f_greet_add'] });

  check(exportedSymbols(library).sort().join(' ') === '_f_greet_add',
    `${target}: dylib exports ${JSON.stringify(exportedSymbols(library))} instead of just _f_greet_add`);
  check(dylibId(library) === installName, `${target}: LC_ID_DYLIB is ${JSON.stringify(dylibId(library))}`);
  has(tool('file', [library]), /Mach-O 64-bit (x86_64|arm64) dynamically linked shared library/, `${target}: not a shared library`);
  has(tool('llvm-objdump', ['--macho', '--private-headers', library]), /MH_MAGIC_64\s+\w+\s+\w+\s+\w+\s+DYLIB/, `${target}: object file type is not DYLIB`);
  // dyld_stub_binder is the lazy-binding helper the stub pages call; it is not a libSystem API.
  const imports = undefinedSymbols(library).filter(symbol => symbol !== 'dyld_stub_binder');
  for (const symbol of imports) check(libSystem.has(symbol), `${target}: dylib imports unexpected ${symbol}`);

  // Positive: an executable that needs the exported symbol records the dylib's install name.
  const consumerObject = join(work, target, 'hello', 'hello.o');
  check(existsSync(consumerObject), `${target}: missing consumer object ${consumerObject}`);
  const executable = join(directory, 'consumer');
  command([process.env.GRAIL_LINKER ?? 'ld64.lld',
    '-arch', machoArchitectures[target], '-platform_version', 'macos', '11.0', '11.0',
    '-L', directory, '-lSystem',
    '-u', '_f_greet_add', library, consumerObject, '-e', '_main', '-o', executable]);
  check(dylibs(executable).includes(installName), `${target}: consumer does not load the dylib by install name (${dylibs(executable).join(', ')})`);
  has(tool('llvm-nm', ['-u', executable]), /_f_greet_add/, `${target}: consumer did not resolve the dylib symbol`);
  dylibsBuilt += 1;

  // Negative: a symbol the dylib does not export must fail the link, not resolve to something else.
  const missing = spawnSync(process.env.GRAIL_LINKER ?? 'ld64.lld', [
    '-arch', machoArchitectures[target], '-platform_version', 'macos', '11.0', '11.0',
    '-L', directory, '-lSystem',
    '-u', '_f_greet_absent', library, consumerObject, '-e', '_main', '-o', join(directory, 'missing'),
  ], { cwd: root, encoding: 'utf8' });
  check(missing.status !== 0, `${target}: an unexported symbol linked successfully`);
  has(`${missing.stdout ?? ''}${missing.stderr ?? ''}`, /undefined symbol: _f_greet_absent/,
    `${target}: missing export produced the wrong diagnostic`);

  // Negative: the driver refuses a dylib without an install name or without exports.
  for (const [options, pattern, what] of [
    [{ exports: ['_f_greet_add'] }, /needs an install name/, 'install name'],
    [{ installName }, /needs at least one exported symbol/, 'export list'],
  ]) {
    let refused = null;
    try { assembleDylib(assembly, join(directory, 'bad.dylib'), target, options); } catch (error) { refused = error; }
    check(refused !== null, `${target}: dylib without ${what} was accepted`);
    has(String(refused && refused.message), pattern, `${target}: dylib without ${what} gave the wrong error`);
  }
  // Negative: --export naming something the module does not define is refused by the compiler, so a
  // typo can never become a global undefined reference the linker would accept.
  let bogus = null;
  try { compileOnly(compiler, [source], directory, { target, name: 'bogus', exports: ['nope'] }); } catch (error) { bogus = error; }
  check(bogus !== null, `${target}: an undefined --export name was accepted`);
  has(String(bogus && bogus.message), /export 'nope' is not defined by any function/, `${target}: undefined export gave the wrong error`);

  has(readFileSync(assembly, 'utf8'), /^\.globl _f_greet_add$/m, `${target}: --export did not make _f_greet_add global`);
}

// @rpath: a dylib can advertise an @rpath install name and the consumer carries LC_RPATH entries.
let rpathLinks = 0;
for (const target of machoTargets) {
  const directory = join(work, target, 'dylib');
  const source = join(directory, 'greet.s');
  if (!existsSync(source)) continue;
  const library = assembleDylib(source, join(directory, 'librpath.dylib'), target, {
    installName: '@rpath/libgreet.dylib',
    exports: ['_f_greet_add'],
  });
  check(dylibId(library) === '@rpath/libgreet.dylib', `${target}: @rpath install name not recorded (${dylibId(library)})`);
  const consumer = join(directory, 'rpath_consumer');
  const loaderPath = '@loader_path/../lib';
  command([process.env.GRAIL_LINKER ?? 'ld64.lld',
    '-arch', machoArchitectures[target], '-platform_version', 'macos', '11.0', '11.0',
    '-L', directory, '-lSystem',
    '-rpath', loaderPath,
    '-u', '_f_greet_add', library, join(work, target, 'hello', 'hello.o'), '-e', '_main', '-o', consumer]);
  check(dylibs(consumer).includes('@rpath/libgreet.dylib'), `${target}: consumer did not record the @rpath dependency (${dylibs(consumer).join(', ')})`);
  check(rpaths(consumer).includes(loaderPath), `${target}: consumer lost LC_RPATH (${rpaths(consumer).join(', ')})`);
  rpathLinks += 1;
}

// Apple arm64 variadics: every variadic argument goes on the stack in its own 8-byte slot (the
// named ones still use registers). c_vmix has one named and eleven variadic arguments, so the
// last lands at sp+80 right before the call.
{
  const asm = join(work, 'variadic-arm64.s');
  command([compiler, '--target', 'macos-aarch64', asm,
    join(root, 'tests/ffi/call_variadic.grl'), join(root, 'compiler/runtime.grl'), join(root, 'compiler/darwin.grl')]);
  const text = readFileSync(asm, 'utf8');
  has(text, /str x9,\[sp,#80\]\nbl _c_vmix/, 'macos-aarch64: variadic arguments are not stored in 8-byte stack slots');
  has(text, /str x9,\[sp\]\n|str x9,\[sp,#0\]\n/, 'macos-aarch64: the first variadic argument is not at sp+0');
}

// Dynamic loading on macOS: the runtime does not own the thread pointer there, so no TLS bridge
// is involved and the loader functions are ordinary libSystem imports. The Linux fixture is
// reused with its libraries declared as `lib "System"`; the image must import the loader
// functions and strlen, and export the Grail callback under its C name (Mach-O `_` prefix).
let loaderLinks = 0;
for (const target of machoTargets) {
  const directory = join(work, target, 'dlopen');
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const source = join(directory, 'dlopen.grl');
  writeFileSync(source, readFileSync(join(root, 'tests/ffi/dlopen.grl'), 'utf8').replace(/lib "(dl|c)"/g, 'lib "System"'));
  const executable = compileProgram(compiler, [source], directory, { target, name: 'dlopen' });
  const undefinedSymbols = command(['llvm-nm', '-u', executable]).stdout;
  for (const symbol of ['_dlopen', '_dlsym', '_dlclose', '_strlen']) {
    has(undefinedSymbols, new RegExp(`(^|\\s)${symbol}$`, 'm'), `${target}: dlopen image does not import ${symbol}`);
  }
  // The callback is defined under its Mach-O C name (local unless --export makes it global, as on
  // Linux); before the fix its definition lacked the underscore and the link failed.
  const definedSymbols = command(['llvm-nm', '--defined-only', executable]).stdout;
  has(definedSymbols, /\s[tT] _c_dl_probe$/m, `${target}: callback c_dl_probe is not defined as _c_dl_probe`);
  check(dylibs(executable).some(name => name === '/usr/lib/libSystem.B.dylib'), `${target}: dlopen image lost libSystem`);
  loaderLinks += 1;
}

// The driver itself, not just the tooling: `grail build --target macos-*` has to assemble and link
// a Mach-O executable on a host with no macOS SDK. This is the path a user (and the CI job on
// macos-15) takes, and it failed at the assembler until the emitter stopped writing ELF directives
// and Darwin spelled weak definitions `.weak_definition`.
let driverBuilds = 0;
for (const target of machoTargets) {
  const directory = join(work, target, 'driver');
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const source = join(directory, 'hello.grl');
  writeFileSync(source, programs[0].source);
  const executable = join(directory, 'hello');
  const env = { ...process.env };
  // No SDK: the driver has to build its own libSystem stub from the object's undefined symbols.
  delete env.GRAIL_SDK;
  const built = spawnSync(compiler, ['build', '--target', target, source, '-o', executable], {
    cwd: root, encoding: 'utf8', env, maxBuffer: 64 * 1024 * 1024,
  });
  check(built.status === 0, `${target}: grail build failed\n${built.stdout}${built.stderr}`);
  check(!/set GRAIL_SDK/.test(built.stdout), `${target}: grail build still asks for an SDK`);
  check(existsSync(executable), `${target}: grail build wrote no executable`);
  has(tool('file', [executable]), new RegExp(`Mach-O 64-bit ${files[target]} executable`), `${target}: grail build did not link a Mach-O executable`);
  has(tool('file', [executable]), /NOUNDEFS/, `${target}: grail build left undefined imports`);
  const commands = tool('llvm-objdump', ['--macho', '--private-headers', executable]);
  has(commands, /platform macos/, `${target}: grail build image has no LC_BUILD_VERSION`);
  has(commands, /cmd LC_MAIN/, `${target}: grail build image has no LC_MAIN`);
  check(dylibs(executable).includes('/usr/lib/libSystem.B.dylib'), `${target}: grail build image does not load libSystem (${dylibs(executable).join(', ')})`);
  // The stub it wrote is linkage scaffolding, not a claim about Apple's library: it exports the
  // object's own imports and nothing else.
  const stub = join(directory, '.grail-macos', 'libSystem.tbd');
  check(existsSync(stub), `${target}: grail build did not write its libSystem stub`);
  const stubText = readFileSync(stub, 'utf8');
  has(stubText, /install-name: '\/usr\/lib\/libSystem\.B\.dylib'/, `${target}: the stub has the wrong install name`);
  has(stubText, /_write/, `${target}: the stub does not export the runtime's libSystem imports`);
  driverBuilds += 1;
}

console.log(`macos: ${objects} Mach-O objects and ${executables} executables verified on ${machoTargets.join(', ')}; ${frameworkLinks} framework links, ${frameworkLinks * 2} unknown-framework rejections, ${frameworkLinks * 3} signature checks, ${dylibsBuilt} shared dylibs, ${rpathLinks} @rpath links, ${loaderLinks} dlopen images and ${driverBuilds} driver links`);
