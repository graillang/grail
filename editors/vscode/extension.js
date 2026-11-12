'use strict';
// Grail for VS Code: the TextMate grammar in syntaxes/ highlights the language, and this file
// starts the Grail language server (tools/lsp/main.grl in a checkout, run by tools/lsp.mjs) and
// wires its diagnostics and definition support into the editor.
//
// The client is written here rather than pulled from `vscode-languageclient` because the server
// advertises two things: full-text synchronisation and textDocument/definition. Sending those and
// publishing textDocument/publishDiagnostics is all this extension has to do, so it carries no
// runtime dependency at all.
const path = require('node:path');
const vscode = require('vscode');
const { Connection } = require('./lib/rpc');

const LANGUAGE = 'grail';
const SELECTOR = [{ language: LANGUAGE }];

/** @type {import('./lib/rpc').Connection | null} */
let connection = null;
/** @type {vscode.OutputChannel | null} */
let output = null;
/** @type {vscode.DiagnosticCollection | null} */
let diagnostics = null;
let starting = false;
let queuedRestart = false;
let reportedFailure = false;

function settings() {
  const config = vscode.workspace.getConfiguration('grail');
  return {
    command: config.get('server.path', 'bun'),
    args: config.get('server.args', ['tools/lsp.mjs']),
    cwd: config.get('server.cwd', ''),
  };
}

function firstFolder() {
  const folders = vscode.workspace.workspaceFolders;
  return folders && folders.length > 0 ? folders[0].uri : undefined;
}

// `tools/lsp.mjs` is relative to the checkout, so an unset directory means the workspace folder.
function workdir(configured) {
  if (configured) return path.isAbsolute(configured) ? configured : path.join(firstFolder()?.fsPath ?? process.cwd(), configured);
  return firstFolder()?.fsPath ?? process.cwd();
}

function log(text) {
  output?.appendLine(text);
}

function report(error) {
  const message = error instanceof Error ? error.message : String(error);
  log(`error: ${message}`);
  if (!reportedFailure) {
    reportedFailure = true;
    const { command, args } = settings();
    vscode.window.showErrorMessage(
      `Grail: cannot start the language server (\`${command} ${args.join(' ')}\`): ${message}. ` +
        'Set `grail.server.path` and `grail.server.args` to the command that serves the Grail language server (see editors/README.md).',
    );
  }
}

function open(document) {
  if (!connection) return;
  connection.notify('textDocument/didOpen', {
    textDocument: { uri: document.uri.toString(), languageId: LANGUAGE, version: document.version, text: document.getText() },
  });
}

function change(document) {
  if (!connection) return;
  connection.notify('textDocument/didChange', {
    textDocument: { uri: document.uri.toString(), version: document.version },
    contentChanges: [{ text: document.getText() }],
  });
}

function close(document) {
  if (!connection) return;
  connection.notify('textDocument/didClose', { textDocument: { uri: document.uri.toString() } });
  diagnostics?.delete(document.uri);
}

function publish(params) {
  if (!params || typeof params.uri !== 'string') return;
  const uri = vscode.Uri.parse(params.uri);
  const items = Array.isArray(params.diagnostics) ? params.diagnostics.map(toDiagnostic) : [];
  diagnostics?.set(uri, items);
}

function toDiagnostic(item) {
  const { start, end } = item.range ?? { start: { line: 0, character: 0 }, end: { line: 0, character: 0 } };
  const range = new vscode.Range(start.line, start.character, end.line, end.character);
  const diagnostic = new vscode.Diagnostic(range, item.message ?? '', severity(item.severity));
  if (item.source) diagnostic.source = item.source;
  return diagnostic;
}

function severity(value) {
  switch (value) {
    case 1:
      return vscode.DiagnosticSeverity.Error;
    case 2:
      return vscode.DiagnosticSeverity.Warning;
    case 3:
      return vscode.DiagnosticSeverity.Information;
    default:
      return vscode.DiagnosticSeverity.Hint;
  }
}

function notify(message) {
  if (message.method === 'textDocument/publishDiagnostics') {
    publish(message.params);
    return;
  }
  if (message.method === 'window/showMessage') {
    const text = message.params?.message ?? '';
    log(`server: ${text}`);
    // 1 error, 2 warning, 3 info, 4 log. The server reports a missing compiler this way.
    if (message.params?.type === 1) vscode.window.showErrorMessage(`Grail: ${text}`);
    else if (message.params?.type === 2) vscode.window.showWarningMessage(`Grail: ${text}`);
    return;
  }
  log(`server notification: ${message.method}`);
}

async function stop() {
  const current = connection;
  connection = null;
  if (current) await current.close().catch(() => undefined);
  diagnostics?.clear();
}

async function start() {
  if (starting) {
    queuedRestart = true;
    return;
  }
  starting = true;
  try {
    await stop();
    reportedFailure = false;
    const { command, args, cwd } = settings();
    const directory = workdir(cwd);
    log(`starting the Grail language server: ${command} ${args.join(' ')} (in ${directory})`);
    const client = new Connection(command, args, { cwd: directory });
    client.on('notification', notify);
    client.on('stderr', text => log(text.trimEnd()));
    client.on('exit', code => {
      if (connection === client) connection = null;
      if (code !== 0) log(`the language server exited with status ${code}`);
    });
    connection = client;
    await client.request('initialize', {
      processId: process.pid,
      clientInfo: { name: 'grail-editors' },
      rootUri: firstFolder()?.toString() ?? null,
      capabilities: {
        textDocument: {
          synchronization: { dynamicRegistration: false, didSave: false, willSave: false },
          definition: { dynamicRegistration: false, linkSupport: false },
          publishDiagnostics: { relatedInformation: false, versionSupport: true },
        },
        workspace: { workspaceFolders: false, configuration: false },
      },
    });
    client.notify('initialized', {});
    for (const document of vscode.workspace.textDocuments) {
      if (document.languageId === LANGUAGE) open(document);
    }
    log('the language server is ready');
  } catch (error) {
    report(error);
    await stop();
  } finally {
    starting = false;
    if (queuedRestart) {
      queuedRestart = false;
      await start();
    }
  }
}

function definitionProvider() {
  return {
    async provideDefinition(document, position) {
      if (!connection) return undefined;
      const result = await connection.request('textDocument/definition', {
        textDocument: { uri: document.uri.toString() },
        position: { line: position.line, character: position.character },
      });
      if (!result || typeof result.uri !== 'string') return undefined;
      const start = result.range?.start ?? { line: 0, character: 0 };
      const end = result.range?.end ?? start;
      return new vscode.Location(vscode.Uri.parse(result.uri), new vscode.Range(start.line, start.character, end.line, end.character));
    },
  };
}

function activate(context) {
  output = vscode.window.createOutputChannel('Grail language server');
  diagnostics = vscode.languages.createDiagnosticCollection('grail');
  context.subscriptions.push(output, diagnostics);

  context.subscriptions.push(
    vscode.languages.registerDefinitionProvider(SELECTOR, definitionProvider()),
    vscode.commands.registerCommand('grail.restartServer', () => start()),
    vscode.workspace.onDidOpenTextDocument(document => {
      if (document.languageId === LANGUAGE) open(document);
    }),
    vscode.workspace.onDidChangeTextDocument(event => {
      if (event.document.languageId === LANGUAGE) change(event.document);
    }),
    vscode.workspace.onDidCloseTextDocument(document => {
      if (document.languageId === LANGUAGE) close(document);
    }),
    vscode.workspace.onDidChangeConfiguration(event => {
      if (event.affectsConfiguration('grail.server')) start();
    }),
    vscode.commands.registerCommand('grail.showOutput', () => output.show()),
    { dispose: () => void stop() },
  );

  return start();
}

async function deactivate() {
  await stop();
  output?.dispose();
  output = null;
  diagnostics?.dispose();
  diagnostics = null;
}

module.exports = { activate, deactivate };
