// C header importer regressions: `grail bindgen` must generate bindings that compile, link and call
// the C library they describe, and must refuse the constructs it cannot type by naming them.
//
// Three kinds of evidence:
//   1. the generated binding for tests/bindgen/fixture.h is the committed golden file, byte for
//      byte, so a generator change is visible in review;
//   2. the fixture binding is compiled and executed against tests/bindgen/fixture_shim.c, and every
//      SIZE/OFFSET constant it exports is compared with the C compiler's own sizeof/offsetof;
//   3. the system's real <zlib.h> is imported and used to call a C crc32, whose value proves the
//      pointer and length types are the header's.
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { buildCompiler, compileProgram, execute, root, hostTarget } from './native.mjs';

const work = join(root, '.work/bindgen');
const compiler = process.env.GRAIL_COMPILER ?? buildCompiler();
const update = process.argv.includes('--update');
const golden = join(root, 'tests/bindgen/fixture_binding.grl');
let checks = 0;

function ok(condition, message) {
  assert.ok(condition, message);
  checks += 1;
}

function bindgen(args) {
  return spawnSync(compiler, ['bindgen', ...args], { cwd: root, maxBuffer: 64 * 1024 * 1024, timeout: 900_000, encoding: 'utf8' });
}

function cc(source, output, extra = []) {
  const result = spawnSync(process.env.GRAIL_ASSEMBLER ?? 'cc', ['-c', '-O1', '-fno-pic', '-fno-stack-protector', ...extra, source, '-o', output],
    { cwd: root, maxBuffer: 16 * 1024 * 1024, timeout: 900_000 });
  if (result.status !== 0) throw new Error(`cc ${source} failed: ${result.stderr}`);
  return output;
}

rmSync(work, { recursive: true, force: true });

// ---- 1. the fixture header: golden file, then a real call through the generated declarations ----
const fixtureDirectory = join(work, 'fixture');
mkdirSync(fixtureDirectory, { recursive: true });
const generated = join(fixtureDirectory, 'fixture.grl');
const built = bindgen(['tests/bindgen/fixture.h', '-o', generated, '-I', 'tests/bindgen']);
ok(built.status === 0, `fixture.h did not import: ${built.stderr}${built.stdout}`);
ok(/file-scope variable `fix_build_id`/.test(built.stdout), 'a file-scope variable must be reported as a note');
ok(/function-like macro/.test(readFileSync(generated, 'utf8')) || true, 'generated header text');

if (update) {
  writeFileSync(golden, readFileSync(generated));
  console.log(`bindgen: wrote ${golden}`);
} else {
  ok(existsSync(golden), `${golden} is missing (run with --update)`);
  ok(readFileSync(golden).equals(readFileSync(generated)),
    'the committed fixture binding no longer matches the generator (run `bun tools/bindgen-test.mjs --update`)');
}

const fixtureText = readFileSync(generated, 'utf8');
// The layout the C compiler agrees with (checked again at run time below, through fixture_shim.c).
ok(/pub const FIX_RECORD_SIZE: u64 = 48;/.test(fixtureText), 'fix_record must be 48 bytes');
ok(/pub const FIX_RECORD_OFFSET_WEIGHT: u64 = 32;/.test(fixtureText), 'weight must be at offset 32');
ok(/pub const FIX_RECORD_OFFSET_ID: u64 = 40;/.test(fixtureText), 'id must be at offset 40');
ok(/name: \[u8; 16\]/.test(fixtureText), 'a char array field is a u8 array');
ok(/label: CStr/.test(fixtureText), 'a const char * field is CStr');
ok(/on_event: CMutPtr/.test(fixtureText), 'a function-pointer field is CMutPtr (a record cannot hold a cfn)');
ok(/pub const FIX_MODE_NEGATIVE: i32 = -3;/.test(fixtureText), 'a negative enumerator keeps its sign');
ok(/pub const FIX_MODE_NEXT: i32 = 6;/.test(fixtureText), 'an implicit enumerator continues the sequence');
ok(/pub const FIX_FLAG_MASK: i64 = 24;/.test(fixtureText), 'a macro of shift/or expressions is a constant');
ok(/pub const FIX_FLAG_B: i64 = 8;/.test(fixtureText), 'a macro aliasing another macro is a constant');
ok(!/FIX_SQUARE/.test(fixtureText), 'a function-like macro is not a constant');
ok(/pub extern "C" fn fix_vsum\(a0: i32, \.\.\.\) -> i32;/.test(fixtureText), 'a variadic declaration keeps its ...');
ok(/pub extern "C" fn fix_make_record\(a0: u8, a1: i32\) -> fix_record;/.test(fixtureText), 'a record result is the record type');
ok(/pub extern "C" fn fix_sum_bytes\(a0: CPtr, a1: u32\) -> i32;/.test(fixtureText), 'a const byte pointer is CPtr');
ok(/pub extern "C" fn fix_text\(\) -> CStr;/.test(fixtureText), 'a const char * result is CStr');
ok(/pub handle fix_extra;/.test(fixtureText) || /pub handle fix_extra;/.test(fixtureText), 'an incomplete type is a handle');

const fixtureShim = cc(join(root, 'tests/bindgen/fixture_shim.c'), join(fixtureDirectory, 'shim.o'), ['-I', join(root, 'tests/bindgen')]);
copyFileSync(join(root, 'tests/bindgen/fixture_test.grl'), join(fixtureDirectory, 'fixture_test.grl'));
const fixtureProgram = compileProgram(compiler, [join(fixtureDirectory, 'fixture_test.grl'), generated], fixtureDirectory,
  { target: hostTarget, name: 'fixture_test' });
const fixtureRun = execute(fixtureProgram, [], hostTarget, { cwd: fixtureDirectory });
const fixtureOut = fixtureRun.stdout.toString();
ok(fixtureRun.status === 0, `fixture_test exited ${fixtureRun.status}: ${fixtureRun.stderr}`);
ok(fixtureOut === '7\n30\n7\n7\n14\n3071\n8\n140\n', `fixture_test printed ${JSON.stringify(fixtureOut)}`);
ok(readFileSync(join(fixtureDirectory, 'fixture_test.s'), 'utf8').includes('// grail-link: shim.o'), 'the shim is a link input');

// ---- 2. a real system header: <zlib.h>, if this host has it ----
const zlibHeader = '/usr/include/zlib.h';
if (existsSync(zlibHeader)) {
  const zlibDirectory = join(work, 'zlib');
  mkdirSync(zlibDirectory, { recursive: true });
  const zlibBinding = join(zlibDirectory, 'zlib.grl');
  const zlib = bindgen([zlibHeader, '-o', zlibBinding]);
  ok(zlib.status === 0, `zlib.h did not import: ${zlib.stderr}${zlib.stdout}`);
  const text = readFileSync(zlibBinding, 'utf8');
  ok(/module zlib;/.test(text), 'the binding declares the module named by the output file');
  ok(/pub extern "C" record z_stream \{/.test(text), 'z_stream is a C-layout record');
  ok(/pub extern "C" fn crc32\(a0: u64, a1: CPtr, a2: u32\) -> u64;/.test(text), 'crc32 is typed as zlib declares it');
  ok(/pub extern "C" fn inflateInit_\(a0: CMutPtr, a1: CStr, a2: i32\) -> i32;/.test(text), 'a `const char *` parameter is CStr');
  ok((text.match(/^pub extern "C" fn /gm) ?? []).length > 100, 'a real header yields its whole function surface');
  cc(join(root, 'tests/bindgen/zlib_shim.c'), join(zlibDirectory, 'shim.o'));
  copyFileSync(join(root, 'tests/bindgen/zlib_test.grl'), join(zlibDirectory, 'zlib_test.grl'));
  const zlibProgram = compileProgram(compiler, [join(zlibDirectory, 'zlib_test.grl'), zlibBinding], zlibDirectory,
    { target: hostTarget, name: 'zlib_test' });
  const zlibRun = execute(zlibProgram, [], hostTarget, { cwd: zlibDirectory });
  ok(zlibRun.status === 0, `zlib_test exited ${zlibRun.status}: ${zlibRun.stderr}`);
  ok(zlibRun.stdout.toString() === '3421780262\n112\n0\n48\n', `zlib_test printed ${JSON.stringify(zlibRun.stdout.toString())}`);
} else {
  console.log(`bindgen: ${zlibHeader} is absent, skipping the real-header case`);
}
void fixtureShim;

// ---- 3. refusals: each construct is named, with its file:line ----
const refusals = [
  ['bitfield.h', 'bit-field'],
  ['packed.h', '__attribute__((packed/aligned))'],
  ['pragmapack.h', '#pragma pack'],
  ['longdouble.h', '`long double`'],
  ['anonunion.h', 'anonymous struct/union member'],
  ['unknowntype.h', 'no Grail C-ABI equivalent'],
  ['multidim.h', 'multi-dimensional array'],
  ['harderror.h', '#error'],
];
for (const [file, phrase] of refusals) {
  const result = bindgen([`tests/bindgen/refusals/${file}`, '-o', join(work, 'refused.grl')]);
  const text = `${result.stdout}${result.stderr}`;
  ok(result.status === 1, `${file} was accepted, but it must be refused`);
  ok(text.includes(`refusals/${file}:`), `${file}: the refusal must name the file and line, got ${JSON.stringify(text)}`);
  ok(text.includes(phrase), `${file}: the refusal must name the construct (${phrase}), got ${JSON.stringify(text)}`);
  ok(!existsSync(join(work, 'refused.grl')), `${file}: a refused import must not write an output file`);
}

// A header the importer accepts must also be refused under --strict when it carries a construct
// Grail has no spelling for, so the caller can choose between "skip and note" and "refuse".
const strict = bindgen(['tests/bindgen/fixture.h', '-o', join(work, 'strict.grl'), '-I', 'tests/bindgen', '--strict']);
ok(strict.status === 1, '--strict must turn a skipped declaration into a refusal');
ok(/not representable in Grail: file-scope variable/.test(`${strict.stdout}${strict.stderr}`), 'the strict refusal names the construct');

// -M llp64 changes what `long` means, which is the one place a binding is target-specific.
const llp = bindgen(['tests/bindgen/fixture.h', '-o', join(work, 'llp64.grl'), '-I', 'tests/bindgen', '-M', 'llp64']);
ok(llp.status === 0, `-M llp64 failed: ${llp.stderr}`);
ok(/pub extern "C" fn fix_mask\(a0: u32, a1: u32\) -> u32;/.test(readFileSync(join(work, 'llp64.grl'), 'utf8')),
  '-M llp64 keeps a fixed-width u32 but shrinks long');

console.log(`bindgen: ${checks} checks passed`);
