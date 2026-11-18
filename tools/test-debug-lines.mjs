// End-to-end DWARF line-table test for Linux x86-64.
//
// Builds one program with --debug, verifies the emitted .debug_line rows against the source
// lines with llvm-dwarfdump, exercises `grail debug lines`, and checks that a normal build has
// no line table. Nothing here executes a cross target.
import { spawnSync } from 'node:child_process';
import { readFileSync, existsSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { root } from './platforms.mjs';

function findCompiler() {
  for (const candidate of [process.env.GRAIL_COMPILER, process.env.GRAIL_LSP_COMPILER]) {
    if (candidate && existsSync(candidate)) return resolve(candidate);
  }
  const installed = spawnSync('sh', ['-c', 'command -v grail'], { encoding: 'utf8' });
  if (installed.status === 0 && installed.stdout.trim()) return installed.stdout.trim();
  const directory = join(root, 'dist');
  if (existsSync(directory)) {
    const names = readdirSync(directory).filter(name => name.startsWith('grail-') && name.endsWith('-linux-x86_64-compiler')).sort().reverse();
    if (names.length) return join(directory, names[0]);
  }
  return null;
}

function run(argv, options = {}) {
  const result = spawnSync(argv[0], argv.slice(1), { cwd: root, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options });
  if (result.error) throw result.error;
  return result;
}

function ok(argv, options = {}) {
  const result = run(argv, options);
  assert.equal(result.status, 0, `${argv.join(' ')} failed\n${result.stdout}${result.stderr}`);
  return result;
}

function rows(dump) {
  const lines = [];
  for (const line of dump.split('\n')) {
    const match = /^(0x[0-9a-f]+)\s+(\d+)\s+(\d+)\s+(\d+)\s/.exec(line);
    if (match) lines.push({ address: match[1], line: Number(match[2]), column: Number(match[3]), file: Number(match[4]) });
  }
  return lines;
}

const compiler = findCompiler();
if (!compiler) {
  console.error('debug-lines: no Grail compiler found; set GRAIL_COMPILER');
  process.exit(2);
}
const work = mkdtempSync(join(tmpdir(), 'grail-debug-lines-'));
try {
  const source = join(work, 'main.grl');
  writeFileSync(
    source,
    'fn add(left: i64, right: i64) -> i64 {\n    return left + right;\n}\nfn main() {\n    mut total = add(2, 3);\n    println(total);\n}\n',
  );
  const runtime = join(root, 'compiler/runtime.grl');
  const osLinux = join(root, 'compiler/os-linux.grl');

  const build = (assembly, executable, debug) => {
    const args = [compiler, '--target', 'x86_64'];
    if (debug) args.push('--debug');
    args.push(assembly, source, runtime, osLinux);
    ok(args);
    const object = `${executable}.o`;
    ok(['clang', '--target=x86_64-linux-gnu', '-c', assembly, '-o', object]);
    ok(['ld.lld', '-m', 'elf_x86_64', object, '-o', executable]);
    return executable;
  };

  const debugBinary = build(join(work, 'debug.s'), join(work, 'debug'), true);
  const dump = ok(['llvm-dwarfdump', '--debug-line', debugBinary]).stdout;
  assert.match(dump, /main\.grl/, 'line table does not name the source file');
  const mainRows = rows(dump).filter(row => row.file === 1);
  const lines = new Set(mainRows.map(row => row.line));
  assert.ok(lines.has(2), `missing line 2 in ${JSON.stringify(mainRows)}`);
  assert.ok(lines.has(5), `missing line 5 in ${JSON.stringify(mainRows)}`);
  assert.ok(lines.has(6), `missing line 6 in ${JSON.stringify(mainRows)}`);

  const inspected = ok([compiler, 'debug', 'lines', debugBinary]).stdout;
  assert.match(inspected, /main\.grl/, 'grail debug lines did not print the source file');
  assert.match(inspected, /^0x[0-9a-f]+\s+2\s/m, 'grail debug lines did not print line 2');

  // .debug_info: compile unit, subprograms with pc ranges, parameters and a local.
  const info = ok(['llvm-dwarfdump', '--debug-info', debugBinary]).stdout;
  assert.match(info, /DW_TAG_compile_unit/, 'missing compile unit');
  assert.match(info, /DW_AT_name\s+\(".*main\.grl"\)/, 'compile unit does not name the source');
  assert.match(info, /DW_TAG_subprogram/, 'missing subprogram DIE');
  assert.match(info, /DW_AT_name\s+\("add"\)/, 'missing subprogram add');
  assert.match(info, /DW_AT_name\s+\("main"\)/, 'missing subprogram main');
  assert.match(info, /DW_AT_low_pc\s+\(0x[0-9a-f]+\)/, 'subprogram has no low_pc');
  assert.match(info, /DW_AT_high_pc\s+\(0x[0-9a-f]+\)/, 'subprogram has no high_pc');
  assert.match(info, /DW_TAG_formal_parameter[\s\S]*DW_AT_name\s+\("left"\)/, 'missing parameter left');
  assert.match(info, /DW_TAG_formal_parameter[\s\S]*DW_AT_name\s+\("right"\)/, 'missing parameter right');
  assert.match(info, /DW_TAG_variable[\s\S]*DW_AT_name\s+\("total"\)/, 'missing local total');
  assert.match(info, /DW_AT_location\s+\(DW_OP_fbreg -?\d+\)/, 'missing stack location');
  assert.match(info, /DW_AT_frame_base\s+\(DW_OP_reg6 RBP\)/, 'missing frame base');

  // Every parameter and local carries a DW_AT_type naming its base type, and the unit verifies.
  for (const [name, type] of [['left', 'i64'], ['right', 'i64'], ['total', 'i64']]) {
    assert.match(info, new RegExp(`DW_AT_name\\s+\\("${name}"\\)\\s+[\\s\\S]*?DW_AT_type\\s+\\(0x[0-9a-f]+ "${type}"\\)`),
      `${name} has no DW_AT_type "${type}"`);
  }
  assert.match(info, /DW_TAG_base_type[\s\S]*?DW_AT_encoding\s+\(DW_ATE_signed\)[\s\S]*?DW_AT_byte_size\s+\(0x08\)/, 'i64 base type');
  const verified = ok(['llvm-dwarfdump', '--verify', debugBinary]).stdout;
  assert.match(verified, /No errors\./, `DWARF does not verify:\n${verified}`);

  const infoCommand = ok([compiler, 'debug', 'info', debugBinary]).stdout;
  assert.match(infoCommand, /DW_TAG_subprogram/, 'grail debug info did not print subprograms');
  assert.match(infoCommand, /DW_AT_name\s+\("total"\)/, 'grail debug info did not print the local');

  // Record, string, vector and C-record members: a debugger walks a Grail value's fields through
  // the pointers the program holds (tests/debug_members.grl).
  {
    const membersSource = join(root, 'tests/debug_members.grl');
    const asm = join(work, 'members.s');
    const exe = join(work, 'members');
    ok([compiler, '--target', 'x86_64', '--debug', asm, membersSource, runtime, osLinux]);
    ok(['clang', '--target=x86_64-linux-gnu', '-c', asm, '-o', `${exe}.o`]);
    ok(['ld.lld', '-m', 'elf_x86_64', `${exe}.o`, '-o', exe]);
    const membersInfo = ok(['llvm-dwarfdump', '--debug-info', exe]).stdout;
    for (const [structure, fields] of [['Outer', ['count', 'ratio', 'inner', 'pos', 'label']], ['Inner', ['id', 'tag']], ['Pos', ['row', 'col']], ['Pt', ['x', 'y', 'w']], ['u8[]', ['data', 'len', 'cap']]]) {
      assert.match(membersInfo, new RegExp(`DW_TAG_structure_type\\s+DW_AT_name\\s+\\("${structure.replace(/[[\]]/g, '\\$&')}"\\)`), `no structure type ${structure}`);
      for (const field of fields) {
        assert.match(membersInfo, new RegExp(`DW_TAG_member\\s+DW_AT_name\\s+\\("${field}"\\)`), `${structure} has no member ${field}`);
      }
    }
    assert.match(membersInfo, /DW_AT_name\s+\("y"\)[\s\S]*?DW_AT_data_member_location\s+\((?:0x0)?4\)/, 'Pt.y is not at offset 4');
    const membersVerified = ok(['llvm-dwarfdump', '--verify', exe]).stdout;
    assert.match(membersVerified, /No errors\./, `member DWARF does not verify:\n${membersVerified}`);
    if (run(['gdb', '--version']).status === 0) {
      const line = readFileSync(membersSource, 'utf8').split('\n').findIndex(row => row.includes('total := ')) + 1;
      const shown = run(['gdb', '-q', '-batch', '-ex', 'set debuginfod enabled off', '-ex', `break debug_members.grl:${line}`, '-ex', 'run',
        // A reference to a record is the record's own address (unboxed-values.md, stage 1a), and a
        // plain record is stored inline in the record and the vector holding it (stage 1b).
        '-ex', 'print *o', '-ex', 'print *o->inner', '-ex', 'print o->pos', '-ex', 'print o->label->data', '-ex', 'print *p', '-ex', 'print (*v)->data[0]@3', '-ex', 'print (*s)->data',
        '-ex', 'print *q', '-ex', 'print (*ps)->data[1]', exe]).stdout;
      for (const expected of ['count = 7, ratio = 2.5', 'id = 42', 'row = 3, col = -4', '"outer-label"', 'x = -3, y = 9, w = 1.5', '{10, 20, 30}', '"hello debugger"', 'row = 11, col = -12', 'row = 31, col = -32']) {
        assert.ok(shown.includes(expected), `gdb did not show ${expected}:\n${shown}`);
      }
      console.log('debug-lines: gdb prints record, nested and inline record, string, vector, flat vector element and C-record members');
    } else {
      console.log('debug-lines: gdb not installed; member DWARF checked with llvm-dwarfdump only');
    }
  }

  const plainBinary = build(join(work, 'plain.s'), join(work, 'plain'), false);
  const plainDump = ok(['llvm-dwarfdump', '--debug-line', plainBinary]).stdout;
  assert.equal(rows(plainDump).length, 0, 'a normal build unexpectedly contains .debug_line rows');
  const plainInfo = ok(['llvm-dwarfdump', '--debug-info', plainBinary]).stdout;
  assert.doesNotMatch(plainInfo, /DW_TAG_subprogram/, 'a normal build unexpectedly contains .debug_info');

  const rejected = run([compiler, '--target', 'windows-aarch64', '--debug', join(work, 'reject.s'), source, runtime, osLinux]);
  assert.notEqual(rejected.status, 0, '--debug was accepted for windows-aarch64');
  assert.match(`${rejected.stdout}${rejected.stderr}`, /only implemented for Linux and Windows x86_64/, 'missing target diagnostic');

  // AArch64 and RISC-V 64 Linux: the same DWARF (frame base x29 / s0); the line table maps the
  // source rows, every variable is typed, and the unit verifies.
  for (const [target, triple, extra] of [['aarch64', 'aarch64-linux-gnu', []], ['riscv64', 'riscv64-linux-gnu', ['-march=rv64imafd', '-mabi=lp64d']]]) {
    const asm = join(work, `${target}.s`);
    const obj = join(work, `${target}.o`);
    const exe = join(work, `${target}-debug`);
    ok([compiler, '--debug', '--target', target, asm, source, runtime, osLinux]);
    ok(['clang', `--target=${triple}`, ...extra, '-c', asm, '-o', obj]);
    ok(['ld.lld', obj, '-o', exe]);
    const lines = ok(['llvm-dwarfdump', '--debug-line', exe]).stdout;
    for (const line of [2, 5, 6]) {
      assert.match(lines, new RegExp(`^0x[0-9a-f]+\\s+${line}\\s`, 'm'), `${target}: no line-table row for line ${line}`);
    }
    const crossInfo = ok(['llvm-dwarfdump', '--debug-info', exe]).stdout;
    assert.match(crossInfo, /DW_AT_name\s+\("total"\)[\s\S]*?DW_AT_type\s+\(0x[0-9a-f]+ "i64"\)/, `${target}: total is not typed`);
    assert.match(ok(['llvm-dwarfdump', '--verify', exe]).stdout, /No errors\./, `${target}: DWARF does not verify`);
  }
  console.log('debug-lines: aarch64 and riscv64 DWARF line rows, typed variables, verified');

  // Windows x86-64: CodeView line tables in the object, a PDB from lld-link /DEBUG, and the
  // function unwind entries still present (debug labels and .cv_ directives sit in the prologue).
  const { compileProgram } = await import('./windows.mjs');
  const win = compileProgram(compiler, [source], join(work, 'windows'), { debug: true });
  const pdbLines = ok(['llvm-pdbutil', 'dump', '-l', win.pdb]).stdout;
  // Only main.grl's block: the PDB also covers the runtime modules.
  const mainBlock = pdbLines.slice(pdbLines.indexOf('main.grl')).split(/\n\S/)[0];
  const pdbRows = [...mainBlock.matchAll(/(\d+) [0-9A-F]{8} !/g)].map(m => Number(m[1]));
  for (const line of [2, 5, 6]) assert.ok(pdbRows.includes(line), `PDB has no row for line ${line}: ${pdbRows}`);
  // CodeView symbols: each function an S_GPROC32 with an S_FRAMEPROC and its typed locals as
  // S_REGREL32 records at negative rbp offsets (llvm-pdbutil prints the int32 offset unsigned).
  const typed = join(work, 'typed.grl');
  writeFileSync(typed, 'fn add(left: i64, right: i64) -> i64 {\n    return left + right;\n}\nfn main() {\n    mut total = add(2, 3);\n    mut ratio: f64 = 1.5;\n    mut done = true;\n    mut small: u8 = 7;\n    println(total);\n}\n');
  const typedWin = compileProgram(compiler, [typed], join(work, 'windows-typed'), { debug: true });
  const symbols = ok(['llvm-pdbutil', 'dump', '--symbols', typedWin.pdb]).stdout;
  const procedure = name => {
    const at = symbols.search(new RegExp(`S_GPROC32 \\[size = \\d+\\] \`${name}\``));
    assert.ok(at >= 0, `PDB has no S_GPROC32 for ${name}`);
    return symbols.slice(at, symbols.indexOf('S_END', at));
  };
  const expected = [['main::add', [['left', '0x0013 (__int64)'], ['right', '0x0013 (__int64)']]],
    ['main::main', [['total', '0x0013 (__int64)'], ['ratio', '0x0041 (double)'], ['done', '0x0030 (bool)'], ['small', '0x0020 (unsigned char)']]]];
  for (const [name, locals] of expected) {
    const scope = procedure(name);
    assert.match(scope, /S_FRAMEPROC/, `${name}: no S_FRAMEPROC`);
    for (const [local, type] of locals) {
      const record = new RegExp(`S_REGREL32 \\[size = \\d+\\] \`${local}\`\\s+type = ${type.replace(/[()]/g, '\\$&')}, register = RBP, offset = (\\d+)`).exec(scope);
      assert.ok(record, `${name}: ${local} is not an RBP-relative ${type}`);
      const offset = Number(record[1]) - 2 ** 32;
      assert.ok(offset < 0 && offset % 8 === 0, `${name}: ${local} offset ${offset} is not a negative slot`);
    }
  }
  // CodeView member layout: the same record, string, vector and C-record types as the DWARF test,
  // as LF_STRUCTURE / LF_FIELDLIST / LF_MEMBER / LF_POINTER records the PDB resolves.
  {
    const membersWin = compileProgram(compiler, [join(root, 'tests/debug_members.grl')], join(work, 'windows-members'), { debug: true });
    const types = ok(['llvm-pdbutil', 'dump', '--types', membersWin.pdb]).stdout;
    // `inner` is inline (unboxed-values.md): a record field is the record's words in place, so
    // Outer is 56 bytes with `pos` at 32 - what the compiled code reads (`o.inner.id` at 16 with no
    // pointer to follow, `o.pos.row` at 32, `o.label` at 48).
    for (const [structure, size, fields] of [['Outer', 56, [['count', 0], ['ratio', 8], ['inner', 16], ['pos', 32], ['label', 48]]], ['Inner', 16, [['id', 0], ['tag', 8]]], ['Pos', 16, [['row', 0], ['col', 8]]], ['Pt', 12, [['x', 0], ['y', 4], ['w', 8]]], ['u8[]', 24, [['data', 0], ['len', 8], ['cap', 16]]]]) {
      const full = new RegExp(`LF_STRUCTURE \\[size = \\d+\\] \`${structure.replace(/[[\]]/g, '\\$&')}\`\\s+vtable: <no type>, base list: <no type>, field list: (0x[0-9A-F]+)\\s+options: , sizeof ${size}`);
      const found = types.match(full);
      assert.ok(found, `CodeView has no full definition of ${structure} (sizeof ${size})`);
      const list = types.slice(types.indexOf(`${found[1]} | LF_FIELDLIST`));
      for (const [field, offset] of fields) {
        assert.match(list.split(/\n  0x/)[0], new RegExp(`LF_MEMBER \\[name = \`${field}\`, Type = 0x[0-9A-F]+[^\\]]*, offset = ${offset},`), `${structure}.${field} not at offset ${offset}`);
      }
    }
    const membersSymbols = ok(['llvm-pdbutil', 'dump', '--symbols', membersWin.pdb]).stdout;
    // `o: &Outer` is the record's own address (unboxed-values.md, stage 1a): one pointer.
    assert.match(membersSymbols, /S_REGREL32 \[size = \d+\] `o`\s+type = 0x[0-9A-F]+ \(Outer\*\)/, 'the local o is not typed Outer*');
    console.log('debug-lines: windows-x86_64 PDB describes record, string, vector and C-record members');
  }
  const unwind = ok(['llvm-readobj', '--unwind', win.object]).stdout;
  assert.match(unwind, /StartAddress: f_main_main/, 'debug build lost the main unwind entry');
  assert.match(unwind, /StartAddress: f_main_add/, 'debug build lost the add unwind entry');
  console.log(`debug-lines: windows-x86_64 PDB rows for lines ${[...new Set(pdbRows)].sort((a, b) => a - b).join(', ')}; typed rbp-relative locals; unwind entries kept`);

  console.log(`debug-lines: ${mainRows.length} source rows verified (lines ${[...lines].sort((a, b) => a - b).join(', ')})`);
  console.log('debug-lines: plain build has no line table; windows-aarch64 --debug rejected');
} finally {
  rmSync(work, { recursive: true, force: true });
}
