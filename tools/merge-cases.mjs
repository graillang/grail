#!/usr/bin/env bun
// Resolve the merge conflicts that recur in this repository, during a `git merge` (MERGE_HEAD set).
//   bun tools/merge-cases.mjs [FILE...]        default: every unmerged file
//
// Case lists (tests/*.json: arrays of objects with a `name`) are merged three ways by case name,
// against the merge base: a case only one side added is kept; a case only one side changed takes
// that side's version; a case only one side removed is removed; anything both sides touched
// differently is reported and the file is left for a person. Ours' text is kept byte for byte - the
// file is never re-serialised - and what comes from the other side is written in the file's own
// form (two-space indent, non-ASCII as \u escapes). The tool this replaces let the incoming branch's
// entry win whenever the two differed, which reverted edits the incoming branch had never made.
//
// Prose (*.md) keeps both sides of each conflict, ours first, and a paragraph both sides already
// carry once. A source conflict is refused: it needs a decision.
import { execSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';

const git = command => execSync(`git ${command}`, { encoding: 'utf8', maxBuffer: 1 << 28 });
const files = process.argv.length > 2 ? process.argv.slice(2)
  : git('diff --name-only --diff-filter=U').split('\n').filter(Boolean);
const base = git('merge-base HEAD MERGE_HEAD').trim();
let failed = 0;

function mergeCases(file) {
  const show = ref => git(`show ${ref}:${file}`);
  let ours = show('HEAD');
  const byName = text => new Map(JSON.parse(text).map(c => [c.name, c]));
  const o = byName(ours), t = byName(show('MERGE_HEAD')), b = byName(show(base));
  const ascii = s => s.replace(/[\u0080-\uffff]/g, ch => '\\u' + ch.charCodeAt(0).toString(16).padStart(4, '0'));
  const text = c => ascii(JSON.stringify(c, null, 2)).split('\n').map(l => '  ' + l).join('\n');
  const same = (x, y) => JSON.stringify(x) === JSON.stringify(y);
  // Where a case's text starts and ends in the file.
  const span = (raw, name) => {
    const at = raw.indexOf(`"name": ${JSON.stringify(name)}`);
    const start = raw.lastIndexOf('\n  {', at) + 1;
    let depth = 0, i = start, inString = false;
    for (; i < raw.length; i++) {
      const ch = raw[i];
      if (inString) { if (ch === '\\') i++; else if (ch === '"') inString = false; continue; }
      if (ch === '"') inString = true;
      else if (ch === '{') depth++;
      else if (ch === '}' && --depth === 0) { i++; break; }
    }
    return [start, i];
  };
  const added = [], changed = [], problems = [];
  for (const [name, c] of t) {
    if (!b.has(name)) {
      if (!o.has(name)) added.push(c);
      else if (!same(o.get(name), c)) problems.push(`both sides added \`${name}\` differently`);
    } else if (!same(b.get(name), c)) {
      if (!o.has(name)) problems.push(`theirs changed \`${name}\`, ours removed it`);
      else if (same(o.get(name), b.get(name))) changed.push(c);
      else if (!same(o.get(name), c)) problems.push(`both sides changed \`${name}\``);
    }
  }
  let removed = 0;
  for (const name of b.keys()) {
    if (t.has(name) || !o.has(name)) continue;
    if (!same(o.get(name), b.get(name))) { problems.push(`theirs removed \`${name}\`, ours changed it`); continue; }
    let [start, end] = span(ours, name);
    if (ours[end] === ',') end++;
    if (ours[end] === '\n') end++;
    ours = ours.slice(0, start) + ours.slice(end);
    removed++;
  }
  for (const c of changed) { const [start, end] = span(ours, c.name); ours = ours.slice(0, start) + text(c) + ours.slice(end); }
  if (added.length) {
    const end = ours.lastIndexOf('\n]');
    ours = ours.slice(0, end).replace(/,\s*$/, '') + ',\n' + added.map(text).join(',\n') + ours.slice(end);
  }
  ours = ours.replace(/,(\s*\n\])/, '$1');
  const names = JSON.parse(ours).map(c => c.name);
  if (new Set(names).size !== names.length) problems.push('a name appears twice after the merge');
  console.log(`${file}: ${names.length} cases (added ${added.length}, changed ${changed.length}, removed ${removed})`);
  for (const problem of problems) console.log(`  NOT MERGED: ${problem}`);
  if (problems.length) return false;
  writeFileSync(file, ours);
  return true;
}

function mergeProse(file) {
  const before = readFileSync(file, 'utf8');
  const hunk = /<<<<<<< [^\n]*\n([^]*?)(?:\|\|\|\|\|\|\| [^\n]*\n[^]*?)?=======\n([^]*?)>>>>>>> [^\n]*\n/g;
  // A paragraph both sides carry (an entry that reached each side through an earlier merge) is kept
  // once: theirs' paragraphs already present anywhere on our side of the file are dropped.
  const oursText = before.replace(hunk, '$1');
  const after = before.replace(hunk, (_, ours, theirs) => {
    const kept = theirs.split(/\n(?=\n)/).filter(p => p.trim() === '' || !oursText.includes(p.replace(/^\n/, '')));
    return ours + kept.join('\n');
  });
  if (/^(<<<<<<<|>>>>>>>) /m.test(after)) { console.log(`${file}: conflict markers left`); return false; }
  writeFileSync(file, after);
  console.log(`${file}: both sides kept`);
  return true;
}

for (const file of files) {
  let ok;
  if (/^tests\/.*\.json$/.test(file)) ok = mergeCases(file);
  else if (file.endsWith('.md')) ok = mergeProse(file);
  else { console.log(`${file}: a source conflict needs a decision; not touched`); ok = false; }
  if (ok) git(`add -- ${JSON.stringify(file)}`); else failed++;
}
process.exit(failed ? 1 : 0);
