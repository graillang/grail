// End-to-end sampling profiler test for Linux x86-64.
//
// Builds a program with a known hot loop, runs `grail profile`, and checks that the report is
// attributed through the program's own ELF .symtab: the hot function is the first row and holds
// most of the attributed samples, the [unknown] row is always present, the rows sum to the total,
// and the run leaves no rendezvous directory behind. Nothing here executes a cross target.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { root } from './platforms.mjs';
import { buildCompiler } from './native.mjs';

function findCompiler() {
  for (const candidate of [process.env.GRAIL_COMPILER, process.env.GRAIL_LSP_COMPILER]) {
    if (candidate && existsSync(candidate)) return resolve(candidate);
  }
  const installed = spawnSync('sh', ['-c', 'command -v grail'], { encoding: 'utf8' });
  if (installed.status === 0 && installed.stdout.trim()) return installed.stdout.trim();
  const dist = join(root, 'dist');
  if (existsSync(dist)) {
    const names = readdirSync(dist).filter(name => name.startsWith('grail-') && name.endsWith('-linux-x86_64-compiler')).sort().reverse();
    if (names.length) return join(dist, names[0]);
  }
  // Same fallback as the other compiler-backed suites: build the tree's own compiler.
  try {
    return buildCompiler();
  } catch (error) {
    console.error(`profile: no Grail compiler and none could be built: ${error.message}`);
    return null;
  }
}

function run(argv, options = {}) {
  const result = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options });
  if (result.error) throw result.error;
  return result;
}

function ok(argv, options = {}) {
  const result = run(argv, options);
  assert.equal(result.status, 0, `${argv.join(' ')} failed\n${result.stdout}${result.stderr}`);
  return result;
}

// "      390  99.2%  hot                         main" / "      396 100.0%  total"
function rows(report) {
  const parsed = [];
  for (const line of report.split('\n')) {
    const match = /^\s+(\d+)\s+([\d.]+)%\s+(.+?)\s*$/.exec(line);
    if (!match) continue;
    const [name, module] = match[3].split(/\s{2,}/);
    parsed.push({ samples: Number(match[1]), share: Number(match[2]), function: name.trim(), module: module ?? null });
  }
  return parsed;
}

const compiler = findCompiler();
if (!compiler) {
  console.error('profile: no Grail compiler found; set GRAIL_COMPILER');
  process.exit(2);
}
const work = mkdtempSync(join(tmpdir(), 'grail-prof-'));
try {
  const source = join(work, 'main.grl');
  // `hot` is a CPU-bound loop; `cool` is a much smaller function, and `main` only drives them.
  writeFileSync(source, [
    'use host;',
    // The profiled program reports a variable the runner sets: `grail profile` passes the child the
    // inherited environment plus the arming request, so the target still sees its own configuration.
    'fn hot(n: u64) -> u64 {',
    '    mut acc: u64 = 0;',
    '    mut i: u64 = 0;',
    '    while i < n {',
    '        acc = acc + i * 3 + acc % 7;',
    '        i += 1;',
    '    }',
    '    return acc;',
    '}',
    'fn cool(n: u64) -> u64 {',
    '    mut t: u64 = n;',
    '    mut k: u64 = 0;',
    '    while k < 40 {',
    '        t = t + k * 3 + 1;',
    '        k += 1;',
    '    }',
    '    return t;',
    '}',
    'fn main() {',
    '    println(host::env(view("GRAIL_PROFILE_ENV_PROBE")));',
    '    deadline := host::now_ms() + 600;',
    '    mut total: u64 = 0;',
    '    mut k: u64 = 0;',
    '    while host::now_ms() < deadline {',
    '        total = total + hot(20000);',
    '        total = total + cool(k);',
    '        k += 1;',
    '    }',
    '    println(total);',
    '}',
    '',
  ].join('\n'));
  const binary = join(work, 'hotloop');
  const env = { ...process.env, GRAIL_HOME: root };
  ok([compiler, 'build', source, '-o', binary], { cwd: work, env });

  // The sampler reports link-time addresses; that is only true for a non-PIE build.
  const image = readFileSync(binary);
  assert.equal(image.readUInt16LE(16), 2, 'a default Grail build must be ET_EXEC (non-PIE)');
  const rate = '500';
  const report = join(work, 'report.txt');
  // Scratch directories the profiler owns, before and after the run: none may be left behind.
  const scratch = () => readdirSync(tmpdir()).filter(name => name.startsWith('grail-profile-')).sort();
  const before = scratch();
  const profiled = ok([compiler, 'profile', '--rate', rate, '--out', report, '--', binary],
    { cwd: work, env: { ...env, GRAIL_PROFILE_ENV_PROBE: 'visible' } });
  // No rendezvous file: the request travelled in the child's environment.
  assert.equal(profiled.stdout.split('\n')[0], 'visible', 'grail profile did not pass the parent environment to the target');
  assert.deepEqual(scratch(), before, 'grail profile left a grail-profile- scratch directory behind');
  // The program's own output is forwarded first; the report follows it.
  const text = profiled.stdout.slice(profiled.stdout.indexOf('grail profile:'));
  assert.ok(text.startsWith('grail profile:'), `no report in\n${profiled.stdout}`);

  assert.match(text, new RegExp(`^grail profile: ${binary.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'm'), 'missing report header');
  assert.match(text, /non-PIE \(ET_EXEC\)/, 'the report must state how PIE is handled');
  assert.match(text, new RegExp(`${rate} Hz ITIMER_PROF`), 'the report must name the requested rate');
  assert.match(text, /samples in [\d.]+ s of CPU time \(effective \d+ Hz\)/, 'the report must state the measured CPU time and rate');
  // The effective rate is samples per CPU second. It tracks the request on this host's timer but may
  // be capped by a coarser kernel tick, so only the floor and the ceiling are asserted.
  const effective = Number(/effective (\d+) Hz/.exec(text)[1]);
  assert.ok(effective >= 50, `the effective rate ${effective} Hz is far below the 500 Hz request:\n${text}`);
  assert.ok(effective <= 750, `the effective rate ${effective} Hz exceeds the request:\n${text}`);
  assert.equal(readFileSync(report, 'utf8'), text, '--out must hold the report that went to stdout');

  const table = rows(text);
  const total = table.find(row => row.function === 'total');
  const unknown = table.find(row => row.function === '[unknown]');
  const functions = table.filter(row => row.function !== 'total' && row.function !== '[unknown]');
  assert.ok(total, `no total row in\n${text}`);
  assert.ok(unknown, `no [unknown] row in\n${text}`);
  assert.ok(unknown.module === '-', '[unknown] must not be attributed to a module');
  assert.equal(total.samples, table.filter(row => row.function !== 'total').reduce((sum, row) => sum + row.samples, 0),
    'the rows must add up to the total');
  assert.equal(total.share, 100, 'the total must be 100%');
  assert.ok(total.samples >= 30, `too few samples to judge the profile: ${total.samples}`);

  const hot = functions[0];
  assert.ok(hot, `no attributed function in\n${text}`);
  assert.equal(hot.function, 'hot', `the first row is not the hot function:\n${text}`);
  assert.equal(hot.module, 'main', 'the module column must come from f_<module>_<function>');
  const attributed = total.samples - unknown.samples;
  assert.ok(hot.samples * 2 > attributed, `the hot function holds only ${hot.samples}/${attributed} attributed samples:\n${text}`);
  assert.ok(hot.share > 50, `the hot function share is only ${hot.share}%:\n${text}`);
  assert.match(text, /^\s+\d+\s+[\d.]+%\s+hot\s+main$/m, 'the hot row must be symbolised by module');

  // --callers: each sample carries its return addresses, and the report says who called the hot
  // function and how much time each function holds with its callees.
  const withCallers = ok([compiler, 'profile', '--callers', '--rate', rate, '--', binary], { cwd: work, env }).stdout;
  assert.match(withCallers, /inclusive: samples with the function anywhere on the stack/, `no inclusive table:\n${withCallers}`);
  const inclusive = withCallers.slice(withCallers.indexOf('inclusive:'));
  assert.match(inclusive, /^\s+\d+\s+[\d.]+%\s+main\s+main$/m, `main must hold the hot loop inclusively:\n${withCallers}`);
  const callersOfHot = withCallers.slice(withCallers.indexOf('    hot ('));
  assert.ok(withCallers.includes('    hot ('), `no caller list for the hot function:\n${withCallers}`);
  assert.match(callersOfHot.split('\n').slice(0, 4).join('\n'), /main\s+main/, `the hot function's caller must be main:\n${withCallers}`);
  // Without the flag the report is the leaf table alone.
  assert.ok(!text.includes('inclusive:'), 'a profile without --callers must not carry the caller view');

  // Samples outside every known symbol must be shown, never dropped: without a symbol table the
  // whole profile falls into [unknown] and the total stays the same.
  const strip = spawnSync('sh', ['-c', 'command -v llvm-strip || command -v strip'], { encoding: 'utf8' });
  if (strip.status === 0 && strip.stdout.trim()) {
    const stripped = join(work, 'hotloop-stripped');
    ok(['cp', binary, stripped]);
    ok([strip.stdout.trim(), '-s', stripped]);
    const bare = ok([compiler, 'profile', '--rate', rate, '--', stripped], { cwd: work, env }).stdout;
    const bareRows = rows(bare);
    const bareTotal = bareRows.find(row => row.function === 'total');
    const bareUnknown = bareRows.find(row => row.function === '[unknown]');
    assert.ok(bareTotal && bareUnknown, `no [unknown] row for a stripped binary:\n${bare}`);
    assert.equal(bareUnknown.samples, bareTotal.samples, 'every sample of a stripped binary must be [unknown]');
    assert.equal(bareRows.filter(row => row.function !== 'total' && row.function !== '[unknown]').length, 0,
      'a stripped binary must not invent function names');
  } else {
    console.log('profile: no llvm-strip/strip available; skipping the [unknown] coverage check');
  }

  // The old rendezvous directory must stay gone: the arming request no longer goes through a file
  // in the working directory.
  assert.equal(existsSync(join(work, '.grail-profile')), false, 'grail profile wrote a rendezvous directory');
  console.log(`profile: hot function dominates the sampled profile (${before.length} scratch dirs in TMPDIR before, ${scratch().length} after)`);
} finally {
  rmSync(work, { recursive: true, force: true });
}
