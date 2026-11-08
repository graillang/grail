import { test, expect, describe } from 'bun:test';
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { byteColumnToCharacter, findCompiler, parseDiagnostics } from './lsp.mjs';
import { root } from './platforms.mjs';

const VALID = 'fn main() {\n    println("hello");\n}\n';
const INVALID = 'fn main() {\n    missing(1);\n}\n';
const VALID_URI = 'file:///virtual/valid.grl';
const INVALID_URI = 'file:///virtual/invalid.grl';
const compiler = [process.env.GRAIL_LSP_COMPILER, process.env.GRAIL_COMPILER].filter(Boolean).find(path => existsSync(path)) ?? findCompiler();

function frame(message) {
  const json = JSON.stringify(message);
  return `Content-Length: ${Buffer.byteLength(json, 'utf8')}\r\n\r\n${json}`;
}

class Client {
  constructor(compilerPath) {
    this.messages = [];
    this.waiters = [];
    this.buffer = Buffer.alloc(0);
    this.stderr = '';
    this.child = spawn(process.execPath, [join(root, 'tools/lsp.mjs')], {
      cwd: root,
      env: {
        ...process.env,
        GRAIL_LSP_COMPILER: compilerPath ?? '',
        GRAIL_HOME: process.env.GRAIL_HOME ?? root,
        GRAIL_LSP_DEBOUNCE_MS: '10',
      },
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
    while (true) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd < 0) return;
      const header = this.buffer.subarray(0, headerEnd).toString('ascii');
      const match = /content-length:\s*(\d+)/i.exec(header);
      if (!match) throw new Error(`bad frame header: ${header}`);
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

  waitFor(predicate, label, timeout = 30_000) {
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

  send(message) {
    this.child.stdin.write(frame(message));
  }

  request(id, method, params) {
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

  async stop() {
    if (this.exitCode !== undefined) return this.exitCode;
    return new Promise(resolve => {
      this.child.once('exit', code => resolve(code));
      this.send({ jsonrpc: '2.0', id: 999, method: 'shutdown', params: null });
      this.send({ jsonrpc: '2.0', method: 'exit', params: null });
      setTimeout(() => { this.child.kill(); resolve(this.child.exitCode); }, 10_000);
    });
  }
}

describe('diagnostic parsing', () => {
  test('turns compiler text into an LSP range', () => {
    const diagnostics = parseDiagnostics('invalid.grl:2:12: unknown function at byte 23\n  |     missing(1);\n  |            ^\n', INVALID, 1);
    expect(diagnostics).toHaveLength(1);
    expect(diagnostics[0]).toMatchObject({
      range: { start: { line: 1, character: 11 }, end: { line: 1, character: 12 } },
      severity: 1,
      source: 'grail',
      code: 'compiler',
      message: 'unknown function at byte 23',
    });
  });

  test('treats a successful check as no diagnostics', () => {
    expect(parseDiagnostics('ok\n', VALID, 0)).toEqual([]);
  });

  test('converts compiler byte columns to UTF-16 positions', () => {
    expect(byteColumnToCharacter('abc', 1)).toBe(0);
    expect(byteColumnToCharacter('héllo', 3)).toBe(2);
    expect(byteColumnToCharacter('', 5)).toBe(0);
  });

  test('falls back to the compiler output when no range is present', () => {
    const diagnostics = parseDiagnostics('grail: internal failure\n', INVALID, 1);
    expect(diagnostics).toHaveLength(1);
    expect(diagnostics[0].code).toBe('compiler-output');
    expect(diagnostics[0].message).toContain('internal failure');
  });
});

describe('stdio protocol', () => {
  test('initialize and shutdown', async () => {
    const client = new Client(compiler);
    try {
      const init = await client.request(1, 'initialize', { processId: null, rootUri: null, capabilities: {} });
      expect(init.result.capabilities.textDocumentSync).toMatchObject({ openClose: true, change: 1 });
      expect(init.result.serverInfo.name).toBe('grail-lsp');
      client.notify('initialized', {});
      const shutdown = await client.request(2, 'shutdown', null);
      expect(shutdown.result).toBeNull();
      expect(await client.stop()).toBe(0);
    } finally {
      client.child.kill();
    }
  });

  test('unknown requests get a JSON-RPC error', async () => {
    const client = new Client(compiler);
    try {
      await client.request(1, 'initialize', { processId: null, rootUri: null, capabilities: {} });
      const response = await client.request(3, 'textDocument/hover', { textDocument: { uri: VALID_URI }, position: { line: 0, character: 0 } });
      expect(response.error.code).toBe(-32601);
      await client.stop();
    } finally {
      client.child.kill();
    }
  });
});

const diagnosticsTest = compiler ? test : test.skip;

describe('compiler diagnostics over stdio', () => {
  diagnosticsTest('valid and invalid documents produce real compiler diagnostics', async () => {
    const client = new Client(compiler);
    try {
      await client.request(1, 'initialize', { processId: null, rootUri: null, capabilities: {} });
      client.notify('initialized', {});

      const valid = await client.open(VALID_URI, 1, VALID);
      expect(valid.params.diagnostics).toEqual([]);

      const invalid = await client.open(INVALID_URI, 1, INVALID);
      expect(invalid.params.diagnostics).toHaveLength(1);
      expect(invalid.params.diagnostics[0]).toMatchObject({
        range: { start: { line: 1, character: 11 }, end: { line: 1, character: 12 } },
        severity: 1,
        source: 'grail',
        code: 'compiler',
      });
      expect(invalid.params.diagnostics[0].message).toContain('unknown function');

      // didChange uses the same compiler path and replaces the previous result.
      const changed = await client.change(VALID_URI, 2, INVALID);
      expect(changed.params.version).toBe(2);
      expect(changed.params.diagnostics[0].message).toContain('unknown function');

      const repaired = await client.change(VALID_URI, 3, VALID);
      expect(repaired.params.version).toBe(3);
      expect(repaired.params.diagnostics).toEqual([]);

      expect(await client.stop()).toBe(0);
    } finally {
      client.child.kill();
    }
  }, 60_000);
});
