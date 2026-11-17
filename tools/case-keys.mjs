// A case file (tests/*-cases.json) with an object that names a key twice parses without complaint:
// JSON.parse keeps the last value, so two cases fused by a bad merge silently become one - the first
// never runs and the second may inherit its expectation. This scans the raw text, which is the only
// place the repeat is visible, and names the cases involved.
import { readFileSync } from 'node:fs';

// Every object in `text` that repeats a key, as { line, key, names } (`names`: the object's `name`
// values, all of them).
export function duplicateKeys(text) {
  const found = [];
  const stack = [];
  let i = 0;
  let line = 1;
  let expectKey = false;
  const readString = () => {
    let out = '';
    i++;
    while (i < text.length && text[i] !== '"') {
      if (text[i] === '\\') { out += text[i] + text[i + 1]; i += 2; continue; }
      if (text[i] === '\n') line++;
      out += text[i++];
    }
    i++;
    return out;
  };
  while (i < text.length) {
    const ch = text[i];
    if (ch === '\n') { line++; i++; continue; }
    if (ch === '{') { stack.push({ keys: new Map(), names: [], line, object: true }); expectKey = true; i++; continue; }
    if (ch === '[') { stack.push({ object: false }); i++; continue; }
    if (ch === '}' || ch === ']') {
      const top = stack.pop();
      if (top && top.object) {
        for (const [key, count] of top.keys) {
          if (count > 1) found.push({ line: top.line, key, names: top.names });
        }
      }
      i++;
      continue;
    }
    if (ch === ',') { const top = stack[stack.length - 1]; expectKey = Boolean(top && top.object); i++; continue; }
    if (ch === '"') {
      const top = stack[stack.length - 1];
      const value = readString();
      if (expectKey && top && top.object) {
        top.keys.set(value, (top.keys.get(value) ?? 0) + 1);
        // The value after `"name":` is the case's name.
        let j = i;
        while (text[j] === ' ' || text[j] === ':') j++;
        if (value === 'name' && text[j] === '"') {
          const save = i;
          i = j;
          top.names.push(readString());
          i = save;
        }
        expectKey = false;
      }
      continue;
    }
    i++;
  }
  return found;
}

// Throws when `path` has an object with a repeated key, naming every one.
export function assertNoDuplicateKeys(path) {
  const found = duplicateKeys(readFileSync(path, 'utf8'));
  if (found.length !== 0) {
    const lines = found.map(({ line, key, names }) => `${path}:${line}: key "${key}" appears twice in one object (cases: ${names.join(', ') || 'unnamed'}) - two cases were fused`);
    throw new Error(lines.join('\n'));
  }
}

if (import.meta.main) {
  const files = process.argv.slice(2);
  let bad = 0;
  for (const file of files) {
    try { assertNoDuplicateKeys(file); } catch (error) { console.error(error.message); bad++; }
  }
  if (bad !== 0) process.exit(1);
  console.log(`case-keys: no repeated keys in ${files.length} file(s)`);
}
