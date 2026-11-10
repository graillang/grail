#!/usr/bin/env bun
// Launcher for the Grail language server. The server itself is the Grail program in
// tools/lsp/main.grl; this only builds it from this tree (cached by source digest) and
// hands it this process's stdio, which is the transport an editor expects.
import { spawn } from 'node:child_process';
import { join } from 'node:path';
import { buildCompiler, compileProgram, root } from './native.mjs';

// lib/json.grl is the server's JSON reader; it needs core and the map module to compile.
export const serverSources = [
  'tools/lsp/main.grl',
  'compiler/lexer.grl',
  'lib/core.grl',
  'lib/hash.grl',
  'lib/hashmap.grl',
  'lib/json.grl',
];

export function buildServer({ directory = join(root, '.work/lsp'), compiler = buildCompiler() } = {}) {
  return compileProgram(compiler, serverSources, directory, { name: 'grail-lsp', typedRefs: true });
}

if (import.meta.main) {
  const compiler = buildCompiler();
  const child = spawn(buildServer({ compiler }), [], {
    stdio: 'inherit',
    // The compiler this checkout just built is the one the server should check with, so a
    // fresh worktree needs no configuration. An installed setup overrides it.
    env: { ...process.env, GRAIL_LSP_COMPILER: process.env.GRAIL_LSP_COMPILER ?? compiler },
  });
  child.on('exit', code => process.exit(code ?? 1));
  child.on('error', error => {
    process.stderr.write(`grail lsp: cannot start the server: ${error.message}\n`);
    process.exit(1);
  });
}
