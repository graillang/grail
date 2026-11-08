import { buildCompiler, assemble, execute, hostTarget, targetName } from './native.mjs';
import { readFileSync, mkdirSync, writeFileSync, copyFileSync, rmSync } from 'node:fs';
import { resolve, dirname, relative, join } from 'node:path';
import { pathToFileURL } from 'node:url';

export const root = resolve(import.meta.dir, '..');
const source = join(root, 'book');
export const output = join(root, '.work/book/html');
const work = join(root, '.work/book');
const escape = text => String(text).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function sourcePath(path) {
  const result = resolve(source, path);
  if (relative(source, result).startsWith('..') || result === source) throw new Error(`Invalid book source: ${path}`);
  return result;
}
export function loadBook(manifest = join(source, 'book.json')) {
  const book = JSON.parse(readFileSync(manifest, 'utf8'));
  for (const [items, key] of [[book.chapters, 'slug'], [book.examples, 'id']]) {
    if (!Array.isArray(items) || !items.length) throw new Error('Empty book manifest');
    const seen = new Set();
    for (const item of items) {
      if (!/^[a-z][a-z0-9-]*$/.test(item[key]) || seen.has(item[key])) throw new Error(`Invalid/duplicate ${key}: ${item[key]}`);
      seen.add(item[key]);
    }
  }
  for (const example of book.examples) {
    if ((typeof example.output === 'string') === (typeof example.diagnostic === 'string')) throw new Error(`Example ${example.id} needs exactly one output or rejection diagnostic`);
    if (!example.rust || typeof example.rust.source !== 'string' || typeof example.rust.note !== 'string' || !example.rust.note.trim()) throw new Error(`Example ${example.id} needs a Rust comparison with source and note`);
    if ((typeof example.rust.output === 'string') === (typeof example.rust.diagnostic === 'string')) throw new Error(`Rust comparison ${example.id} needs output or diagnostic`);
    readFileSync(sourcePath(example.rust.source));
    if ((example.modules ?? []).length !== (example.rust.modules ?? []).length) throw new Error(`Example ${example.id} needs a Rust counterpart for each supporting module`);
    for (const path of example.rust.modules ?? []) readFileSync(sourcePath(path));
    for (const path of [example.entry, ...(example.modules ?? [])]) readFileSync(sourcePath(path));
  }
  return book;
}
export function expand(text, book, used = new Set()) {
  return text.replace(/\{\{(example|source):([^}]+)\}\}/g, (_, kind, id) => {
    if (kind === 'source') return `\n\`\`\`grl\n${readFileSync(sourcePath(id), 'utf8')}\`\`\`\n`;
    const example = book.examples.find(e => e.id === id);
    if (!example) throw new Error(`Unknown example: ${id}`);
    used.add(id);
    const code = readFileSync(sourcePath(example.entry), 'utf8');
    const codeBlock = (code, language, cls = '') => `<pre class="${cls}"><code class="language-${language}">${escape(code)}</code></pre>`;
    const outcome = (label, text, rejected) => `<div class="example-result${rejected ? ' rejection' : ''}"><div class="result-label">${label}</div>${codeBlock(text, 'text')}</div>`;
    const grailResult = example.diagnostic ? outcome('Expected compiler rejection', `Diagnostic contains: ${example.diagnostic}\n`, true) : outcome('Output', example.output, false);
    const command = codeBlock(`$ just book-run ${id}\n`, 'sh', 'run-command');
    const grail = `<section class="grail-column" aria-label="Grail example"><div class="code-heading"><strong>Grail</strong><span>${escape(example.entry)}</span></div>${codeBlock(code, 'grl', 'source-code')}${grailResult}${command}</section>`;
    const r = example.rust;
    const result = r.diagnostic ? outcome('Expected compiler rejection', `${r.diagnostic}\n`, true) : outcome('Output', r.output, false);
    const rust = `<details class="rust-column" open><summary><span class="compare-show">Compare Rust ＋</span><span class="compare-hide">Hide Rust −</span></summary><div class="code-heading"><strong>Rust</strong><span>${escape(r.source)}</span></div>${codeBlock(readFileSync(sourcePath(r.source), 'utf8'), 'rust', 'source-code')}${result}<p class="comparison-verified">Rust 2024 · overflow checks on · panic abort · checked by <code>just book-check</code></p></details>`;
    const note = `<div class="comparison-note"><strong>Notes</strong><p>${escape(r.note)}</p></div>`;
    const supporting = (example.modules ?? []).map((file, i) => {
      const other = r.modules[i];
      return `<div class="comparison-note"><strong>Supporting module files</strong></div><div class="example-grid"><section class="grail-column"><div class="code-heading"><strong>Grail</strong><span>${escape(file)}</span></div>${codeBlock(readFileSync(sourcePath(file), 'utf8'), 'grl', 'source-code')}</section><details class="rust-column" open><summary><span class="compare-show">Compare Rust ＋</span><span class="compare-hide">Hide Rust −</span></summary><div class="code-heading"><strong>Rust</strong><span>${escape(other)}</span></div>${codeBlock(readFileSync(sourcePath(other), 'utf8'), 'rust', 'source-code')}</details></div>`;
    }).join('');
    return `\n<figure class="example-workspace has-comparison" id="example-${id}"><figcaption>Example <span>${escape(id)}</span>${example.diagnostic ? '<em>intentional compile error</em>' : ''}</figcaption><div class="example-grid">${grail}${rust}</div>${note}${supporting}</figure>\n`;

  });
}
function page(book, chapter, index, html) {
  const link = (c, label, cls) => c ? `<a class="${cls}" href="${c.slug}.html">${label}<strong>${escape(c.title)}</strong></a>` : '<span></span>';
  const toc = book.chapters.map((c, i) => `<li><a href="${c.slug}.html" ${i === index ? 'aria-current="page"' : ''}><span>${String(i + 1).padStart(2, '0')}</span>${escape(c.title)}</a></li>`).join('');
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light dark"><meta name="description" content="Learn Grail through complete, compiler-checked examples."><title>${escape(chapter.title)} · ${escape(book.title)}</title><link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 128 128%22%3E %3Cg transform=%22rotate%28-8 64 64%29%22%3E %3Cpath d=%22M26 26h76c0 30-16 50-38 50S26 56 26 26z M54 74h20l3 16H51z M36 106c0-9 12-14 28-14s28 5 28 14z%22 fill=%22%23fff%22 stroke=%22%23fff%22 stroke-width=%2214%22 stroke-linejoin=%22round%22/%3E %3Cg stroke=%22%232a1a4a%22 stroke-width=%225%22 stroke-linejoin=%22round%22%3E %3Cpath d=%22M26 26h76c0 30-16 50-38 50S26 56 26 26z%22 fill=%22%23ffc53d%22/%3E %3Cpath d=%22M54 74h20l3 16H51z%22 fill=%22%23ffb020%22/%3E %3Cpath d=%22M36 106c0-9 12-14 28-14s28 5 28 14z%22 fill=%22%23ff9f1c%22/%3E %3C/g%3E %3Cpath d=%22M28 30c20 6 52 6 72 0%22 fill=%22none%22 stroke=%22%232a1a4a%22 stroke-width=%225%22 stroke-linecap=%22round%22/%3E %3Cellipse cx=%2250%22 cy=%2248%22 rx=%224.5%22 ry=%226%22 fill=%22%232a1a4a%22/%3E%3Cellipse cx=%2278%22 cy=%2248%22 rx=%224.5%22 ry=%226%22 fill=%22%232a1a4a%22/%3E %3Ccircle cx=%2251.5%22 cy=%2245.5%22 r=%221.6%22 fill=%22%23fff%22/%3E%3Ccircle cx=%2279.5%22 cy=%2245.5%22 r=%221.6%22 fill=%22%23fff%22/%3E %3Cpath d=%22M56 58c4 5 12 5 16 0%22 fill=%22none%22 stroke=%22%232a1a4a%22 stroke-width=%224.5%22 stroke-linecap=%22round%22/%3E %3Cellipse cx=%2241%22 cy=%2258%22 rx=%225%22 ry=%223%22 fill=%22%23ff7a8a%22 opacity=%22.7%22/%3E%3Cellipse cx=%2287%22 cy=%2258%22 rx=%225%22 ry=%223%22 fill=%22%23ff7a8a%22 opacity=%22.7%22/%3E %3C/g%3E %3Cpath d=%22M108 12l3 7 7 3-7 3-3 7-3-7-7-3 7-3z%22 fill=%22%237b5cff%22 stroke=%22%232a1a4a%22 stroke-width=%222.5%22 stroke-linejoin=%22round%22/%3E %3Cpath d=%22M14 78l2 5 5 2-5 2-2 5-2-5-5-2 5-2z%22 fill=%22%233ddcb0%22 stroke=%22%232a1a4a%22 stroke-width=%222%22 stroke-linejoin=%22round%22/%3E %3C/svg%3E"><link rel="stylesheet" href="theme.css"><script src="search.js" defer></script><script src="book.js" defer></script></head>
<body><a class="skip" href="#content">Skip to content</a><aside class="sidebar" id="sidebar"><a class="brand" href="index.html"><svg class="brand-mark" viewBox="0 0 128 128" aria-hidden="true" focusable="false"><g transform="rotate(-8 64 64)"> <path d="M26 26h76c0 30-16 50-38 50S26 56 26 26z M54 74h20l3 16H51z M36 106c0-9 12-14 28-14s28 5 28 14z" fill="#fff" stroke="#fff" stroke-width="14" stroke-linejoin="round"/> <g stroke="#2a1a4a" stroke-width="5" stroke-linejoin="round"> <path d="M26 26h76c0 30-16 50-38 50S26 56 26 26z" fill="#ffc53d"/> <path d="M54 74h20l3 16H51z" fill="#ffb020"/> <path d="M36 106c0-9 12-14 28-14s28 5 28 14z" fill="#ff9f1c"/> </g> <path d="M28 30c20 6 52 6 72 0" fill="none" stroke="#2a1a4a" stroke-width="5" stroke-linecap="round"/> <ellipse cx="50" cy="48" rx="4.5" ry="6" fill="#2a1a4a"/><ellipse cx="78" cy="48" rx="4.5" ry="6" fill="#2a1a4a"/> <circle cx="51.5" cy="45.5" r="1.6" fill="#fff"/><circle cx="79.5" cy="45.5" r="1.6" fill="#fff"/> <path d="M56 58c4 5 12 5 16 0" fill="none" stroke="#2a1a4a" stroke-width="4.5" stroke-linecap="round"/> <ellipse cx="41" cy="58" rx="5" ry="3" fill="#ff7a8a" opacity=".7"/><ellipse cx="87" cy="58" rx="5" ry="3" fill="#ff7a8a" opacity=".7"/> </g> <path d="M108 12l3 7 7 3-7 3-3 7-3-7-7-3 7-3z" fill="#7b5cff" stroke="#2a1a4a" stroke-width="2.5" stroke-linejoin="round"/> <path d="M14 78l2 5 5 2-5 2-2 5-2-5-5-2 5-2z" fill="#3ddcb0" stroke="#2a1a4a" stroke-width="2" stroke-linejoin="round"/></svg><span>Grail<small>BY EXAMPLE</small></span></a><label class="search-label" for="search">Find a topic</label><div class="search-box"><input id="search" type="search" placeholder="Search the book…" autocomplete="off" aria-controls="search-results"><kbd>/</kbd></div><div id="search-status" role="status" aria-live="polite"></div><ol id="search-results" hidden></ol><nav aria-label="Chapters"><ol class="chapters">${toc}</ol></nav></aside>
<div class="reading-pane"><header class="toolbar"><button id="menu-toggle" aria-controls="sidebar" aria-expanded="false" aria-label="Toggle chapters">☰</button><span></span><button id="rust-toggle" hidden>Hide Rust</button><button id="theme-toggle" aria-label="Toggle color theme">◐ <span>Theme</span></button></header><main id="content" tabindex="-1"><article>${html}</article><nav class="pagination" aria-label="Chapter navigation">${link(book.chapters[index - 1], '← Previous', 'previous')}${link(book.chapters[index + 1], 'Next →', 'next')}</nav><footer>Build: <code>just book-build</code> · Verify: <code>just book-check</code></footer></main></div></body></html>\n`;
}
export function buildBook(destination = output) {
  if (!Bun.markdown?.html) throw new Error('Book rendering requires Bun 1.4 or newer.');
  const book = loadBook();
  mkdirSync(destination, { recursive: true });
  const search = [], used = new Set();
  book.chapters.forEach((chapter, index) => {
    const expanded = expand(readFileSync(sourcePath(chapter.source), 'utf8'), book, used);
    const html = page(book, chapter, index, Bun.markdown.html(expanded));
    writeFileSync(join(destination, `${chapter.slug}.html`), html);
    if (!index) writeFileSync(join(destination, 'index.html'), html);
    search.push({ title: chapter.title, url: `${chapter.slug}.html`, text: expanded.replace(/<[^>]*>/g, ' ').replace(/&(?:amp|lt|gt|quot|#39);/g, e => ({'&amp;':'&','&lt;':'<','&gt;':'>','&quot;':'"','&#39;':"'"}[e])).replace(/[`#]/g, '') });
  });
  for (const example of book.examples) if (!used.has(example.id)) throw new Error(`Example is not included in the book: ${example.id}`);
  for (const asset of ['theme.css', 'book.js']) copyFileSync(join(source, asset), join(destination, asset));
  writeFileSync(join(destination, 'search.js'), `window.grailBookSearch=${JSON.stringify(search)};\n`);
  return join(destination, 'index.html');
}
export function runCommand(args, options = {}) {
  const result = Bun.spawnSync(args, { cwd: root, stdout: 'pipe', stderr: 'pipe', ...options });
  if (!result.success) throw new Error(`${args[0]} failed (${result.exitCode}):\n${result.stdout.toString()}${result.stderr.toString()}`);
  return result;
}
export function verifyExample(example, compiler, suppliedArgs, target = hostTarget) {
  targetName(target);
  if (!/^[a-z][a-z0-9-]*$/.test(example.id)) throw new Error('Invalid example id');
  const directory = join(work, 'runs', target, example.id);
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const asm = join(directory, 'program.s');
  const prior = 'prior valid artifact\n';
  writeFileSync(asm, prior);
  // `std` lists standard-library modules (lib/NAME.grl) linked like `grail build` does.
  const args = [compiler, '--default-u64', '--typed-refs', '--target', target, asm, sourcePath(example.entry), ...(example.modules ?? []).map(sourcePath), ...(example.std ?? []).map(name => join(root, 'lib', `${name}.grl`)), join(root, 'compiler/runtime.grl')];
  const result = Bun.spawnSync(args, { cwd: root, stdout: 'pipe', stderr: 'pipe' });
  if (example.diagnostic !== undefined) {
    const diagnostic = result.stdout.toString() + result.stderr.toString();
    if (result.success || !diagnostic.includes(example.diagnostic) || readFileSync(asm, 'utf8') !== prior) throw new Error(`${example.id}: expected rejection containing ${example.diagnostic}, without replacing prior output\n${diagnostic}`);
    return diagnostic;
  }
  if (!result.success) throw new Error(`${example.id}: compilation failed\n${result.stdout}${result.stderr}`);
  const exe = assemble(asm, join(directory, 'program'), target);
  writeFixtures(directory, example.fixtures);
  const execution = execute(exe, suppliedArgs ?? example.args ?? [], target, { cwd: directory });
  if (execution.error) throw execution.error;
  if (execution.status !== 0) throw new Error(`${example.id}: execution failed (${execution.signal ?? execution.status})\n${execution.stderr}`);
  const stdout = execution.stdout.toString();
  if (suppliedArgs === undefined && stdout !== example.output) throw new Error(`${example.id}: stdout mismatch\nexpected ${JSON.stringify(example.output)}\nreceived ${JSON.stringify(stdout)}`);
  verifyFiles(directory, example.files, example.id);
  return stdout;
}
function fixturePath(directory, name) {
  const target = resolve(directory, name);
  const path = relative(directory, target);
  if (!path || path.startsWith('..') || resolve(directory, path) !== join(directory, name)) throw new Error('Fixture path must stay inside its scratch directory');
  return target;
}
function writeFixtures(directory, fixtures = {}) {
  for (const [name, contents] of Object.entries(fixtures)) {
    const path = fixturePath(directory, name);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, contents);
  }
}
function verifyFiles(directory, files = {}, label) {
  for (const [name, contents] of Object.entries(files)) if (readFileSync(fixturePath(directory, name), 'utf8') !== contents) throw new Error(`${label}: output file mismatch: ${name}`);
}
export function verifyRust(example) {
  const rust = example.rust;
  const directory = join(work, 'runs', example.id, 'rust');
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const exe = join(directory, 'rust-example');
  const result = Bun.spawnSync(['rustc', '--edition=2024', '-C', 'overflow-checks=on', '-C', 'panic=abort', sourcePath(rust.source), '-o', exe], { cwd: root, stdout: 'pipe', stderr: 'pipe' });
  if (rust.diagnostic) {
    if (result.success || !result.stderr.toString().includes(rust.diagnostic)) throw new Error(`${example.id}: expected Rust rejection ${rust.diagnostic}\n${result.stderr}`);
  } else {
    if (!result.success) throw new Error(`${example.id}: Rust compilation failed\n${result.stderr}`);
    writeFixtures(directory, rust.fixtures);
    const stdout = runCommand([exe, ...(rust.args ?? [])], { cwd: directory }).stdout.toString();
    if (stdout !== rust.output) throw new Error(`${example.id}: Rust stdout mismatch: ${JSON.stringify(stdout)}`);
    verifyFiles(directory, rust.files, `${example.id}: Rust`);
  }
}
export function openBook(index, opener = process.env.GRAIL_BOOK_OPENER) {
  const commands = opener ? [opener, index] : process.platform === 'darwin' ? ['open', index] : process.platform === 'win32' ? ['cmd', '/c', 'start', '', index] : ['xdg-open', index];
  runCommand(commands);
}
export function main(args) {
  const [command = 'open', ...rest] = args;
  let target = hostTarget, grailOnly = false;
  while (rest[0]?.startsWith('--')) {
    const option = rest.shift();
    if (option.startsWith('--target=')) target = targetName(option.slice(9));
    else if (option === '--grail-only') grailOnly = true;
    else throw new Error(`Unknown book option ${option}`);
  }
  const [id, ...argv] = rest;
  if (command === 'build' || command === 'open') {
    const index = buildBook();
    console.log(`Built ${index}`);
    if (command === 'open') {
      try { openBook(index); } catch (error) { throw new Error(`Could not open your browser. Open ${pathToFileURL(index)} manually, or set GRAIL_BOOK_OPENER to an opener executable.\n${error.message}`); }
    }
  } else if (command === 'check' || command === 'run') {
    const book = loadBook();
    if (command === 'check') buildBook();
    const selected = command === 'run' ? book.examples.filter(e => e.id === id) : book.examples;
    if (!selected.length) throw new Error(`Unknown example ${id ?? '(missing)'}; choose: ${book.examples.map(e => e.id).join(', ')}`);
    const compiler = buildCompiler();
    for (const example of selected) {
      const stdout = verifyExample(example, compiler, command === 'run' && argv.length ? argv : undefined, target);
      if (command === 'run') process.stdout.write(stdout);
      else {
        if (!grailOnly) verifyRust(example);
        console.log(`✓ ${example.id}${example.diagnostic ? ' (expected rejection)' : ''}${!grailOnly ? ' + Rust' : ''}`);
      }
    }
    if (command === 'check') console.log(`${selected.length} Grail examples${!grailOnly ? ` and ${selected.length} Rust comparisons` : ''} verified; stdout, file outputs and intentional rejections match.`);
  } else throw new Error('Usage: bun tools/book.mjs [open|build|check|run EXAMPLE [ARGS...]]');
}
if (import.meta.main) {
  try { main(Bun.argv.slice(2)); } catch (error) { console.error(`book: ${error.message}`); process.exitCode = 1; }
}
