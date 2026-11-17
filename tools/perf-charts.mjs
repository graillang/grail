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
const palette = { grail: ['#d9480f', '#f08c00', '#f59f00'], c: '#4263eb', rust: '#8d5524', go: '#0b7285', zig: '#7048e8', tbb: '#2b8a3e', rayon: '#8d5524', other: '#868e96' };
function colourOf(column, grailIndex) {
  if (column.grail) return palette.grail[Math.min(grailIndex, palette.grail.length - 1)];
  const key = column.key.toLowerCase();
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

export function chart(table, data = undefined) {
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
  return `<figure class="perf-chart" id="chart-${escape(table.id)}"><svg viewBox="0 0 ${total} ${height}" width="100%" role="img" aria-label="${escape(`${table.title}. ${caption}`)}" xmlns="http://www.w3.org/2000/svg">${parts.join('')}</svg><figcaption>${escape(table.title)}. ${escape(caption)}${source ? ` ${escape(source)}` : ''}</figcaption></figure>`;
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
  const items = [
    ['Grail', `<code>${escape(data.commit)}</code>`],
    ['Measured', escape(data.date)],
    ['Machine', escape(`${data.machine?.cpu ?? 'unknown'}, ${data.machine?.cpus ?? '?'} CPUs, ${data.machine?.kernel ?? ''}`)],
    ['Load average', load],
    ['Toolchains', escape(Object.values(data.versions ?? {}).join('; '))],
  ];
  const commands = (data.commands ?? []).map(c => `<li><code>${escape(c)}</code></li>`).join('');
  return `<div class="perf-provenance"><dl>${items.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl><p>Reproduce with:</p><ul>${commands}</ul></div>`;
}

// The whole result file: every charted table as a chart then its numbers, the rest as numbers.
export function renderResults(data) {
  if (data?.schema !== 1 || !Array.isArray(data.tables)) throw new Error(`not a rivals result file (schema ${data?.schema})`);
  const html = data.tables.map(t => `${t.chart ? chart(t, data) : ''}${numbers(t)}`).join('') + provenance(data);
  return `<section class="perf-results" data-tool="${escape(data.tool)}">${html}</section>`.replace(/\n/g, ' ');
}
