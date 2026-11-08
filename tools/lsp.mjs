#!/usr/bin/env bun
// Minimal Grail language server.
//
// JSON-RPC 2.0 over stdio (Content-Length framing) with initialize/shutdown,
// didOpen/didChange/didClose and push diagnostics. Diagnostics come from the
// existing `grail check FILE` interface: the compiler prints
// `file:line:column: message` and exits non-zero. Nothing here invents a
// language diagnostic; when the compiler cannot run, the server reports an
// environment error with window/showMessage and publishes nothing.
//
// Deliberately out of scope for this MVP: hover, definition, references,
// formatting, completion, workspace/project-wide checks and pull diagnostics.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { hostPlatformId, inspectBinary, platformById, readVersion, root } from './platforms.mjs';

const log = (...parts) => {
  if (process.env.GRAIL_LSP_LOG) process.stderr.write(`[grail-lsp] ${parts.join(' ')}\n`);
};
const DEBOUNCE_MS = Number(process.env.GRAIL_LSP_DEBOUNCE_MS ?? 50);
const CHECK_TIMEOUT_MS = Number(process.env.GRAIL_LSP_TIMEOUT_MS ?? 30_000);
const SERVER_VERSION = (() => { try { return readVersion(process.env); } catch { return '0.0.0'; } })();

function findOnPath(name) {
  for (const directory of (process.env.PATH ?? '').split(process.platform === 'win32' ? ';' : ':')) {
    if (!directory) continue;
    const candidate = join(directory, name + (process.platform === 'win32' ? '.exe' : ''));
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

export function findCompiler(env = process.env) {
  for (const candidate of [env.GRAIL_LSP_COMPILER, env.GRAIL_COMPILER]) {
    if (candidate && existsSync(candidate)) return candidate;
  }
  const installed = findOnPath('grail');
  if (installed) return installed;
  const host = hostPlatformId();
  if (!host) return null;
  const id = platformById(host).id;
  const directory = join(root, 'dist');
  if (!existsSync(directory)) return null;
  const candidates = readdirSync(directory)
    .filter(name => name.startsWith('grail-') && name.endsWith(`-${id}-compiler`))
    .sort()
    .reverse()
    .map(name => join(directory, name));
  for (const candidate of candidates) {
    try {
      const info = inspectBinary(candidate);
      if (info.format === 'elf' && info.arch === platformById(host).arch) return candidate;
    } catch {
      // Ignore unreadable candidates.
    }
  }
  return null;
}

function safeName(uri) {
  let name = 'document.grl';
  try {
    if (uri.startsWith('file:')) name = basename(fileURLToPath(uri));
  } catch {
    name = basename(uri.split('/').pop() ?? 'document.grl');
  }
  name = name.replace(/[^A-Za-z0-9._-]/g, '_');
  if (!name.endsWith('.grl')) name = `${name}.grl`;
  return name;
}

// The compiler reports byte columns. LSP positions are UTF-16 code units, so
// convert through the document line instead of copying the byte offset.
export function byteColumnToCharacter(line, byteColumn) {
  if (!line) return 0;
  const bytes = Buffer.from(line, 'utf8');
  const prefix = bytes.subarray(0, Math.max(0, byteColumn - 1));
  return Math.min(prefix.toString('utf8').length, line.length);
}

export function parseDiagnostics(output, text, status = 1) {
  const documentLines = text.split(/\r?\n/);
  const diagnostics = [];
  const seen = new Set();
  for (const raw of output.split(/\r?\n/)) {
    const match = /^(.+):(\d+):(\d+): (.+)$/.exec(raw);
    if (!match) continue;
    const line = Math.max(0, Number(match[2]) - 1);
    const documentLine = documentLines[line] ?? '';
    const character = byteColumnToCharacter(documentLine, Math.max(1, Number(match[3])));
    const end = Math.min(character + 1, Math.max(character, documentLine.length));
    const message = match[4].trim();
    const key = `${line}:${character}:${message}`;
    if (seen.has(key)) continue;
    seen.add(key);
    diagnostics.push({
      range: { start: { line, character }, end: { line, character: end } },
      severity: 1,
      source: 'grail',
      code: 'compiler',
      message,
      data: { file: match[1] },
    });
  }
  if (diagnostics.length === 0 && status !== 0) {
    const summary = output.trim().split(/\r?\n/).slice(0, 4).join(' ').trim();
    diagnostics.push({
      range: { start: { line: 0, character: 0 }, end: { line: 0, character: 1 } },
      severity: 1,
      source: 'grail',
      code: 'compiler-output',
      message: summary || `grail check failed with status ${status}`,
    });
  }
  return diagnostics;
}

function grailHome() {
  if (process.env.GRAIL_HOME) return process.env.GRAIL_HOME;
  if (existsSync(join(root, 'compiler/runtime.grl'))) return root;
  return undefined;
}

export function runCheck(compiler, text, uri) {
  const directory = mkdtempSync(join(tmpdir(), 'grail-lsp-'));
  try {
    const name = safeName(uri);
    writeFileSync(join(directory, name), text);
    const env = { ...process.env };
    const home = grailHome();
    if (home) env.GRAIL_HOME = home;
    const result = spawnSync(compiler, ['check', name], {
      cwd: directory,
      env,
      encoding: 'utf8',
      timeout: CHECK_TIMEOUT_MS,
    });
    if (result.error) return { error: result.error.message, diagnostics: [] };
    if (result.signal) return { error: `grail check terminated by ${result.signal}`, diagnostics: [] };
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    return { status: result.status ?? 1, output, diagnostics: parseDiagnostics(output, text, result.status ?? 1) };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

class Connection {
  constructor() {
    this.buffer = Buffer.alloc(0);
    this.documents = new Map();
    this.timers = new Map();
    this.shutdownRequested = false;
    this.exited = false;
    this.compiler = findCompiler();
    if (!this.compiler) log('no compiler found; set GRAIL_LSP_COMPILER');
  }

  start() {
    process.stdin.on('data', chunk => this.receive(chunk));
    process.stdin.on('end', () => this.exit(0));
    process.stdin.on('error', error => {
      log('stdin error', error.message);
      this.exit(1);
    });
  }

  receive(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (true) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd < 0) return;
      const header = this.buffer.subarray(0, headerEnd).toString('ascii');
      const match = /content-length:\s*(\d+)/i.exec(header);
      if (!match) {
        log('frame without Content-Length');
        this.buffer = this.buffer.subarray(headerEnd + 4);
        continue;
      }
      const length = Number(match[1]);
      const start = headerEnd + 4;
      if (this.buffer.length < start + length) return;
      const payload = this.buffer.subarray(start, start + length).toString('utf8');
      this.buffer = this.buffer.subarray(start + length);
      let message;
      try {
        message = JSON.parse(payload);
      } catch (error) {
        this.send({ jsonrpc: '2.0', id: null, error: { code: -32700, message: `parse error: ${error.message}` } });
        continue;
      }
      try {
        this.dispatch(message);
      } catch (error) {
        log('dispatch failed', error.stack ?? error.message);
        if (message.id !== undefined) this.send({ jsonrpc: '2.0', id: message.id, error: { code: -32603, message: error.message } });
      }
    }
  }

  send(message) {
    const json = JSON.stringify(message);
    process.stdout.write(`Content-Length: ${Buffer.byteLength(json, 'utf8')}\r\n\r\n${json}`);
  }

  publish(uri, version, diagnostics) {
    this.send({
      jsonrpc: '2.0',
      method: 'textDocument/publishDiagnostics',
      params: { uri, ...(version === undefined ? {} : { version }), diagnostics },
    });
  }

  dispatch(message) {
    const method = message.method;
    if (method === 'initialize') {
      if (this.initialized) {
        this.send({ jsonrpc: '2.0', id: message.id, error: { code: -32600, message: 'already initialized' } });
        return;
      }
      this.initialized = true;
      this.send({
        jsonrpc: '2.0',
        id: message.id,
        result: {
          capabilities: {
            textDocumentSync: { openClose: true, change: 1, save: false },
            positionEncoding: 'utf-16',
          },
          serverInfo: { name: 'grail-lsp', version: SERVER_VERSION },
        },
      });
      return;
    }
    if (method === 'initialized') return;
    if (method === 'shutdown') {
      this.shutdownRequested = true;
      this.send({ jsonrpc: '2.0', id: message.id, result: null });
      return;
    }
    if (method === 'exit') {
      this.exit(this.shutdownRequested ? 0 : 1);
      return;
    }
    if (method === 'textDocument/didOpen') {
      const document = message.params?.textDocument;
      if (!document?.uri) return;
      this.documents.set(document.uri, { text: document.text ?? '', version: document.version, generation: 0 });
      this.schedule(document.uri);
      return;
    }
    if (method === 'textDocument/didChange') {
      const uri = message.params?.textDocument?.uri;
      if (!uri) return;
      const existing = this.documents.get(uri);
      if (!existing) return;
      const change = message.params.contentChanges?.[0];
      if (!change) return;
      existing.text = change.text ?? existing.text;
      existing.version = message.params.textDocument.version ?? existing.version;
      this.schedule(uri);
      return;
    }
    if (method === 'textDocument/didClose') {
      const uri = message.params?.textDocument?.uri;
      if (!uri) return;
      this.documents.delete(uri);
      clearTimeout(this.timers.get(uri));
      this.timers.delete(uri);
      this.publish(uri, undefined, []);
      return;
    }
    if (method === '$/cancelRequest') return;
    if (message.id !== undefined) {
      this.send({ jsonrpc: '2.0', id: message.id, error: { code: -32601, message: `method not found: ${method}` } });
    }
  }

  schedule(uri) {
    const document = this.documents.get(uri);
    if (!document) return;
    clearTimeout(this.timers.get(uri));
    const generation = ++document.generation;
    this.timers.set(uri, setTimeout(() => {
      this.timers.delete(uri);
      this.check(uri, generation);
    }, DEBOUNCE_MS));
  }

  check(uri, generation) {
    const document = this.documents.get(uri);
    if (!document || document.generation !== generation) return;
    if (!this.compiler) {
      this.send({
        jsonrpc: '2.0',
        method: 'window/showMessage',
        params: { type: 1, message: 'Grail LSP: no compiler found; set GRAIL_LSP_COMPILER to a Grail executable' },
      });
      return;
    }
    const outcome = runCheck(this.compiler, document.text, uri);
    if (document.generation !== generation || !this.documents.has(uri)) return;
    if (outcome.error) {
      this.send({
        jsonrpc: '2.0',
        method: 'window/showMessage',
        params: { type: 1, message: `Grail LSP: compiler failed: ${outcome.error}` },
      });
      return;
    }
    this.publish(uri, document.version, outcome.diagnostics);
  }

  exit(code) {
    if (this.exited) return;
    this.exited = true;
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.timers.clear();
    process.exit(code);
  }
}

if (import.meta.main) {
  new Connection().start();
}
