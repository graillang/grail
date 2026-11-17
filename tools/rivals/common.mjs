// Shared by the rivals tools (bench-rivals, compile-rivals, sched-rivals): the measuring helper, the
// load average and the toolchain versions. docs/design/runtime-parity.md, "Against other languages".
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

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
