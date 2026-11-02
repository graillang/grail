import { test, expect, afterAll } from 'bun:test';
import { mkdtempSync, readFileSync, existsSync, readdirSync, rmSync, writeFileSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadBook, expand, buildBook, openBook, sourcePath, root } from './book.mjs';

const scratch = mkdtempSync(join(tmpdir(), 'grail-book-test-'));
afterAll(() => rmSync(scratch, { recursive: true, force: true }));
const book = loadBook();

test('manifest has substantial example-led coverage in both languages', () => {
  expect(book.chapters.length).toBeGreaterThanOrEqual(20);
  expect(book.examples.length).toBeGreaterThanOrEqual(30);
  expect(book.examples.filter(e => e.rust).length).toBeGreaterThanOrEqual(20);
  expect(book.examples.filter(e => e.diagnostic).length).toBeGreaterThanOrEqual(4);
  for (const e of book.examples) expect(readFileSync(sourcePath(e.entry), 'utf8')).toContain('fn main');
});
test('source paths cannot escape the book directory', () => {
  expect(() => sourcePath('../README.md')).toThrow();
  expect(() => sourcePath('/etc/passwd')).toThrow();
});
test('unknown example references fail instead of silently publishing placeholders', () => {
  expect(() => expand('{{example:not-a-real-example}}', book)).toThrow('Unknown example');
});
test('example code, results, Rust details and notes are included from real source', () => {
  const used = new Set();
  const markdown = expand('{{example:hello}}', book, used);
  expect(markdown).toContain('Hello, world!');
  expect(markdown).toContain('language-grl');
  expect(markdown).toContain('language-rust');
  expect(markdown).toContain('<details class="rust-column" open>');
  expect(markdown).toContain('<details class="rust-column" open');
  expect(markdown).toContain('checked call-scoped borrowing');
  expect(used.has('hello')).toBe(true);
});
test('expected rejections are labelled separately from runtime stdout', () => {
  const text = expand('{{example:moved-value}}', book);
  expect(text).toContain('Expected compiler rejection');
  expect(text).toContain('E0382');
  expect(text).toContain('example-workspace');
});
test('build is reproducible and every chapter has working local navigation', () => {
  const first = join(scratch, 'first'), second = join(scratch, 'second');
  const index = buildBook(first); buildBook(second);
  expect(existsSync(index)).toBe(true);
  for (const file of readdirSync(first)) expect(readFileSync(join(first, file))).toEqual(readFileSync(join(second, file)));
  for (const chapter of book.chapters) {
    const html = readFileSync(join(first, `${chapter.slug}.html`), 'utf8');
    expect(html).toContain('aria-current="page"');
    expect(html).toContain('aria-label="Chapter navigation"');
    expect(html).not.toContain('{{example:');
    expect(html).not.toMatch(/(?:src|href)="https?:/);
    for (const [, target] of html.matchAll(/href="([^"#]+\.html)"/g)) expect(existsSync(join(first, target))).toBe(true);
  }
});
test('offline search covers prose and both languages without fetching a service', () => {
  const directory = join(scratch, 'search'); buildBook(directory);
  const script = readFileSync(join(directory, 'search.js'), 'utf8');
  const pages = JSON.parse(script.slice('window.grailBookSearch='.length, -2));
  expect(pages.length).toBe(book.chapters.length);
  expect(pages.find(p => p.url === 'generics.html').text).toContain('turbofish');
  expect(pages.find(p => p.url === 'ownership.html').text).toContain('E0382');
});
test('browser opener receives the exact built file path as one argument', () => {
  if (process.platform === 'win32') return;
  const record = join(scratch, 'opened.txt'), opener = join(scratch, 'mock-opener');
  writeFileSync(opener, `#!/bin/sh\nprintf '%s' "$1" > '${record}'\n`); chmodSync(opener, 0o755);
  const index = join(scratch, 'a book with spaces.html');
  openBook(index, opener);
  expect(readFileSync(record, 'utf8')).toBe(index);
});
test('just book invokes build and browser opener end-to-end', () => {
  if (process.platform === 'win32') return;
  const record = join(scratch, 'just-opened.txt'), opener = join(scratch, 'just-opener');
  writeFileSync(opener, `#!/bin/sh\nprintf '%s' "$1" > '${record}'\n`); chmodSync(opener, 0o755);
  const result = Bun.spawnSync(['just', 'book'], { cwd: root, env: { ...process.env, GRAIL_BOOK_OPENER: opener }, stdout: 'pipe', stderr: 'pipe' });
  expect(result.success).toBe(true);
  expect(readFileSync(record, 'utf8')).toBe(join(root, '.work/book/html/index.html'));
  expect(result.stdout.toString()).toContain('Built ');
});
