// The Debug Adapter Protocol server (tools/dap.mjs) against a real gdb and a real debug build.
//
// Builds one program with `--debug`, then speaks DAP to the adapter exactly as an editor would:
// initialize, setBreakpoints, launch, stopped, threads, stackTrace, scopes, variables (a struct's
// fields through gdb's DWARF), next, output events, continue to exit, terminate. The assertions are
// about what a client sees, not about gdb's internals.
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { root } from './platforms.mjs';

function findCompiler() {
  for (const candidate of [process.env.GRAIL_COMPILER, process.env.GRAIL_LSP_COMPILER]) {
    if (candidate && existsSync(candidate)) return resolve(candidate);
  }
  const installed = spawnSync('sh', ['-c', 'command -v grail'], { encoding: 'utf8' });
  if (installed.status === 0 && installed.stdout.trim()) return installed.stdout.trim();
  const directory = join(root, 'dist');
  if (existsSync(directory)) {
    const names = readdirSync(directory).filter(name => name.startsWith('grail-') && name.endsWith('-linux-x86_64-compiler')).sort().reverse();
    if (names.length) return join(directory, names[0]);
  }
  return null;
}
function run(argv, options = {}) {
  const result = spawnSync(argv[0], argv.slice(1), { cwd: root, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options });
  if (result.error) throw result.error;
  return result;
}
function ok(argv, options = {}) {
  const result = run(argv, options);
  assert.equal(result.status, 0, `${argv.join(' ')} failed\n${result.stdout}${result.stderr}`);
  return result;
}

// A DAP client: Content-Length framing in both directions, responses matched by request_seq, events
// collected as they arrive and awaitable.
class Client {
  constructor(argv) {
    this.child = spawn(process.execPath, argv, { cwd: root, stdio: ['pipe', 'pipe', 'pipe'] });
    this.buffer = '';
    this.seq = 0;
    this.pending = new Map();
    this.events = [];
    this.waiters = [];
    this.output = '';
    this.child.stdout.setEncoding('utf8');
    this.child.stdout.on('data', (chunk) => this.consume(chunk));
    this.child.stderr.setEncoding('utf8');
    this.child.stderr.on('data', (chunk) => { this.output += chunk; });
  }
  consume(chunk) {
    this.buffer += chunk;
    while (true) {
      const header = this.buffer.indexOf('\r\n\r\n');
      if (header < 0) return;
      const length = Number(/Content-Length:\s*(\d+)/i.exec(this.buffer.slice(0, header))?.[1] ?? -1);
      assert.ok(length >= 0, `bad DAP header: ${this.buffer.slice(0, header)}`);
      if (this.buffer.length < header + 4 + length) return;
      const message = JSON.parse(this.buffer.slice(header + 4, header + 4 + length));
      this.buffer = this.buffer.slice(header + 4 + length);
      this.message(message);
    }
  }
  message(message) {
    if (message.type === 'response') {
      const pending = this.pending.get(message.request_seq);
      this.pending.delete(message.request_seq);
      if (!pending) return;
      if (message.success) pending.resolve(message.body);
      else pending.reject(new Error(`${pending.command}: ${message.message}`));
      return;
    }
    if (message.type === 'event') {
      this.events.push(message);
      if (message.event === 'output') this.output += message.body.output;
      for (const waiter of [...this.waiters]) {
        if (waiter.event !== message.event) continue;
        this.waiters.splice(this.waiters.indexOf(waiter), 1);
        waiter.resolve(message);
      }
    }
  }
  request(command, args) {
    const seq = ++this.seq;
    const body = JSON.stringify({ seq, type: 'request', command, arguments: args });
    const promise = new Promise((resolve, reject) => this.pending.set(seq, { resolve, reject, command }));
    this.child.stdin.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
    return promise;
  }
  waitFor(event, timeout = 20_000) {
    const seen = this.events.find((one) => one.event === event);
    if (seen) return Promise.resolve(seen);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`timed out waiting for ${event}\n${this.output}`)), timeout);
      this.waiters.push({ event, resolve: (message) => { clearTimeout(timer); resolve(message); } });
    });
  }
  stop() { try { this.child.kill(); } catch { /* gone */ } }
}

const compiler = findCompiler();
if (!compiler) {
  console.error('dap: no Grail compiler found; set GRAIL_COMPILER');
  process.exit(2);
}
if (run(['gdb', '--version']).status !== 0) {
  console.error('dap: gdb is required (the adapter drives gdb over MI)');
  process.exit(2);
}

const work = mkdtempSync(join(tmpdir(), 'grail-dap-'));
const client = new Client([join(root, 'tools/dap.mjs')]);
try {
  const source = join(work, 'main.grl');
  writeFileSync(source, [
    'struct Point {',
    '    x: i64,',
    '    y: i64',
    '}',
    'enum Shape {',
    '    Circle(f64),',
    '    Square(u64)',
    '}',
    'fn dist(p: Point) -> i64 {',
    '    return p.x + p.y;',
    '}',
    'fn main() {',
    '    p := Point { x: 3, y: 4 };',
    '    mut total = dist(p);',
    '    mut values = u64[1, 2, 3];',
    '    values.push(9);',
    '    s := Shape::Square(7);',
    '    println(total);',
    '    println(values.len());',
    '    println(1);',
    '}',
    '',
  ].join('\n'));
  const assembly = join(work, 'main.s');
  const executable = join(work, 'main');
  ok([compiler, '--target', 'x86_64', '--debug', assembly, source, join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')]);
  ok(['clang', '--target=x86_64-linux-gnu', '-c', assembly, '-o', `${executable}.o`]);
  ok(['ld.lld', '-m', 'elf_x86_64', `${executable}.o`, '-o', executable]);
  const lineOf = (needle) => readFileSync(source, 'utf8').split('\n').findIndex((row) => row.includes(needle)) + 1;
  const breakpointLine = lineOf('println(values.len())');

  // 1. initialize / setBreakpoints / launch: the client gets `initialized`, verified breakpoints and
  //    a stopped event at the line it asked for.
  const capabilities = await client.request('initialize', { adapterID: 'grail', clientID: 'grail-test', linesStartAt1: true, columnsStartAt1: true, pathFormat: 'path' });
  assert.equal(capabilities.supportsConfigurationDoneRequest, true, 'configurationDone is supported');
  await client.waitFor('initialized');
  const placed = await client.request('setBreakpoints', { source: { path: source }, breakpoints: [{ line: breakpointLine }] });
  assert.equal(placed.breakpoints.length, 1, 'the breakpoint was not recorded');
  assert.equal(placed.breakpoints[0].line, breakpointLine, 'the breakpoint line was not echoed');
  await client.request('launch', { program: executable });
  // Before launch a breakpoint can only be recorded; the adapter reports the verified one as a
  // DAP `breakpoint` event once gdb has a program to insert it into.
  const verified = await client.waitFor('breakpoint');
  assert.equal(verified.body.breakpoint.verified, true, `breakpoint not verified: ${JSON.stringify(verified.body)}`);
  const stopped = await client.waitFor('stopped');
  assert.equal(stopped.body.reason, 'breakpoint', `stopped for ${stopped.body.reason}`);

  // 2. threads / stackTrace / scopes: one thread, a frame in our file, and a Locals scope.
  const threads = await client.request('threads', {});
  assert.ok(threads.threads.length >= 1, 'no threads');
  const threadId = threads.threads[0].id;
  const stack = await client.request('stackTrace', { threadId, startFrame: 0, levels: 20 });
  assert.ok(stack.stackFrames.length >= 1, 'no frames');
  const top = stack.stackFrames[0];
  assert.equal(top.source?.path, source, `top frame is ${JSON.stringify(top.source)}`);
  assert.equal(top.line, breakpointLine, `top frame line ${top.line}`);
  const scopes = await client.request('scopes', { frameId: top.id });
  assert.ok(scopes.scopes.some((scope) => scope.name === 'Locals'), `no Locals scope: ${JSON.stringify(scopes)}`);

  // 3. variables: a scalar, a record handle whose fields a client expands, and an enum tag - read
  //    through the DWARF the compiler wrote, so the names and values are the program's.
  const locals = scopes.scopes.find((scope) => scope.name === 'Locals');
  const variables = await client.request('variables', { variablesReference: locals.variablesReference });
  const byName = (list, name) => list.find((one) => one.name === name);
  assert.equal(byName(variables, 'total')?.value, '7', `total: ${JSON.stringify(variables)}`);
  const point = byName(variables, 'p');
  assert.ok(point, `no local p: ${JSON.stringify(variables)}`);
  assert.ok(point.variablesReference > 0, 'the record p is not expandable');
  const fields = await client.request('variables', { variablesReference: point.variablesReference });
  const field = (name) => fields.find((one) => String(one.name).endsWith(name));
  assert.equal(field('x')?.value, '3', `p.x: ${JSON.stringify(fields)}`);
  assert.equal(field('y')?.value, '4', `p.y: ${JSON.stringify(fields)}`);
  const enumValue = byName(variables, 's');
  assert.ok(enumValue, `no local s: ${JSON.stringify(variables)}`);

  // 4. next: a step stops again, at the next statement, and the program's own output arrives as
  //    `output` events.
  await client.request('next', { threadId });
  const stepped = await client.waitFor('stopped');
  assert.equal(stepped.body.reason, 'step', `stepped for ${stepped.body.reason}`);
  const steppedStack = await client.request('stackTrace', { threadId });
  assert.ok(steppedStack.stackFrames[0].line > breakpointLine, 'next did not advance the line');

  // 5. continue to the end: an exited event, then terminated.
  client.events.length = 0;
  await client.request('continue', { threadId });
  await client.waitFor('exited');
  await client.waitFor('terminated');
  for (const expected of ['7', '4']) assert.ok(client.output.includes(expected), `no output event carried ${expected}: ${client.output}`);

  // 6. terminate is answered and the adapter exits.
  const terminated = await client.request('terminate', {});
  assert.equal(terminated, undefined, 'terminate returns no body');
  await new Promise((resolve) => client.child.on('exit', resolve));
  console.log('dap: initialize/setBreakpoints/launch/stopped/threads/stackTrace/scopes/variables/next/continue/terminate verified');
  console.log('dap: struct fields (p.x, p.y) and locals read through DWARF; program output delivered as output events');
} finally {
  client.stop();
  rmSync(work, { recursive: true, force: true });
}
