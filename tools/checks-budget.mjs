// What the validation in a Grail program costs, split by kind. Measurement only: nothing here
// changes the compiler, and no front-end counter is involved -- the kind of an arm is decided by
// two facts the tree already has. The sequence accessors of compiler/runtime.grl are the only place
// a bounds check lives, and an arm the `--overflow=wrap` build does not contain is an arithmetic
// check. Four readings of the same corpus, bench/NAME.grl:
//
//   count   the abort arms in the emitted .ll per benchmark, by kind, for the default build and for
//           --overflow=wrap. Exact, needs no timing.
//   time    paired medians of the same program built from variants of that .ll: --overflow=wrap,
//           every abort arm deleted, only the sequence accessors' arms deleted, only the arms
//           --overflow=wrap does not emit deleted, and those two again on the wrap build.
//   proofs  one variant per candidate proof, with the bytes of code it removes and the gap share.
//   floor   the check-free build, and the same build with the accessors inlined (call overhead).
//           `--rounds N` is tools/bench.mjs's method: interleaved rounds, median of N.
//
// Deleting an arm is the experiment docs/design/llvm-backend.md stage 2b ran by hand: the branch
// that reaches an abort block is replaced by an unconditional branch to the block the check
// allows, and the abort block is dropped. No check fires on these five programs, so every variant
// must print what C prints, which the timing passes assert.
//   bun tools/checks-budget.mjs count|time|proofs|floor [--rounds N] [NAME...]
//   GRAIL_COMPILER=/path/to/grail ... to skip the build
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { linkInputs } from './native.mjs';
import { root } from './platforms.mjs';

const ARM = 'call void @"rt_abort.cold"()';
const DEFINE = /^define\s.*?@("[^"]+"|[\w.]+)\(/;
const LABEL = /^([\w.\-]+):$/;
const DEF = /^\s*(%[\w.]+)\s*=\s*(.+)$/;
const CONDITIONAL = /^br i1 (%[\w.]+), label %([\w.]+), label %([\w.]+)$/;

// The runtime's sequence accessors, from compiler/runtime.grl: the arm in each of these is an
// index or length test (`i < len`, `b < a`, `len < b`, `len == 0`, capacity for the pushes).
// Every other abort site in the module is a conversion, allocation, UTF-8, division or
// descriptor test, and the arms the front end emits in program functions are arithmetic.
const ACCESSORS = new Set([
  'rt_slot', 'rt_slotb', 'rt_slot4', 'rt_atb', 'rt_write', 'rt_slice', 'rt_vslice',
  'rt_pop', 'rt_popb', 'rt_pop4', 'rt_push', 'rt_push4', 'rt_pushb_checked', 'rt_reserveb',
  'rt_fill', 'rt_fillb', 'rt_fill4', 'rt_vec_insert', 'rt_vec_insert4', 'rt_vec_remove',
  'rt_vec_remove4', 'rt_vec_swap', 'rt_vec_swap4',
]);

function parse(text) {
  const lines = text.split('\n');
  const funcs = [];
  let cur = null;
  for (let i = 0; i < lines.length; i++) {
    const m = DEFINE.exec(lines[i]);
    if (m) {
      cur = { name: m[1].replace(/^"|"$/g, ''), start: i, end: lines.length, blocks: [] };
      funcs.push(cur);
      continue;
    }
    if (cur === null) continue;
    if (lines[i] === '}') { cur.end = i; cur = null; continue; }
    const label = LABEL.exec(lines[i].trim());
    if (label) { cur.blocks.push({ label: label[1], first: i, last: i }); continue; }
    if (cur.blocks.length && lines[i].trim()) cur.blocks[cur.blocks.length - 1].last = i;
  }
  return { lines, funcs };
}

const blockText = (ll, block) => ll.lines.slice(block.first, block.last + 1).map(s => s.trim()).filter(Boolean);

// Every abort arm, with the conditional branch that reaches it and the block that branch allows.
function arms(text) {
  const ll = parse(text);
  const out = [];
  for (const fn of ll.funcs) {
    const preds = new Map();
    const defs = new Map();
    for (const block of fn.blocks) {
      const text = blockText(ll, block);
      for (const ins of text) {
        const m = DEF.exec(ins);
        if (m) defs.set(m[1], m[2].trim());
      }
      const term = text[text.length - 1] ?? '';
      if (term.startsWith('br ')) for (const target of term.match(/label %[\w.]+/g) ?? []) {
        preds.set(target.slice(7), [...(preds.get(target.slice(7)) ?? []), block]);
      }
    }
    for (const block of fn.blocks) {
      if (!blockText(ll, block).some(ins => ins.startsWith(ARM))) continue;
      const guard = (preds.get(block.label) ?? []).find(p => {
        const term = blockText(ll, p).at(-1) ?? '';
        return CONDITIONAL.test(term);
      });
      const term = guard ? blockText(ll, guard).at(-1) : '';
      const m = CONDITIONAL.exec(term);
      out.push({
        fn: fn.name, block, guard: guard?.label ?? null, branchLine: guard?.last ?? null,
        predicate: m?.[1] ?? null, targets: m ? [m[2], m[3]] : [], defs,
      });
    }
  }
  return { ll, arms: out };
}

// The predicate a check tests, resolved through the frame slots the word machine spills it to.
function predicateChain(arm) {
  const { ll, defs } = arm;
  const seen = new Set();
  const out = [];
  const walk = (name, depth) => {
    if (depth > 10 || seen.has(name)) return;
    seen.add(name);
    const rhs = defs.get(name);
    if (rhs === undefined) return;
    out.push(rhs);
    for (const op of rhs.match(/%[\w.]+/g) ?? []) walk(op, depth + 1);
  };
  if (arm.predicate) walk(arm.predicate, 0);
  return out;
}

const signature = arm => predicateChain(arm)
  .map(rhs => rhs.replace(/%[\w.]+/g, '%x'))
  .sort()
  .join('\n');

// Longest common subsequence of the checked build's arms against the wrap build's, per function.
// --overflow=wrap elides the arithmetic check at its source, so an arm the wrap build does not
// have is an overflow arm and every arm it does have is a bounds or other arm.
function alignOverflow(checked, wrapped) {
  const key = arms => arms.map(signature);
  const kinds = new Map();
  const fns = new Set([...checked.keys(), ...wrapped.keys()]);
  for (const fn of fns) {
    const a = key(checked.get(fn) ?? []);
    const b = key(wrapped.get(fn) ?? []);
    const lcs = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0));
    for (let i = a.length - 1; i >= 0; i--) {
      for (let j = b.length - 1; j >= 0; j--) {
        lcs[i][j] = a[i] === b[j] ? lcs[i + 1][j + 1] + 1 : Math.max(lcs[i + 1][j], lcs[i][j + 1]);
      }
    }
    const kept = new Set();
    for (let i = 0, j = 0; i < a.length && j < b.length;) {
      if (a[i] === b[j]) { kept.add(i); i++; j++; } else if (lcs[i + 1][j] >= lcs[i][j + 1]) i++; else j++;
    }
    const list = checked.get(fn) ?? [];
    kinds.set(fn, list.map((_, i) => (kept.has(i) ? 'kept' : 'overflow')));
  }
  return kinds;
}

// An arm the wrap build still has is either an accessor's index/length test or one of the
// module's other checks; an arm only the checked build has is an arithmetic check.
const kindOf = (fn, aligned) => (aligned === 'overflow' ? 'overflow' : (ACCESSORS.has(fn) ? 'bounds' : 'other'));

function command(argv) {
  const result = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', maxBuffer: 1 << 30 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${argv.join(' ')} failed (${result.status})\n${result.stdout}${result.stderr}`);
  return result.stdout;
}

function compiler() {
  if (process.env.GRAIL_COMPILER && existsSync(process.env.GRAIL_COMPILER)) return resolve(process.env.GRAIL_COMPILER);
  return command(['bun', join(root, 'tools/native.mjs'), 'build']).trim().split('\n').pop();
}

// One benchmark, two builds of it: the default one and --overflow=wrap. Both come from the
// compiler the repository builds; the .ll is written beside the .s, so the arm analysis reads
// exactly what clang -O2 was given.
function emit(grail, name, work, overflow) {
  const tag = overflow === 'wrap' ? 'wrap' : 'checked';
  const assembly = join(work, `${name}-${tag}.s`);
  const inputs = [join(root, 'bench', `${name}.grl`), join(root, 'lib/core.grl'),
    join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')];
  command([grail, '--backend=llvm', '--target', 'x86_64',
    `--overflow=${overflow}`, assembly, ...inputs]);
  const text = readFileSync(`${assembly}.ll`, 'utf8');
  return { ll: text, asm: assembly, tag };
}

function link(work, name, tag, llText, base) {
  const ll = join(work, `${name}-${tag}.ll`);
  writeFileSync(ll, llText);
  const object = join(work, `${name}-${tag}.o`);
  command(['clang', '--target=x86_64-linux-gnu', '-O2', '-c', ll, '-o', object]);
  // The lifted module is one of two objects: the assembly the compiler wrote still carries the
  // data symbols (rt_state, the pools) and the functions the lifter declined.
  const data = join(work, `${name}-${base}-data.o`);
  command(['clang', '--target=x86_64-linux-gnu', '-c', join(work, `${name}-${base}.s`), '-o', data]);
  const exe = join(work, `${name}-${tag}`);
  const linkArgs = linkInputs(readFileSync(join(work, `${name}-${base}.s`), 'utf8'), join(root, 'bench'));
  command(['ld.lld', '-m', 'elf_x86_64', object, data, ...linkArgs, '-o', exe]);
  return exe;
}

// Functions reachable from the program's own code: the module is compiled with the whole runtime
// and core library in it and most of those arms never run, so a static count over the whole module
// says nothing about what a benchmark pays for. The start set is every `f_*` function (the
// program's own) and the edges are the direct calls in the emitted .ll.
function reachable(text) {
  const ll = parse(text);
  const calls = new Map();
  for (const fn of ll.funcs) {
    const body = ll.lines.slice(fn.start, fn.end).join('\n');
    calls.set(fn.name, [...new Set([...body.matchAll(/call[^@\n]*@("[^"]+"|[\w.]+)\(/g)].map(m => m[1].replace(/^"|"$/g, '')))]);
  }
  const seen = new Set();
  const roots = [...calls.keys()].filter(name => /^f_main/.test(name));
  const queue = roots.length ? roots : [...calls.keys()].filter(name => /^f_/.test(name));
  while (queue.length) {
    const name = queue.pop();
    if (seen.has(name)) continue;
    seen.add(name);
    for (const callee of calls.get(name) ?? []) if (!seen.has(callee)) queue.push(callee);
  }
  return seen;
}

function deleteArms(text, doomed) {
  const { ll } = arms(text);
  const drop = new Set();
  const rewrite = new Map();
  for (const arm of doomed) {
    if (arm.branchLine === null) continue;
    const term = ll.lines[arm.branchLine];
    const m = CONDITIONAL.exec(term.trim());
    if (!m) continue;
    const keep = m[2] === arm.block.label ? m[3] : m[2];
    rewrite.set(arm.branchLine, `br label %${keep}`);
    for (let i = arm.block.first; i <= arm.block.last; i++) drop.add(i);
  }
  const out = [];
  for (let i = 0; i < ll.lines.length; i++) {
    if (drop.has(i)) continue;
    out.push(rewrite.get(i) ?? ll.lines[i]);
  }
  return out.join('\n');
}

// The checked build's arms that --overflow=wrap does not emit, in the same per-function order
// alignOverflow uses. These are the arithmetic checks: deleting exactly these leaves the rest of
// the checked build (its registers, its flag stores) as the front end wrote it.
function overflowArms(checkedText, wrappedText) {
  const a = arms(checkedText).arms;
  const b = arms(wrappedText).arms;
  const kinds = alignOverflow(group(a), group(b));
  const ordinal = new Map();
  return a.filter(arm => {
    const n = ordinal.get(arm.fn) ?? 0;
    ordinal.set(arm.fn, n + 1);
    return kinds.get(arm.fn)?.[n] === 'overflow';
  });
}

// One candidate proof per benchmark: which arms it would remove, deleting nothing else. The
// numbers these print are "if this proof held and nothing else changed", which is the most a
// proof can be worth on the .ll as it stands. The program's own functions are `f_main*`; every
// other `f_` name in the module is the runtime's host layer.
const PROOFS = {
  fnv: [
    ['bounds: len(data) == n from the fill loop (rt_atb)', r => r.fn === 'rt_atb'],
    ['overflow: the xorshift shifts and the hash multiply', (r, live) => r.kind === 'overflow' && /^f_main/.test(r.fn)],
    ['other: u64(data[i]) (rt_int_cast)', r => r.fn === 'rt_int_cast'],
  ],
  sieve: [
    ['bounds: len(composite) == n + 1, loops bounded by n', (r, live) => (r.fn === 'rt_atb' || r.fn === 'rt_write') && live.has(r.fn)],
    ['bounds: the inner store only (rt_write)', r => r.fn === 'rt_write'],
    ['bounds: the outer scan only (rt_atb)', r => r.fn === 'rt_atb'],
    ['overflow: i * i and the strides', (r, live) => r.kind === 'overflow' && /^f_main/.test(r.fn)],
  ],
  sort: [
    ['bounds: i < mid <= hi <= n == len(v), k < hi (rt_slot)', (r, live) => r.fn === 'rt_slot' && live.has(r.fn)],
    ['overflow: lo + width, 2 * width, the strides', (r, live) => r.kind === 'overflow' && /^f_main/.test(r.fn)],
    ['other: the merge body has no conversion check', (r, live) => r.kind === 'other' && /^f_main/.test(r.fn)],
  ],
  nbody: [
    ['bounds: i*3+k < 15 == len(p), len(v), len(m) (rt_slot)', r => r.fn === 'rt_slot'],
    ['overflow: i*3 and i*3+k, bounded by the step', (r, live) => r.kind === 'overflow' && /^f_main/.test(r.fn)],
    ['other: f64 arithmetic as a call (rt_f64_op)', r => r.fn === 'rt_f64_op'],
  ],
  matmul: [
    ['bounds: i*n+k, k*n+j < n*n (rt_slot4)', r => r.fn === 'rt_slot4'],
    ['bounds: every reachable accessor', (r, live) => r.kind === 'bounds' && live.has(r.fn)],
    ['overflow: i*n+k and k*n+j, bounded by 256', (r, live) => r.kind === 'overflow' && /^f_main/.test(r.fn)],
    ['other: the f32 round trip (rt_f32_round)', r => r.fn === 'rt_f32_round'],
  ],
};

// The check-free floor is the representation plus whatever else the lowering costs. Inlining the
// sequence accessors into their call sites is the one lever that separates a call from the header
// load it carries: it removes the call and the return, and it lets LLVM merge the header load of
// consecutive accesses (which is the representation cost, so the win is an *upper* bound on call
// overhead and the scheduling it blocks, and a *lower* bound on what is left).
function markAlwaysInline(text) {
  const out = [];
  let current = null;
  for (const line of text.split('\n')) {
    const m = /^define\s.*@("[^"]+"|[\w.]+)\(/.exec(line);
    if (m) current = m[1].replace(/^"|"$/g, '');
    if (m && ACCESSORS.has(current)) {
      out.push(line.replace(/\{$/, 'alwaysinline {'));
      continue;
    }
    out.push(line);
  }
  return out.join('\n');
}

function textBytes(object) {
  const out = command(['objdump', '-h', object]);
  const line = out.split('\n').find(l => /^\s*\d+\s+\.text\s/.test(l));
  return line ? Number.parseInt(line.trim().split(/\s+/)[2], 16) : 0;
}

const median = values => [...values].sort((a, b) => a - b)[values.length >> 1];
const numbers = text => text.trim().split(/\s+/).map(word => {
  const n = Number(word);
  return Number.isFinite(n) && /[.e]/i.test(word) ? n.toPrecision(12) : word;
});

function once(exe) {
  const start = process.hrtime.bigint();
  const out = command([exe]);
  return { time: Number(process.hrtime.bigint() - start) / 1e9, out };
}

export { arms, kindOf, alignOverflow, overflowArms, reachable, deleteArms, emit, ACCESSORS, textBytes, PROOFS, markAlwaysInline };

if (import.meta.main) {
  const grail = compiler();
  const argv = process.argv.slice(2);
  const mode = argv[0] ?? 'count';
  const at = argv.indexOf('--rounds');
  const rounds = at >= 0 ? Number(argv[at + 1]) : 0;
  const names = argv.slice(1).filter(a => a !== '--rounds' && a !== String(rounds));
  const all = names.length ? names : readdirSync(join(root, 'bench')).filter(f => f.endsWith('.grl')).map(f => f.slice(0, -4)).sort();
  const work = mkdtempSync(join(tmpdir(), 'grail-checks-'));
  const attribution = [];
  let failed = 0;
  try {
    const per = new Map();
    for (const name of all) {
      const checked = emit(grail, name, work, 'checked');
      const wrapped = emit(grail, name, work, 'wrap');
      const a = arms(checked.ll);
      const b = arms(wrapped.ll);
      const kinds = alignOverflow(group(a.arms), group(b.arms));
      const ordinal = new Map();
      const rows = a.arms.map(arm => {
        const n = ordinal.get(arm.fn) ?? 0;
        ordinal.set(arm.fn, n + 1);
        return { ...arm, kind: kindOf(arm.fn, kinds.get(arm.fn)?.[n] ?? 'kept') };
      });
      const live = reachable(checked.ll);
      const byKind = {};
      for (const row of rows) if (live.has(row.fn)) byKind[row.kind] = (byKind[row.kind] ?? 0) + 1;
      per.set(name, { rows, byKind, live, wrapArms: b.arms.length, checkedArms: a.arms.length, checked, wrapped });
    }
    if (mode === 'count') {
      console.log('benchmark    checked  wrap   bounds  overflow  other   (abort arms in the emitted .ll, all functions)');
      for (const [name, p] of per) {
        console.log(`${name.padEnd(12)} ${String(p.checkedArms).padStart(7)} ${String(p.wrapArms).padStart(5)} ${String(p.byKind.bounds ?? 0).padStart(8)} ${String(p.byKind.overflow ?? 0).padStart(9)} ${String(p.byKind.other ?? 0).padStart(6)}`);
      }
      console.log('\nreachable from the program\'s own code (the arms a run can execute):');
      console.log('benchmark    bounds  overflow  other   total');
      for (const [name, p] of per) {
        const k = p.byKind;
        console.log(`${name.padEnd(12)} ${String(k.bounds ?? 0).padStart(7)} ${String(k.overflow ?? 0).padStart(9)} ${String(k.other ?? 0).padStart(6)} ${String((k.bounds ?? 0) + (k.overflow ?? 0) + (k.other ?? 0)).padStart(7)}`);
      }
      console.log('\narms in the program\'s own functions (f_main*):');
      for (const [name, p] of per) {
        const own = p.rows.filter(r => /^f_main/.test(r.fn) && p.live.has(r.fn));
        const counts = {};
        for (const r of own) counts[r.kind] = (counts[r.kind] ?? 0) + 1;
        console.log(`  ${name.padEnd(10)} ${own.length} arms  ${JSON.stringify(counts)}`);
      }
      console.log(`\n(${grail})`);
    } else if (mode === 'time') {
      if (!(rounds >= 1)) throw new Error('time needs --rounds N');
      console.log('benchmark    C -O2     checked    ratio    wrap    ratio    noarm   ratio   wbounds  ratio   wnoarm  ratio   covf    ratio  (median of ' + rounds + ' paired)');
      for (const [name, p] of per) {
        const variants = new Map();
        const { checked, wrapped } = p;
        variants.set('checked', link(work, name, 'checked', checked.ll, 'checked'));
        variants.set('wrap', link(work, name, 'wrap', wrapped.ll, 'wrap'));
        variants.set('no-arm', link(work, name, 'no-arm', deleteArms(checked.ll, arms(checked.ll).arms), 'checked'));
        variants.set('wrap-noarm', link(work, name, 'wrap-noarm', deleteArms(wrapped.ll, arms(wrapped.ll).arms), 'wrap'));
        const wrapArms = arms(wrapped.ll).arms;
        variants.set('wrap-boundsfree', link(work, name, 'wrap-boundsfree',
          deleteArms(wrapped.ll, wrapArms.filter(arm => ACCESSORS.has(arm.fn))), 'wrap'));
        variants.set('checked-overflowfree', link(work, name, 'checked-overflowfree',
          deleteArms(checked.ll, overflowArms(checked.ll, wrapped.ll)), 'checked'));
        const cexe = join(work, `${name}-c`);
        command(['clang', '-O2', '-ffp-contract=off', join(root, 'bench', `${name}.c`), '-o', cexe, '-lm']);
        const times = new Map([['C', []], ...[...variants.keys()].map(k => [k, []])]);
        const outputs = new Map();
        for (const exe of [cexe, ...variants.values()]) once(exe);
        for (let i = 0; i < rounds; i++) {
          for (const [key, exe] of [['C', cexe], ...variants]) {
            const r = once(exe);
            times.get(key).push(r.time);
            outputs.set(key, r.out);
          }
        }
        const med = key => median(times.get(key));
        const c = med('C');
        const same = [...variants.keys()].every(k => JSON.stringify(numbers(outputs.get(k))) === JSON.stringify(numbers(outputs.get('C'))));
        if (!same) failed++;
        const cell = key => `${med(key).toFixed(3)}s ${(med(key) / c).toFixed(3)}x`;
        console.log(`${name.padEnd(12)} ${c.toFixed(3)}s  ${cell('checked')}  ${cell('wrap')}  ${cell('no-arm')}  ${cell('wrap-boundsfree')}  ${cell('wrap-noarm')}  ${cell('checked-overflowfree')}${same ? '' : '  OUTPUT DIFFERS'}`);
        const gap = med('checked') - c;
        const over = med('checked') - med('wrap');
        const bounds = med('wrap') - med('wrap-boundsfree');
        const other = med('wrap-boundsfree') - med('wrap-noarm');
        const total = med('checked') - med('no-arm');
        const overBranch = med('checked') - med('checked-overflowfree');
        attribution.push({
          name, c, checked: med('checked'), wrap: med('wrap'), noarm: med('no-arm'),
          gap, over, overBranch, bounds, other, total,
          residual: (med('no-arm') - c) / gap * 100, interaction: total - over - bounds - other,
        });
      }
      console.log('\nattribution: % of the checked-over-C gap, measured by deleting one kind of arm');
      console.log('benchmark     gap     overflow (branch)   bounds   other   checks  interaction   floor');
      for (const row of attribution) {
        const pct = x => `${(x / row.gap * 100).toFixed(1)}%`.padStart(7);
        console.log(`${row.name.padEnd(12)}${pct(row.gap)}  ${pct(row.over)}  ${pct(row.overBranch)}      ${pct(row.bounds)}  ${pct(row.other)}  ${pct(row.total)}  ${pct(row.interaction)}   ${row.residual.toFixed(1)}%`);
      }
    } else if (mode === 'proofs') {
      if (!(rounds >= 1)) throw new Error('proofs needs --rounds N');
      for (const [name, p] of per) {
        const { checked } = p;
        const base = p.rows;
        const baseExe = link(work, name, 'checked', checked.ll, 'checked');
        const baseText = textBytes(join(work, `${name}-checked.o`));
        const cexe = join(work, `${name}-c`);
        command(['clang', '-O2', '-ffp-contract=off', join(root, 'bench', `${name}.c`), '-o', cexe, '-lm']);
        const variants = new Map();
        for (const [index, [label, doomed]] of (PROOFS[name] ?? []).entries()) {
          const doomedArms = base.filter(row => doomed(row, p.live));
          const tag = `proof${index}`;
          variants.set(label, {
            arms: doomedArms.length,
            exe: link(work, name, tag, deleteArms(checked.ll, doomedArms), 'checked'),
            object: join(work, `${name}-${tag}.o`),
          });
        }
        const times = new Map([['C', []], ['checked', []], ...[...variants.keys()].map(k => [k, []])]);
        const outputs = new Map();
        for (const exe of [cexe, baseExe, ...[...variants.values()].map(v => v.exe)]) once(exe);
        for (let i = 0; i < rounds; i++) {
          for (const [key, exe] of [['C', cexe], ['checked', baseExe], ...[...variants].map(([k, v]) => [k, v.exe])]) {
            const r = once(exe);
            times.get(key).push(r.time);
            outputs.set(key, r.out);
          }
        }
        const c = median(times.get('C'));
        console.log(`${name}: checked ${median(times.get('checked')).toFixed(3)}s = ${(median(times.get('checked')) / c).toFixed(3)}x of C (${c.toFixed(3)}s), gap ${((median(times.get('checked')) - c) * 1000).toFixed(0)} ms`);
        for (const [label, v] of variants) {
          const t = median(times.get(label));
          const same = JSON.stringify(numbers(outputs.get(label))) === JSON.stringify(numbers(outputs.get('C')));
          if (!same) failed++;
          console.log(`  ${label.padEnd(58)} ${String(v.arms).padStart(4)} arms ${String(baseText - textBytes(v.object)).padStart(7)} B  ${t.toFixed(3)}s ${(t / c).toFixed(3)}x${same ? '' : '  OUTPUT DIFFERS'}`);
        }
      }
    } else if (mode === 'floor') {
      if (!(rounds >= 1)) throw new Error('floor needs --rounds N');
      console.log('benchmark    C -O2    no checks   ratio   accessors inlined   ratio   (median of ' + rounds + ')');
      for (const [name, p] of per) {
        const { checked } = p;
        const free = deleteArms(checked.ll, arms(checked.ll).arms);
        const inlined = markAlwaysInline(free);
        const variants = new Map([
          ['free', link(work, name, 'free', free, 'checked')],
          ['inlined', link(work, name, 'inlined', inlined, 'checked')],
        ]);
        const cexe = join(work, `${name}-c`);
        command(['clang', '-O2', '-ffp-contract=off', join(root, 'bench', `${name}.c`), '-o', cexe, '-lm']);
        const times = new Map([['C', []], ...[...variants.keys()].map(k => [k, []])]);
        const outputs = new Map();
        for (const exe of [cexe, ...variants.values()]) once(exe);
        for (let i = 0; i < rounds; i++) {
          for (const [key, exe] of [['C', cexe], ...variants]) {
            const r = once(exe);
            times.get(key).push(r.time);
            outputs.set(key, r.out);
          }
        }
        const c = median(times.get('C'));
        const same = [...variants.keys()].every(k => JSON.stringify(numbers(outputs.get(k))) === JSON.stringify(numbers(outputs.get('C'))));
        if (!same) failed++;
        const cell = key => `${(median(times.get(key)) / c).toFixed(3)}x`;
        console.log(`${name.padEnd(12)} ${c.toFixed(3)}s  ${cell('free')}       ${cell('free')}   ${cell('inlined')}               ${cell('inlined')}${same ? '' : '  OUTPUT DIFFERS'}`);
      }
    } else {
      throw new Error(`unknown mode ${mode}; use count, time, proofs or floor`);
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
  if (failed) process.exit(1);
}

function group(list) {
  const map = new Map();
  for (const arm of list) map.set(arm.fn, [...(map.get(arm.fn) ?? []), arm]);
  return map;
}
