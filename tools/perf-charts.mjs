// Renders a rivals result file (bench/results/*.json, written by `--json` of tools/bench-rivals.mjs,
// sched-rivals.mjs and compile-rivals.mjs) as HTML for the book: per table, an inline SVG chart of
// grouped horizontal bars (one group per program or measure, one bar per language, Grail
// highlighted) and the same numbers as a table, then the machine, load, versions, commit and
// commands. Pure string functions: no DOM, no script, no network, so the book stays offline HTML.
//
// Bars are normalised per row - each its distance from the row's best as a multiple, so 1x is the
// best and longer is worse whichever way the row reads - because rows mix units and span orders of
// magnitude; past an 8x spread the axis is logarithmic. The chart says which. Each group is labelled with Grail's ratio
// to the fastest rival, and "met" where that ratio is at or under the table's threshold.

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
    const label = ratio !== undefined ? `Grail ${ratio.toFixed(2)}x the fastest rival${met ? ' · met' : ''}` : mine ? 'no rival figure' : 'no Grail figure';
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
    return `<tr><td>${escape(row.name)}${(row.direction ?? table.direction) === 'higher' ? ' ↑' : ''}</td><td>${escape(row.unit ?? '')}</td>${table.columns.map(c => `<td${c.grail ? ' class="perf-grail-col"' : ''}>${escape(number(row.values[c.key]))}</td>`).join('')}<td class="${met ? 'perf-met' : 'perf-missed'}">${ratio === undefined ? '-' : `${ratio.toFixed(2)}x${met ? ' met' : ''}`}</td></tr>`;
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
// logarithmic axis centred on 1x (left: Grail ahead, right: behind), with its best and worst rows
// marked and named. Nothing is measured here; it reads the same committed files as the charts.
export const summaryCategories = [
  { file: 'compile', table: 'compile', label: 'Compile: check, cold', match: n => /check cold$/.test(n) },
  { file: 'compile', table: 'compile', label: 'Compile: check after an edit', match: n => /check edited$/.test(n) },
  { file: 'compile', table: 'compile', label: 'Compile: build, cold', match: n => /build cold$/.test(n) },
  { file: 'compile', table: 'compile', label: 'Compile: build after an edit', match: n => /build edited$/.test(n) },
  { file: 'compile', table: 'compile', label: 'Compile: rebuild, nothing changed', match: n => /build no-op$/.test(n) },
  { file: 'bench-rivals', table: 'release', label: 'Release run time: kernels' },
  { file: 'engine', table: 'release', label: 'Release run time: engine programs' },
  { file: 'parallel', table: 'release', label: 'Release run time: parallel ECS' },
  { file: 'sched-rivals', table: 'scheduler', label: 'Scheduler (release build)' },
  { file: 'bench-rivals', table: 'instructions', label: 'Release instructions: kernels' },
  { file: 'engine', table: 'instructions', label: 'Release instructions: engine programs' },
  { file: 'bench-rivals', table: 'dev', label: 'Development build run time: kernels' },
  { file: 'engine', table: 'dev', label: 'Development build run time: engine programs' },
  { file: 'parallel', table: 'dev', label: 'Development build run time: parallel ECS' },
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
  // A ratio read as words: below 1 Grail is faster, above 1 slower.
  const rel = r => r <= 1 ? `${(1 / r).toFixed(r < 0.1 ? 0 : 1)}x faster` : `${r.toFixed(2)}x slower`;
  const left = 300, width = 420, right = 560, rowH = 26, top = 74, bottom = 34;
  const lo = Math.log(1 / 32), hi = Math.log(32);
  const px = r => left + ((Math.min(Math.max(Math.log(r), lo), hi) - lo) / (hi - lo)) * width;
  const one = px(1);
  const height = top + cats.length * rowH + bottom;
  const parts = [];
  parts.push(`<text x="0" y="13" class="perf-axis perf-direction">How Grail compares with the fastest rival in each category (the geometric mean of the category's rows).</text>`);
  parts.push(`<text x="0" y="27" class="perf-axis">A green bar to the left: Grail is faster. A red bar to the right: Grail is slower. ◆ the category's worst row, ○ its best.</text>`);
  parts.push(`<text x="${(one - 6).toFixed(1)}" y="${top - 26}" class="perf-met" text-anchor="end">◀ Grail faster</text><text x="${(one + 6).toFixed(1)}" y="${top - 26}" class="perf-missed">Grail slower ▶</text>`);
  for (const t of [1 / 32, 1 / 8, 1 / 2, 1, 2, 8, 32]) {
    const x = px(t);
    const label = t === 1 ? 'same' : t < 1 ? `${Math.round(1 / t)}x` : `${t}x`;
    parts.push(`<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${top - 6}" y2="${height - bottom + 4}" class="perf-grid"${t === 1 ? ' stroke-width="2"' : ''}/><text x="${x.toFixed(1)}" y="${top - 10}" class="perf-tick" text-anchor="middle">${label}</text>`);
  }
  cats.forEach((c, i) => {
    const y = top + i * rowH;
    const ahead = c.mean <= 1;
    const x0 = Math.min(one, px(c.mean)), w = Math.max(2, Math.abs(px(c.mean) - one));
    parts.push(`<text x="${left - 8}" y="${y + 15}" class="perf-label" text-anchor="end">${escape(c.label)}</text>`);
    parts.push(`<rect x="${x0.toFixed(1)}" y="${y + 5}" width="${w.toFixed(1)}" height="14" fill="${ahead ? '#2b8a3e' : '#c92a2a'}" opacity="0.85"><title>${escape(`${c.label}: ${rel(c.mean)} over ${c.rows.length} rows`)}</title></rect>`);
    if (c.best) parts.push(`<circle cx="${px(c.best.ratio).toFixed(1)}" cy="${y + 12}" r="4" fill="none" stroke="#212529"><title>${escape(`best: ${c.best.name}, ${rel(c.best.ratio)}`)}</title></circle>`);
    if (c.worst) parts.push(`<path d="M ${px(c.worst.ratio).toFixed(1)} ${y + 7} l 5 5 l -5 5 l -5 -5 z" fill="#212529"><title>${escape(`worst: ${c.worst.name}, ${rel(c.worst.ratio)}`)}</title></path>`);
    const note = c.behind ? `${rel(c.mean)} · slower on ${c.behind} of ${c.rows.length}; worst ${c.worst.name}, ${rel(c.worst.ratio)}` : `${rel(c.mean)} · faster on all ${c.rows.length}`;
    parts.push(`<text x="${left + width + 8}" y="${y + 15}" class="${ahead ? 'perf-met' : 'perf-missed'}">${escape(note.length > 96 ? note.slice(0, 95) + '…' : note)}</text>`);
  });
  const sources = [...new Set(cats.map(c => `${c.file} ${String(c.commit).slice(0, 8)} ${c.date}`))].join('; ');
  parts.push(`<text x="0" y="${height - 8}" class="perf-axis perf-source">${escape(`From bench/results: ${sources}.`)}</text>`);
  const svg = `<figure class="perf-chart" id="chart-summary"><svg viewBox="0 0 ${left + width + right} ${height}" width="100%" role="img" aria-label="Summary: Grail against the fastest rival in every category" xmlns="http://www.w3.org/2000/svg">${parts.join('')}</svg><figcaption>Every benchmark on one page: per category, how much faster or slower Grail is than the fastest rival (the geometric mean of the category's rows). The charts further down have every row.</figcaption></figure>`;
  const body = cats.map(c => `<tr><td>${escape(c.label)}</td><td class="${c.mean <= 1 ? 'perf-met' : 'perf-missed'}">${rel(c.mean)}</td><td>${c.behind} of ${c.rows.length}</td><td>${escape(c.best.name)}: ${rel(c.best.ratio)}</td><td>${escape(c.worst.name)}: ${rel(c.worst.ratio)}</td><td><code>${escape(String(c.commit).slice(0, 8))}</code> ${escape(c.date)}</td></tr>`).join('');
  const table = `<div class="perf-table"><table><caption>Every category: how Grail compares with the fastest rival (geometric mean), the rows where it is slower, and its best and worst rows</caption><thead><tr><th>category</th><th>Grail vs the fastest rival</th><th>rows where Grail is slower</th><th>best row</th><th>worst row</th><th>measured on</th></tr></thead><tbody>${body}</tbody></table></div>`;
  return `<section class="perf-results perf-summary">${svg}${table}</section>`.replace(/\n/g, ' ');
}

// The languages at a glance: one bar per language, the geometric mean over every program of the
// language's time as a multiple of the fastest language's on that program (1x = the fastest on
// every one). Release builds read the release tables of the run-time, engine and parallel files (the
// parallel one at its most workers only, so ecs_par is one program, not three); development builds
// read the dev tables, Grail's native backend against the rivals' debug builds (Go has one build, so
// it is in both). A language without a twin of some program is averaged over the programs it has,
// and its bar says over how many. Nothing is measured here.
export const overviewPanels = [
  { id: 'release', label: 'Release builds', table: 'release', languages: [['c', 'C'], ['cpp', 'C++'], ['rust-release', 'Rust'], ['go', 'Go'], ['zig-fast', 'Zig'], ['grail-llvm', 'Grail']] },
  { id: 'dev', label: 'Development builds', table: 'dev', languages: [['go', 'Go'], ['rust-dev', 'Rust dev'], ['zig-debug', 'Zig Debug'], ['grail-native', 'Grail-native']] },
];
const overviewFiles = ['bench-rivals', 'engine', 'parallel'];

// Per panel: its programs (rows) and, per language, the geometric mean of its ratios to each
// program's fastest, how many programs it has a figure for and how many it is the fastest on.
export function overviewRows(files) {
  return overviewPanels.map(panel => {
    const programs = [];
    for (const file of overviewFiles) {
      const table = files[file]?.tables?.find(t => t.id === panel.table);
      if (!table) continue;
      // A parallel file has a row per worker count (`ecs_par x8`): only its most workers count.
      const most = Math.max(0, ...table.rows.map(r => Number(r.name.match(/ x(\d+)$/)?.[1] ?? 0)));
      for (const row of table.rows) {
        if (most && !row.name.endsWith(` x${most}`)) continue;
        const values = Object.fromEntries(panel.languages.map(([key]) => [key, row.values[key]]).filter(([, v]) => Number.isFinite(v) && v > 0));
        const best = Math.min(...Object.values(values));
        if (Object.keys(values).length < 2) continue; // nothing to compare against
        programs.push({ name: row.name, file, ratios: Object.fromEntries(Object.entries(values).map(([k, v]) => [k, v / best])) });
      }
    }
    const languages = panel.languages.map(([key, label]) => {
      const ratios = programs.map(p => p.ratios[key]).filter(Number.isFinite);
      const mean = ratios.length ? Math.exp(ratios.reduce((s, r) => s + Math.log(r), 0) / ratios.length) : undefined;
      return { key, label, grail: key.startsWith('grail'), mean, count: ratios.length, fastest: ratios.filter(r => r === 1).length, missing: programs.filter(p => !Number.isFinite(p.ratios[key])).map(p => p.name) };
    });
    return { ...panel, programs, languages };
  });
}

export function overview(files) {
  const panels = overviewRows(files).filter(p => p.programs.length);
  const left = 110, width = 420, bar = 15, gap = 5, panelGap = 30, top = 58;
  // Each bar's note on the right, and room for the longest of them (about 5.2 units a character at
  // the note's size); the chart is at least wide enough for the two heading lines above it.
  const noteOf = (lang, panel) => `fastest on ${lang.fastest} of ${lang.count}${lang.count < panel.programs.length ? `; no twin of ${lang.missing.join(', ')}` : ''}`.slice(0, 70);
  const longest = Math.max(0, ...panels.flatMap(p => p.languages.filter(l => Number.isFinite(l.mean)).map(l => noteOf(l, p).length)));
  const total = Math.max(left + width + Math.max(110, 16 + Math.ceil(longest * 5.2)), 650);
  // Each panel has its own linear scale, from 0 to its slowest language's mean.
  let spread = 1.5;
  const x = r => (r / spread) * (width - 50); // the bar's value label goes after it
  const parts = [];
  parts.push(`<text x="0" y="13" class="perf-axis perf-direction">Lower is better: each language's time as a multiple of the fastest language's, geometric mean over the programs.</text>`);
  parts.push(`<text x="0" y="27" class="perf-axis">1x would be the fastest on every program. A language without a twin of some program is averaged over the programs it has.</text>`);
  let y = top;
  for (const panel of panels) {
    spread = Math.max(1.5, ...panel.languages.map(l => l.mean).filter(Number.isFinite));
    const ticks = [1, 1.5, 2, 3, 4, 6, 8, 12, 16].filter(t => t <= spread);
    // The panel's heading, its axis labels under it, then its bars with the grid behind them.
    parts.push(`<text x="0" y="${y}" class="perf-label">${escape(`${panel.label} (${panel.programs.length} programs)`)}</text>`);
    const gridTop = y + 16, bars = panel.languages.length;
    for (const t of ticks) {
      const px = left + x(t);
      parts.push(`<line x1="${px.toFixed(1)}" x2="${px.toFixed(1)}" y1="${gridTop - 3}" y2="${gridTop + 4 + bars * (bar + gap)}" class="perf-grid"${t === 1 ? ' stroke-width="2"' : ''}/><text x="${px.toFixed(1)}" y="${gridTop - 5}" class="perf-tick" text-anchor="middle">${t}x</text>`);
    }
    y = gridTop + 2;
    for (const lang of panel.languages) {
      if (!Number.isFinite(lang.mean)) { parts.push(`<text x="${left - 8}" y="${y + bar - 3}" class="perf-label" text-anchor="end">${escape(lang.label)}</text><text x="${left + 3}" y="${y + bar - 3}" class="perf-missing">not measured</text>`); y += bar + gap; continue; }
      const colour = colourOf({ key: lang.key, grail: lang.grail }, 0);
      const of = lang.count < panel.programs.length ? `over ${lang.count} of ${panel.programs.length} programs` : `over all ${lang.count}`;
      parts.push(`<text x="${left - 8}" y="${y + bar - 3}" class="perf-label${lang.grail ? ' perf-grail-text' : ''}" text-anchor="end">${escape(lang.label)}</text>`);
      parts.push(`<rect x="${left}" y="${y}" width="${Math.max(2, x(lang.mean)).toFixed(1)}" height="${bar}" fill="${colour}"${lang.grail ? ' class="perf-grail"' : ''}><title>${escape(`${lang.label}: ${lang.mean.toFixed(2)}x the fastest, ${of}; the fastest on ${lang.fastest}`)}</title></rect>`);
      parts.push(`<text x="${(left + x(lang.mean) + 5).toFixed(1)}" y="${y + bar - 3}" class="perf-value${lang.grail ? ' perf-grail-text' : ''}">${lang.mean.toFixed(2)}x</text>`);
      parts.push(`<text x="${left + width + 8}" y="${y + bar - 3}" class="perf-unit">${escape(noteOf(lang, panel))}</text>`);
      y += bar + gap;
    }
    y += panelGap;
  }
  const sources = overviewFiles.filter(f => files[f]).map(f => `${f} ${String(files[f].commit).slice(0, 8)} ${String(files[f].date ?? '').slice(0, 10)}`).join('; ');
  parts.push(`<text x="0" y="${y - 8}" class="perf-axis perf-source">${escape(`From bench/results: ${sources}.`)}</text>`);
  const height = y;
  const svg = `<figure class="perf-chart" id="chart-overview"><svg viewBox="0 0 ${total} ${height}" width="100%" role="img" aria-label="The languages at a glance: each one's time as a multiple of the fastest, geometric mean over the programs" xmlns="http://www.w3.org/2000/svg">${parts.join('')}</svg><figcaption>The languages at a glance: per language, the geometric mean over the run-time, engine and parallel programs (the parallel one at its most workers) of its time as a multiple of the fastest language's on that program. Lower is better; 1x is the fastest everywhere.</figcaption></figure>`;
  const body = panels.map(panel => panel.languages.filter(l => Number.isFinite(l.mean)).map(l => `<tr><td>${escape(panel.label)}</td><td${l.grail ? ' class="perf-grail-col"' : ''}>${escape(l.label)}</td><td>${l.mean.toFixed(2)}x</td><td>${l.count} of ${panel.programs.length}${l.missing.length ? ` (no twin of ${escape(l.missing.join(', '))})` : ''}</td><td>${l.fastest}</td></tr>`).join('')).join('');
  const table = `<div class="perf-table"><table><caption>Each language's time as a multiple of the fastest on each program, geometric mean; the programs it was measured on and how many it was the fastest on</caption><thead><tr><th>builds</th><th>language</th><th>geometric mean vs the fastest</th><th>programs</th><th>fastest on</th></tr></thead><tbody>${body}</tbody></table></div>`;
  return `<section class="perf-results perf-overview">${svg}${table}</section>`.replace(/\n/g, ' ');
}
