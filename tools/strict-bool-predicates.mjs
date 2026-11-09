// Extract the u64 functions that are really predicates.
//
// `--strict-bool` (compiler/native.grl, `strict_bool_check` / `strict_condition`) reports a u64
// function that returns a comparison, `true`/`false` or another predicate as bool/integer mixing.
// Converting those helpers to `-> bool` is the first migration phase: while a predicate still
// returns u64, every caller's condition reads as an integer condition.
//
// Not every bool-shaped u64 function is a predicate. The compiler's command handlers return 0/1 as
// a *process exit status* (`test_command` ends with `return failed != 0`), and the runtime's void
// routines are spelled `return 0`. This tool therefore classifies by shape and by how the value is
// consumed:
//
//   predicate  every `return` is bool-shaped and a caller tests the value
//   status     bool-shaped, but the value reaches an integer position: the process exit status
//              (main and everything returned straight through it), `mut status = f(...)` followed by
//              `status == 0`, or a u64 record field. These stay u64.
//   void       every `return` is a bare 0/1 and no caller tests it: a routine spelled `return 0`
//
// `unsafe module runtime;` files (runtime, os-*, darwin) are skipped: the compiler does not run
// strict_bool in raw mode, so they are not part of the migration.
//
// Usage:
//   bun tools/strict-bool-predicates.mjs                 predicates for the compiler's sources
//   bun tools/strict-bool-predicates.mjs --calls         ... with every call site and its context
//   bun tools/strict-bool-predicates.mjs --status        status functions that must stay u64
//   bun tools/strict-bool-predicates.mjs --void          0/1 routines that are not predicates
//   bun tools/strict-bool-predicates.mjs --integer-sites predicates with a call site in an integer position
//   bun tools/strict-bool-predicates.mjs --json          machine-readable
//   bun tools/strict-bool-predicates.mjs FILE.grl ...    any other set of files
import { readFileSync } from 'node:fs';
import { relative, resolve } from 'node:path';
import { compilerSources, root } from './native.mjs';

const punctuation = ['->', '==', '!=', '<=', '>=', '&&', '||', '<<', '>>', '**', '+=', '-=', '*=', '/=', '%=', '..', '::', '=>',
  '(', ')', '{', '}', '[', ']', '<', '>', '+', '-', '*', '/', '%', '=', '!', '&', '|', '^', '~', '?', ':', ';', ',', '.', '#', '@'];

function tokenize(text) {
  const tokens = [];
  let i = 0;
  let line = 1;
  let column = 1;
  const advance = n => {
    for (let k = 0; k < n; k++) {
      if (text[i + k] === '\n') { line += 1; column = 1; } else column += 1;
    }
    i += n;
  };
  while (i < text.length) {
    const c = text[i];
    if (c === ' ' || c === '\t' || c === '\r' || c === '\n') { advance(1); continue; }
    if (c === '/' && text[i + 1] === '/') {
      while (i < text.length && text[i] !== '\n') advance(1);
      continue;
    }
    const at = { line, column };
    if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < text.length && text[j] !== c) j += text[j] === '\\' ? 2 : 1;
      tokens.push({ kind: 'literal', value: text.slice(i, j + 1), ...at });
      advance(j + 1 - i);
      continue;
    }
    const word = /^[A-Za-z_][A-Za-z0-9_]*/.exec(text.slice(i));
    if (word) {
      tokens.push({ kind: 'ident', value: word[0], ...at });
      advance(word[0].length);
      continue;
    }
    const number = /^[0-9][0-9A-Za-z_.]*/.exec(text.slice(i));
    if (number) {
      tokens.push({ kind: 'number', value: number[0], ...at });
      advance(number[0].length);
      continue;
    }
    const op = punctuation.find(p => text.startsWith(p, i));
    if (!op) throw new Error(`unexpected character ${JSON.stringify(c)} at ${line}:${column}`);
    tokens.push({ kind: 'punct', value: op, ...at });
    advance(op.length);
  }
  return tokens;
}

const openers = { '(': ')', '[': ']', '{': '}' };
function skipGroup(tokens, start) {
  const close = openers[tokens[start].value];
  let depth = 0;
  for (let i = start; i < tokens.length; i++) {
    const v = tokens[i].kind === 'punct' ? tokens[i].value : '';
    if (v === tokens[start].value) depth += 1;
    else if (v === close && --depth === 0) return i + 1;
  }
  throw new Error(`unclosed ${tokens[start].value} at ${tokens[start].line}:${tokens[start].column}`);
}
function skipAngle(tokens, start) {
  let depth = 0;
  for (let i = start; i < tokens.length; i++) {
    if (tokens[i].value === '<') depth += 1;
    else if (tokens[i].value === '>') { if (--depth === 0) return i + 1; }
    else if (tokens[i].value === '(' || tokens[i].value === '{') return start;
  }
  return start;
}
function functions(tokens, path) {
  const found = [];
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i].kind !== 'ident' || tokens[i].value !== 'fn') continue;
    const name = tokens[i + 1];
    if (name?.kind !== 'ident') continue;
    let j = i + 2;
    if (tokens[j].value === '<') j = skipAngle(tokens, j);
    if (tokens[j].value !== '(') continue;
    j = skipGroup(tokens, j);
    if (tokens[j]?.value !== '->') continue;
    let k = j + 1;
    while (k < tokens.length && tokens[k].value !== '{') k += 1;
    if (k >= tokens.length) continue;
    const type = tokens.slice(j + 1, k).map(x => x.value).join('');
    const end = skipGroup(tokens, k);
    found.push({ name: name.value, type, path, line: name.line, column: name.column,
      start: i, bodyStart: k + 1, end, body: tokens.slice(k + 1, end - 1) });
    i = end - 1;
  }
  return found;
}
function returns(body) {
  const list = [];
  for (let i = 0; i < body.length; i++) {
    if (body[i].kind !== 'ident' || body[i].value !== 'return') continue;
    let depth = 0;
    let j = i + 1;
    for (; j < body.length; j++) {
      const v = body[j].kind === 'punct' ? body[j].value : '';
      if (openers[v]) depth += 1;
      else if (v === ')' || v === ']' || v === '}') depth -= 1;
      else if (v === ';' && depth === 0) break;
    }
    list.push(body.slice(i + 1, j));
    i = j;
  }
  return list;
}

const comparisons = new Set(['==', '!=', '<', '>', '<=', '>=']);
const arithmetic = new Set(['+', '-', '*', '/', '%', '&', '|', '^', '<<', '>>']);
const strip = tokens => {
  let t = tokens;
  while (t.length >= 2 && t[0].value === '(' && skipGroup(t, 0) === t.length) t = t.slice(1, -1);
  return t;
};
function topLevel(tokens, values) {
  const hits = [];
  let depth = 0;
  for (let i = 0; i < tokens.length; i++) {
    const v = tokens[i].kind === 'punct' ? tokens[i].value : '';
    if (openers[v]) depth += 1;
    else if (v === ')' || v === ']' || v === '}') depth -= 1;
    else if (depth === 0 && values.has(v)) hits.push(i);
  }
  return hits;
}
function callName(tokens) {
  if (tokens.length < 3 || tokens[0].kind !== 'ident') return null;
  let i = 1;
  if (tokens[i].value === '<') i = skipAngle(tokens, i);
  return tokens[i]?.value === '(' ? tokens[0].value : null;
}

// How bool-like a return expression is: 2 a bool value (comparison, `true`/`false`, logic, a
// predicate call), 1 only 0/1 constants, 0 an ordinary integer.
function shape(tokens, predicates) {
  const t = strip(tokens);
  if (t.length === 0) return 0;
  if (t.length === 1 && t[0].kind === 'ident' && (t[0].value === 'true' || t[0].value === 'false')) return 2;
  if (t.length === 1 && t[0].kind === 'number' && (t[0].value === '0' || t[0].value === '1')) return 1;
  if (t[0].kind === 'punct' && t[0].value === '!' && t.length > 1) return shape(t.slice(1), predicates) >= 1 ? 2 : 0;
  for (const ops of [new Set(['+']), new Set(['&&', '||'])]) {
    const arms = topLevel(t, ops);
    if (arms.length === 0) continue;
    let level = 2;
    let start = 0;
    for (const at of [...arms, t.length]) {
      const part = t.slice(start, at);
      start = at + 1;
      if (part.length === 0) continue;
      const partLevel = shape(part, predicates);
      if (partLevel === 0) return 0;
      level = Math.min(level, partLevel);
    }
    return level;
  }
  if (topLevel(t, comparisons).length > 0) return 2;
  const call = callName(t);
  if (call && predicates.has(call)) return 2;
  return 0;
}

const args = process.argv.slice(2);
const flags = new Set(args.filter(a => a.startsWith('--')));
const files = args.filter(a => !a.startsWith('--'));
const scope = files.length > 0 ? files.map(f => resolve(f)) : compilerSources;
const sources = scope.map(path => {
  const text = readFileSync(path, 'utf8');
  const tokens = tokenize(text);
  // `unsafe module runtime;` (runtime, os-*, darwin) is exempt from strict_bool: the checker only
  // runs when the parser is not in raw mode.
  const unsafe = /^\s*unsafe\s+module\s/.test(text);
  return { path, unsafe, tokens, functions: functions(tokens, path) };
});
const all = sources.flatMap(s => s.functions);
const u64 = all.filter(f => f.type === 'u64');

// Call graph: every identifier used as a call, with the context that consumes its value.
const definitions = new Map(); // name -> definition
for (const f of all) {
  if (!definitions.has(f.name)) definitions.set(f.name, []);
  definitions.get(f.name).push(f);
}
const callsByFunction = new Map(); // 'path::name' -> [{file, line, column, context, owner, local}]
const callsOf = f => callsByFunction.get(`${f.path}::${f.name}`) ?? [];
for (const source of sources) {
  const tokens = source.tokens;
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i];
    if (t.kind !== 'ident') continue;
    let j = i + 1;
    if (tokens[j]?.value === '<') j = skipAngle(tokens, j);
    if (tokens[j]?.value !== '(') continue;
    if (tokens[i - 1]?.value === 'fn') continue;
    const after = skipGroup(tokens, j);
    // `run()` / `host::exit(n)` / `x.push(v)`: the value's consumer is the token before the whole
    // callee path, not before its last segment.
    let base = i;
    while ((tokens[base - 1]?.value === '::' || tokens[base - 1]?.value === '.') && tokens[base - 2]?.kind === 'ident') base -= 2;
    const owner = source.functions.find(f => f.start < i && i < f.end) ?? null;
    const prev = tokens[base - 1];
    const next = tokens[after];
    const after2 = tokens[after + 1];
    const conditional = ['if', 'while'].includes(prev?.value) && next?.value === '{';
    let context = 'value';
    let local = null;
    let op = null;
    // The token before the callee path says more than the `;` after the call: `status = f(...);`
    // is an assignment, not a statement.
    if (prev?.value === 'return') context = 'return';
    else if (prev?.value === ':=' || prev?.value === '=') {
      // `x := f(...)` is a local; `r.field = f(...)` lands in a declared record field.
      context = tokens[base - 3]?.value === '.' ? 'field' : 'assign';
      local = tokens[base - 2]?.value ?? null;
    } else if (comparisons.has(prev?.value) && tokens[base - 2]?.kind === 'number') context = 'compare';
    else if (comparisons.has(next?.value) && after2?.kind === 'number') context = 'compare';
    else if (conditional) context = 'condition';
    else if (['!', '&&', '||', '&', '|', '^'].includes(prev?.value)) context = 'condition';
    else if (['&&', '||', '&', '|', '^'].includes(next?.value)) context = 'condition';
    else if (next?.value === ';') context = 'statement';
    else if (arithmetic.has(prev?.value)) { context = 'arithmetic'; op = prev.value; }
    else if (arithmetic.has(next?.value)) { context = 'arithmetic'; op = next.value; }
    // Same-file definitions win: `same` exists in native and optimize, and each module's own
    // helper is the callee.
    const key = `${definitions.get(t.value)?.find(d => d.path === source.path)?.path ?? definitions.get(t.value)?.[0]?.path}::${t.value}`;
    if (!callsByFunction.has(key)) callsByFunction.set(key, []);
    callsByFunction.get(key).push({ file: source.path, line: t.line, column: t.column, context, op, owner, local, source });
  }
}

// A local that receives the value and is later compared with a number (or counted) makes the
// result an integer: `mut status = compile(...); if status == 0`.
function localUsedAsCondition(call) {
  if (!call.local || !call.owner || call.context !== 'assign') return false;
  const body = call.owner.body;
  for (let i = 0; i < body.length; i++) {
    if (body[i].kind !== 'ident' || body[i].value !== call.local) continue;
    const after = body[i + 1];
    // A bare truth test (`if x`, `x && y`, `!x`), not `if x == 0`.
    if (body[i - 1]?.kind === 'ident' && ['if', 'while'].includes(body[i - 1].value)) {
      if (after?.value === '{' || ['&&', '||', '&', '|'].includes(after?.value)) return true;
    }
    if (['&&', '||', '!', '&', '|', '^'].includes(body[i - 1]?.value)) return true;
    if (['&&', '||', '&', '|', '^'].includes(after?.value)) return true;
  }
  return false;
}
function localUsedAsNumber(call) {
  if (!call.local || !call.owner || call.context !== 'assign') return false;
  const body = call.owner.body;
  for (let i = 0; i < body.length; i++) {
    if (body[i].kind !== 'ident' || body[i].value !== call.local) continue;
    const after = body[i + 1];
    const after2 = body[i + 2];
    if (after?.kind === 'punct' && comparisons.has(after.value) && after2?.kind === 'number') return true;
    if (after?.kind === 'punct' && arithmetic.has(after.value)) return true;
    if (body[i - 1]?.kind === 'punct' && arithmetic.has(body[i - 1].value)) return true;
  }
  return false;
}

// How a value is consumed. A condition (`if f(...)`, `&&`, `!`, `while`, or a local that is then
// tested) says the function is a predicate; `mut status = f(...)` followed by `status == 0`, or
// threading the value into main's exit code, says it is an integer.
const key = f => `${f.path}::${f.name}`;
const hasCondition = calls => calls.some(c => c.context === 'condition' || localUsedAsCondition(c));
const integerCalls = calls => calls.filter(c => localUsedAsNumber(c) || ['statement', 'field', 'compare'].includes(c.context));

// The exit-status family: main's result is the process status, and a value returned straight
// through (`return handler(...)`) inherits that role.
const status = new Set(all.filter(f => f.name === 'main').map(key));
for (let changed = true; changed;) {
  changed = false;
  for (const f of u64) {
    if (status.has(key(f))) continue;
    const calls = callsOf(f);
    const integer = calls.some(c => localUsedAsNumber(c) || c.context === 'field') && !hasCondition(calls);
    const threaded = calls.length > 0 && calls.every(c => c.context === 'return' && c.owner && status.has(key(c.owner)));
    if (integer || threaded) {
      status.add(key(f));
      changed = true;
    }
  }
}

// Fixpoint: a predicate may return the result of another predicate. A function that only ever
// returns 0/1 counts once a caller tests it as a condition (`fn overlaps` returns the sum of two
// such helpers); until then it is indistinguishable from a routine spelled `return 0`.
const predicates = new Set();
for (let changed = true; changed;) {
  changed = false;
  for (const f of u64) {
    if (predicates.has(f.name)) continue;
    const rets = returns(f.body);
    if (rets.length === 0) continue;
    const levels = rets.map(r => shape(r, predicates));
    if (levels.some(l => l === 0)) continue;
    if (levels.some(l => l === 2) || hasCondition(callsOf(f))) {
      predicates.add(f.name);
      changed = true;
    }
  }
}

const report = [];
for (const f of u64) {
  if (sources.find(src => src.path === f.path)?.unsafe) continue; // exempt module: not part of the migration
  const rets = returns(f.body);
  if (rets.length === 0) continue;
  const levels = rets.map(r => shape(r, predicates));
  if (levels.some(l => l === 0)) continue;
  const calls = callsOf(f);
  const literalOnly = levels.every(l => l === 1);
  const tested = calls.some(c => c.context === 'compare');
  const verdict = status.has(key(f)) && !hasCondition(calls) ? 'status'
    : literalOnly && !hasCondition(calls) && !tested ? 'void'
    : 'predicate';
  const contexts = {};
  for (const c of calls) contexts[c.context] = (contexts[c.context] ?? 0) + 1;
  const operators = {};
  for (const c of calls) if (c.op) operators[c.op] = (operators[c.op] ?? 0) + 1;
  report.push({
    name: f.name, file: relative(root, f.path), line: f.line, column: f.column, verdict, contexts, operators,
    literal: literalOnly,
    integerSites: integerCalls(calls).map(c => `${relative(root, c.file)}:${c.line}`),
    compared: calls.filter(c => c.context === 'compare').length,
    returns: rets.length,
    callCount: calls.length,
    calls: calls.map(c => `${relative(root, c.file)}:${c.line}:${c.column} (${c.context})`),
  });
}

const bucket = flags.has('--status') ? 'status'
  : flags.has('--void') ? 'void'
  : flags.has('--integer-sites') ? 'integer-sites'
  : 'predicate';

if (flags.has('--json')) {
  console.log(JSON.stringify({ functions: report }, null, 2));
} else if (bucket === 'integer-sites') {
  for (const r of report.filter(r => r.verdict === 'predicate' && r.integerSites.length > 0)) {
    console.log(`${r.file}:${r.line}  ${r.name}  ${r.integerSites.length} integer site(s) of ${r.callCount}: ${r.integerSites.slice(0, 6).join(' ')}`);
  }
} else {
  let file = null;
  for (const r of report.filter(x => x.verdict === bucket)) {
    if (!flags.has('--calls') && r.file !== file) { file = r.file; console.log(`\n## ${file}`); }
    const at = flags.has('--calls') ? `${r.file}:${r.line}:${r.column}` : `${r.line}`;
    console.log(`${at}  ${r.name}${r.literal ? ' [0/1 only]' : ''}  (${r.callCount} call${r.callCount === 1 ? '' : 's'}${r.integerSites.length ? `, ${r.integerSites.length} integer site` : ''}${r.compared ? `, ${r.compared} compared with a number` : ''})`);
    if (flags.has('--calls')) for (const c of r.calls) console.log(`      ${c}`);
  }
}
const count = v => report.filter(r => r.verdict === v).length;
console.error(`${report.length} bool-shaped u64 functions: ${count('predicate')} predicate, ${count('status')} status, ${count('void')} void; ${u64.length} u64 functions in scope`);
