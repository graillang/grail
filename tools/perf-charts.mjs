// Renders a rivals result file (bench/results/*.json, written by `--json` of tools/bench-rivals.mjs,
// sched-rivals.mjs and compile-rivals.mjs) as HTML for the book: per table, an inline SVG chart of
// grouped horizontal bars (one group per program or measure, one bar per language, Grail
// highlighted) and the same numbers as a table, then the machine, load, versions, commit and
// commands. Pure string functions: no DOM, no script, no network, so the book stays offline HTML.
//
// Bars are normalised per row - each its distance from the row's best as a multiple, so 1x is the
// best and longer is worse whichever way the row reads - because rows mix units and span orders of
// magnitude; past an 8x spread the axis is logarithmic. The chart says which. Each group is labelled with Grail's ratio
// to the fastest rival, coloured by whether it is at or under the table's threshold.

const escape = text => String(text).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
// One colour per language, the same in every chart; Grail's builds share the book's accent family.
const palette = { grail: ['#d9480f', '#f08c00', '#f59f00'], c: '#4263eb', cpp: '#c2255c', rust: '#8d5524', go: '#0b7285', zig: '#7048e8', tbb: '#2b8a3e', rayon: '#8d5524', other: '#868e96' };
function colourOf(column, grailIndex) {
  if (column.grail) return palette.grail[Math.min(grailIndex, palette.grail.length - 1)];
  const key = column.key.toLowerCase();
  if (key.startsWith('cpp')) return palette.cpp;
  if (key.startsWith('c')) return palette.c;
  if (key.startsWith('rust')) return palette.rust;
  if (key.startsWith('go')) return palette.go;
  if (key.startsWith('zig')) return palette.zig;
  if (key === 'onetbb') return palette.tbb;
  if (key === 'rayon') return palette.rayon;
  return palette.other;
}
const number = v => v === undefined || v === null || !Number.isFinite(v) ? '-' : Math.abs(v) >= 100 ? v.toFixed(0) : Math.abs(v) >= 10 ? v.toFixed(1) : Math.abs(v) >= 1 ? v.toFixed(2) : v.toFixed(3);

// Grail's ratio to the fastest rival in one row: above 1 is behind, whatever the direction.
export function rowRatio(table, row, key = table.primary) {
  const mine = row.values[key];
  const rivals = table.columns.filter(c => !c.grail).map(c => row.values[c.key]).filter(Number.isFinite);
  if (!Number.isFinite(mine) || !rivals.length) return undefined;
  return (row.direction ?? table.direction) === 'higher' ? Math.max(...rivals) / mine : mine / Math.min(...rivals);
}

// `prefix` names the result file, so two files' tables of one id (release) are two elements.
export function chart(table, data = undefined, prefix = data?.tool) {
  const cols = table.columns;
  const grailOrder = new Map(cols.filter(c => c.grail).map((c, i) => [c.key, i]));
  // Each bar: how far it is from the row's best, as a multiple: value / best where lower is better,
  // best / value where higher is better. 1x is the best and a longer bar is always worse.
  const scaled = table.rows.map(row => {
    const higher = (row.direction ?? table.direction) === 'higher';
    const present = cols.map(c => row.values[c.key]).filter(Number.isFinite);
    const best = present.length ? (higher ? Math.max(...present) : Math.min(...present)) : undefined;
    return cols.map(c => Number.isFinite(row.values[c.key]) && best && row.values[c.key] ? (higher ? best / row.values[c.key] : row.values[c.key] / best) : undefined);
  });
  const spread = Math.max(1, ...scaled.flat().filter(Number.isFinite));
  const log = spread > 8;
  const left = 230, width = 430, right = 190, bar = 11, gap = 2, groupGap = 14;
  const groupHeight = cols.length * (bar + gap) + groupGap;
  const top = data ? 62 : 48, legend = 26, height = top + table.rows.length * groupHeight + legend + 18;
  const x = r => {
    if (!Number.isFinite(r)) return 0;
    const room = width - 44; // the bar's own value label goes after it, before the ratio column
    if (log) return Math.max(3, (Math.log(Math.max(r, 1)) / Math.log(spread)) * room + 3);
    return Math.max(3, (r / spread) * room);
  };
  const parts = [];
  const mixed = table.rows.some(r => (r.direction ?? table.direction) !== table.direction);
  const caption = `${table.direction === 'higher' ? 'Higher is better' : 'Lower is better'}${mixed ? ', except rows marked ↑, where higher is better' : ''}. Bars are normalised per row: each is its distance from the row's best as a multiple (1x is the best, a longer bar is worse)${log ? ', on a logarithmic axis' : ', on a linear axis'}. The numbers are in the table below.`;
  // The caption in two lines inside the chart (so an exported image keeps it), whole in the figcaption.
  const direction = `${table.direction === 'higher' ? 'Higher is better' : 'Lower is better'}${mixed ? ' (rows marked ↑: higher is better)' : ''}.`;
  const scale = `Bars normalised per row: a multiple of the row's best (1x), longer is worse; ${log ? 'logarithmic' : 'linear'} axis.`;
  parts.push(`<text x="0" y="13" class="perf-axis perf-direction">${escape(direction)}</text><text x="0" y="27" class="perf-axis">${escape(scale)}</text>`);
  // The provenance in the chart itself, so a picture of one chart still says what it measured.
  const source = data ? `Grail ${data.commit}; measured ${String(data.date).slice(0, 10)}, load average ${Array.isArray(data.load) ? [...new Set(data.load.map(l => l.split(' ')[0]))].join(' to ') : data.load} on ${data.machine?.cpus ?? '?'} CPUs.` : '';
  if (source) parts.push(`<text x="0" y="41" class="perf-axis perf-source">${escape(source)}</text>`);
  // Axis ticks.
  const ticks = log ? [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000].filter(t => t <= spread) : [0, 0.25, 0.5, 0.75, 1].map(f => f * spread);
  for (const t of ticks) {
    const px = left + (log ? x(t) : x(t) || 0);
    parts.push(`<line x1="${px.toFixed(1)}" x2="${px.toFixed(1)}" y1="${top - 6}" y2="${height - legend - 14}" class="perf-grid"/><text x="${px.toFixed(1)}" y="${top - 9}" class="perf-tick" text-anchor="middle">${Number.isInteger(t) ? t : number(t)}x</text>`);
  }
  table.rows.forEach((row, ri) => {
    const y0 = top + ri * groupHeight;
    const higher = (row.direction ?? table.direction) === 'higher';
    const ratio = rowRatio(table, row);
    const met = ratio !== undefined && ratio <= (table.threshold ?? 1);
    parts.push(`<text x="${left - 8}" y="${y0 + groupHeight / 2 - groupGap / 2 - 4}" class="perf-label" text-anchor="end">${escape(row.name)}${higher ? ' ↑' : ''}</text>`);
    parts.push(`<text x="${left - 8}" y="${y0 + groupHeight / 2 - groupGap / 2 + 9}" class="perf-unit" text-anchor="end">${escape(row.unit ?? '')}</text>`);
    cols.forEach((c, ci) => {
      const r = scaled[ri][ci];
      const y = y0 + ci * (bar + gap);
      if (!Number.isFinite(r)) { parts.push(`<text x="${left + 3}" y="${y + bar - 2}" class="perf-missing">${escape(c.label)}: not measured</text>`); return; }
      const w = x(r);
      parts.push(`<rect x="${left}" y="${y}" width="${w.toFixed(1)}" height="${bar}" fill="${colourOf(c, grailOrder.get(c.key) ?? 0)}"${c.grail ? ' class="perf-grail"' : ''}><title>${escape(`${c.label}: ${number(row.values[c.key])} ${row.unit ?? ''} (${number(r)}x the best)`)}</title></rect>`);
      parts.push(`<text x="${(left + w + 4).toFixed(1)}" y="${y + bar - 2}" class="perf-value${c.grail ? ' perf-grail-text' : ''}">${escape(number(r))}x</text>`);
    });
    const mine = Number.isFinite(row.values[table.primary]);
    const label = ratio !== undefined ? `Grail ÷ fastest rival: ${ratio.toFixed(2)}x` : mine ? 'no rival figure' : 'no Grail figure';
    parts.push(`<text x="${left + width + right - 4}" y="${y0 + 10}" text-anchor="end" class="${met ? 'perf-met' : ratio === undefined ? 'perf-unit' : 'perf-missed'}">${escape(label)}</text>`);
  });
  // Legend.
  let lx = 0;
  const ly = height - legend + 4;
  cols.forEach(c => {
    parts.push(`<rect x="${lx}" y="${ly}" width="11" height="11" fill="${colourOf(c, grailOrder.get(c.key) ?? 0)}"/><text x="${lx + 15}" y="${ly + 10}" class="perf-legend">${escape(c.label)}</text>`);
    lx += 22 + c.label.length * 6.6;
  });
  const total = left + width + right;
  return `<figure class="perf-chart" id="chart-${prefix ? `${escape(prefix)}-` : ''}${escape(table.id)}"><svg viewBox="0 0 ${total} ${height}" width="100%" role="img" aria-label="${escape(`${table.title}. ${caption}`)}" xmlns="http://www.w3.org/2000/svg">${parts.join('')}</svg><figcaption>${escape(table.title)}. ${escape(caption)}${source ? ` ${escape(source)}` : ''}</figcaption></figure>`;
}

export function numbers(table) {
  const head = `<tr><th>${escape(table.direction === 'higher' ? 'measure (higher is better)' : 'program / measure')}</th><th>unit</th>${table.columns.map(c => `<th${c.grail ? ' class="perf-grail-col"' : ''}>${escape(c.label)}</th>`).join('')}<th>Grail / fastest rival</th></tr>`;
  const body = table.rows.map(row => {
    const ratio = rowRatio(table, row);
    const met = ratio !== undefined && ratio <= (table.threshold ?? 1);
    return `<tr><td>${escape(row.name)}${(row.direction ?? table.direction) === 'higher' ? ' ↑' : ''}</td><td>${escape(row.unit ?? '')}</td>${table.columns.map(c => `<td${c.grail ? ' class="perf-grail-col"' : ''}>${escape(number(row.values[c.key]))}</td>`).join('')}<td class="${met ? 'perf-met' : 'perf-missed'}">${ratio === undefined ? '-' : `${ratio.toFixed(2)}x`}</td></tr>`;
  }).join('');
  return `<div class="perf-table"><table><caption>${escape(table.title)}${table.note ? ` — ${escape(table.note)}` : ''}</caption><thead>${head}</thead><tbody>${body}</tbody></table></div>`;
}

export function provenance(data) {
  const load = Array.isArray(data.load) ? data.load.map(escape).join(' at start, ') + ' at end' : escape(data.load ?? '');
  let items = [
    ['Grail', `<code>${escape(data.commit)}</code>`],
    ['Measured', escape(data.date)],
    ['Machine', escape(`${data.machine?.cpu ?? 'unknown'}, ${data.machine?.cpus ?? '?'} CPUs, ${data.machine?.kernel ?? ''}`)],
    ['Load average', load],
    ['Toolchains', escape(Object.values(data.versions ?? {}).join('; '))],
  ];
  const commands = (data.commands ?? []).map(c => `<li><code>${escape(c)}</code></li>`).join('');
  // abundance-perf: the slowest program's hottest functions, and any program that did not build or run.
  if (data.hot) items.push(['Hot spots', `${escape(data.hot.program)}, the slowest release run: ${data.hot.top.length ? data.hot.top.map(t => `<code>${escape(t.fn)}</code> ${escape(t.percent)} %`).join(', ') : 'no samples'} of its time by inclusive samples (<code>grail profile --callers</code>)`]);
  const failed = Object.entries(data.failed ?? {});
  if (failed.length) items.push(['Did not build or run', failed.map(([k, v]) => `${escape(k)}: ${escape(v)}`).join('; ')]);
  return `<div class="perf-provenance"><dl>${items.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl><p>Reproduce with:</p><ul>${commands}</ul></div>`;
}

// The whole result file: every charted table as a chart then its numbers, the rest as numbers.
export function renderResults(data, prefix = data?.tool) {
  if (data?.schema !== 1 || !Array.isArray(data.tables)) throw new Error(`not a rivals result file (schema ${data?.schema})`);
  const html = data.tables.map(t => `${t.chart ? chart(t, data, prefix) : ''}${numbers(t)}`).join('') + provenance(data);
  return `<section class="perf-results" data-tool="${escape(data.tool)}">${html}</section>`.replace(/\n/g, ' ');
}

// The one-page summary: every result file's headline tables, each row reduced to Grail's ratio to the
// fastest rival (rowRatio), grouped into categories. A category is one bar, its geometric mean on a
// logarithmic axis centred on 1x (left: Grail's figure is lower, right: higher), with its best and
// worst rows marked and named; the axis spans the data, a power of two each way. The words are the
// ratio and its unit (CPU time unless the category says otherwise), never a verdict. Nothing is
// measured here; it reads the same committed files as the charts.
export const summaryCategories = [
  { file: 'compile', table: 'compile', label: 'Compile: check, cold', unit: 'instructions', match: n => /check cold$/.test(n) },
  { file: 'compile', table: 'compile', label: 'Compile: check after an edit', unit: 'instructions', match: n => /check edited$/.test(n) },
  { file: 'compile', table: 'compile', label: 'Compile: build, cold', unit: 'instructions', match: n => /build cold$/.test(n) },
  { file: 'compile', table: 'compile', label: 'Compile: build after an edit', unit: 'instructions', match: n => /build edited$/.test(n) },
  { file: 'bench-rivals', table: 'release', label: 'Release run time: kernels' },
  { file: 'engine', table: 'release', label: 'Release run time: engine programs' },
  { file: 'parallel', table: 'release', label: 'Release run time: parallel ECS', unit: 'wall time' },
  { file: 'sched-rivals', table: 'scheduler', label: 'Scheduler (release build)', unit: 'wall time' },
  { file: 'bench-rivals', table: 'instructions', label: 'Release instructions: kernels', unit: 'instructions' },
  { file: 'engine', table: 'instructions', label: 'Release instructions: engine programs', unit: 'instructions' },
  { file: 'bench-rivals', table: 'dev', label: 'Development build run time: kernels' },
  { file: 'engine', table: 'dev', label: 'Development build run time: engine programs' },
  { file: 'parallel', table: 'dev', label: 'Development build run time: parallel ECS', unit: 'wall time' },
];

export function summaryRows(files) {
  return summaryCategories.map(cat => {
    const data = files[cat.file];
    const table = data?.tables?.find(t => t.id === cat.table);
    if (!table) return { ...cat, rows: [] };
    const rows = table.rows.filter(r => !cat.match || cat.match(r.name)).map(r => ({ name: r.name, ratio: rowRatio(table, r) })).filter(r => Number.isFinite(r.ratio) && r.ratio > 0);
    const mean = rows.length ? Math.exp(rows.reduce((s, r) => s + Math.log(r.ratio), 0) / rows.length) : undefined;
    const sorted = [...rows].sort((a, b) => a.ratio - b.ratio);
    return { ...cat, rows, mean, best: sorted[0], worst: sorted[sorted.length - 1], behind: rows.filter(r => r.ratio > 1).length, commit: data.commit, date: String(data.date ?? '').slice(0, 10) };
  });
}

export function summary(files) {
  const cats = summaryRows(files).filter(c => c.rows.length);
  // A ratio as written: Grail's figure over the fastest rival's (below 1, Grail's is lower).
  const rel = r => `${r.toFixed(2)}x`;
  const unitOf = c => c.unit ?? 'CPU time';
  const left = 300, width = 420, right = 560, rowH = 26, top = 74, bottom = 34;
  // The axis: the smallest power of two each way that holds every category's mean, best and worst row.
  const reach = Math.max(...cats.flatMap(c => [c.mean, c.best?.ratio, c.worst?.ratio]).filter(Number.isFinite).map(r => Math.abs(Math.log2(r))), 1);
  const bound = 2 ** Math.ceil(reach);
  const lo = Math.log(1 / bound), hi = Math.log(bound);
  const px = r => left + ((Math.min(Math.max(Math.log(r), lo), hi) - lo) / (hi - lo)) * width;
  const one = px(1);
  const height = top + cats.length * rowH + bottom;
  const parts = [];
  parts.push(`<text x="0" y="13" class="perf-axis perf-direction">Grail's figure divided by the fastest rival's, per category (the geometric mean of the category's rows). Lower is better.</text>`);
  parts.push(`<text x="0" y="27" class="perf-axis">Left of 1x: Grail's figure is lower than the fastest rival's; right: higher. ◆ the category's worst row, ○ its best.</text>`);
  parts.push(`<text x="${(one - 6).toFixed(1)}" y="${top - 26}" class="perf-met" text-anchor="end">◀ Grail lower</text><text x="${(one + 6).toFixed(1)}" y="${top - 26}" class="perf-missed">Grail higher ▶</text>`);
  const tickSet = [];
  for (let e = -Math.log2(bound); e <= Math.log2(bound); e++) tickSet.push(2 ** e);
  const every = tickSet.length > 9 ? 2 : 1;
  for (const t of tickSet.filter((t, i) => t === 1 || (i - Math.log2(bound)) % every === 0)) {
    const x = px(t);
    const label = t === 1 ? '1x' : t < 1 ? `1/${Math.round(1 / t)}x` : `${t}x`;
    parts.push(`<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${top - 6}" y2="${height - bottom + 4}" class="perf-grid"${t === 1 ? ' stroke-width="2"' : ''}/><text x="${x.toFixed(1)}" y="${top - 10}" class="perf-tick" text-anchor="middle">${label}</text>`);
  }
  cats.forEach((c, i) => {
    const y = top + i * rowH;
    const ahead = c.mean <= 1;
    const x0 = Math.min(one, px(c.mean)), w = Math.max(2, Math.abs(px(c.mean) - one));
    parts.push(`<text x="${left - 8}" y="${y + 15}" class="perf-label" text-anchor="end">${escape(c.label)}</text>`);
    parts.push(`<rect x="${x0.toFixed(1)}" y="${y + 5}" width="${w.toFixed(1)}" height="14" fill="${ahead ? '#2b8a3e' : '#c92a2a'}" opacity="0.85"><title>${escape(`${c.label}: Grail ${rel(c.mean)} the fastest rival's ${unitOf(c)}, geometric mean over ${c.rows.length} rows`)}</title></rect>`);
    if (c.best) parts.push(`<circle cx="${px(c.best.ratio).toFixed(1)}" cy="${y + 12}" r="4" fill="none" stroke="#212529"><title>${escape(`best: ${c.best.name}, ${rel(c.best.ratio)}`)}</title></circle>`);
    if (c.worst) parts.push(`<path d="M ${px(c.worst.ratio).toFixed(1)} ${y + 7} l 5 5 l -5 5 l -5 -5 z" fill="#212529"><title>${escape(`worst: ${c.worst.name}, ${rel(c.worst.ratio)}`)}</title></path>`);
    const note = `${rel(c.mean)} the fastest rival's ${unitOf(c)} · higher on ${c.behind} of ${c.rows.length} rows${c.behind ? `; worst ${c.worst.name}, ${rel(c.worst.ratio)}` : ''}`;
    parts.push(`<text x="${left + width + 8}" y="${y + 15}" class="${ahead ? 'perf-met' : 'perf-missed'}">${escape(note.length > 96 ? note.slice(0, 95) + '…' : note)}</text>`);
  });
  const sources = [...new Set(cats.map(c => `${c.file} ${String(c.commit).slice(0, 8)} ${c.date}`))].join('; ');
  parts.push(`<text x="0" y="${height - 8}" class="perf-axis perf-source">${escape(`From bench/results: ${sources}.`)}</text>`);
  const svg = `<figure class="perf-chart" id="chart-summary"><svg viewBox="0 0 ${left + width + right} ${height}" width="100%" role="img" aria-label="Summary: Grail against the fastest rival in every category" xmlns="http://www.w3.org/2000/svg">${parts.join('')}</svg><figcaption>Every benchmark on one page: per category, Grail's figure divided by the fastest rival's (the geometric mean of the category's rows; CPU time unless the category names another unit). The charts further down have every row.</figcaption></figure>`;
  const body = cats.map(c => `<tr><td>${escape(c.label)}</td><td>${escape(unitOf(c))}</td><td class="${c.mean <= 1 ? 'perf-met' : 'perf-missed'}">${rel(c.mean)}</td><td>${c.behind} of ${c.rows.length}</td><td>${escape(c.best.name)}: ${rel(c.best.ratio)}</td><td>${escape(c.worst.name)}: ${rel(c.worst.ratio)}</td><td><code>${escape(String(c.commit).slice(0, 8))}</code> ${escape(c.date)}</td></tr>`).join('');
  const table = `<div class="perf-table"><table><caption>Every category: Grail's figure over the fastest rival's (geometric mean), the rows where Grail's is higher, and its best and worst rows</caption><thead><tr><th>category</th><th>figure</th><th>Grail ÷ fastest rival</th><th>rows where Grail's is higher</th><th>best row</th><th>worst row</th><th>measured on</th></tr></thead><tbody>${body}</tbody></table></div>`;
  return `<section class="perf-results perf-summary">${svg}${table}</section>`.replace(/\n/g, ' ');
}

// The languages at a glance: one panel per category the chapter measures, one bar per language, the
// geometric mean over the panel's rows of the language's figure as a multiple of the fastest
// language's on that row (1x = the fastest on every one; on a row where more is better, the
// fastest's figure over the language's). Release and development builds read the release and dev
// tables of the run-time, engine and parallel files (the parallel one at its most workers only, so
// ecs_par is one program, not three; Go has one build, so it is in both); compile speed reads the
// compile file's instruction table, every program and scenario a row; the scheduler reads its wall
// times, Grail's release (LLVM) build against rayon and oneTBB. A language without a figure on some
// row is averaged over the rows it has, and its bar says which it lacks. Nothing is measured here.
const languageNames = { c: 'C', cpp: 'C++', rust: 'Rust', go: 'Go', zig: 'Zig', grail: 'Grail' };
export const overviewPanels = [
  { id: 'compile', label: 'Compile speed', files: ['compile'], table: 'compile-wall', only: /^syn/, skip: /build no-op$/, figure: 'wall time at four jobs (20-unit scaling projects only; single-process instructions and tiny startup rows are in the detail tables below)', rows: 'measurements', missing: 'no figure for',
    languages: [['c', 'C', 'c'], ['cpp', 'C++', 'cpp'], ['rust', 'Rust', 'rust'], ['go', 'Go', 'go'], ['zig', 'Zig', 'zig'], ['grail', 'Grail', 'grail']] },
  { id: 'release', label: 'Release builds - run time', files: ['bench-rivals', 'engine', 'parallel'], table: 'release', figure: 'CPU time (wall time for the parallel ECS)', rows: 'programs', missing: 'no twin of',
    languages: [['c', 'C', 'c'], ['cpp', 'C++', 'cpp'], ['rust-release', 'Rust', 'rust'], ['go', 'Go', 'go'], ['zig-fast', 'Zig', 'zig'], ['grail-llvm', 'Grail', 'grail']] },
  { id: 'dev', label: 'Development builds - run time', files: ['bench-rivals', 'engine', 'parallel'], table: 'dev', figure: 'CPU time (wall time for the parallel ECS)', rows: 'programs', missing: 'no twin of', why: 'their development builds are not measured',
    languages: [['go', 'Go', 'go'], ['rust-dev', 'Rust dev', 'rust'], ['zig-debug', 'Zig Debug', 'zig'], ['grail-native', 'Grail-native', 'grail']] },
  { id: 'scheduler', label: 'Scheduler', files: ['sched-rivals'], table: 'scheduler', skip: /serial/, figure: "wall time; importer rounds inverted, as more is better there (serial fib(32) baseline excluded from mean)", rows: 'measurements', missing: 'no figure for', why: 'they have no scheduler twin',
    note: "Grail is its release (LLVM) build, Rust is rayon, C++ is oneTBB",
    languages: [['onetbb', 'C++', 'cpp'], ['rayon', 'Rust', 'rust'], ['grail-llvm', 'Grail', 'grail']] },
];

// Per panel: its rows and, per language, the geometric mean of its ratios to each row's fastest, how
// many rows it has a figure for and how many it is the fastest on; and the languages the panel lacks.
export function overviewRows(files) {
  return overviewPanels.map(panel => {
    const programs = [];
    for (const file of panel.files) {
      const table = files[file]?.tables?.find(t => t.id === panel.table);
      if (!table) continue;
      // A parallel file has a row per worker count (`ecs_par x8`): only its most workers count.
      const most = Math.max(0, ...table.rows.map(r => Number(r.name.match(/ x(\d+)$/)?.[1] ?? 0)));
      for (const row of table.rows) {
        if (most && !row.name.endsWith(` x${most}`)) continue;
        const higher = (row.direction ?? table.direction) === 'higher';
        const values = Object.fromEntries(panel.languages.map(([key]) => [key, row.values[key]]).filter(([, v]) => Number.isFinite(v) && v > 0));
        if (Object.keys(values).length < 2) continue; // nothing to compare against
        if (panel.only && !panel.only.test(row.name)) continue;
        if (panel.skip?.test(row.name)) continue;
        const best = higher ? Math.max(...Object.values(values)) : Math.min(...Object.values(values));
        programs.push({ name: row.name, file, higher, ratios: Object.fromEntries(Object.entries(values).map(([k, v]) => [k, higher ? best / v : v / best])) });
      }
    }
    // Only the rows every language the panel measures has a figure for: a mean over different rows
    // would compare languages on different work. The others are named in the panel's source line.
    const measuredKeys = panel.languages.map(([key]) => key).filter(key => programs.some(p => Number.isFinite(p.ratios[key])));
    const dropped = programs.filter(p => !measuredKeys.every(key => Number.isFinite(p.ratios[key])));
    const shared = programs.filter(p => !dropped.includes(p));
    // Ratios to the fastest among the languages the panel counts, on the shared rows.
    for (const p of shared) {
      const low = Math.min(...measuredKeys.map(k => p.ratios[k]));
      for (const k of measuredKeys) p.ratios[k] = p.ratios[k] / low;
    }
    programs.length = 0;
    programs.push(...shared);
    const languages = panel.languages.map(([key, label, family]) => {
      const ratios = programs.map(p => p.ratios[key]).filter(Number.isFinite);
      const mean = ratios.length ? Math.exp(ratios.reduce((s, r) => s + Math.log(r), 0) / ratios.length) : undefined;
      return { key, label, family, grail: family === 'grail', mean, count: ratios.length, fastest: ratios.filter(r => r === 1).length, missing: programs.filter(p => !Number.isFinite(p.ratios[key])).map(p => p.name) };
    });
    // The languages this panel has no bar for: those it does not set out to measure, and those its
    // file has no figure of.
    const absent = Object.keys(languageNames).filter(f => !panel.languages.some(l => l[2] === f)).map(f => languageNames[f]);
    const unmeasured = programs.length ? languages.filter(l => !l.count).map(l => l.label) : [];
    return { ...panel, programs, languages, absent, unmeasured, dropped: dropped.map(p => p.name) };
  });
}

const listOf = names => names.length < 2 ? names.join('') : `${names.slice(0, -1).join(', ')} or ${names[names.length - 1]}`;
// The line under a panel's heading: its source, its figure and the languages it lacks.
export function overviewSource(panel) {
  const lacks = [];
  if (panel.absent.length) lacks.push(`No ${listOf(panel.absent)}: ${panel.why ?? 'not measured'}`);
  if (panel.unmeasured.length) lacks.push(`No ${listOf(panel.unmeasured)}: not measured in this file`);
  if (panel.dropped?.length) lacks.push(`Not counted, as some language here has no figure: ${panel.dropped.join(', ')}`);
  return [`${panel.files.map(f => `bench/results/${f}.json`).join(', ')}; ${panel.figure}`, panel.note, ...lacks].filter(Boolean).join('. ') + '.';
}

export function overview(files) {
  const panels = overviewRows(files).filter(p => p.programs.length);
  // Every panel shares one logarithmic scale that starts at 1x, the fastest language's figure: a
  // bar's length is how far behind the fastest a language is, 2x is the same distance from 1x in
  // every panel, and nothing is drawn below 1x, where no language can be.
  const means = panels.flatMap(p => p.languages.map(l => l.mean)).filter(Number.isFinite);
  const steps = [1, 1.25, 1.5, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128];
  const end = steps.find(t => t >= Math.max(2, ...means)) ?? Math.max(2, ...means);
  const left = 120, width = 460, bar = 16, gap = 6, panelGap = 22, value = 46;
  const x = r => (Math.log(Math.max(1, r)) / Math.log(end)) * width;
  // The ticks that fit: each label at least 30 units from the last, the end always kept.
  const ticks = [];
  for (const t of steps.filter(t => t <= end)) {
    if (ticks.length && x(t) - x(ticks[ticks.length - 1]) < 30) { if (t !== end) continue; ticks.pop(); }
    ticks.push(t);
  }
  // Each bar is followed by its value and then how often the language was the fastest.
  const noteOf = (lang, panel) => `fastest on ${lang.fastest} of ${lang.count}${lang.count < panel.programs.length ? `; ${panel.missing} ${lang.missing.join(', ')}` : ''}`.slice(0, 70);
  const reach = Math.max(0, ...panels.flatMap(p => p.languages.filter(l => Number.isFinite(l.mean)).map(l => x(l.mean) + value + noteOf(l, p).length * 5.2)));
  const sourceReach = Math.max(0, ...panels.map(p => overviewSource(p).length * 5.4));
  const total = Math.max(left + Math.max(width, reach) + 12, sourceReach, 700);
  const parts = [];
  parts.push(`<text x="0" y="14" class="perf-axis perf-direction">How each language compares with the fastest language on each program or measurement. Shorter is better.</text>`);
  parts.push(`<text x="0" y="30" class="perf-axis">1× is the fastest's figure; 2× is twice it. Each bar is the geometric mean over the rows every language in its panel was measured on; all panels share one scale.</text>`);
  let y = 56;
  for (const panel of panels) {
    const languages = [...panel.languages].sort((a, b) => (Number.isFinite(a.mean) ? a.mean : Infinity) - (Number.isFinite(b.mean) ? b.mean : Infinity));
    parts.push(`<text x="0" y="${y}" class="perf-label">${escape(`${panel.label} - ${panel.programs.length} ${panel.rows}`)}</text>`);
    parts.push(`<text x="0" y="${y + 15}" class="perf-axis perf-source">${escape(overviewSource(panel))}</text>`);
    const gridTop = y + 38, rows = languages.length;
    for (const t of ticks) {
      const px = left + x(t);
      parts.push(`<line x1="${px.toFixed(1)}" x2="${px.toFixed(1)}" y1="${gridTop - 3}" y2="${gridTop + 4 + rows * (bar + gap)}" class="perf-grid"${t === 1 ? ' stroke-width="2"' : ''}/><text x="${px.toFixed(1)}" y="${gridTop - 5}" class="perf-tick" text-anchor="middle">${t}×</text>`);
    }
    y = gridTop + 2;
    for (const lang of languages) {
      if (!Number.isFinite(lang.mean)) { parts.push(`<text x="${left - 8}" y="${y + bar - 3}" class="perf-label" text-anchor="end">${escape(lang.label)}</text><text x="${left + 3}" y="${y + bar - 3}" class="perf-missing">not measured</text>`); y += bar + gap; continue; }
      const colour = colourOf({ key: lang.family, grail: lang.grail }, 0);
      const of = lang.count < panel.programs.length ? `over ${lang.count} of ${panel.programs.length} ${panel.rows}` : `over all ${lang.count}`;
      const w = Math.max(2, x(lang.mean));
      parts.push(`<text x="${left - 8}" y="${y + bar - 3}" class="perf-label${lang.grail ? ' perf-grail-text' : ''}" text-anchor="end">${escape(lang.label)}</text>`);
      parts.push(`<rect x="${left}" y="${y}" width="${w.toFixed(1)}" height="${bar}" fill="${colour}"${lang.grail ? ' class="perf-grail"' : ''}><title>${escape(`${lang.label}: ${lang.mean.toFixed(2)}× the fastest language's figure, ${of}; the fastest on ${lang.fastest}`)}</title></rect>`);
      parts.push(`<text x="${(left + w + 5).toFixed(1)}" y="${y + bar - 3}" class="perf-value${lang.grail ? ' perf-grail-text' : ''}">${lang.mean.toFixed(2)}×</text>`);
      parts.push(`<text x="${(left + w + value).toFixed(1)}" y="${y + bar - 3}" class="perf-unit">${escape(noteOf(lang, panel))}</text>`);
      y += bar + gap;
    }
    y += panelGap;
  }
  const used = [...new Set(panels.flatMap(p => p.files))].filter(f => files[f]);
  const sources = used.map(f => `${f} ${String(files[f].commit).slice(0, 8)} ${String(files[f].date ?? '').slice(0, 10)}`).join('; ');
  parts.push(`<text x="0" y="${y - 4}" class="perf-axis perf-source">${escape(`Measured: ${sources}.`)}</text>`);
  const height = y + 4;
  const svg = `<figure class="perf-chart" id="chart-overview"><svg viewBox="0 0 ${total.toFixed(0)} ${height}" width="100%" role="img" aria-label="The languages at a glance: run time of release and development builds, compile speed and the scheduler, each language against the fastest on each row, geometric mean over the rows" xmlns="http://www.w3.org/2000/svg">${parts.join('')}</svg><figcaption>The languages at a glance: in each panel, each language's figure on each row divided by the fastest language's (the fastest's over the language's where more is better), then the geometric mean over the rows. 1× would be the fastest on every row. Release and development builds: the programs of the run-time, engine and parallel charts (the parallel one at its most workers); compile speed: every program and scenario of the compile chart; scheduler: every row of the scheduler chart.</figcaption></figure>`;
  const body = panels.map(panel => panel.languages.filter(l => Number.isFinite(l.mean)).map(l => `<tr><td>${escape(panel.label)}</td><td${l.grail ? ' class="perf-grail-col"' : ''}>${escape(l.label)}</td><td>${l.mean.toFixed(2)}x</td><td>${l.count} of ${panel.programs.length}${l.missing.length ? ` (${escape(panel.missing)} ${escape(l.missing.join(', '))})` : ''}</td><td>${l.fastest}</td></tr>`).join('')).join('');
  const table = `<div class="perf-table"><table><caption>Each language's figure as a multiple of the fastest on each row, geometric mean; the rows it was measured on and how many it was the fastest on. ${escape(panels.map(p => `${p.label}: ${overviewSource(p)}`).join(' '))}</caption><thead><tr><th>panel</th><th>language</th><th>geometric mean vs the fastest</th><th>rows</th><th>fastest on</th></tr></thead><tbody>${body}</tbody></table></div>`;
  return `<section class="perf-results perf-overview">${svg}${table}</section>`.replace(/\n/g, ' ');
}
