import { test, expect, afterAll } from 'bun:test';
import { mkdtempSync, readFileSync, existsSync, readdirSync, rmSync, writeFileSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadBook, expand, buildBook, openBook, sourcePath, root, verifyRust } from './book.mjs';

const scratch = mkdtempSync(join(tmpdir(), 'grail-book-test-'));
afterAll(() => rmSync(scratch, { recursive: true, force: true }));
const book = loadBook();

test('manifest has substantial example-led coverage in both languages', () => {
  expect(book.chapters.length).toBeGreaterThanOrEqual(20);
  expect(book.examples.length).toBeGreaterThanOrEqual(30);
  expect(book.examples.every(e => e.rust)).toBe(true);
  for (const example of book.examples) expect(expand(`{{example:${example.id}}}`, book)).toContain('language-rust');
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

test('missing Rust comparisons are rejected at manifest validation', () => {
  const manifest = structuredClone(book);
  delete manifest.examples[0].rust;
  const path = join(scratch, 'missing-comparison.json');
  writeFileSync(path, JSON.stringify(manifest));
  expect(() => loadBook(path)).toThrow('needs a Rust comparison');
});
test('Rust host examples independently verify arguments, fixtures and file outputs', () => {
  for (const id of ['arguments', 'files', 'commands']) verifyRust(book.examples.find(e => e.id === id));
  const example = book.examples.find(e => e.id === 'files');
  expect(() => verifyRust({ ...example, rust: { ...example.rust, files: { 'copy.txt': 'wrong' } } })).toThrow('output file mismatch');
  expect(() => verifyRust({ ...example, rust: { ...example.rust, fixtures: { '../outside.txt': 'bad' } } })).toThrow('Fixture path');
});

test('supporting module files have real side-by-side Rust analogues', () => {
  const html = expand('{{example:modules}}', book);
  expect(html).toContain('examples/arithmetic.grl');
  expect(html).toContain('rust/arithmetic.rs');
  expect(html).toContain('mod arithmetic;');
  expect(html).toContain('pub fn twice');
  const manifest = structuredClone(book);
  delete manifest.examples.find(e => e.id === 'modules').rust.modules;
  const path = join(scratch, 'missing-module-comparison.json');
  writeFileSync(path, JSON.stringify(manifest));
  expect(() => loadBook(path)).toThrow('counterpart for each supporting module');
});
test('performance charts render from a results file: SVG, direction captions, ratios, met marks, no script', async () => {
  const { renderResults, rowRatio } = await import('./perf-charts.mjs');
  const { perfBlock } = await import('./book.mjs');
  const fixture = JSON.parse(readFileSync(join(root, 'tools/fixtures/perf-results.json'), 'utf8'));
  const html = renderResults(fixture);
  expect((html.match(/<svg /g) ?? []).length).toBe(2); // one chart per charted table
  expect(html).toContain('Lower is better');
  expect(html).toContain('except rows marked ↑, where higher is better');
  expect(html).toContain('importer rounds ↑');
  expect(html).toContain('logarithmic axis'); // the scheduler rows span more than 8x
  expect(html).toContain('linear axis');
  expect(html).toContain('Grail 1.02x the fastest rival · met'); // fnv: 0.55 / 0.54, under 1.05
  expect(html).toContain('Grail 6.84x the fastest rival'); // xform_f32: 0.13 / 0.019
  expect(html).toContain('Grail 0.74x the fastest rival · met'); // frame p99
  expect(rowRatio(fixture.tables[1], fixture.tables[1].rows[1])).toBeCloseTo(2.4); // higher is better: 3600 / 1500
  expect(html).toContain('A table without a chart'); // a numbers-only table still renders as a table
  expect(html).toContain('0123456789ab (fixture)');
  expect(html).toContain('bun tools/bench-rivals.mjs --runs 3');
  expect(html).not.toMatch(/<script|https?:\/\/(?!www\.w3\.org\/2000\/svg)/);
  expect(html).not.toContain('\n'); // one line: a raw HTML block markdown leaves alone
  expect(perfBlock('perf-results#release', join(root, 'tools/fixtures'))).toContain('<svg ');
  expect(() => perfBlock('perf-results#no-such-table', join(root, 'tools/fixtures'))).toThrow('no table');
  expect(() => renderResults({ schema: 2 })).toThrow('not a rivals result file');
});
test('the Performance chapter renders every committed result file', () => {
  const chapter = book.chapters.find(c => c.slug === 'performance');
  expect(chapter).toBeDefined();
  const text = readFileSync(sourcePath(chapter.source), 'utf8');
  for (const name of ['bench-rivals', 'compile-rivals', 'sched-rivals']) {
    expect(existsSync(join(root, 'bench/results', `${name}.json`))).toBe(true);
    expect(text).toContain(`{{perf:${name}`);
  }
  const html = expand(text, book);
  for (const id of ['chart-release', 'chart-dev', 'chart-compile', 'chart-scheduler']) expect(html).toContain(`id="${id}"`);
  expect(html).toContain('higher is better');
});
