// The Grail language server on stdio: handshake, compiler-sourced diagnostics that clear
// when the buffer is fixed, definition, and malformed input that must be answered with a
// JSON-RPC error instead of taking the server down.
//
// Hermetic: the compiler and the server are built from this tree, the session talks to the
// real server binary over pipes, and every buffer lives in a virtual file:// uri.
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';
import { mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { buildCompiler, root } from './native.mjs';
import { buildServer } from './lsp.mjs';

const work = join(root, '.work/lsp-tests');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });

const compiler = buildCompiler();
const server = buildServer({ directory: work, compiler });

let checks = 0;
function ok(condition, message) {
  assert.ok(condition, message);
  checks += 1;
}
function equal(actual, expected, message) {
  assert.deepEqual(actual, expected, message);
  checks += 1;
}

function frame(message) {
  const json = JSON.stringify(message);
  return `Content-Length: ${Buffer.byteLength(json, 'utf8')}\r\n\r\n${json}`;
}

class Client {
  // Defaults to the server binary built from this tree. `command`/`args`/`env` exist so the
  // documented entry point (`bun tools/lsp.mjs`) can be driven the same way.
  constructor({ command = server, args = [], env = { GRAIL_LSP_COMPILER: compiler, GRAIL_HOME: root } } = {}) {
    this.messages = [];
    this.waiters = [];
    this.buffer = Buffer.alloc(0);
    this.stderr = '';
    this.exitCode = undefined;
    this.child = spawn(command, args, {
      cwd: root,
      env: { ...process.env, ...env },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    this.child.stdout.on('data', chunk => this.receive(chunk));
    this.child.stderr.on('data', chunk => { this.stderr += chunk.toString(); });
    this.child.on('exit', code => {
      this.exitCode = code;
      for (const waiter of this.waiters.splice(0)) {
        clearTimeout(waiter.timer);
        waiter.reject(new Error(`server exited (${code}) while waiting for ${waiter.label}\n${this.stderr}`));
      }
    });
  }

  receive(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    for (;;) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd < 0) return;
      const header = this.buffer.subarray(0, headerEnd).toString('ascii');
      const match = /content-length:\s*(\d+)/i.exec(header);
      if (!match) throw new Error(`server sent a frame without Content-Length: ${JSON.stringify(header)}`);
      const start = headerEnd + 4;
      const length = Number(match[1]);
      if (this.buffer.length < start + length) return;
      const payload = this.buffer.subarray(start, start + length).toString('utf8');
      this.buffer = this.buffer.subarray(start + length);
      this.dispatch(JSON.parse(payload));
    }
  }

  dispatch(message) {
    const index = this.waiters.findIndex(waiter => waiter.predicate(message));
    if (index >= 0) {
      const [waiter] = this.waiters.splice(index, 1);
      clearTimeout(waiter.timer);
      waiter.resolve(message);
      return;
    }
    this.messages.push(message);
  }

  waitFor(predicate, label, timeout = 120_000) {
    const index = this.messages.findIndex(predicate);
    if (index >= 0) return Promise.resolve(this.messages.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const waiter = { predicate, label, resolve, reject, timer: null };
      waiter.timer = setTimeout(() => {
        this.waiters = this.waiters.filter(entry => entry !== waiter);
        reject(new Error(`timeout waiting for ${label}\nstderr:\n${this.stderr}\nmessages: ${JSON.stringify(this.messages)}`));
      }, timeout);
      this.waiters.push(waiter);
    });
  }

  write(bytes) {
    this.child.stdin.write(bytes);
  }

  send(message) {
    this.write(frame(message));
  }

  async request(id, method, params) {
    this.send({ jsonrpc: '2.0', id, method, params });
    return this.waitFor(message => message.id === id, `${method} response`);
  }

  notify(method, params) {
    this.send({ jsonrpc: '2.0', method, params });
  }

  diagnostics(uri) {
    return this.waitFor(
      message => message.method === 'textDocument/publishDiagnostics' && message.params.uri === uri,
      `diagnostics for ${uri}`,
    );
  }

  async open(uri, version, text) {
    this.notify('textDocument/didOpen', { textDocument: { uri, languageId: 'grail', version, text } });
    return this.diagnostics(uri);
  }

  async change(uri, version, text) {
    this.notify('textDocument/didChange', { textDocument: { uri, version }, contentChanges: [{ text }] });
    return this.diagnostics(uri);
  }

  async initialize(id = 1) {
    const response = await this.request(id, 'initialize', { processId: null, rootUri: null, capabilities: {} });
    this.notify('initialized', {});
    return response;
  }

  async stop() {
    if (this.exitCode !== undefined) return this.exitCode;
    this.send({ jsonrpc: '2.0', id: 9999, method: 'shutdown', params: null });
    this.send({ jsonrpc: '2.0', method: 'exit', params: null });
    return new Promise(resolve => {
      const timer = setTimeout(() => { this.child.kill('SIGKILL'); resolve(this.exitCode); }, 30_000);
      this.child.once('exit', code => { clearTimeout(timer); resolve(code); });
    });
  }
}


// A position from a byte index in a fixture: lines are split, and the character is the
// number of UTF-16 code units - exactly what LSP asks for and what JS strings count.
function pointAt(text, index) {
  const before = text.slice(0, index);
  const lineStart = before.lastIndexOf('\n') + 1;
  return { line: before.split('\n').length - 1, character: before.length - lineStart };
}
// The position `inside` characters into the first occurrence of `needle`.
function pointIn(text, needle, inside = 0) {
  const at = text.indexOf(needle);
  assert.ok(at >= 0, `fixture contains ${JSON.stringify(needle)}`);
  return pointAt(text, at + inside);
}
// The range of the identifier `needle` starts with.
function rangeIn(text, needle, length) {
  const at = text.indexOf(needle);
  assert.ok(at >= 0, `fixture contains ${JSON.stringify(needle)}`);
  return { start: pointAt(text, at), end: pointAt(text, at + length) };
}
// Request ids for the cases below: each request must be distinguishable so its own
// response can be awaited.
let nextId = (() => {
  let id = 1000;
  return () => (id += 1);
})();
function sliceRange(text, range) {
  const line = text.split('\n')[range.start.line];
  return line.slice(range.start.character, range.end.character);
}

const GOOD = 'fn main() {\n    println("hello");\n}\n';
// A call to something the file never declares: the compiler's own `unknown function`.
const UNKNOWN_CALL = 'fn main() {\n    missing(1);\n}\n';
// A wrong argument count on line 5 (1-based, the closing paren is column 19).
const WRONG_ARITY = 'fn add(a: u64, b: u64) -> u64 {\n    return a + b;\n}\nfn main() {\n    println(add(1));\n}\n';

const URI = 'file:///virtual/session.grl';

// --- 1. Handshake, and what it honestly advertises -------------------------------
{
  const client = new Client();
  const init = await client.initialize();
  const capabilities = init.result.capabilities;
  equal(capabilities.textDocumentSync, { openClose: true, change: 1 }, 'full-text sync is advertised');
  equal(capabilities.definitionProvider, true, 'definition is advertised');
  equal(init.result.serverInfo.name, 'grail-lsp', 'serverInfo name');
  ok(typeof init.result.serverInfo.version === 'string' && init.result.serverInfo.version.length > 0, 'serverInfo version');
  // What it does implement is advertised with the shape the specification gives it.
  equal(capabilities.hoverProvider, true, 'hover is advertised');
  equal(capabilities.completionProvider, { triggerCharacters: ['.', ':'], resolveProvider: false },
    'completion is advertised with its trigger characters');
  equal(capabilities.renameProvider, { prepareProvider: true }, 'rename is advertised with prepareRename');
  // Nothing is claimed that the server does not implement.
  for (const absent of ['referencesProvider', 'documentSymbolProvider', 'documentFormattingProvider',
    'documentRangeFormattingProvider', 'signatureHelpProvider', 'codeActionProvider',
    'semanticTokensProvider', 'diagnosticProvider', 'workspaceSymbolProvider', 'inlayHintProvider']) {
    ok(!(absent in capabilities), `${absent} is not advertised`);
  }
  equal(await client.stop(), 0, 'exit after shutdown is 0');
  equal(client.stderr, '', 'the server writes nothing to stderr');
}

// --- 2. Real diagnostics, cleared by a fix, re-derived at a new line --------------
{
  const client = new Client();
  await client.initialize();

  const clean = await client.open(URI, 1, GOOD);
  equal(clean.params.diagnostics, [], 'a clean buffer publishes no diagnostics');

  const bad = await client.open(URI, 2, UNKNOWN_CALL);
  equal(bad.params.version, 2, 'diagnostics carry the document version');
  equal(bad.params.diagnostics.length, 1, 'the compiler reports one error');
  const [first] = bad.params.diagnostics;
  // The compiler prints `error[E0002]: ...`, a ` --> file:line:column` line and an excerpt
  // whose carets cover the offending token, so the published range is that whole token:
  // `missing` starts at byte 4 of the line (character 4) and is 7 wide.
  equal(first.range.start, { line: 1, character: 4 }, 'the range starts where the compiler points, in UTF-16');
  equal(first.range.end, { line: 1, character: 11 }, 'the range covers the token the carets underline');
  equal(first.severity, 1, 'severity is Error');
  equal(first.source, 'grail', 'source is grail');
  equal(first.code, 'compiler', 'code names the compiler');
  ok(first.message.includes('unknown function'), `message is the compiler's: ${first.message}`);

  // Fixing the buffer clears the diagnostic, which is what removes the squiggle.
  const fixed = await client.change(URI, 3, GOOD);
  equal(fixed.params.version, 3, 'the clearing publication carries the new version');
  equal(fixed.params.diagnostics, [], 'a fixed buffer publishes an empty list');

  // A different error on a different line, to prove the mapping is not fixed at line 1.
  const arity = await client.change(URI, 4, WRONG_ARITY);
  equal(arity.params.diagnostics.length, 1, 'the arity error is reported');
  equal(arity.params.diagnostics[0].range.start.line, 4, 'line 5 (1-based) is reported as line 4');
  ok(arity.params.diagnostics[0].message.includes('leaves `b` without an argument'), `arity message: ${arity.params.diagnostics[0].message}`);

  equal(await client.stop(), 0, 'clean exit');
  equal(client.stderr, '', 'no stderr noise');
}

// --- 3. Malformed input is answered, and the server survives it --------------------
{
  const client = new Client();
  await client.initialize();

  // A header block with no Content-Length at all.
  client.write('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n');
  const noHeader = await client.waitFor(message => message.error?.code === -32700, 'framing error');
  equal(noHeader.id, null, 'a framing error has a null id');
  ok(noHeader.error.message.includes('Content-Length'), `framing message: ${noHeader.error.message}`);

  // A Content-Length that is not a number.
  client.write('Content-Length: twelve\r\n\r\n{}');
  const badLength = await client.waitFor(message => message.error?.code === -32700, 'length error');
  equal(badLength.id, null, 'a malformed length has a null id');

  // A well-framed body that is not JSON.
  const body = '{not json}';
  client.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
  const badJson = await client.waitFor(message => message.error?.code === -32700, 'parse error');
  equal(badJson.id, null, 'a parse error has a null id');
  ok(badJson.error.message.includes('parse'), `parse message: ${badJson.error.message}`);

  // JSON that is not a request: no method, no id. Ignored, and the session keeps working.
  client.write(frame({ jsonrpc: '2.0', result: null }));
  // Unknown methods are refused by name once the server is initialized.
  const unknown = await client.request(2, 'textDocument/semanticTokens/full', { textDocument: { uri: URI } });
  equal(unknown.error.code, -32601, 'an unknown method is refused with -32601');
  ok(unknown.error.message.includes('method not found'), `unknown method message: ${unknown.error.message}`);

  // The proofs above all came before this: the server is still serving.
  const after = await client.open(URI, 1, UNKNOWN_CALL);
  equal(after.params.diagnostics.length, 1, 'the session still produces diagnostics after malformed input');
  equal(await client.stop(), 0, 'clean exit after malformed input');
  equal(client.stderr, '', 'no stderr noise');
}

// --- 4. Requests before initialize, and a buffer closed mid-session ---------------
{
  const early = new Client();
  const refused = await early.request(1, 'textDocument/didOpen', {});
  equal(refused.error.code, -32002, 'a request before initialize is refused');
  await early.initialize(2);
  await early.open(URI, 1, UNKNOWN_CALL);
  early.notify('textDocument/didClose', { textDocument: { uri: URI } });
  const cleared = await early.diagnostics(URI);
  equal(cleared.params.diagnostics, [], 'closing a document clears its diagnostics');
  equal(await early.stop(), 0, 'clean exit');
}

// --- 5. Definition of a same-file function and of a local binding ----------------
{
  const client = new Client();
  await client.initialize();
  const DECLARATIONS = [
    'fn add(a: u64, b: u64) -> u64 {',
    '    sum := a + b;',
    '    return sum;',
    '}',
    'fn main() {',
    '    total := add(1, 2);',
    '    println(total);',
    '}',
    '',
  ].join('\n');
  const uri = 'file:///virtual/definition.grl';
  await client.open(uri, 1, DECLARATIONS);

  // `add` in the call on line 5 points at the `fn add` name on line 0.
  const call = await client.request(3, 'textDocument/definition', { textDocument: { uri }, position: { line: 5, character: 15 } });
  equal(call.result?.uri, uri, 'definition answers with the same document');
  equal(call.result?.range.start, { line: 0, character: 3 }, 'a call resolves to the function declaration');

  // `total` on line 6 points at the binding on line 5.
  const local = await client.request(4, 'textDocument/definition', { textDocument: { uri }, position: { line: 6, character: 13 } });
  equal(local.result?.range.start, { line: 5, character: 4 }, 'a local use resolves to its declaration');

  // `sum` inside add: the use on line 2 points at the binding on line 1.
  const inner = await client.request(5, 'textDocument/definition', { textDocument: { uri }, position: { line: 2, character: 12 } });
  equal(inner.result?.range.start, { line: 1, character: 4 }, 'a use before its own return resolves to the binding');

  // A parameter use resolves to the parameter.
  const parameter = await client.request(6, 'textDocument/definition', { textDocument: { uri }, position: { line: 1, character: 11 } });
  equal(parameter.result?.range.start, { line: 0, character: 7 }, 'a parameter use resolves to the parameter');

  // Nothing to point at: a name the file does not declare, and a position outside any name.
  const nowhere = await client.request(7, 'textDocument/definition', { textDocument: { uri }, position: { line: 6, character: 5 } });
  equal(nowhere.result, null, 'an undeclared name has no definition');
  const midWord = await client.request(8, 'textDocument/definition', { textDocument: { uri }, position: { line: 3, character: 0 } });
  equal(midWord.result, null, 'a position outside any name has no definition');

  equal(await client.stop(), 0, 'clean exit');
  equal(client.stderr, '', 'no stderr noise');
}

// --- 6. The documented entry point -----------------------------------------------
// `bun tools/lsp.mjs` must hand the server its stdio and the compiler it built, otherwise
// a fresh checkout would start a server that can only answer with an environment warning.
{
  const launcher = new Client({ command: process.execPath, args: [join(root, 'tools/lsp.mjs')], env: { GRAIL_HOME: root } });
  const init = await launcher.initialize();
  equal(init.result.capabilities.definitionProvider, true, 'the launcher starts the server');
  const uri = 'file:///virtual/launcher.grl';
  const diagnostics = await launcher.open(uri, 1, UNKNOWN_CALL);
  equal(diagnostics.params.diagnostics.length, 1, 'the launcher gives the server a compiler without configuration');
  ok(diagnostics.params.diagnostics[0].message.includes('unknown function'), 'the launcher session reports the compiler diagnostic');
  equal(await launcher.stop(), 0, 'the launcher session exits cleanly');
}

// --- 7. Hover: types, signatures, fields, literals, and nothing when unsure --------
{
  const client = new Client();
  await client.initialize();
  const HOVER = [
    'module hover;',
    '',
    '/// Adds two numbers.',
    'fn add(a: u64, b: u64) -> u64 {',
    '    return a + b;',
    '}',
    '',
    'struct Point {',
    '    x: u64,',
    '    y: u64',
    '}',
    '',
    'enum Word {',
    '    First,',
    '    Second(u64)',
    '}',
    '',
    'fn area(p: &Point) -> u64 {',
    '    return p.x;',
    '}',
    '',
    'fn main() {',
    '    p := Point { x: 1, y: 2 };',
    '    total := add(p.x, 3);',
    '    tag := "héllo 😀"; tail := 1;',
    '    println(tail);',
    '    w := Word::Second(4);',
    '    println(w);',
    '    ghost := absent;',
    '}',
    '',
  ].join('\n');
  const uri = 'file:///virtual/hover.grl';
  await client.open(uri, 1, HOVER);
  const hover = (position) => client.request(nextId(), 'textDocument/hover', { textDocument: { uri }, position });

  // A call: the signature, the doc comment, and the range of the callee's name.
  {
    const position = pointIn(HOVER, 'add(p.x, 3)', 1);
    const answer = await hover(position);
    ok(answer.result.contents.kind === 'markdown', 'hover answers markdown');
    const value = answer.result.contents.value;
    ok(value.includes('fn add(a: u64, b: u64) -> u64'), `signature in hover: ${value}`);
    ok(value.includes('Adds two numbers.'), 'the doc comment is shown');
    equal(answer.result.range, rangeIn(HOVER, 'add(p.x, 3)', 3), 'the range covers the callee name');
  }
  // A local binding whose type came from a record literal.
  {
    const answer = await hover(pointIn(HOVER, 'p.x, 3', 0));
    ok(answer.result.contents.value.includes('p: Point'), `local type: ${answer.result.contents.value}`);
  }
  // A field after `.`, from the receiver's type.
  {
    const answer = await hover(pointIn(HOVER, 'p.x, 3', 2));
    const value = answer.result.contents.value;
    ok(value.includes('x: u64'), `field type: ${value}`);
    ok(value.includes('field of `Point`'), 'the field says which record it belongs to');
    equal(answer.result.range, rangeIn(HOVER, 'x, 3)', 1), 'the range covers the field name');
  }
  // A field label in a record literal.
  {
    const answer = await hover(pointIn(HOVER, 'x: 1, y: 2', 0));
    ok(answer.result.contents.value.includes('x: u64'), 'a record-literal label shows the field type');
  }
  // A field reached through a reference parameter: `p: &Point` still ends at `Point`.
  {
    const answer = await hover(pointIn(HOVER, 'p.x;\n}', 'p.x;\n}'.length - 3));
    ok(answer.result.contents.value.includes('x: u64'), 'a field through a reference parameter');
  }
  // A literal.
  {
    const answer = await hover(pointIn(HOVER, '3);', 0));
    equal(answer.result.contents.value, '```grail\nu64\n```', 'an integer literal is u64');
  }
  // A string literal on a line with non-ASCII text: the range must be in UTF-16 units.
  {
    const answer = await hover(pointIn(HOVER, '"héllo 😀"', 3));
    equal(answer.result.contents.value, '```grail\nstring\n```', 'a string literal is string');
    equal(answer.result.range, rangeIn(HOVER, '"héllo 😀"', '"héllo 😀"'.length), 'the range is UTF-16, not bytes');
  }
  // A binding after a non-ASCII string on the same line: characters, not bytes.
  {
    const answer = await hover(pointIn(HOVER, 'tail := 1', 1));
    ok(answer.result.contents.value.includes('tail: u64'), 'a binding after non-ASCII text');
    equal(answer.result.range, rangeIn(HOVER, 'tail := 1', 4), 'the reported range is in UTF-16 units');
  }
  // A record declaration and an enum variant.
  {
    const record = await hover(pointIn(HOVER, 'Point {', 2));
    ok(record.result.contents.value.includes('struct Point { x: u64, y: u64 }'), 'a record signature');
    const variant = await hover(pointIn(HOVER, 'Second(4)', 2));
    ok(variant.result.contents.value.includes('Word::Second(u64)'), 'an enum variant');
  }
  // Nothing is answered when there is nothing to say.
  equal((await hover(pointIn(HOVER, 'ghost := absent', 1))).result, null,
    'a binding whose type cannot be known has no hover');
  equal((await hover(pointIn(HOVER, 'absent', 1))).result, null, 'an undeclared name has no hover');
  equal((await hover({ line: 1, character: 0 })).result, null, 'an empty line has no hover');
  equal((await hover({ line: 40, character: 0 })).error.code, -32602, 'a position past the end is an error');
  equal((await hover({ line: 0, character: 999 })).error.code, -32602, 'a character past the line is an error');
  equal((await client.request(nextId(), 'textDocument/hover', { position: { line: 0, character: 0 } })).error.code, -32602,
    'hover without a textDocument is an error');
  equal(await client.stop(), 0, 'clean exit');
  equal(client.stderr, '', 'no stderr noise');
}

// --- 8. Completion: locals, fields, variants, parameters, keywords ------------------
{
  const client = new Client();
  await client.initialize();
  const COMPLETE = [
    'struct Point {',
    '    x: u64,',
    '    y: u64',
    '}',
    'enum Word {',
    '    First,',
    '    Second(u64)',
    '}',
    'impl Point {',
    '    fn sum(self: &Point) -> u64 {',
    '        return self.x + self.y;',
    '    }',
    '}',
    'fn area(p: &Point) -> u64 {',
    '    return p.x;',
    '}',
    'fn main() {',
    '    point := Point { x: 1, y: 2 };',
    '    ',
    '    poi',
    '    Po',
    '    other := point.',
    '    s := point.sum();',
    '    w := Word.',
    '    W := Word::',
    '    total := area(',
    '    ghost.',
    '}',
    'fn shadow() {',
    '    value := 1;',
    '    if true {',
    '        value := "text";',
    '        val',
    '    }',
    '    va',
    '}',
    '',
  ].join('\n');
  const uri = 'file:///virtual/complete.grl';
  await client.open(uri, 1, COMPLETE);
  const complete = (position) => client.request(nextId(), 'textDocument/completion', { textDocument: { uri }, position });
  const labels = (answer) => answer.result.items.map(item => item.label);
  const itemFor = (answer, label) => answer.result.items.find(item => item.label === label);

  // A bare prefix: the local binding, the functions and keywords, each with a kind and a
  // detail, and locals sorting ahead of module-level names.
  {
    const answer = await complete(pointIn(COMPLETE, '\n    poi\n', '\n    poi'.length));
    equal(answer.result.isIncomplete, false, 'completion is complete');
    const local = itemFor(answer, 'point');
    ok(local, `locals are offered: ${labels(answer)}`);
    equal(local.kind, 6, 'a local is a Variable');
    equal(local.detail, 'Point', 'a local carries its type');
    equal(labels(answer), ['point'], 'only names with that exact prefix are offered');
    ok(!labels(answer).includes('ghost'), 'nothing invents a name the buffer does not have');
  }
  // A capital prefix reaches the declarations that are capitalised.
  {
    const answer = await complete(pointIn(COMPLETE, '\n    Po\n', '\n    Po'.length));
    equal(itemFor(answer, 'Point').kind, 22, 'a record is a Struct');
    equal(itemFor(answer, 'Point').detail, 'struct Point', 'a record carries its name');
  }
  // An empty prefix: keywords, this file's declarations and its bindings in scope.
  {
    const answer = await complete(pointIn(COMPLETE, 'y: 2 };\n    \n', 'y: 2 };\n    '.length));
    ok(labels(answer).includes('match'), 'keywords are offered');
    ok(labels(answer).includes('Word'), 'an enum is offered');
    equal(itemFor(answer, 'Word').kind, 13, 'an enum is an Enum');
    const areaItem = itemFor(answer, 'area');
    equal(areaItem.kind, 3, 'a function is offered');
    ok(areaItem.detail.startsWith('fn area('), `a function carries a signature: ${areaItem.detail}`);
    ok(labels(answer).includes('point'), 'a local in scope is offered');
    ok(itemFor(answer, 'point').sortText < areaItem.sortText,
      'locals rank before functions');
    ok(!labels(answer).includes('sum'), 'a method is not a bare name');
  }
  // After `.`: the record's fields and its methods.
  {
    const answer = await complete(pointIn(COMPLETE, 'point.\n', 'point.\n'.length - 1));
    const x = itemFor(answer, 'x');
    ok(x, `fields are offered: ${labels(answer)}`);
    equal(x.kind, 5, 'a field is a Field');
    equal(x.detail, 'u64', 'a field carries its type');
    const sum = itemFor(answer, 'sum');
    ok(sum, 'methods of the receiver type are offered');
    equal(sum.kind, 2, 'a method is a Method');
    ok(!labels(answer).includes('area'), 'an unrelated function is not offered after a dot');
  }
  // After `Type.`: an enum's variants.
  {
    const answer = await complete(pointIn(COMPLETE, 'Word.\n', 'Word.\n'.length - 1));
    equal(labels(answer).sort(), ['First', 'Second'], 'an enum offers its variants at `Type.`');
    equal(itemFor(answer, 'Second').kind, 20, 'a variant is an EnumMember');
    equal(itemFor(answer, 'Second').detail, 'Word::Second(u64)', 'a variant carries its payload');
  }
  // `Type::` is the same context as `Type.`.
  {
    const answer = await complete(pointIn(COMPLETE, 'W := Word::\n', 'W := Word::\n'.length - 1));
    equal(labels(answer).sort(), ['First', 'Second'], 'a variant is offered after `::` too');
  }
  // After `name(`: the call's parameters.
  {
    const answer = await complete(pointIn(COMPLETE, 'area(\n', 'area(\n'.length - 1));
    equal(labels(answer), ['p'], 'a call offers its parameters');
    equal(itemFor(answer, 'p').detail, '&Point', 'a parameter carries its type');
    equal(itemFor(answer, 'p').kind, 6, 'a parameter is a Variable');
  }
  // A receiver whose type is unknown: no completion rather than a wrong list.
  {
    const answer = await complete(pointIn(COMPLETE, 'ghost.\n', 'ghost.\n'.length - 1));
    equal(answer.result.items, [], 'an unknown receiver offers nothing');
  }
  // Shadowing: the inner binding of a name is the one the editor is offered.
  {
    const inner = await complete(pointIn(COMPLETE, '\n        val\n', '\n        val'.length));
    equal(itemFor(inner, 'value').detail, 'string', 'the innermost binding wins');
    const outer = await complete(pointIn(COMPLETE, '\n    va\n}', '\n    va'.length));
    equal(itemFor(outer, 'value').detail, 'u64', 'outside the block the outer binding is offered');
  }
  // A method call's hover is its signature.
  {
    const answer = await client.request(nextId(), 'textDocument/hover', {
      textDocument: { uri }, position: pointIn(COMPLETE, 'point.sum()', 7),
    });
    ok(answer.result.contents.value.includes('fn sum(self: &Point) -> u64'), 'a method call shows its signature');
  }
  equal((await complete({ line: 90, character: 0 })).error.code, -32602, 'a bad completion position is an error');
  equal(await client.stop(), 0, 'clean exit');
  equal(client.stderr, '', 'no stderr noise');
}

// --- 9. Rename: locals, parameters, items and fields; refusals and errors -----------
{
  const client = new Client();
  await client.initialize();
  const RENAME = [
    'module rename;',
    'struct Point {',
    '    x: u64,',
    '    y: u64',
    '}',
    'fn add(a: u64, b: u64) -> u64 {',
    '    return a + b;',
    '}',
    'fn main() {',
    '    p := Point { x: 1, y: 2 };',
    '    a := 1;',
    '    {',
    '        a := 2;',
    '        println(a);',
    '    }',
    '    println(a);',
    '    tag := "héllo 😀"; trinket := add(p.x, a);',
    '    note := "a x trinket p";',
    '    // a x trinket p',
    '    println(trinket);',
    '}',
    '',
    'struct Pair {',
    '    x: string',
    '}',
    '',
    'fn pair() {',
    '    pair := Pair { x: "text" };',
    '    println(pair.x);',
    '}',
    '',
    'fn lone(b: u64) -> u64 {',
    '    return b;',
    '}',
    '',
  ].join('\n');
  const uri = 'file:///virtual/rename.grl';
  await client.open(uri, 1, RENAME);
  const renameAt = (position, newName = 'renamed') =>
    client.request(nextId(), 'textDocument/rename', { textDocument: { uri }, position, newName });
  const prepareAt = (position) => client.request(nextId(), 'textDocument/prepareRename', { textDocument: { uri }, position });
  const edits = async (position) => (await renameAt(position)).result.changes[uri];

  // prepareRename answers the identifier's range and its text as the placeholder.
  {
    const position = pointIn(RENAME, 'trinket := add', 2);
    const prepared = await prepareAt(position);
    equal(prepared.result.range, rangeIn(RENAME, 'trinket := add', 7), 'prepareRename gives the name range');
    equal(prepared.result.placeholder, 'trinket', 'prepareRename gives the name');
  }
  // A local: the declaration and every use that resolves to it.
  {
    const found = await edits(pointIn(RENAME, 'trinket := add', 2));
    equal(found.length, 2, 'the binding and its use are the edits');
    for (const span of found) {
      equal(sliceRange(RENAME, span.range), 'trinket', 'each edit covers exactly the identifier');
    }
    equal(found[0].range.start.line, 16, 'the declaration on the non-ASCII line is edited first');
    equal(found[1].range.start.line, 19, 'the use is edited too');
    // The string and the comment that spell the same name are not touched.
    ok(!found.some(span => span.range.start.line === 17 || span.range.start.line === 18),
      'string and comment text are never edited');
  }
  // A shadowed binding: only its own uses, never the shadowed one's.
  {
    const inner = await edits(pointIn(RENAME, 'println(a);\n    }\n', 'println('.length));
    equal(inner.length, 2, 'the shadowing binding has its own two edits');
    equal(inner.map(span => span.range.start.line), [12, 13], 'the inner declaration and use');
  }
  {
    const outer = await edits(pointIn(RENAME, 'println(a);\n    tag', 8));
    equal(outer.length, 3, 'the outer binding has three edits');
    equal(outer.map(span => span.range.start.line), [10, 15, 16], 'declaration and both uses');
  }
  // A parameter.
  {
    const found = await edits(pointIn(RENAME, 'b: u64)', 0), 'renamed');
    equal(found.length, 2, 'a parameter renames its declaration and use');
    equal(found.map(span => span.range.start.line), [5, 6], 'parameter declaration and use');
    ok(!found.some(span => span.range.start.line > 20), 'a same-named parameter of another function is untouched');
    equal(found[0].newText, 'renamed', 'the edit carries the new name');
  }
  // A function, a record and a field.
  {
    const fn = await edits(pointIn(RENAME, 'add(p.x', 1));
    equal(fn.length, 2, 'a function renames its declaration and call');
    equal(fn.map(span => span.range.start.line), [5, 16], 'function declaration and call');
  }
  {
    const record = await edits(pointIn(RENAME, 'Point { x: 1', 2));
    equal(record.length, 2, 'a record renames its declaration and literal');
    equal(record.map(span => span.range.start.line), [1, 9], 'record declaration and literal');
  }
  // A rename asked for at the literal's label reaches the same field.
  {
    const atLabel = await edits(pointIn(RENAME, 'x: 1, y: 2', 0));
    const atAccess = await edits(pointIn(RENAME, 'p.x, a', 2));
    equal(atLabel, atAccess, 'the label and the access resolve to the same field');
  }
  {
    const field = await edits(pointIn(RENAME, 'p.x, a', 2));
    equal(field.length, 3, 'a field renames its declaration, the literal label and the access');
    equal(field.map(span => span.range.start.line), [2, 9, 16], 'field declaration, label and access');
    for (const span of field) {
      equal(sliceRange(RENAME, span.range), 'x', 'each field edit is the field name');
    }
    // `Pair` has a field of the same name and is a different field: untouched.
    ok(!field.some(span => span.range.start.line >= 22), 'a same-named field of another record is not renamed');
  }
  // Refusals: a keyword, a builtin, and anything the server cannot name.
  {
    const keyword = await renameAt(pointIn(RENAME, 'fn add', 0));
    equal(keyword.error.code, -32001, 'renaming a keyword is refused');
    ok(/keyword/.test(keyword.error.message), `refusal says why: ${keyword.error.message}`);
    const builtin = await renameAt(pointIn(RENAME, 'println(a);\n    tag', 1));
    equal(builtin.error.code, -32001, 'renaming a builtin is refused');
    equal((await prepareAt(pointIn(RENAME, 'println(a);\n    tag', 1))).result, null,
      'prepareRename answers null for a name it will not rename');
    const nothing = await prepareAt({ line: 0, character: 0 });
    ok(nothing.result === null || nothing.error, 'a position with no name answers null or an error');
    equal((await renameAt({ line: 95, character: 0 })).error.code, -32602, 'a bad rename position is an error');
    equal((await renameAt(pointIn(RENAME, 'trinket := add', 2), 'not a name')).error.code, -32602,
      'a newName that is not an identifier is an error');
    equal((await renameAt(pointIn(RENAME, 'trinket := add', 2), '')).error.code, -32602,
      'an empty newName is an error');
  }
  equal(await client.stop(), 0, 'clean exit');
  equal(client.stderr, '', 'no stderr noise');
}

// --- 10. Rename across open documents, and refusals for unopened modules ------------
{
  const client = new Client();
  await client.initialize();
  const LIB = [
    'module mathlib;', '', 'pub struct Bundle {', '    item: u64,', '    other: u64', '}', '',
    'pub fn helper(a: u64) -> u64 {', '    return a;', '}', '',
  ].join('\n');
  const APP = [
    'module app;', '', 'use mathlib;', 'use mathlib::Bundle;', '',
    'fn main() {', '    x := mathlib::helper(1);',
    '    b := Bundle { item: 2, other: 3 };',
    '    println(b.item);', '    println(x);', '}', '',
  ].join('\n');
  const OTHER = ['module other;', '', 'use somewhere;', '', 'fn main() {', '    y := somewhere::thing(1);', '    println(y);', '}', ''].join('\n');
  const lib = 'file:///virtual/mathlib.grl';
  const app = 'file:///virtual/app.grl';
  const other = 'file:///virtual/other.grl';
  // These documents are modules, not executables: `grail check` cannot compile one on its
  // own, so they are opened without waiting for a publication that will never come. What
  // the rename asks about is the open buffer, which is all the server indexes.
  for (const [uri, text] of [[lib, LIB], [app, APP], [other, OTHER]]) {
    client.notify('textDocument/didOpen', { textDocument: { uri, languageId: 'grail', version: 1, text } });
  }
  const renameAt = (uri, position, newName = 'renamed') =>
    client.request(nextId(), 'textDocument/rename', { textDocument: { uri }, position, newName });

  // Renaming the declaration renames the qualified use in the other document.
  {
    const answer = await renameAt(lib, pointIn(LIB, 'helper(a', 2));
    const changes = answer.result.changes;
    equal(Object.keys(changes).sort(), [app, lib].sort(), 'both documents are edited');
    equal(changes[lib].length, 1, 'the declaration');
    equal(changes[app].length, 1, 'the qualified use');
    equal(sliceRange(LIB, changes[lib][0].range), 'helper', 'the declaration edit is the name');
    equal(sliceRange(APP, changes[app][0].range), 'helper', 'the use edit is the name');
  }
  // Renaming the qualified use finds the declaration in the other document.
  {
    const answer = await renameAt(app, pointIn(APP, 'helper(1)', 1));
    const changes = answer.result.changes;
    equal(Object.keys(changes).sort(), [app, lib].sort(), 'the use renames the declaration too');
    equal(changes[lib].length, 1, 'the declaration is edited once');
  }
  // A local in one document stays in that document.
  {
    const answer = await renameAt(app, pointIn(APP, 'x := mathlib', 1));
    equal(Object.keys(answer.result.changes), [app], 'a local rename stays in its document');
    equal(answer.result.changes[app].length, 2, 'its declaration and use');
  }
  // A record field across documents: the declaration, the literal label and the access.
  {
    const answer = await renameAt(lib, pointIn(LIB, 'item: u64', 1), 'part');
    const changes = answer.result.changes;
    equal(Object.keys(changes).sort(), [app, lib].sort(), 'the field rename reaches both documents');
    equal(changes[lib].length, 1, 'the field declaration');
    equal(changes[app].length, 2, 'the literal label and the access in the other document');
    for (const span of changes[app]) {
      equal(sliceRange(APP, span.range), 'item', 'each edit covers the field name');
    }
  }
  // A module that is not open cannot be renamed soundly, and its members are not guessed.
  {
    const answer = await renameAt(other, pointIn(OTHER, 'thing(1)', 1));
    equal(answer.error.code, -32001, 'an unopened module refuses rename');
    ok(answer.error.message.includes('somewhere'), `the refusal names the module: ${answer.error.message}`);
    const hovered = await client.request(nextId(), 'textDocument/hover', {
      textDocument: { uri: other }, position: pointIn(OTHER, 'thing(1)', 1),
    });
    equal(hovered.result, null, 'and nothing is guessed about it on hover');
  }
  equal(await client.stop(), 0, 'clean exit');
  equal(client.stderr, '', 'no stderr noise');
}

// --- 11. A buffer that is being typed is never fatal -------------------------------
// The strict lexer asserts on an unterminated string; the server's own scanner must not,
// or the first keystroke inside a literal would take the session down.
{
  const client = new Client();
  await client.initialize();
  const uri = 'file:///virtual/typing.grl';
  const HALF = 'fn main() {\n    s := "hej\n    x := 1;\n    println(x);\n}\n';
  client.notify('textDocument/didOpen', { textDocument: { uri, languageId: 'grail', version: 1, text: HALF } });
  const answer = await client.request(nextId(), 'textDocument/hover', {
    textDocument: { uri }, position: pointIn(HALF, 'x := 1', 1),
  });
  ok(answer.result && answer.result.contents.value.includes('x: u64'), 'hover works inside a half-typed buffer');
  const items = await client.request(nextId(), 'textDocument/completion', {
    textDocument: { uri }, position: pointIn(HALF, 'println(x)', 8),
  });
  ok(Array.isArray(items.result.items) && items.result.items.length > 0, 'completion works too');
  // An unterminated character literal is not fatal either.
  const quote = 'fn main() {\n    c := \'a\n}\n';
  client.notify('textDocument/didChange', { textDocument: { uri, version: 2 }, contentChanges: [{ text: quote }] });
  const after = await client.request(nextId(), 'textDocument/hover', {
    textDocument: { uri }, position: pointIn(quote, 'c :=', 0),
  });
  ok(after.result === null || after.result.contents, 'the session still answers after an unterminated quote');
  equal(await client.stop(), 0, 'clean exit');
}

console.log(`lsp: ${checks} checks passed`);
