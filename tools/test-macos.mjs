// Static macOS backend checks: Mach-O objects and linked executables. Nothing is executed.
// Set GRAIL_COMPILER=<grail> when the checked-in bootstrap seed is older than the compiler sources.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { root, buildCompiler, compileProgram, machoTargets } from './native.mjs';

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
  '_clock_gettime', '_close', '___error', '_execve', '_exit', '_fork', '_getdirentries64', '_getpid',
  '_kill', '_mkdir', '_mmap', '_mprotect', '_munmap', '_nanosleep', '_open', '_pipe', '_poll',
  '_read', '_rmdir', '_sched_yield', '_sysconf', '_unlink', '_wait4', '_write',
]);
const programs = [
  { name: 'hello', source: 'fn main() {\n    println("Hello, macOS!");\n}\n', literal: true },
  { name: 'numbers', source: 'fn main() {\n    mut total = 0;\n    for i in 5 {\n        total += i * i;\n    }\n    println(total);\n}\n', literal: false },
];
const cputypes = { 'macos-x86_64': 'X86_64', 'macos-aarch64': 'ARM64' };
const files = { 'macos-x86_64': 'x86_64', 'macos-aarch64': 'arm64' };
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
    if (!program.literal) lacks(sections, /__const\s/, `${label}: unexpected __const section`);
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
lacks(elf, /\.build_version|rt_state@|\.pushsection __TEXT/, 'Mach-O output leaked into ELF');

// The darwin module and Mach-O targets stay unavailable where they do not apply.
// The compiler reports diagnostics on stdout; accept either stream.
function rejection(argv, pattern, message) {
  const result = spawnSync(compiler, argv, { cwd: root, encoding: 'utf8' });
  check(result.status !== 0, message);
  has(`${result.stdout ?? ''}${result.stderr ?? ''}`, pattern, `${message} (wrong diagnostic)`);
}
rejection(['--default-u64', '--typed-refs', '--target', 'x86_64', join(work, 'reject.s'), join(elfDirectory, 'hello.grl'), join(root, 'compiler/darwin.grl'), join(root, 'compiler/runtime.grl')],
  /darwin module requires a macos-x86_64 or macos-aarch64 target/, 'darwin module was accepted for an ELF target');
rejection(['--default-u64', '--typed-refs', '--target', 'macos-riscv64', join(work, 'reject2.s'), join(elfDirectory, 'hello.grl'), join(root, 'compiler/runtime.grl')],
  /unsupported target/, 'macos-riscv64 was accepted');

console.log(`macos: ${objects} Mach-O objects and ${executables} executables verified on ${machoTargets.join(', ')}`);
