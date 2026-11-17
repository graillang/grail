// Shared by the rivals tools (bench-rivals, compile-rivals, sched-rivals): the measuring helper, the
// load average and the toolchain versions. docs/design/runtime-parity.md, "Against other languages".
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

export function run(argv, options = {}) {
  const result = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024, ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${argv.join(' ')} failed (${result.signal ?? result.status})\n${result.stdout}${result.stderr}`);
  return result;
}

// tools/rivals/measure.c, built once per work directory.
export function measurer(root, work) {
  mkdirSync(work, { recursive: true });
  const exe = join(work, 'measure');
  if (!existsSync(exe)) run(['clang', '-O2', join(root, 'tools/rivals/measure.c'), '-o', exe]);
  // One measured run: CPU seconds (user + sys, the child and its threads), wall seconds, user-space
  // instructions (all threads), and what the program printed.
  return (argv, options = {}) => {
    const out = join(work, `measure.${process.pid}.json`);
    const result = spawnSync(exe, [out, ...argv], { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024, timeout: 1_800_000, ...options });
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`${argv.join(' ')} failed (${result.signal ?? result.status})\n${result.stdout}${result.stderr}`);
    const m = JSON.parse(readFileSync(out, 'utf8'));
    return { cpu: m.user + m.sys, wall: m.wall, instructions: m.instructions, maxrss_kb: m.maxrss_kb, stdout: result.stdout, stderr: result.stderr };
  };
}

export const loadavg = () => readFileSync('/proc/loadavg', 'utf8').split(' ').slice(0, 3).join(' ');

export function versions() {
  const first = argv => { try { return run(argv).stdout.split('\n')[0].trim(); } catch { return 'not installed'; } };
  return {
    clang: first(['clang', '--version']),
    'g++': first(['g++', '--version']),
    rustc: first(['rustc', '--version']),
    cargo: first(['cargo', '--version']),
    go: first(['go', 'version']),
    zig: 'zig ' + first(['zig', 'version']),
  };
}

// Ratio of a Grail figure to the best competitor's, as printed in every rivals table.
export const ratio = (mine, theirs) => (mine === undefined || theirs === undefined || !isFinite(theirs)) ? '-' : `${(mine / theirs).toFixed(2)}x`;

// The Grail compiler a rivals tool measures, and the tree its runtime and libraries come from:
//   --compiler PATH   that compiler, with this tree's runtime and libraries
//   --branch REF      REF's compiler: REF (a branch, tag or commit; origin/REF is tried too) is
//                     extracted with `git archive` into .work/branches/<commit>, read-only, and its
//                     compiler built there - from its own seed, else bootstrapped by this tree's
//                     compiler or GRAIL_BRANCH_BOOTSTRAP (a branch's checked-in seed may be older
//                     than its sources)
//   neither           this tree's compiler (GRAIL_COMPILER when set)
// `release` asks for the release compiler (`native.mjs release`). Returns { compiler, tree, commit }
// so every table can say which Grail it measured.
export function grailCompiler(root, { compiler, branch, release = false, log = line => console.error(line) } = {}) {
  const git = args => run(['git', '-C', root, ...args]).stdout.trim();
  if (compiler) return { compiler: resolveFile(compiler), tree: root, commit: `${git(['rev-parse', '--short=12', 'HEAD'])}${dirty(git)} (--compiler ${compiler})` };
  let tree = root, commit = `${git(['rev-parse', '--short=12', 'HEAD'])}${dirty(git)}`;
  if (branch) {
    let sha;
    for (const ref of [branch, `origin/${branch}`]) {
      try { sha = git(['rev-parse', '--short=12', `${ref}^{commit}`]); break; } catch {}
    }
    if (!sha) throw new Error(`--branch ${branch}: no such ref (fetch it first)`);
    tree = join(root, '.work/branches', sha);
    if (!existsSync(join(tree, 'tools/native.mjs'))) {
      mkdirSync(tree, { recursive: true });
      const archive = spawnSync('git', ['-C', root, 'archive', sha], { maxBuffer: 1 << 30 });
      if (archive.status !== 0) throw new Error(`git archive ${sha} failed`);
      run(['tar', '-x', '-C', tree], { input: archive.stdout });
    }
    commit = `${sha} (${branch})`;
  }
  const mode = release ? 'release' : 'build';
  if (!branch && !release && process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER)) return { compiler: resolveFile(process.env.GRAIL_COMPILER), tree, commit };
  const attempt = env => spawnSync('bun', [join(tree, 'tools/native.mjs'), mode], { cwd: tree, encoding: 'utf8', maxBuffer: 1 << 26, env: { ...process.env, ...env } });
  const clean = { ...process.env };
  delete clean.GRAIL_COMPILER;
  log(`building the ${mode === 'release' ? 'release ' : ''}compiler of ${commit}`);
  let result = spawnSync('bun', [join(tree, 'tools/native.mjs'), mode], { cwd: tree, encoding: 'utf8', maxBuffer: 1 << 26, env: clean });
  if (result.status !== 0 && tree !== root) {
    // GRAIL_BRANCH_BOOTSTRAP names a compiler new enough to build REF when neither REF's seed nor
    // this tree's compiler is (a branch that changed the runtime's entry points).
    const base = process.env.GRAIL_BRANCH_BOOTSTRAP ? resolveFile(process.env.GRAIL_BRANCH_BOOTSTRAP) : grailCompiler(root, { log }).compiler;
    log(`  its seed cannot build it; bootstrapping with ${base}`);
    result = attempt({ GRAIL_COMPILER: base });
  }
  if (result.status !== 0) throw new Error(`building the compiler of ${commit} failed\n${(result.stderr ?? '').slice(-2000)}`);
  return { compiler: result.stdout.trim().split('\n').pop(), tree, commit };
}
const dirty = git => git(['status', '--porcelain', '--untracked-files=no']) ? '+changes' : '';
const resolveFile = path => { if (!existsSync(path)) throw new Error(`--compiler ${path} does not exist`); return resolve(path); };
// `--compiler PATH` and `--branch REF` from an argument vector (removed from it).
export function compilerOptions(argv) {
  const take = name => { const at = argv.indexOf(name); if (at < 0) return undefined; const v = argv[at + 1]; argv.splice(at, 2); return v; };
  return { compiler: take('--compiler'), branch: take('--branch') };
}

// Which rival toolchains this machine has. A tool drops the columns of one that is absent and says
// so, so the gate still runs on a machine without, say, Zig.
export function toolchains() {
  const ok = argv => { try { return spawnSync(argv[0], argv.slice(1), { encoding: 'utf8' }).status === 0; } catch { return false; } };
  const have = {
    c: ok(['clang', '--version']),
    rust: ok(['rustc', '--version']) && ok(['cargo', '--version']),
    go: ok(['go', 'version']),
    zig: ok(['zig', 'version']),
    tbb: ok(['g++', '--version']) && ['/usr/include/oneapi/tbb.h', '/usr/local/include/oneapi/tbb.h'].some(existsSync),
  };
  const missing = Object.entries(have).filter(([, v]) => !v).map(([k]) => k);
  if (missing.length) console.log(`note: not installed here, so not measured: ${missing.map(k => ({ c: 'clang', rust: 'rustc/cargo', go: 'go', zig: 'zig', tbb: 'g++ with oneTBB' })[k]).join(', ')}`);
  return have;
}

// `--json PATH`: the results as one file the book renders (tools/perf-charts.mjs) without running
// anything. Each table: columns (one per language and build, Grail's flagged, `primary` the one its
// ratio is read from), rows (a program or measure, its unit, its direction - lower or higher is
// better - and each column's value), and `threshold`, the ratio to the fastest rival at or under
// which the bar counts as met. The machine, load, versions, commit and commands come with it so a
// chart can be reproduced.
export function writeResults(path, { tool, title, commit, versions, load, commands, tables }) {
  const cpuinfo = existsSync('/proc/cpuinfo') ? readFileSync('/proc/cpuinfo', 'utf8') : '';
  const machine = {
    cpu: (cpuinfo.match(/^model name\s*:\s*(.*)$/m) ?? [])[1] ?? 'unknown',
    cpus: (cpuinfo.match(/^processor\s*:/gm) ?? []).length,
    kernel: (() => { try { return run(['uname', '-sr']).stdout.trim(); } catch { return 'unknown'; } })(),
  };
  const data = { schema: 1, tool, title, commit, date: new Date().toISOString(), machine, load, versions, commands, tables };
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(data, null, 1) + '\n');
  return data;
}
export const jsonOption = argv => { const at = argv.indexOf('--json'); if (at < 0) return undefined; const v = argv[at + 1]; argv.splice(at, 2); return resolve(v); };
