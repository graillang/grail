// End-to-end DWARF line-table test for Linux x86-64.
//
// Builds one program with --debug, verifies the emitted .debug_line rows against the source
// lines with llvm-dwarfdump, exercises `grail debug lines`, and checks that a normal build has
// no line table. Nothing here executes a cross target.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
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

  const infoCommand = ok([compiler, 'debug', 'info', debugBinary]).stdout;
  assert.match(infoCommand, /DW_TAG_subprogram/, 'grail debug info did not print subprograms');
  assert.match(infoCommand, /DW_AT_name\s+\("total"\)/, 'grail debug info did not print the local');

  const plainBinary = build(join(work, 'plain.s'), join(work, 'plain'), false);
  const plainDump = ok(['llvm-dwarfdump', '--debug-line', plainBinary]).stdout;
  assert.equal(rows(plainDump).length, 0, 'a normal build unexpectedly contains .debug_line rows');
  const plainInfo = ok(['llvm-dwarfdump', '--debug-info', plainBinary]).stdout;
  assert.doesNotMatch(plainInfo, /DW_TAG_subprogram/, 'a normal build unexpectedly contains .debug_info');

  const rejected = run([compiler, '--target', 'aarch64', '--debug', join(work, 'reject.s'), source, runtime, osLinux]);
  assert.notEqual(rejected.status, 0, '--debug was accepted for aarch64');
  assert.match(`${rejected.stdout}${rejected.stderr}`, /only implemented for Linux x86_64/, 'missing target diagnostic');

  // Windows x86-64: CodeView line tables in the object, a PDB from lld-link /DEBUG, and the
  // function unwind entries still present (debug labels and .cv_ directives sit in the prologue).
  const { compileProgram } = await import('./windows.mjs');
  const win = compileProgram(compiler, [source], join(work, 'windows'), { debug: true });
  const pdbLines = ok(['llvm-pdbutil', 'dump', '-l', win.pdb]).stdout;
  // Only main.grl's block: the PDB also covers the runtime modules.
  const mainBlock = pdbLines.slice(pdbLines.indexOf('main.grl')).split(/\n\S/)[0];
  const pdbRows = [...mainBlock.matchAll(/(\d+) [0-9A-F]{8} !/g)].map(m => Number(m[1]));
  for (const line of [2, 5, 6]) assert.ok(pdbRows.includes(line), `PDB has no row for line ${line}: ${pdbRows}`);
  const unwind = ok(['llvm-readobj', '--unwind', win.object]).stdout;
  assert.match(unwind, /StartAddress: f_main_main/, 'debug build lost the main unwind entry');
  assert.match(unwind, /StartAddress: f_main_add/, 'debug build lost the add unwind entry');
  console.log(`debug-lines: windows-x86_64 PDB rows for lines ${[...new Set(pdbRows)].sort((a, b) => a - b).join(', ')}; unwind entries kept`);

  console.log(`debug-lines: ${mainRows.length} source rows verified (lines ${[...lines].sort((a, b) => a - b).join(', ')})`);
  console.log('debug-lines: plain build has no line table; aarch64 --debug rejected');
} finally {
  rmSync(work, { recursive: true, force: true });
}
