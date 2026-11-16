#!/usr/bin/env bun
// The editor grammar, checked the way an editor uses it.
//
//   bun tools/grammar-test.mjs
//
// Three properties, in order of how badly they break a user:
//
//  1. `editors/vscode/syntaxes/grail.tmLanguage.json` parses and declares the language it must
//     (`source.grail`, `.grl`).
//  2. every `match` regex in it compiles in JavaScript. The grammar is written with Oniguruma's
//     and JavaScript's common subset (no subexpression calls, no recursion, no \G), so the same
//     text compiles in both and an editor that uses the JS engine highlights what VS Code does.
//  3. fixture lines - nearly all of them verbatim lines from this tree - tokenize to the scopes
//     the grammar claims: keywords, types, a function name, a numeric literal with a suffix, a
//     string and the escape inside it, a line comment, `@`-forms, lifetimes, closures, operators.
//
// The tokenizer is the real TextMate engine (`vscode-textmate` + `vscode-oniguruma`) when those
// packages are installed, and otherwise a small self-contained matcher over the grammar's own
// top-level patterns, applied the way TextMate does: at each position the rule whose match starts
// earliest wins, ties going to the rule listed first, and capture groups that carry `patterns` are
// tokenized again inside their span. Either engine feeds the same assertions.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const grammarPath = join(root, 'editors/vscode/syntaxes/grail.tmLanguage.json');

let checks = 0;
function ok(condition, message, detail = '') {
  assert.ok(condition, detail ? `${message}: ${detail}` : message);
  checks += 1;
}

// ---------------------------------------------------------------------------------------------
// 1. The grammar is a grammar for Grail.
// ---------------------------------------------------------------------------------------------

const text = readFileSync(grammarPath, 'utf8');
let grammar;
try {
  grammar = JSON.parse(text);
} catch (error) {
  assert.fail(`${relative(root, grammarPath)} is not valid JSON: ${error.message}`);
}
ok(grammar.scopeName === 'source.grail', 'the grammar declares scopeName source.grail', String(grammar.scopeName));
ok(Array.isArray(grammar.fileTypes) && grammar.fileTypes.includes('grl'), 'the grammar claims the .grl extension', JSON.stringify(grammar.fileTypes));
ok(Array.isArray(grammar.patterns) && grammar.patterns.length > 0, 'the grammar has top-level patterns');
ok(grammar.repository && typeof grammar.repository === 'object', 'the grammar has a repository');

// ---------------------------------------------------------------------------------------------
// 2. Every regex compiles in JavaScript, and near enough every scope is a standard one.
// ---------------------------------------------------------------------------------------------

const regexes = [];
const scopes = new Set();
const STANDARD = /^(comment|constant|entity|invalid|keyword|markup|meta|punctuation|source|storage|string|support|variable|text)\./;

function inspect(node) {
  if (Array.isArray(node)) {
    for (const entry of node) inspect(entry);
    return;
  }
  if (!node || typeof node !== 'object') return;
  if (typeof node.match === 'string') {
    let regex;
    try {
      regex = new RegExp(node.match);
    } catch (error) {
      assert.fail(`regex does not compile in JavaScript: /${node.match}/ (${error.message})`);
    }
    regexes.push({ source: node.match, regex });
  }
  if (typeof node.name === 'string') {
    for (const scope of node.name.split(/\s+/)) if (scope) scopes.add(scope);
  }
  for (const value of Object.values(node)) inspect(value);
}

inspect(grammar.patterns);
inspect(grammar.repository);
ok(regexes.length >= 40, 'the grammar has a real pattern set', `${regexes.length} regexes`);
for (const scope of scopes) {
  ok(STANDARD.test(scope) && scope.endsWith('.grail'), `scope follows TextMate conventions: ${scope}`, scope);
}

// ---------------------------------------------------------------------------------------------
// 3. Tokenize fixture lines.
// ---------------------------------------------------------------------------------------------

// A regex compiled for scanning: `g` to start at an offset, `d` for capture positions.
function compile(source) {
  return new RegExp(source, 'gd');
}

const flattened = new WeakMap();

function flatten(patterns, repository, depth = 0) {
  if (flattened.has(patterns)) return flattened.get(patterns);
  if (depth > 8) assert.fail('the grammar includes itself in a cycle');
  const rules = [];
  for (const rule of patterns) {
    if (rule.include) {
      const key = rule.include.replace(/^#/, '');
      const target = repository[key];
      if (!target) assert.fail(`the grammar includes an unknown group: ${rule.include}`);
      rules.push(...flatten(target.patterns ?? [target], repository, depth + 1));
      continue;
    }
    if (typeof rule.match !== 'string') {
      assert.fail(`a rule is neither a match nor an include: ${JSON.stringify(rule).slice(0, 120)}`);
    }
    rules.push({ ...rule, compiled: compile(rule.match) });
  }
  flattened.set(patterns, rules);
  return rules;
}

const topLevel = flatten(grammar.patterns, grammar.repository);

// The self-contained matcher: tokens are `{ start, end, scopes }`, pushed outermost first, so the
// innermost scope at an offset is the narrowest token covering it (the last one on a tie).
function walk(line, start, end, rules, scopes_, out, depth) {
  if (depth > 8) return;
  let position = start;
  while (position < end) {
    let best = null;
    for (const rule of rules) {
      rule.compiled.lastIndex = position;
      const match = rule.compiled.exec(line);
      if (!match || match[0].length === 0 || match.index >= end) continue;
      if (!best || match.index < best.match.index) best = { rule, match };
    }
    if (!best) return;
    const from = best.match.index;
    const to = from + best.match[0].length;
    const rule = best.rule;
    const outer = rule.name ? [...scopes_, rule.name] : scopes_;
    if (rule.name) out.push({ start: from, end: to, scopes: outer });
    for (const key of Object.keys(rule.captures ?? {})) {
      const index = Number(key);
      const range = best.match.indices?.[index];
      if (!range) continue;
      const capture = rule.captures[key];
      const inner = capture.name ? [...outer, capture.name] : outer;
      if (capture.name) out.push({ start: range[0], end: range[1], scopes: inner });
      if (capture.patterns) walk(line, range[0], range[1], flatten(capture.patterns, grammar.repository), inner, out, depth + 1);
    }
    position = to;
  }
}

function selfContained() {
  return {
    name: 'self-contained matcher over the grammar\'s own patterns',
    line(line) {
      const tokens = [];
      walk(line, 0, line.length, topLevel, [], tokens, 0);
      return tokens;
    },
  };
}

// The real engine, when the packages are installed: `bun add vscode-textmate vscode-oniguruma`.
async function textMate() {
  let vsctm;
  let oniguruma;
  try {
    vsctm = await import('vscode-textmate');
    oniguruma = await import('vscode-oniguruma');
  } catch {
    return null;
  }
  const require = createRequire(import.meta.url);
  let wasm;
  try {
    wasm = require.resolve('vscode-oniguruma/release/onig.wasm');
  } catch {
    wasm = join(dirname(require.resolve('vscode-oniguruma')), 'release/onig.wasm');
  }
  const bytes = readFileSync(wasm);
  await oniguruma.loadWASM(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
  const registry = new vsctm.Registry({
    onigLib: Promise.resolve({
      createOnigScanner: sources => new oniguruma.OnigScanner(sources),
      createOnigString: value => new oniguruma.OnigString(value),
    }),
    loadGrammar: async () => vsctm.parseRawGrammar(text, grammarPath),
  });
  const loaded = await registry.loadGrammar('source.grail');
  assert.ok(loaded, 'vscode-textmate loads the grammar');
  return {
    name: 'vscode-textmate + vscode-oniguruma',
    line(line) {
      // Tokenize a whole file's worth of state away by asking for a fresh line: every fixture is
      // independent, exactly as a highlight on its own would be.
      const result = loaded.tokenizeLine(line, null);
      return result.tokens.map(token => ({ start: token.startIndex, end: token.endIndex, scopes: token.scopes }));
    },
  };
}

// Both engines when both exist: the matcher keeps the test honest on a machine without the
// packages, and the real engine is what VS Code itself runs, so the same expectations hold there.
const engines = [selfContained()];
const real = await textMate();
if (real) engines.push(real);

function scopesAt(tokens, offset) {
  let best = null;
  for (const token of tokens) {
    if (offset < token.start || offset >= token.end) continue;
    if (!best || token.end - token.start <= best.end - best.start) best = token;
  }
  return best ? best.scopes : [];
}

function offsetOf(line, needle, nth) {
  let index = -1;
  for (let found = 0; found < nth; found += 1) {
    index = line.indexOf(needle, index + 1);
    if (index < 0) return -1;
  }
  return index;
}

// `where` is the file the line is taken from, or what the line exercises when it is synthetic.
// Each expectation is [needle, expected scope, occurrence?]; `absent` is [[needle, scope]] and
// must not appear, which is how a comment that mentions `fn` proves it stays a comment.
const fixtures = [
  {
    where: 'lib/iter.grl:31',
    line: 'pub fn upto(lo: u64, hi: u64) -> Iter<u64> {',
    expect: [
      ['pub', 'storage.modifier.grail'],
      ['fn', 'storage.type.function.grail'],
      ['upto', 'entity.name.function.grail'],
      ['u64', 'support.type.grail'],
    ],
    absent: [],
  },
  {
    where: 'a declaration with a generic name (synthetic)',
    line: 'fn add(a: u64, b: u64) -> u64 {',
    expect: [
      ['fn', 'storage.type.function.grail'],
      ['add', 'entity.name.function.grail'],
      ['u64', 'support.type.grail', 3],
      ['->', 'keyword.operator.grail'],
      ['{', 'punctuation.section.block.begin.grail'],
    ],
  },
  {
    where: 'lib/iter.grl:12',
    line: 'pub struct Indexed<T> { index: u64, value: T }',
    expect: [
      ['struct', 'storage.type.grail'],
      ['Indexed', 'entity.name.type.grail'],
      ['T', 'entity.name.type.grail', 2],
    ],
  },
  {
    where: 'book/chapters/lifetimes.md',
    line: 'struct Cursor<a> { source: &a [u8] }',
    expect: [
      ['Cursor', 'entity.name.type.grail'],
      ['a', 'storage.modifier.lifetime.grail', 2],
      ['u8', 'support.type.grail'],
    ],
  },
  {
    where: 'tools/lsp/main.grl:1206',
    line: '    put(&mut out, view("\\"}}"));',
    expect: [
      ['}}', 'string.quoted.double.grail'],
      ['\\"', 'constant.character.escape.grail'],
      ['view', 'entity.name.function.grail'],
      ['&', 'keyword.operator.grail'],
      ['mut', 'storage.modifier.grail'],
    ],
  },
  {
    where: 'a line comment that mentions code (synthetic)',
    line: '// fn add is retired: 0xFF',
    expect: [
      ['fn add', 'comment.line.double-slash.grail'],
      ['0xFF', 'comment.line.double-slash.grail'],
    ],
    absent: [
      ['fn', 'storage.type.function.grail'],
      ['0xFF', 'constant.numeric.grail'],
    ],
  },
  {
    where: 'lib/rhi_vulkan.grl lines (abundance/src/rhi_vulkan.grl:71)',
    line: 'pub extern "C" lib "vulkan" fn vkEnumerateInstanceVersion(version: Uint32Out) -> i32;',
    expect: [
      ['extern', 'storage.type.grail'],
      ['"C"', 'string.quoted.double.grail'],
      ['lib', 'keyword.other.lib.grail'],
      ['"vulkan"', 'string.quoted.double.grail'],
      ['vkEnumerateInstanceVersion', 'entity.name.function.grail'],
      ['Uint32Out', 'entity.name.type.grail'],
      [';', 'punctuation.terminator.statement.grail'],
    ],
  },
  {
    where: 'abundance/src/rhi_vulkan.grl:76',
    line: 'pub const extension_bytes: u64 = 260;',
    expect: [
      ['const', 'storage.type.grail'],
      ['extension_bytes', 'variable.other.constant.grail'],
      ['260', 'constant.numeric.grail'],
      [':', 'punctuation.separator.colon.grail'],
    ],
  },
  {
    where: 'literal forms from the tree (0x3FF in rhi_vulkan.grl, 65533u32 in strings.grl)',
    line: 'const MASK: u64 = 0x3FF; small := 65533u32; ratio := 3.0e38;',
    expect: [
      ['MASK', 'variable.other.constant.grail'],
      ['0x3FF', 'constant.numeric.grail'],
      ['65533u32', 'constant.numeric.grail'],
      ['3.0e38', 'constant.numeric.grail'],
    ],
  },
  {
    where: 'book/examples/comptime.grl:18',
    line: '@if target.os == .windows {',
    expect: [
      ['@if', 'meta.attribute.grail'],
      ['@', 'punctuation.definition.attribute.grail'],
      ['==', 'keyword.operator.grail'],
      ['{', 'punctuation.section.block.begin.grail'],
    ],
  },
  {
    where: 'book/examples/value-generics.grl:3',
    line: 'fn rotl<@k: u64>(x: u64) -> u64 {',
    expect: [
      ['@k', 'meta.attribute.grail'],
      ['u64', 'support.type.grail', 1],
      ['fn', 'storage.type.function.grail'],
    ],
  },
  {
    where: 'tests/comptime/embed.grl:2',
    line: '    bytes := @embed("greeting.txt");',
    expect: [
      ['@embed', 'meta.attribute.grail'],
      ['greeting.txt', 'string.quoted.double.grail'],
      [':=', 'keyword.operator.grail'],
    ],
  },
  {
    where: 'lib/hash.grl:6',
    line: 'pub interface Hash{fn hash<a,b>(value:(&a Self),state:(&b mut Hasher));}',
    expect: [
      ['interface', 'storage.type.grail'],
      ['Hash', 'entity.name.type.grail'],
      ['hash', 'entity.name.function.grail', 1],
      ['Self', 'support.type.grail'],
      ['Hasher', 'entity.name.type.grail'],
      ['&a', 'keyword.operator.grail'],
      ['a Self', 'storage.modifier.lifetime.grail'],
    ],
  },
  {
    where: 'lib/iter.grl:89',
    line: '        while let Some(x) = src.next() {',
    expect: [
      ['while', 'keyword.control.grail'],
      ['let', 'keyword.control.grail'],
      ['Some', 'constant.language.grail'],
      ['next', 'entity.name.function.grail'],
      ['.', 'punctuation.separator.period.grail'],
    ],
  },
  {
    where: 'book/chapters/methods.md (a range loop)',
    line: '    for day in 1..4 {',
    expect: [
      ['for', 'keyword.control.grail'],
      ['in', 'keyword.control.grail'],
      ['..', 'keyword.operator.grail'],
      ['1', 'constant.numeric.grail'],
      ['4', 'constant.numeric.grail'],
    ],
  },
  {
    where: 'lib/iter.grl:36 (a closure with no parameters)',
    line: '        return Iter { step: || -> u64? {',
    expect: [
      ['||', 'punctuation.section.closure.begin.grail'],
      ['?', 'keyword.operator.grail'],
      ['u64', 'support.type.grail'],
    ],
  },
  {
    where: 'book/chapters/closures.md (a closure with annotated parameters)',
    line: 'order.sort_by(|x: &u64, y: &u64| -> bool {',
    expect: [
      ['|x:', 'punctuation.section.closure.begin.grail'],
      ['x', 'variable.parameter.grail'],
      ['u64', 'support.type.grail'],
      ['bool', 'support.type.grail'],
      ['y:', 'variable.parameter.grail'],
    ],
  },
  {
    where: 'lib/json.grl:57 (a result type)',
    line: 'pub fn parse<a>(text: &a [u8]) -> Value |? Error {',
    expect: [
      ['|?', 'keyword.operator.grail'],
      ['Value', 'entity.name.type.grail'],
      ['Error', 'entity.name.type.grail'],
      ['a>(', 'storage.modifier.lifetime.grail'],
    ],
  },
  {
    where: 'book/examples/errors.grl:12',
    line: '    value := parse(flag)?; // Returns ParseError early; success continues as u64.',
    expect: [
      ['parse', 'entity.name.function.grail'],
      ['?', 'keyword.operator.grail'],
      ['// Returns', 'comment.line.double-slash.grail'],
    ],
    absent: [['parse(flag)', 'comment.line.double-slash.grail']],
  },
];

for (const engine of engines) {
  console.log(`\nengine: ${engine.name}`);
  for (const fixture of fixtures) {
    const tokens = engine.line(fixture.line);
    for (const [needle, scope, nth] of fixture.expect) {
      const at = offsetOf(fixture.line, needle, nth ?? 1);
      ok(at >= 0, `${fixture.where}: the fixture line contains ${JSON.stringify(needle)}`, fixture.line);
      const found = scopesAt(tokens, at);
      ok(found.includes(scope), `${fixture.where}: ${JSON.stringify(needle)} is ${scope}`, `found ${JSON.stringify(found)}`);
    }
    for (const [needle, scope] of fixture.absent ?? []) {
      const at = offsetOf(fixture.line, needle, 1);
      ok(at >= 0, `${fixture.where}: the fixture line contains ${JSON.stringify(needle)}`, fixture.line);
      const found = scopesAt(tokens, at);
      ok(!found.includes(scope), `${fixture.where}: ${JSON.stringify(needle)} is not ${scope}`, `found ${JSON.stringify(found)}`);
    }
    console.log(`  ok  ${fixture.line.trim().slice(0, 96)}`);
  }
}

console.log(`\ngrammar: ${relative(root, grammarPath)} (${grammar.patterns.length} top-level patterns, ${Object.keys(grammar.repository).length} repository group)`);
console.log(`regexes: ${regexes.length} compile in JavaScript; ${scopes.size} scopes, all TextMate conventions`);
console.log(`engines: ${engines.map(engine => engine.name).join('; ')}`);
console.log(`fixtures: ${fixtures.length} lines x ${engines.length} engine(s), ${checks} checks passed`);
