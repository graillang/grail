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
export function loadBook() {
  const book = JSON.parse(readFileSync(join(source, 'book.json'), 'utf8'));
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
    if (example.rust && (typeof example.rust.output === 'string') === (typeof example.rust.diagnostic === 'string')) throw new Error(`Rust comparison ${example.id} needs output or diagnostic`);
    if (example.rust) readFileSync(sourcePath(example.rust.source));
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
    let rust = '', note = '';
    if (example.rust) {
      const r = example.rust;
      const result = r.diagnostic ? outcome('Expected compiler rejection', `${r.diagnostic}\n`, true) : outcome('Output', r.output, false);
      rust = `<details class="rust-column" open><summary><span class="compare-show">Compare Rust ＋</span><span class="compare-hide">Hide Rust −</span></summary><div class="code-heading"><strong>Rust</strong><span>${escape(r.source)}</span></div>${codeBlock(readFileSync(sourcePath(r.source), 'utf8'), 'rust', 'source-code')}${result}<p class="comparison-verified">Rust 2024 · checked by <code>just book-check</code></p></details>`;
      note = `<div class="comparison-note"><strong>Notes</strong><p>${escape(r.note)}</p></div>`;
    }
    return `\n<figure class="example-workspace${rust ? ' has-comparison' : ''}" id="example-${id}"><figcaption>Example <span>${escape(id)}</span>${example.diagnostic ? '<em>intentional compile error</em>' : ''}</figcaption><div class="example-grid">${grail}${rust}</div>${note}</figure>\n`;

  });
}
function page(book, chapter, index, html) {
  const link = (c, label, cls) => c ? `<a class="${cls}" href="${c.slug}.html">${label}<strong>${escape(c.title)}</strong></a>` : '<span></span>';
  const toc = book.chapters.map((c, i) => `<li><a href="${c.slug}.html" ${i === index ? 'aria-current="page"' : ''}><span>${String(i + 1).padStart(2, '0')}</span>${escape(c.title)}</a></li>`).join('');
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light dark"><meta name="description" content="Learn Grail through complete, compiler-checked examples."><title>${escape(chapter.title)} · ${escape(book.title)}</title><link rel="stylesheet" href="theme.css"><script src="search.js" defer></script><script src="book.js" defer></script></head>
<body><a class="skip" href="#content">Skip to content</a><aside class="sidebar" id="sidebar"><a class="brand" href="index.html"><span class="brand-mark">g.</span><span>Grail<small>BY EXAMPLE</small></span></a><label class="search-label" for="search">Find a topic</label><div class="search-box"><input id="search" type="search" placeholder="Search the book…" autocomplete="off" aria-controls="search-results"><kbd>/</kbd></div><div id="search-status" role="status" aria-live="polite"></div><ol id="search-results" hidden></ol><nav aria-label="Chapters"><ol class="chapters">${toc}</ol></nav></aside>
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
function nativeCompiler() {
  if (process.platform !== 'linux' || process.arch !== 'x64') throw new Error('Running examples currently requires Linux x86-64 with GNU as and ld. The static book can still be built/read.');
  mkdirSync(work, { recursive: true });
  runCommand(['as', '--64', join(root, 'compiler/bootstrap/native.s'), '-o', join(work, 'native.o')]);
  runCommand(['ld', join(work, 'native.o'), '-o', join(work, 'native')]);
  return join(work, 'native');
}
export function verifyExample(example, compiler, suppliedArgs) {
  if (!/^[a-z][a-z0-9-]*$/.test(example.id)) throw new Error('Invalid example id');
  const directory = join(work, 'runs', example.id);
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  const asm = join(directory, 'program.s');
  const prior = 'prior valid artifact\n';
  writeFileSync(asm, prior);
  const args = [compiler, asm, sourcePath(example.entry), ...(example.modules ?? []).map(sourcePath), join(root, 'compiler/runtime.grl')];
  const result = Bun.spawnSync(args, { cwd: root, stdout: 'pipe', stderr: 'pipe' });
  if (example.diagnostic !== undefined) {
    const diagnostic = result.stdout.toString() + result.stderr.toString();
    if (result.success || !diagnostic.includes(example.diagnostic) || readFileSync(asm, 'utf8') !== prior) throw new Error(`${example.id}: expected rejection containing ${example.diagnostic}, without replacing prior output\n${diagnostic}`);
    return diagnostic;
  }
  if (!result.success) throw new Error(`${example.id}: compilation failed\n${result.stdout}${result.stderr}`);
  const object = join(directory, 'program.o'), exe = join(directory, 'program');
  runCommand(['as', '--64', asm, '-o', object]);
  runCommand(['ld', object, '-o', exe]);
  for (const [name, contents] of Object.entries(example.fixtures ?? {})) {
    if (resolve(directory, name) !== join(directory, name) || name.includes('..')) throw new Error('Fixture path must stay inside its scratch directory');
    mkdirSync(dirname(join(directory, name)), { recursive: true });
    writeFileSync(join(directory, name), contents);
  }
  const stdout = runCommand([exe, ...(suppliedArgs ?? example.args ?? [])], { cwd: directory }).stdout.toString();
  if (suppliedArgs === undefined && stdout !== example.output) throw new Error(`${example.id}: stdout mismatch\nexpected ${JSON.stringify(example.output)}\nreceived ${JSON.stringify(stdout)}`);
  for (const [name, contents] of Object.entries(example.files ?? {})) if (readFileSync(join(directory, name), 'utf8') !== contents) throw new Error(`${example.id}: output file mismatch: ${name}`);
  return stdout;
}
export function verifyRust(example) {
  const rust = example.rust;
  if (!rust) return;
  const directory = join(work, 'runs', example.id);
  mkdirSync(directory, { recursive: true });
  const exe = join(directory, 'rust-example');
  const result = Bun.spawnSync(['rustc', '--edition=2024', sourcePath(rust.source), '-o', exe], { cwd: root, stdout: 'pipe', stderr: 'pipe' });
  if (rust.diagnostic) {
    if (result.success || !result.stderr.toString().includes(rust.diagnostic)) throw new Error(`${example.id}: expected Rust rejection ${rust.diagnostic}\n${result.stderr}`);
  } else {
    if (!result.success) throw new Error(`${example.id}: Rust compilation failed\n${result.stderr}`);
    const stdout = runCommand([exe], { cwd: directory }).stdout.toString();
    if (stdout !== rust.output) throw new Error(`${example.id}: Rust stdout mismatch: ${JSON.stringify(stdout)}`);
  }
}
export function openBook(index, opener = process.env.GRAIL_BOOK_OPENER) {
  const commands = opener ? [opener, index] : process.platform === 'darwin' ? ['open', index] : process.platform === 'win32' ? ['cmd', '/c', 'start', '', index] : ['xdg-open', index];
  runCommand(commands);
}
export function main(args) {
  const [command = 'open', id, ...argv] = args;
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
    const compiler = nativeCompiler();
    for (const example of selected) {
      const stdout = verifyExample(example, compiler, command === 'run' && argv.length ? argv : undefined);
      if (command === 'run') process.stdout.write(stdout);
      else {
        if (id !== '--grail-only') verifyRust(example);
        console.log(`✓ ${example.id}${example.diagnostic ? ' (expected rejection)' : ''}${example.rust && id !== '--grail-only' ? ' + Rust' : ''}`);
      }
    }
    if (command === 'check') console.log(`${selected.length} Grail examples${id !== '--grail-only' ? ` and ${selected.filter(e => e.rust).length} Rust comparisons` : ''} verified; stdout, file outputs and intentional rejections match.`);
  } else throw new Error('Usage: bun tools/book.mjs [open|build|check|run EXAMPLE [ARGS...]]');
}
if (import.meta.main) {
  try { main(Bun.argv.slice(2)); } catch (error) { console.error(`book: ${error.message}`); process.exitCode = 1; }
}
