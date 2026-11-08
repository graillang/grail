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
  writeFileSync(source, 'fn main() {\n    println("first");\n    println("second");\n}\n');
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
  assert.ok(lines.has(3), `missing line 3 in ${JSON.stringify(mainRows)}`);

  const inspected = ok([compiler, 'debug', 'lines', debugBinary]).stdout;
  assert.match(inspected, /main\.grl/, 'grail debug lines did not print the source file');
  assert.match(inspected, /^0x[0-9a-f]+\s+2\s/m, 'grail debug lines did not print line 2');
  assert.match(inspected, /^0x[0-9a-f]+\s+3\s/m, 'grail debug lines did not print line 3');

  const plainBinary = build(join(work, 'plain.s'), join(work, 'plain'), false);
  const plainDump = ok(['llvm-dwarfdump', '--debug-line', plainBinary]).stdout;
  assert.equal(rows(plainDump).length, 0, 'a normal build unexpectedly contains .debug_line rows');

  const rejected = run([compiler, '--target', 'aarch64', '--debug', join(work, 'reject.s'), source, runtime, osLinux]);
  assert.notEqual(rejected.status, 0, '--debug was accepted for aarch64');
  assert.match(`${rejected.stdout}${rejected.stderr}`, /only implemented for Linux x86_64/, 'missing target diagnostic');

  console.log(`debug-lines: ${mainRows.length} source rows verified (lines ${[...lines].sort((a, b) => a - b).join(', ')})`);
  console.log('debug-lines: plain build has no line table; aarch64 --debug rejected');
} finally {
  rmSync(work, { recursive: true, force: true });
}
