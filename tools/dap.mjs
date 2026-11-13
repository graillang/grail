#!/usr/bin/env bun
// A Debug Adapter Protocol server for Grail programs, driving gdb over its MI interface.
//
// The adapter is deliberately thin: gdb owns the program, the breakpoints and the DWARF, and this
// file only translates. `initialize`, `setBreakpoints`, `launch`/`attach`-less `launch`, `threads`,
// `stackTrace`, `scopes`, `variables`, `continue`/`next`/`stepIn`/`stepOut`, `output` events,
// `terminate` and `disconnect` are implemented; anything else is answered `success: false` with the
// DAP `not supported` message rather than pretended.
//
//   bun tools/dap.mjs --program target/hello       # or launch.program from the client
//
// A client (VS Code, nvim-dap, `tools/test-dap.mjs`) speaks Content-Length framed JSON on stdio.
// Debug information comes from `grail build --debug` (docs/tooling/debugging.md), so variables appear
// with the types the compiler wrote: a record is a handle (`*p` in gdb, `*p` here), an enum prints
// its variant tag, a sequence is `{data, len, cap}`.
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';

const notSupported = (message) => ({ success: false, message: message ?? 'not supported by the Grail debug adapter' });

// ---- MI value parsing ------------------------------------------------------------------------
// gdb's MI values are nested: `a="b"`, `c={d="e"}`, `f=[{g="h"},{i="j"}]`, `k=1`. This is the whole
// grammar the adapter needs, and it returns plain objects and arrays.
class MiParser {
  constructor(text) { this.text = text; this.at = 0; }
  value() {
    const ch = this.text[this.at];
    if (ch === '"') return this.string();
    if (ch === '{') return this.tuple();
    if (ch === '[') return this.list();
    return this.atom();
  }
  string() {
    this.at += 1;
    let out = '';
    while (this.at < this.text.length) {
      const ch = this.text[this.at];
      if (ch === '\\') { out += this.escape(); continue; }
      if (ch === '"') { this.at += 1; return out; }
      out += ch;
      this.at += 1;
    }
    return out;
  }
  escape() {
    const ch = this.text[this.at + 1];
    this.at += 2;
    if (ch === 'n') return '\n';
    if (ch === 't') return '\t';
    if (ch === 'r') return '\r';
    if (ch === 'a') return '\x07';
    if (ch === 'b') return '\b';
    if (ch === 'f') return '\f';
    if (ch === 'v') return '\v';
    if (ch === '"' || ch === '\\' || ch === "'") return ch;
    return ch;
  }
  tuple() {
    this.at += 1;
    const out = {};
    while (this.at < this.text.length) {
      while (this.text[this.at] === ',') this.at += 1;
      if (this.text[this.at] === '}') { this.at += 1; return out; }
      const key = this.name();
      if (this.text[this.at] !== '=') { out[key] = ''; continue; }
      this.at += 1;
      out[key] = this.value();
    }
    return out;
  }
  list() {
    this.at += 1;
    const out = [];
    while (this.at < this.text.length) {
      while (this.text[this.at] === ',') this.at += 1;
      if (this.text[this.at] === ']') { this.at += 1; return out; }
      if (this.text[this.at] === '=') this.at += 1;
      out.push(this.value());
    }
    return out;
  }
  name() {
    const start = this.at;
    while (this.at < this.text.length && !'=,}'.includes(this.text[this.at])) this.at += 1;
    return this.text.slice(start, this.at);
  }
  atom() {
    const start = this.at;
    while (this.at < this.text.length && !',}]'.includes(this.text[this.at])) this.at += 1;
    return this.text.slice(start, this.at);
  }
}
// `key1="v1",key2={...},key3=[...]` (the tail of a ^done/*stopped record) as an object.
function miResults(text) {
  const out = {};
  let at = 0;
  while (at < text.length) {
    const eq = text.indexOf('=', at);
    if (eq < 0) break;
    const key = text.slice(at, eq);
    const parser = new MiParser(text);
    parser.at = eq + 1;
    out[key] = parser.value();
    at = parser.at;
    if (text[at] === ',') at += 1;
  }
  return out;
}

// ---- gdb -------------------------------------------------------------------------------------
// One gdb process, MI commands serialised, async records turned into events. `send` resolves with
// the ^done record's results (or rejects with the ^error message).
class Gdb {
  constructor(program, cwd, onEvent) {
    this.program = program;
    this.cwd = cwd;
    this.onEvent = onEvent;
    this.pending = [];
    this.buffer = '';
    this.sequence = 0;
    this.child = null;
    this.exited = false;
  }
  async start() {
    const argv = [process.env.GRAIL_GDB ?? 'gdb', '-q', '-nw', '--interpreter=mi2', '--args', this.program];
    this.child = spawn(argv[0], argv.slice(1), { cwd: this.cwd, stdio: ['pipe', 'pipe', 'pipe'] });
    this.child.on('error', (error) => this.finish(error));
    this.child.on('exit', (code, signal) => this.finish(`gdb exited (${signal ?? code})`));
    this.child.stdout.setEncoding('utf8');
    this.child.stdout.on('data', (chunk) => this.consume(chunk));
    this.child.stderr.setEncoding('utf8');
    this.child.stderr.on('data', (chunk) => this.onEvent({ event: 'output', body: { category: 'stderr', output: chunk } }));
    await this.send('-gdb-set confirm off');
    await this.send('-gdb-set pagination off');
    await this.send('-gdb-set debuginfod enabled off');
    await this.send('-enable-pretty-printing');
  }
  finish(reason) {
    if (this.exited) return;
    this.exited = true;
    for (const pending of this.pending.splice(0)) pending.reject(new Error(reason ?? 'gdb exited'));
    this.onEvent({ event: 'terminated', reason, gdb: true });
  }
  consume(chunk) {
    this.buffer += chunk;
    let newline;
    while ((newline = this.buffer.indexOf('\n')) >= 0) {
      const line = this.buffer.slice(0, newline).replace(/\r$/, '');
      this.buffer = this.buffer.slice(newline + 1);
      this.line(line);
    }
  }
  line(line) {
    if (line === '' || line === '(gdb)' || line.startsWith('=') && line.startsWith('=library-loaded')) return;
    const kind = line[0];
    if (kind === '^') {
      const body = line.slice(1);
      const space = body.indexOf(',');
      const status = space < 0 ? body : body.slice(0, space);
      const results = miResults(space < 0 ? '' : body.slice(space + 1));
      const pending = this.pending.shift();
      if (!pending) return;
      if (status === 'done' || status === 'running' || status === 'connected') pending.resolve(results);
      else pending.reject(new Error(results.msg ?? status));
      return;
    }
    if (kind === '*') {
      const body = line.slice(1);
      const space = body.indexOf(',');
      const status = space < 0 ? body : body.slice(0, space);
      const results = miResults(space < 0 ? '' : body.slice(space + 1));
      this.onEvent({ event: 'mi', name: status, results });
      return;
    }
    if (kind === '~' || kind === '@' || kind === '&') {
      const text = new MiParser(line.slice(1)).value();
      const category = kind === '~' ? 'console' : (kind === '@' ? 'stdout' : 'log');
      if (text.length) this.onEvent({ event: 'output', body: { category, output: text } });
      return;
    }
    if (kind === '=') return;
    this.onEvent({ event: 'output', body: { category: 'log', output: `${line}\n` } });
  }
  send(command) {
    if (this.exited) return Promise.reject(new Error('gdb is not running'));
    return new Promise((resolve, reject) => {
      this.pending.push({ resolve, reject });
      this.child.stdin.write(`${command}\n`);
    });
  }
  stop() {
    try { this.child?.stdin.write('-gdb-exit\n'); } catch { /* already gone */ }
    try { this.child?.kill(); } catch { /* already gone */ }
  }
}

// ---- DAP -------------------------------------------------------------------------------------
const text = (out) => {
  const body = JSON.stringify(out);
  return `Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`;
};
const write = (out) => process.stdout.write(text(out));
const quote = (value) => (typeof value === 'string' ? `"${value.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"` : String(value));
// A gdb `file:line` breakpoint, or `file:line` with a column the adapter drops (gdb has no columns).
const location = (breakpoint) => `${breakpoint.source.path}:${breakpoint.line ?? 1}`;

class Session {
  constructor(argv) {
    this.argv = argv;
    this.gdb = null;
    this.seq = 0;
    // variablesReference bookkeeping: id -> {kind, frameId, threadId, name}
    this.handles = new Map();
    this.nextHandle = 1;
    this.varObjects = new Map();
    this.breakpoints = new Map();
    this.threadList = [];
    this.stopped = null;
    this.lastFrames = [];
    this.terminated = false;
  }
  handle(kind, data) {
    const id = this.nextHandle++;
    this.handles.set(id, { kind, ...data });
    return id;
  }
  event(event, body) {
    write({ seq: ++this.seq, type: 'event', event, body });
  }
  respond(request, body) {
    write({ seq: ++this.seq, type: 'response', request_seq: request.seq, success: true, command: request.command, body });
  }
  fail(request, message) {
    write({ seq: ++this.seq, type: 'response', request_seq: request.seq, success: false, command: request.command, message });
  }
  // gdb -> DAP events
  onGdbEvent(record) {
    if (record.event === 'output') {
      this.event('output', record.body);
      return;
    }
    if (record.event === 'terminated') {
      if (this.terminated) return;
      this.terminated = true;
      this.event('exited', { exitCode: 0 });
      this.event('terminated');
      return;
    }
    if (record.event === 'mi' && record.name === 'stopped') {
      const results = record.results;
      const threadId = Number(results['thread-id'] ?? 1);
      const frames = results.frame ? [results.frame] : [];
      this.stopped = { threadId, reason: this.reasonOf(results), frames };
      if (results.frame) this.lastFrames = frames.map((frame) => ({
        id: Number(frame.level ?? 0), name: frame.func ?? '?', source: frame.file ? { name: frame.file.split('/').pop(), path: frame.file } : undefined,
        line: Number(frame.line ?? 0), column: 0,
      }));
      if (results['stopped-threads'] === 'all' || results['thread-id']) this.event('stopped', { reason: this.stopped.reason, threadId, allThreadsStopped: true });
    }
  }
  reasonOf(results) {
    if (results.reason === 'exited-normally' || results.reason === 'exited') return 'exited';
    if (results.reason === 'breakpoint-hit') return 'breakpoint';
    if (results.reason === 'end-stepping-range') return 'step';
    if (results.reason === 'function-finished') return 'step';
    if (results.reason === 'signal-received') return 'exception';
    return 'breakpoint';
  }
  async initialize(request) {
    this.respond(request, {
      supportsConfigurationDoneRequest: true,
      supportsFunctionBreakpoints: false,
      supportsConditionalBreakpoints: true,
      supportsEvaluateForHovers: false,
      supportsTerminateRequest: true,
      supportsSingleThreadExecutionRequests: false,
      supportsRestartRequest: false,
      supportsStepBack: false,
      exceptionBreakpointFilters: [],
    });
    this.event('initialized');
  }
  async launch(request) {
    const args = request.arguments ?? {};
    const program = args.program ?? this.argv.program;
    if (!program) throw new Error('launch needs a "program" (the built binary)');
    if (!existsSync(program)) throw new Error(`no such program: ${program}`);
    this.gdb = new Gdb(program, args.cwd ?? process.cwd(), (record) => this.onGdbEvent(record));
    await this.gdb.start();
    // Breakpoints a client set before launch were recorded but not placed: gdb can only insert one
    // into a program it has loaded. Place them now and tell the client which ones became real, which
    // is how DAP says "verified later" (a `breakpoint` event with reason "changed").
    for (const [path, list] of this.breakpoints) {
      for (const breakpoint of list) {
        if (!breakpoint.line) continue;
        const answer = { ...breakpoint };
        try {
          const results = await this.gdb.send(`-break-insert ${quote(location(breakpoint))}`);
          const placed = results.bkpt ?? {};
          answer.verified = placed.number !== undefined;
          answer.gdb = placed.number;
          answer.line = Number(placed.line ?? breakpoint.line);
          Object.assign(breakpoint, answer);
          this.event('breakpoint', { reason: 'changed', breakpoint: answer });
        } catch (error) {
          answer.verified = false;
          answer.message = error.message;
          Object.assign(breakpoint, answer);
          this.event('breakpoint', { reason: 'changed', breakpoint: answer });
        }
      }
    }
    this.respond(request, {});
    this.gdb.send('-exec-run').catch((error) => this.event('output', { category: 'stderr', output: `${error.message}\n` }));
  }
  async setBreakpoints(request) {
    const args = request.arguments ?? {};
    const path = args.source?.path ?? args.source?.name;
    if (!path) throw new Error('setBreakpoints needs a source path');
    // Replace this source's breakpoints, keeping the client's ids stable by position in the list.
    const previous = this.breakpoints.get(path) ?? [];
    for (const breakpoint of previous) if (this.gdb) await this.gdb.send(`-break-delete ${breakpoint.gdb}`).catch(() => {});
    const list = args.breakpoints ?? [];
    const answered = [];
    const kept = [];
    for (const [index, requested] of list.entries()) {
      const wanted = { id: index + 1, verified: false, line: requested.line, source: { path } };
      if (!this.gdb) { answered.push(wanted); kept.push(wanted); continue; }
      try {
        const results = await this.gdb.send(`-break-insert ${quote(`${path}:${requested.line}`)}`);
        const breakpoint = results.bkpt ?? {};
        wanted.verified = breakpoint.number !== undefined;
        wanted.line = Number(breakpoint.line ?? requested.line);
        wanted.gdb = breakpoint.number;
        wanted.id = Number(breakpoint.number ?? index + 1);
        if (breakpoint.number === undefined) wanted.message = 'gdb did not place a breakpoint there';
      } catch (error) {
        wanted.message = error.message;
      }
      answered.push(wanted);
      kept.push(wanted);
    }
    this.breakpoints.set(path, kept);
    this.respond(request, { breakpoints: answered });
  }
  async configurationDone(request) { this.respond(request, {}); }
  async threads(request) {
    let list = [];
    if (this.gdb) {
      try {
        const results = await this.gdb.send('-thread-info');
        list = (results.threads ?? []).map((thread) => ({ id: Number(thread.id), name: thread.name ?? `Thread ${thread.id}`, state: thread.state ?? 'stopped' }));
      } catch { list = []; }
    }
    if (!list.length && this.stopped) list = [{ id: this.stopped.threadId, name: `Thread ${this.stopped.threadId}`, state: 'stopped' }];
    this.respond(request, { threads: list });
  }
  async stackTrace(request) {
    const args = request.arguments ?? {};
    const threadId = args.threadId ?? this.stopped?.threadId ?? 1;
    let frames = [];
    if (this.gdb) {
      try {
        // MI has no --thread on -stack-list-frames: the thread is selected first, and the command
        // then reports the stack of whatever is selected.
        if (this.stopped && this.stopped.threadId !== threadId) await this.gdb.send(`-thread-select ${threadId}`);
        const results = await this.gdb.send('-stack-list-frames');
        frames = (results.stack ?? []).map((entry, index) => {
          const frame = entry.frame ?? entry;
          const level = Number(frame.level ?? index);
          const source = frame.file ? { name: frame.file.split('/').pop(), path: frame.file } : undefined;
          return { id: level, name: frame.func ?? '?', line: Number(frame.line ?? 0), column: Number(frame.col ?? 0), source };
        });
      } catch (error) {
        this.event('output', { category: 'stderr', output: `stackTrace: ${error.message}\n` });
      }
    }
    if (!frames.length) frames = this.lastFrames.slice(0, args.levels ?? 20);
    this.respond(request, { stackFrames: frames.slice(args.startFrame ?? 0, (args.startFrame ?? 0) + (args.levels ?? 20)), totalFrames: frames.length });
  }
  async scopes(request) {
    const args = request.arguments ?? {};
    const frameId = Number(args.frameId ?? 0);
    const threadId = this.stopped?.threadId ?? 1;
    this.respond(request, {
      scopes: [
        { name: 'Locals', presentationHint: 'locals', variablesReference: this.handle('locals', { frameId, threadId }), expensive: false },
      ],
    });
  }
  async variables(request) {
    const args = request.arguments ?? {};
    const handle = this.handles.get(args.variablesReference);
    if (!handle) { this.respond(request, { variables: [] }); return; }
    if (!this.gdb) { this.respond(request, { variables: [] }); return; }
    if (handle.kind === 'locals' || handle.kind === 'arguments') {
      const thread = handle.threadId ?? 1;
      const frame = handle.frameId ?? 0;
      let rows = [];
      try {
        if (this.stopped && this.stopped.threadId !== thread) await this.gdb.send(`-thread-select ${thread}`);
        if (frame) await this.gdb.send(`-stack-select-frame ${frame}`);
        const results = await this.gdb.send('-stack-list-variables --simple-values');
        rows = results.variables ?? [];
      } catch (error) {
        this.event('output', { category: 'stderr', output: `variables: ${error.message}\n` });
      }
      // A variable gdb could evaluate is a value; one it could not is a varobj the client expands.
      const variables = [];
      for (const row of rows) {
        const entry = { name: row.name, value: row.value ?? '<not available>', type: row.type ?? '', variablesReference: 0 };
        if (row.value === undefined || row.children || /^\*\*|\[\]|\{[^}]*\}$/.test(row.value ?? '')) entry.variablesReference = this.handle('varobj', { expression: row.name, thread, frame });
        variables.push(entry);
      }
      this.respond(request, { variables });
      return;
    }
    if (handle.kind === 'varobj') {
      // A variable the client asked to expand: gdb's varobj machinery prints its children.
      const key = `${handle.expression}\u0000${handle.thread}\u0000${handle.frame}`;
      let name = this.varObjects.get(key);
      try {
        if (!name) {
          const created = await this.gdb.send(`-var-create - * ${handle.expression}`);
          name = created.name;
          this.varObjects.set(key, name);
        }
        const results = await this.gdb.send(`-var-list-children --all-values ${name}`);
        const variables = (results.children ?? []).map((child) => {
          const one = child.child ?? child;
          const entry = { name: one.exp ?? one.name, value: one.value ?? '<not available>', type: one.type ?? '', variablesReference: 0 };
          if (Number(one.numchild ?? 0) > 0) entry.variablesReference = this.handle('varobj', { expression: one.exp ?? one.name, thread: handle.thread, frame: handle.frame });
          return entry;
        });
        this.respond(request, { variables });
        return;
      } catch (error) {
        this.respond(request, { variables: [{ name: handle.expression, value: `<not available: ${error.message}>`, type: '', variablesReference: 0 }] });
        return;
      }
    }
    this.respond(request, { variables: [] });
  }
  async resume(request, command, reason) {
    if (!this.gdb) throw new Error('no program is running');
    this.respond(request, { allThreadsContinued: true });
    this.gdb.send(command).catch((error) => this.event('output', { category: 'stderr', output: `${reason}: ${error.message}\n` }));
  }
  async continue(request) { await this.resume(request, '-exec-continue', 'continue'); }
  async next(request) { await this.resume(request, '-exec-next', 'next'); }
  async stepIn(request) { await this.resume(request, '-exec-step', 'stepIn'); }
  async stepOut(request) { await this.resume(request, '-exec-finish', 'stepOut'); }
  async pause(request) { await this.resume(request, '-exec-interrupt', 'pause'); }
  async terminate(request) {
    this.respond(request, {});
    if (this.gdb) this.gdb.stop();
    process.exit(0);
  }
  async disconnect(request) {
    this.respond(request, {});
    if (this.gdb) this.gdb.stop();
    process.exit(0);
  }
}

async function main() {
    const argv = process.argv.slice(2);
    const options = {};
    for (let i = 0; i < argv.length; i++) if (argv[i] === '--program') options.program = argv[++i];
    const session = new Session(options);
    let buffer = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      buffer += chunk;
      while (true) {
        const header = buffer.indexOf('\r\n\r\n');
        if (header < 0) return;
        const length = Number(/Content-Length:\s*(\d+)/i.exec(buffer.slice(0, header))?.[1] ?? -1);
        if (length < 0) { buffer = buffer.slice(header + 4); continue; }
        if (buffer.length < header + 4 + length) return;
        const body = buffer.slice(header + 4, header + 4 + length);
        buffer = buffer.slice(header + 4 + length);
        let message;
        try { message = JSON.parse(body); } catch { continue; }
        dispatch(session, message);
      }
    });
    process.stdin.on('end', () => { if (session.gdb) session.gdb.stop(); });
}

async function dispatch(session, message) {
  if (message.type !== 'request') return;
  const handler = session[message.command];
  try {
    if (typeof handler !== 'function') { session.fail(message, `command ${message.command} is not supported`); return; }
    await handler.call(session, message);
  } catch (error) {
    session.fail(message, error?.message ?? String(error));
  }
}

if (process.argv[1] && process.argv[1].endsWith('dap.mjs')) await main();
