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
  expect(html).toContain('Grail ÷ fastest rival: 1.02x'); // fnv: 0.55 / 0.54
  expect(html).toContain('Grail ÷ fastest rival: 6.84x'); // xform_f32: 0.13 / 0.019
  expect(html).toContain('Grail ÷ fastest rival: 0.74x'); // frame p99
  expect(html).not.toMatch(/ met\b/); // a ratio, not a verdict
  expect(rowRatio(fixture.tables[1], fixture.tables[1].rows[1])).toBeCloseTo(2.4); // higher is better: 3600 / 1500
  expect(html).toContain('A table without a chart'); // a numbers-only table still renders as a table
  expect(html).toContain('0123456789ab (fixture)');
  expect(html).toContain('<text x="0" y="41" class="perf-axis perf-source">Grail 0123456789ab (fixture); measured 2026-11-16, load average 1.00 on 4 CPUs.</text>'); // provenance inside each chart
  expect(html).toContain('bun tools/bench-rivals.mjs --runs 3');
  expect(html).toContain('world, the slowest release run: <code>f_world_generate</code> 61.5 %'); // abundance-perf's hot spots
  expect(html).toContain('Did not build or run</dt><dd>asset (current): grail: an interface carries a number wider than 64 bits');
  expect(html).not.toMatch(/<script|https?:\/\/(?!www\.w3\.org\/2000\/svg)/);
  expect(html).not.toContain('\n'); // one line: a raw HTML block markdown leaves alone
  expect(perfBlock('perf-results#release', join(root, 'tools/fixtures'))).toContain('<svg ');
  expect(() => perfBlock('perf-results#no-such-table', join(root, 'tools/fixtures'))).toThrow('no table');
  expect(perfBlock('perf-results#no-such-table|numbers-only', join(root, 'tools/fixtures'))).toContain('A table without a chart'); // the first table present
  expect(() => renderResults({ schema: 2 })).toThrow('not a rivals result file');
});
test('the languages overview: geometric mean of each language over the fastest per program, on the programs every language has', async () => {
  const { overviewRows, overview } = await import('./perf-charts.mjs');
  const table = (id, rows) => ({ id, rows: rows.map(([name, values]) => ({ name, values })) });
  const files = {
    'bench-rivals': { commit: 'abc', tables: [table('release', [['a', { c: 1, cpp: 2, 'rust-release': 4, go: 8, 'zig-fast': 1, 'grail-llvm': 2 }], ['b', { c: 4, 'rust-release': 1, go: 2, 'zig-fast': 4, 'grail-llvm': null }]])] },
    parallel: { commit: 'abc', tables: [table('release', [['p x1', { c: 1, cpp: 100, 'grail-llvm': 1 }], ['p x8', { c: 2, cpp: 1, 'rust-release': 2, go: 4, 'zig-fast': 2, 'grail-llvm': 4 }]])] },
  };
  const [release, dev] = overviewRows(files);
  // The parallel file at its most workers only; b has no C++ twin and a null (a wrong answer) for
  // Grail, so it is left out of every language's mean and named.
  expect(release.programs.map(p => p.name)).toEqual(['a', 'p x8']);
  expect(release.dropped).toEqual(['b']);
  const lang = key => release.languages.find(l => l.key === key);
  expect(lang('c').mean).toBeCloseTo(Math.sqrt(1 * 2));
  expect(lang('cpp').mean).toBeCloseTo(Math.sqrt(2 * 1));
  expect(lang('grail-llvm').mean).toBeCloseTo(Math.sqrt(2 * 4));
  expect(lang('grail-llvm').count).toBe(2);
  expect(lang('cpp').missing).toEqual([]);
  expect(lang('zig-fast').fastest).toBe(1);
  expect(dev.programs).toEqual([]);
  const html = overview(files);
  expect(html).toContain('id="chart-overview"');
  expect(html).toContain('Not counted, as some language here has no figure: b');
  expect(html).not.toContain('\n');
});
test('the languages overview: compile speed and scheduler panels, a language with no figure, a row where more is better', async () => {
  const { overviewRows, overview } = await import('./perf-charts.mjs');
  const table = (id, rows, direction = 'lower') => ({ id, direction, rows: rows.map(([name, values, dir]) => ({ name, values, ...(dir ? { direction: dir } : {}) })) });
  const files = {
    compile: { commit: 'abc', tables: [table('compile', [['hello check cold', { grail: 1, go: 4, zig: 8, rust: 2 }], ['hello build no-op', { grail: 1, go: 2, zig: 2, rust: 4, 'go-build': 0.5 }], ['syn build cold', { grail: 2, go: 4, zig: 8, rust: 4 }]])] },
    'sched-rivals': { commit: 'abc', tables: [table('scheduler', [
      ['join', { 'grail-native': 1, 'grail-llvm': 2, rayon: 4, onetbb: 1 }],
      ['join, on a worker', { rayon: 2, onetbb: 1 }],
      ['one at a time', { 'grail-native': 1, 'grail-llvm': 2 }],
      ['importer rounds', { 'grail-llvm': 50, rayon: 100, onetbb: 25 }, 'higher'],
    ])] },
  };
  const panels = overviewRows(files);
  const compile = panels.find(p => p.id === 'compile'), sched = panels.find(p => p.id === 'scheduler');
  const lang = (panel, key) => panel.languages.find(l => l.key === key);
  expect(compile.programs.map(p => p.name)).toEqual(['hello check cold', 'syn build cold']); // a rebuild with nothing changed is not counted
  expect(lang(compile, 'grail').mean).toBe(1);
  expect(lang(compile, 'rust').mean).toBeCloseTo(Math.sqrt(2 * 2));
  expect(compile.languages.map(l => l.key)).not.toContain('go-build'); // Go's other check is not a language
  expect(lang(compile, 'c').count).toBe(0); // a file without C or C++ columns: not measured, said so
  expect(compile.unmeasured).toEqual(['C', 'C++']);
  expect(compile.absent).toEqual([]);
  // The scheduler: Grail's release build, rayon as Rust, oneTBB as C++; a row with one language is
  // left out, and so is a row Grail has no figure on (named in the panel's source line).
  expect(sched.programs.map(p => p.name)).toEqual(['join', 'importer rounds']);
  expect(sched.dropped).toEqual(['join, on a worker']);
  expect(sched.absent).toEqual(['C', 'Go', 'Zig']);
  const rounds = sched.programs.find(p => p.name === 'importer rounds');
  expect(rounds.higher).toBe(true);
  expect(rounds.ratios).toEqual({ 'grail-llvm': 2, rayon: 1, onetbb: 4 }); // more is better: the most over each
  expect(lang(sched, 'grail-llvm').mean).toBeCloseTo(Math.sqrt(2 * 2));
  expect(lang(sched, 'onetbb').mean).toBeCloseTo(Math.sqrt(1 * 4));
  expect(lang(sched, 'rayon').mean).toBeCloseTo(Math.sqrt(4 * 1));
  expect(lang(sched, 'rayon').fastest).toBe(1);
  const html = overview(files);
  expect(html).toContain('Compile speed - 2 measurements');
  expect(html).toContain('bench/results/compile.json; user-space instructions');
  expect(html).toContain('No C or C++: not measured in this file');
  expect(html).toContain('bench/results/sched-rivals.json; wall time');
  expect(html).toContain('Grail is its release (LLVM) build, Rust is rayon, C++ is oneTBB');
  expect(html).toContain('No C, Go or Zig: they have no scheduler twin');
  expect(html).toContain('Not counted, as some language here has no figure: join, on a worker');
  expect(html).not.toContain('Release builds'); // a panel without data is left out
  expect(html).not.toContain('\n');
});
test('the Performance chapter renders every committed result file', () => {
  const chapter = book.chapters.find(c => c.slug === 'performance');
  expect(chapter).toBeDefined();
  const text = readFileSync(sourcePath(chapter.source), 'utf8');
  for (const name of ['bench-rivals', 'engine', 'parallel', 'abundance', 'compile', 'sched-rivals']) {
    expect(existsSync(join(root, 'bench/results', `${name}.json`))).toBe(true);
    expect(text).toContain(`{{perf:${name}`);
  }
  const html = expand(text, book);
  for (const id of ['chart-overview', 'chart-bench-rivals-release', 'chart-bench-rivals-dev', 'chart-engine-release', 'chart-engine-dev', 'chart-compile-compile', 'chart-compile-compile-wall', 'chart-sched-rivals-scheduler']) expect(html).toContain(`id="${id}"`);
  expect(new Set(html.match(/id="chart-[^"]+"/g)).size).toBe(html.match(/id="chart-[^"]+"/g).length); // no id twice
  expect(html).toContain('higher is better');
});
