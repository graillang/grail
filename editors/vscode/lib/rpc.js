'use strict';
// A minimal JSON-RPC 2.0 client over a child process's stdio, using the `Content-Length` framing
// the language server protocol specifies. This is deliberately small and dependency-free: the
// Grail server advertises exactly one capability beyond synchronisation (definition), so the
// editor side only has to send requests, forward notifications and correlate responses.
const { spawn } = require('node:child_process');
const { EventEmitter } = require('node:events');

const HEADER_END = Buffer.from('\r\n\r\n', 'ascii');
const LENGTH = /content-length:\s*(\d+)/i;

class Connection extends EventEmitter {
  constructor(command, args, { cwd, env } = {}) {
    super();
    this.nextId = 1;
    this.pending = new Map();
    this.buffer = Buffer.alloc(0);
    this.exited = false;
    this.child = spawn(command, args ?? [], {
      cwd,
      env: { ...process.env, ...(env ?? {}) },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    this.child.stdout.on('data', chunk => this.receive(chunk));
    this.child.stderr.on('data', chunk => this.emit('stderr', chunk.toString()));
    this.child.on('error', error => this.fail(error));
    this.child.on('exit', (code, signal) => {
      this.exited = true;
      this.fail(new Error(`the Grail language server exited (${signal ?? code})`));
      this.emit('exit', code);
    });
  }

  // Send a request and resolve with its result. A JSON-RPC error rejects.
  request(method, params) {
    if (this.exited) return Promise.reject(new Error('the Grail language server is not running'));
    const id = this.nextId;
    this.nextId += 1;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject, method });
      this.send({ jsonrpc: '2.0', id, method, params });
    });
  }

  notify(method, params) {
    if (this.exited) return;
    this.send({ jsonrpc: '2.0', method, params });
  }

  send(message) {
    const json = Buffer.from(JSON.stringify(message), 'utf8');
    const header = Buffer.from(`Content-Length: ${json.length}\r\n\r\n`, 'ascii');
    try {
      this.child.stdin.write(Buffer.concat([header, json]));
    } catch (error) {
      this.fail(error);
    }
  }

  receive(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    for (;;) {
      const end = this.buffer.indexOf(HEADER_END);
      if (end < 0) return;
      const header = this.buffer.subarray(0, end).toString('ascii');
      const length = LENGTH.exec(header);
      const start = end + HEADER_END.length;
      if (!length) {
        // No usable length: this frame cannot be bounded, so drop its header and resynchronise.
        this.buffer = this.buffer.subarray(start);
        continue;
      }
      const size = Number(length[1]);
      if (this.buffer.length < start + size) return;
      const body = this.buffer.subarray(start, start + size).toString('utf8');
      this.buffer = this.buffer.subarray(start + size);
      let message;
      try {
        message = JSON.parse(body);
      } catch (error) {
        this.emit('stderr', `unparseable message from the server: ${error.message}\n`);
        continue;
      }
      this.dispatch(message);
    }
  }

  dispatch(message) {
    if (message && message.method !== undefined) {
      if (message.id !== undefined && message.id !== null) {
        // The server sends no requests of its own; answer anything unexpected as unimplemented.
        this.send({ jsonrpc: '2.0', id: message.id, error: { code: -32601, message: 'method not found' } });
        return;
      }
      this.emit('notification', message);
      return;
    }
    const waiter = this.pending.get(message?.id);
    if (!waiter) return;
    this.pending.delete(message.id);
    if (message.error) waiter.reject(new Error(`${waiter.method}: ${message.error.message ?? JSON.stringify(message.error)}`));
    else waiter.resolve(message.result);
  }

  fail(error) {
    for (const waiter of this.pending.values()) waiter.reject(error);
    this.pending.clear();
  }

  // Ask the server to shut down, then end the process. Idempotent.
  async close() {
    if (!this.exited) {
      try {
        await Promise.race([this.request('shutdown', null), new Promise(resolve => setTimeout(resolve, 1000))]);
        this.notify('exit', null);
      } catch (error) {
        // A server that already failed has nothing to shut down.
      }
    }
    if (this.child.stdin.writable) this.child.stdin.end();
    setTimeout(() => {
      if (!this.exited) this.child.kill();
    }, 1000).unref?.();
  }
}

module.exports = { Connection };
