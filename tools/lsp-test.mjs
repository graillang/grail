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
  constructor() {
    this.messages = [];
    this.waiters = [];
    this.buffer = Buffer.alloc(0);
    this.stderr = '';
    this.exitCode = undefined;
    this.child = spawn(server, [], {
      cwd: root,
      env: { ...process.env, GRAIL_LSP_COMPILER: compiler, GRAIL_HOME: root },
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
  // Nothing is claimed that the server does not implement.
  for (const absent of ['hoverProvider', 'completionProvider', 'renameProvider', 'referencesProvider',
    'documentSymbolProvider', 'documentFormattingProvider', 'documentRangeFormattingProvider',
    'signatureHelpProvider', 'codeActionProvider', 'semanticTokensProvider', 'diagnosticProvider']) {
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
  equal(first.range.start, { line: 1, character: 11 }, 'the range is the compiler position, in UTF-16');
  equal(first.range.end, { line: 1, character: 12 }, 'the range covers the offending token');
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
  ok(arity.params.diagnostics[0].message.includes('argument count'), `arity message: ${arity.params.diagnostics[0].message}`);

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
  const unknown = await client.request(2, 'textDocument/hover', { textDocument: { uri: URI }, position: { line: 0, character: 0 } });
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

console.log(`lsp: ${checks} checks passed`);
