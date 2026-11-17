#!/usr/bin/env bun
// The front end's robustness fuzzer: mutate real Grail sources, feed each mutation to one compiler
// run, and look only for crashes.
//
//   bun tools/fuzz-frontend.mjs [--cases N] [--seed S] [--jobs J] [--timeout MS] [--max-bytes B]
//                               [--shrink] [--quiet] [--keep] [--compiler PATH]
//
// A compiler that panics on source text a person could type is a hole in a workhorse language: the
// user sees "assertion failed" and a compiler source line instead of a diagnostic that names the
// mistake (docs/diagnostics.md, "Source the scanner cannot read"; docs/design/frontend-robustness.md).
// So every case is classified, not just counted:
//
//   fine  the compiler exits 0, or exits 1 with a diagnostic: `error: ...` / `error[Exxxx]: ...`
//         followed by a `-->` location. That is the language refusing a program, which is the job.
//   bug   the compiler died: killed by a signal, a runtime check inside the compiler
//         ("index N out of bounds", "assertion failed", "unwrap of None or Err", "arithmetic
//         overflow"...), an internal error, or a run that outlived --timeout.
//   other anything else: a diagnostic without a location, a driver failure, ...
//
// Each case is one mutation set over one real source, so a bug has an input to shrink and keep. The
// corpus is every `tests/**/*.grl`, every `book/examples/*.grl` and the compiler's own modules
// (`compiler/*.grl`); the mutation set is byte deletion, byte duplication, byte swap, truncation,
// a one-byte insertion from a set of plausible tokens, and line deletion/duplication.
//
// Deterministic from --seed: the corpus is in sorted order and every case is generated before any
// case runs, so --jobs changes the wall clock and nothing else. Working files live under
// `.work/fuzz/`.
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCompiler } from './native.mjs';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const workRoot = join(root, '.work/fuzz');

// ---------------------------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------------------------
function parse(argv) {
  const options = { cases: 200, seed: 1, jobs: 4, timeout: 20000, maxBytes: 262144, shrink: false, shrinkBudget: 400, quiet: false, keep: false, help: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const value = () => {
      const next = argv[i + 1];
      if (next === undefined) throw new Error(`${arg} needs a value`);
      i += 1;
      return next;
    };
    if (arg === '--cases') options.cases = Number(value());
    else if (arg === '--seed') options.seed = Number(value());
    else if (arg === '--jobs') options.jobs = Number(value());
    else if (arg === '--timeout') options.timeout = Number(value());
    else if (arg === '--max-bytes') options.maxBytes = Number(value());
    else if (arg === '--compiler') options.compiler = value();
    else if (arg === '--shrink') options.shrink = true;
    else if (arg === '--shrink-budget') options.shrinkBudget = Number(value());
    else if (arg === '--quiet') options.quiet = true;
    else if (arg === '--keep') options.keep = true;
    else if (arg === '--help' || arg === '-h') options.help = true;
    else throw new Error(`unknown argument ${arg}`);
  }
  for (const name of ['cases', 'seed', 'jobs', 'timeout', 'maxBytes', 'shrinkBudget']) {
    if (!Number.isInteger(options[name]) || options[name] < 0) throw new Error(`--${name} must be a non-negative integer`);
  }
  if (options.cases < 1) throw new Error('--cases must be at least 1');
  if (options.jobs < 1) throw new Error('--jobs must be at least 1');
  if (options.timeout < 1) throw new Error('--timeout must be at least 1');
  return options;
}

// The compiler under test is the tree's own: the one `bun tools/native.mjs build` produces from
// compiler/*.grl, which is cached by content hash (or GRAIL_COMPILER, which that build honours).
// Testing the checked-in seed instead would answer for a compiler this tree no longer contains.
function compilerPath(options) {
  if (options.compiler) return resolve(options.compiler);
  return buildCompiler();
}

// ---------------------------------------------------------------------------------------------
// Deterministic randomness: one 32-bit state, advanced only by our own decisions.
// ---------------------------------------------------------------------------------------------
function randomFrom(seed) {
  let state = seed >>> 0;
  const next = limit => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    const value = ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    return Math.floor(value * limit);
  };
  return { next };
}

// ---------------------------------------------------------------------------------------------
// Corpus
// ---------------------------------------------------------------------------------------------
function walk(directory, out) {
  for (const entry of readdirSync(directory, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) walk(path, out);
    else if (entry.name.endsWith('.grl')) out.push(path);
  }
  return out;
}

// Every real source the front end is expected to read: the regression corpus, the book's examples,
// and the compiler's own modules (a program no one has ever made the compiler read is no test).
export function corpusFiles() {
  const files = [];
  if (existsSync(join(root, 'tests'))) walk(join(root, 'tests'), files);
  if (existsSync(join(root, 'book/examples'))) walk(join(root, 'book/examples'), files);
  if (existsSync(join(root, 'compiler'))) {
    for (const name of readdirSync(join(root, 'compiler')).sort()) {
      if (name.endsWith('.grl')) files.push(join(root, 'compiler', name));
    }
  }
  return files;
}

// A source this run will mutate. `--max-bytes` keeps the run's cost bounded: every case is one
// compiler run, and one run over the compiler's 1.5 MB module is a whole compile of the compiler
// (minutes), so the default covers every ordinary source and `--max-bytes 0` covers the giant too.
export function corpus(options) {
  const sources = [];
  for (const path of corpusFiles()) {
    const bytes = readFileSync(path);
    if (options.maxBytes !== 0 && bytes.length > options.maxBytes) continue;
    sources.push({ path, bytes });
  }
  if (sources.length === 0) throw new Error(`no corpus source is within --max-bytes ${options.maxBytes}`);
  return sources;
}

// ---------------------------------------------------------------------------------------------
// Mutations. Each takes bytes and the generator, and returns new bytes or null when the input has
// nothing to cut (an empty file cannot lose a line). One mutation is one plausible keystroke.
// ---------------------------------------------------------------------------------------------
// A byte a person can type, or one that arrives from a file that is not UTF-8.
export const INSERT_BYTES = [
  0x27, /* ' */ 0x22, /* " */ 0x28, /* ( */ 0x29, /* ) */ 0x7b, /* { */ 0x7d, /* } */
  0x3b, /* ; */ 0x3a, /* : */ 0x3d, /* = */ 0x40, /* @ */ 0x23, /* # */
  0x30, 0x37, 0x39, /* digits */ 0xc3, 0xa9, /* a UTF-8 lead and continuation byte */
  0x00, /* NUL */ 0x0a, /* newline */ 0x5c, /* backslash */ 0x60, /* backtick */
];

function splice(bytes, from, to) {
  return Uint8Array.from([...bytes.subarray(0, from), ...bytes.subarray(to)]);
}

function lineRanges(bytes) {
  const ranges = [];
  let start = 0;
  for (let i = 0; i < bytes.length; i += 1) {
    if (bytes[i] === 0x0a) {
      ranges.push([start, i + 1]);
      start = i + 1;
    }
  }
  if (start < bytes.length) ranges.push([start, bytes.length]);
  return ranges;
}

export const MUTATIONS = [
  { name: 'delete-byte', apply(bytes, random) {
    if (bytes.length === 0) return null;
    const at = random.next(bytes.length);
    return splice(bytes, at, at + 1);
  } },
  { name: 'duplicate-byte', apply(bytes, random) {
    if (bytes.length === 0) return null;
    const at = random.next(bytes.length);
    return Uint8Array.from([...bytes.subarray(0, at + 1), bytes[at], ...bytes.subarray(at + 1)]);
  } },
  { name: 'swap-byte', apply(bytes, random) {
    if (bytes.length < 2) return null;
    const at = random.next(bytes.length - 1);
    const copy = Uint8Array.from(bytes);
    const held = copy[at];
    copy[at] = copy[at + 1];
    copy[at + 1] = held;
    return copy;
  } },
  { name: 'truncate', apply(bytes, random) {
    if (bytes.length === 0) return null;
    return bytes.slice(0, random.next(bytes.length));
  } },
  { name: 'insert-byte', apply(bytes, random) {
    const at = random.next(bytes.length + 1);
    const byte = INSERT_BYTES[random.next(INSERT_BYTES.length)];
    return Uint8Array.from([...bytes.subarray(0, at), byte, ...bytes.subarray(at)]);
  } },
  { name: 'delete-line', apply(bytes, random) {
    const ranges = lineRanges(bytes);
    if (ranges.length === 0) return null;
    const [from, to] = ranges[random.next(ranges.length)];
    return splice(bytes, from, to);
  } },
  { name: 'duplicate-line', apply(bytes, random) {
    const ranges = lineRanges(bytes);
    if (ranges.length === 0) return null;
    const [from, to] = ranges[random.next(ranges.length)];
    return Uint8Array.from([...bytes.subarray(0, to), ...bytes.subarray(from, to), ...bytes.subarray(to)]);
  } },
];

// One case is one source and one to three mutations applied in order. Fewer is easier to shrink,
// but one mutation per case spends the whole budget on one keystroke per file; three still leaves a
// repro a person can read after shrinking.
export function mutate(bytes, random) {
  const applied = [];
  let current = bytes;
  const count = 1 + random.next(3);
  for (let i = 0; i < count; i += 1) {
    const mutation = MUTATIONS[random.next(MUTATIONS.length)];
    const next = mutation.apply(current, random);
    if (next !== null) {
      current = next;
      applied.push(mutation.name);
    }
  }
  return { bytes: current, applied };
}

// A case is a small project, not a loose file: `use` resolves through a module root, and the file
// under test needs its siblings or the front end never sees it. `src/` holds the mutated file plus a
// symlink per sibling module, and `grail.toml` is what makes `src` a root (compiler/native.grl,
// resolve_modules). The entry keeps its own file name, so a diagnostic reads like the real one.
function layOutCase(directory, sourcePath, bytes) {
  rmSync(directory, { recursive: true, force: true });
  const source = join(directory, 'src');
  mkdirSync(source, { recursive: true });
  writeFileSync(join(directory, 'grail.toml'), '[package]\nname = "fuzzcase"\nversion = "0.1.0"\n');
  const name = basename(sourcePath);
  for (const sibling of readdirSync(dirname(sourcePath)).sort()) {
    if (!sibling.endsWith('.grl') || sibling === name) continue;
    try {
      symlinkSync(join(dirname(sourcePath), sibling), join(source, sibling));
    } catch {
      // A sibling that cannot be linked is one module this case does not reach; the case still runs.
    }
  }
  writeFileSync(join(source, name), bytes);
  return join('src', name);
}

// ---------------------------------------------------------------------------------------------
// Running one compiler, and reading what it said
// ---------------------------------------------------------------------------------------------
const OUTPUT_CAP = 256 * 1024;

export function runCompiler(compiler, args, cwd, timeout) {
  return new Promise(done => {
    let settled = false;
    const child = spawn(compiler, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, GRAIL_HOME: root } });
    let output = '';
    const collect = chunk => {
      if (output.length < OUTPUT_CAP) output += chunk.toString('utf8');
    };
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGKILL');
    }, timeout);
    child.stdout.on('data', collect);
    child.stderr.on('data', collect);
    const finish = result => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      done({ ...result, timedOut, output });
    };
    child.on('error', error => finish({ status: null, signal: null, error }));
    child.on('close', (status, signal) => finish({ status, signal, error: null }));
  });
}

// The messages a compiler's *own* runtime prints when the compiler has failed (compiler/runtime.grl
// click "rt_fail_body"). A diagnostic about the program is not in this list, however it is worded;
// these are the compiler saying it could not finish.
const INTERNAL_MESSAGES = [
  /^assertion failed$/,
  /^index -?\d+ out of bounds for length -?\d+$/,
  /^index out of bounds$/,
  /^range -?\d+\.\.-?\d+ out of bounds$/,
  /^unwrap of None or Err$/,
  /^arithmetic overflow$/,
  /^division by zero$/,
  /^pop from an empty vector$/,
  /^negative value converted to an unsigned type$/,
  /^value has no matching variant$/,
  /^byte value -?\d+ does not fit in u8$/,
  /^C array length mismatch/,
  /^stack overflow$/,
  /^the program aborted$/,
  /^internal error/,
  /^internal compiler error/,
  /^ENOEXEC$/,
  /^cannot exec/,
];
const INTERNAL_NOTES = [/^note: this is a compiler bug/];

// Digits become N: two "index 4 out of bounds for length 3" hits from different files are one bug
// class, and the crash *site* line that follows names the compiler location that has to be fixed.
function normalize(text) {
  return text.replace(/-?\d+/g, 'N').replace(/\s+/g, ' ').trim();
}

// The crash site: the compiler's own diagnostic frame. `rt_fail_site_full` prints ` --> file:line`,
// and a compiler-source file names the code that broke; the message alone is too coarse (one
// "index out of bounds" covers many sites).
export function signatureOf(result) {
  if (result.timedOut) return 'hang: no exit within the timeout';
  if (result.error) return `exec: ${result.error.code ?? result.error.message}`;
  if (result.signal) return `signal ${result.signal}`;
  const lines = result.output.split('\n').map(line => line.trimEnd());
  const at = lines.findIndex(line => /^(error|note)(\[[A-Z]\d+\])?: /.test(line));
  if (at < 0) return `exit ${result.status}: no diagnostic`;
  const message = normalize(lines[at].replace(/^error(\[[A-Z]\d+\])?: /, '').replace(/^note: /, ''));
  // The location line that belongs to this error: the next `-->` before any other error.
  let site = '';
  for (let i = at + 1; i < lines.length; i += 1) {
    if (/^(error|note)(\[[A-Z]\d+\])?: /.test(lines[i])) break;
    const location = /^\s*-->\s+(\S+)$/.exec(lines[i]);
    if (location) {
      site = location[1];
      break;
    }
  }
  return site ? `${message} @ ${site}` : message;
}

// `fine` is the language refusing a program. `bug` is the compiler failing at its own job. Anything
// else is reported as itself, because a classification that cannot say "I do not know" hides bugs.
export function classify(result) {
  if (result.timedOut) return { verdict: 'bug', kind: 'hang', why: 'the compiler did not exit within the timeout' };
  if (result.error) return { verdict: 'bug', kind: 'signal', why: `the compiler could not be run: ${result.error.message}` };
  if (result.signal) return { verdict: 'bug', kind: 'signal', why: `killed by ${result.signal}` };
  const lines = result.output.split('\n').map(line => line.trimEnd());
  for (const line of lines) {
    const note = /^note: (.*)$/.exec(line);
    if (note && INTERNAL_NOTES.some(pattern => pattern.test(line))) {
      return { verdict: 'bug', kind: 'internal', why: note[1] };
    }
    const error = /^error(\[[A-Z]\d+\])?: (.*)$/.exec(line);
    if (!error) continue;
    const message = error[2];
    if (INTERNAL_MESSAGES.some(pattern => pattern.test(message))) {
      return { verdict: 'bug', kind: 'internal', why: message };
    }
  }
  if (result.status === 0) return { verdict: 'fine' };
  if (result.status === 1) {
    const diagnostic = lines.some(line => /^error(\[[A-Z]\d+\])?: /.test(line));
    const location = lines.some(line => /^\s*-->\s+\S+:\d+:\d+$/.test(line));
    if (diagnostic && location) return { verdict: 'fine' };
    if (diagnostic) return { verdict: 'other', why: 'a diagnostic without a `-->` location' };
    const first = lines.find(line => line.trim() !== '') ?? '';
    return { verdict: 'other', why: first === '' ? 'exit 1 and no output' : `exit 1 with no diagnostic: ${normalize(first)}` };
  }
  const first = lines.find(line => line.trim() !== '') ?? '';
  return { verdict: 'other', why: `exit ${result.status}${first === '' ? ' with no output' : `: ${normalize(first)}`}` };
}

// ---------------------------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------------------------
export function generateCases(options, compilerBytes) {
  const sources = compilerBytes ?? corpusFiles().map(path => ({ path, bytes: readFileSync(path) }));
  const random = randomFrom(options.seed);
  const cases = [];
  for (let index = 0; index < options.cases; index += 1) {
    const chosen = sources[random.next(sources.length)];
    const { bytes, applied } = mutate(chosen.bytes, random);
    cases.push({
      id: `${String(index + 1).padStart(5, '0')}`,
      path: chosen.path,
      source: relative(root, chosen.path),
      mutations: applied,
      bytes,
    });
  }
  return cases;
}

async function runCases(cases, options, compiler) {
  const results = new Array(cases.length);
  let next = 0;
  const worker = async () => {
    for (;;) {
      const index = next;
      next += 1;
      if (index >= cases.length) return;
      const item = cases[index];
      const directory = join(workRoot, 'cases', item.id);
      const entry = layOutCase(directory, item.path, item.bytes);
      const started = Date.now();
      const result = await runCompiler(compiler, ['check', entry], directory, options.timeout);
      const elapsed = Date.now() - started;
      const verdict = classify(result);
      results[index] = {
        ...item,
        ...verdict,
        status: result.status ?? null,
        signal: result.signal ?? null,
        timedOut: result.timedOut,
        elapsed,
        output: result.output,
      };
      if (verdict.verdict === 'fine' && !options.keep) rmSync(directory, { recursive: true, force: true });
    }
  };
  await Promise.all(Array.from({ length: Math.min(options.jobs, cases.length) }, worker));
  return results;
}

// ---------------------------------------------------------------------------------------------
// Shrinking
// ---------------------------------------------------------------------------------------------
// The minimal repro is the whole point of a crash report: "index 4 out of bounds" plus 1.5 MB of
// mutated compiler source names nothing. Shrink lines first (a repro with whole lines is readable),
// then byte runs, until no single deletion still crashes.
export async function shrink(bytes, sourcePath, options, compiler, kind) {
  let current = bytes;
  const budget = { runs: 0, max: options.shrinkBudget ?? 600 };
  const stillCrashes = async candidate => {
    if (budget.runs >= budget.max) return false;
    budget.runs += 1;
    const directory = join(workRoot, 'shrink');
    const entry = layOutCase(directory, sourcePath, candidate);
    const result = await runCompiler(compiler, ['check', entry], directory, options.timeout);
    const verdict = classify(result);
    return verdict.verdict === 'bug' && verdict.kind === kind;
  };
  const shrinkBy = async units => {
    let size = units();
    for (let count = Math.max(1, Math.floor(size / 2)); size > 0 && count >= 1; count = Math.floor(count / 2)) {
      for (let at = 0; at + count <= size; ) {
        const spans = units();
        const head = spans.slice(0, at);
        const tail = spans.slice(at + count);
        const candidate = joinSpans([...head, ...tail]);
        if (candidate.length < current.length && (await stillCrashes(candidate))) {
          current = candidate;
          size = units().length;
        } else {
          at += count;
        }
        if (budget.runs >= budget.max) return;
      }
    }
  };
  // Whole lines, then single bytes: a shortened file still has to parse as far as the crash.
  const lines = () => {
    const spans = [];
    let start = 0;
    for (let i = 0; i < current.length; i += 1) {
      if (current[i] === 0x0a) {
        spans.push([start, i + 1]);
        start = i + 1;
      }
    }
    if (start < current.length) spans.push([start, current.length]);
    return spans;
  };
  const joinSpans = spans => Uint8Array.from(spans.flatMap(([from, to]) => [...current.subarray(from, to)]));
  await shrinkBy(lines);
  const single = () => Array.from({ length: current.length }, (_, index) => [index, index + 1]);
  await shrinkBy(single);
  const runBytes = async () => {
    // One byte at a time, repeatedly, so a deletion that only becomes interesting later still lands.
    for (let changed = true; changed && budget.runs < budget.max; ) {
      changed = false;
      for (let at = 0; at < current.length; ) {
        const candidate = splice(current, at, at + 1);
        if (await stillCrashes(candidate)) {
          current = candidate;
          changed = true;
        } else {
          at += 1;
        }
        if (budget.runs >= budget.max) break;
      }
    }
  };
  await runBytes();
  return current;
}

// A file name from a signature, so `.work/fuzz/bugs/` is readable: the crash site's module and line.
function slug(signature, index) {
  const cleaned = signature.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60);
  return `${String(index + 1).padStart(2, '0')}-${cleaned || 'bug'}`;
}

// ---------------------------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------------------------
export async function fuzz(options) {
  const compiler = compilerPath(options);
  const sources = corpus(options);
  const cases = generateCases(options, sources);
  const started = Date.now();
  const results = await runCases(cases, options, compiler);
  const elapsed = Date.now() - started;

  const counts = { cases: results.length, fine: 0, bugs: 0, hangs: 0, other: 0 };
  const byKind = {};
  const bySignature = new Map();
  const others = new Map();
  for (const result of results) {
    if (result.verdict === 'bug') {
      if (result.kind === 'hang') counts.hangs += 1;
      else counts.bugs += 1;
      byKind[result.kind] = (byKind[result.kind] ?? 0) + 1;
      const signature = signatureOf(result);
      if (!bySignature.has(signature)) bySignature.set(signature, []);
      bySignature.get(signature).push(result);
    } else if (result.verdict === 'fine') counts.fine += 1;
    else {
      counts.other += 1;
      if (!others.has(result.why)) others.set(result.why, []);
      others.get(result.why).push(result);
    }
  }

  // One entry per distinct crash site: the first case that reached it carries the repro.
  const bugs = [];
  let index = 0;
  for (const [signature, hits] of bySignature) {
    const name = slug(signature, index);
    index += 1;
    const directory = join(workRoot, 'bugs', name);
    layOutCase(directory, hits[0].path, hits[0].bytes);
    writeFileSync(join(directory, 'crash.txt'), hits[0].output);
    const entry = {
      signature,
      kind: hits[0].kind,
      why: hits[0].why,
      hits: hits.length,
      source: hits[0].source,
      mutations: hits[0].mutations,
      case: hits[0].id,
      repro: relative(root, join(directory, 'src', basename(hits[0].path))),
      output: join(directory, 'crash.txt'),
    };
    if (options.shrink) {
      const minimal = await shrink(hits[0].bytes, hits[0].path, options, compiler, hits[0].kind);
      writeFileSync(join(directory, 'minimal.grl'), minimal);
      entry.minimal = relative(root, join(directory, 'minimal.grl'));
      entry.minimalBytes = minimal.length;
      entry.minimalText = minimal.toString('utf8');
    }
    bugs.push(entry);
  }

  // The slowest cases, whatever their verdict: a hang under a loaded host and a real loop look the
  // same in the counts, and the time each case took is what tells them apart (and where to look).
  const slowest = [...results].sort((a, b) => b.elapsed - a.elapsed).slice(0, 5)
    .map(r => ({ case: r.id, source: r.source, ms: r.elapsed, verdict: r.kind === 'hang' ? 'hang' : r.verdict }));
  const report = { seed: options.seed, cases: options.cases, jobs: options.jobs, timeout: options.timeout, maxBytes: options.maxBytes, corpus: sources.length, compiler, elapsed, counts, byKind, bugs, others: [...others.entries()].map(([why, hits]) => ({ why, hits: hits.length, case: hits[0].id })), slowest };
  const slowLine = `slowest: ${slowest.map(s => `${s.case} ${s.source} ${s.ms}ms${s.verdict === 'hang' ? ' (hang)' : ''}`).join('; ')}`;
  mkdirSync(workRoot, { recursive: true });
  writeFileSync(join(workRoot, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);

  if (!options.quiet) {
    if (byKind.internal) {
      console.log('crashes in the compiler:');
      for (const [kind, count] of Object.entries(byKind)) console.log(`  ${kind}: ${count}`);
      for (const bug of bugs) {
        console.log(`\n  ${bug.signature}`);
        console.log(`    source ${bug.source} [${bug.mutations.join(', ')}]; ${bug.hits} hit(s); ${bug.repro}`);
        if (bug.minimalText !== undefined) {
          // A minimal repro is a few lines or the shrinker ran out of budget; print the source only
          // when it is short enough to read, and name the file either way.
          if (bug.minimalBytes <= 400) {
            console.log(`    minimal (${bug.minimalBytes} bytes):`);
            for (const line of bug.minimalText.split('\n')) console.log(`      ${line}`);
          } else {
            console.log(`    shrink stopped at ${bug.minimalBytes} bytes: ${bug.minimal}`);
          }
        }
      }
    }
    console.log(slowLine);
    if (others.size > 0) {
      console.log('not classified as a bug, and not a plain rejection:');
      for (const [why, hits] of others) console.log(`  ${hits.length}x ${why} (first: ${hits[0].id}, ${hits[0].source})`);
    }
    console.log(
      `fuzz: ${counts.cases} cases, ${counts.fine} fine, ${counts.bugs} bugs, ${counts.hangs} hangs` +
        `${counts.other ? `, ${counts.other} other` : ''} (seed ${options.seed}, ${sources.length} sources, ` +
        `${options.jobs} jobs, ${(elapsed / 1000).toFixed(1)}s)`,
    );
  } else {
    for (const bug of bugs) console.log(`BUG ${bug.signature}\n  repro ${bug.repro} (source ${bug.source}, ${bug.mutations.join(', ')})`);
    if (counts.hangs > 0) console.log(slowLine);
    console.log(
      `fuzz: ${counts.cases} cases, ${counts.fine} fine, ${counts.bugs} bugs, ${counts.hangs} hangs` +
        `${counts.other ? `, ${counts.other} other` : ''} (seed ${options.seed}, ${sources.length} sources, ` +
        `${options.jobs} jobs, ${(elapsed / 1000).toFixed(1)}s)`,
    );
  }
  return report;
}

if (import.meta.main) {
  let options;
  try {
    options = parse(process.argv.slice(2));
  } catch (error) {
    console.error(`fuzz-frontend: ${error.message}`);
    process.exit(2);
  }
  if (options.help) {
    console.log(`usage: bun tools/fuzz-frontend.mjs [--cases N] [--seed S] [--jobs J] [--timeout MS] [--max-bytes B]
                                   [--shrink] [--quiet] [--keep] [--compiler PATH]

Mutates real Grail sources and runs one compiler per case, looking for crashes.
  --cases N      how many mutations to run (default 200)
  --seed S       the generator's seed; the corpus and every case are deterministic from it (default 1)
  --jobs J       concurrent compiles (default 4); it changes the wall clock, not the cases
  --timeout MS   a case that runs past this is a hang (default 20000)
  --max-bytes B  mutate sources no larger than this (default 262144; 0 takes every source,
                 including the compiler's 1.5 MB module, which costs minutes per case)
  --shrink       shrink each distinct crash to a minimal repro in .work/fuzz/bugs/NAME/minimal.grl
  --shrink-budget N  compiler runs one shrink may spend (default 400)
  --quiet        only bugs and the summary line; exit 1 when a case crashed
  --keep         keep every case's bytes under .work/fuzz/cases/
Working files are under .work/fuzz/; the run's classification is .work/fuzz/report.json.`);
    process.exit(0);
  }
  const report = await fuzz(options);
  process.exit(report.counts.bugs + report.counts.hangs > 0 ? 1 : 0);
}
