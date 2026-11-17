// The internal assembler's oracle (docs/design/compile-speed.md, stage 4): the object the
// compiler's own assembler (compiler/asm_x86.grl) writes from an assembly file must match the
// object clang writes from the same file - every content section's bytes, size, flags and
// alignment, the relocation lists (section, offset, type, symbol, addend) and the symbol tables as
// sets. A difference prints the first differing section and, for code, objdump's view of where.
//
//   bun tools/asm-oracle.mjs FILE.s...            compare the two objects of each file
//   bun tools/asm-oracle.mjs --corpus [--filter RE] [--shard i/n]   compile corpus programs, compare
//   GRAIL_ASM selects the assembler binary (default: the tree's compiler, `grail asm IN -o OUT`)
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync } from 'node:fs';
import { basename, join } from 'node:path';

export function readElf(bytes) {
  const b = Buffer.from(bytes);
  if (b.readUInt32BE(0) !== 0x7f454c46) throw new Error('not an ELF file');
  const shoff = Number(b.readBigUInt64LE(0x28));
  const shnum = b.readUInt16LE(0x3c);
  const shstrndx = b.readUInt16LE(0x3e);
  const headers = [];
  for (let i = 0; i < shnum; i++) {
    const h = shoff + i * 64;
    headers.push({
      nameAt: b.readUInt32LE(h), type: b.readUInt32LE(h + 4), flags: Number(b.readBigUInt64LE(h + 8)),
      offset: Number(b.readBigUInt64LE(h + 24)), size: Number(b.readBigUInt64LE(h + 32)),
      link: b.readUInt32LE(h + 40), info: b.readUInt32LE(h + 44), align: Number(b.readBigUInt64LE(h + 48)),
    });
  }
  const str = (table, at) => { let e = at; while (b[table.offset + e]) e++; return b.toString('latin1', table.offset + at, table.offset + e); };
  for (const h of headers) h.name = str(headers[shstrndx], h.nameAt);
  const symtab = headers.find(h => h.type === 2);
  const symbols = [];
  if (symtab) {
    const strtab = headers[symtab.link];
    for (let at = symtab.offset; at < symtab.offset + symtab.size; at += 24) {
      const shndx = b.readUInt16LE(at + 6);
      const info = b[at + 4];
      const name = (info & 15) === 3 ? `[section ${headers[shndx].name}]` : str(strtab, b.readUInt32LE(at));
      symbols.push({ name, bind: info >> 4, type: info & 15, section: shndx === 0 ? 'UND' : shndx === 0xfff1 ? 'ABS' : headers[shndx]?.name, value: Number(b.readBigUInt64LE(at + 8)), size: Number(b.readBigUInt64LE(at + 16)) });
    }
  }
  const sections = new Map();
  for (const h of headers) {
    if (h.type === 1 || h.type === 8) {
      sections.set(h.name, { type: h.type, flags: h.flags, align: h.align, size: h.size, data: h.type === 8 ? null : b.subarray(h.offset, h.offset + h.size), relocs: [] });
    }
  }
  for (const h of headers) {
    if (h.type !== 4) continue;
    const target = headers[h.info].name;
    const list = sections.get(target).relocs;
    for (let at = h.offset; at < h.offset + h.size; at += 24) {
      const info = b.readBigUInt64LE(at + 8);
      list.push({ offset: Number(b.readBigUInt64LE(at)), type: Number(info & 0xffffffffn), symbol: symbols[Number(info >> 32n)]?.name ?? '', addend: b.readBigInt64LE(at + 16) });
    }
    list.sort((x, y) => x.offset - y.offset || x.type - y.type);
  }
  return { sections, symbols: symbols.slice(1) };
}

// The first difference between two objects, or null.
export function compareObjects(want, got) {
  const a = readElf(want);
  const b = readElf(got);
  const names = new Set([...a.sections.keys(), ...b.sections.keys()]);
  for (const name of names) {
    const x = a.sections.get(name);
    const y = b.sections.get(name);
    if (!x || !y) return `section ${name}: only in ${x ? 'clang' : 'internal'}`;
    for (const k of ['type', 'flags', 'align', 'size']) {
      if (x[k] !== y[k]) return `section ${name}: ${k} ${x[k]} (clang) vs ${y[k]} (internal)`;
    }
    if (x.data && !x.data.equals(y.data)) {
      let i = 0;
      while (x.data[i] === y.data[i]) i++;
      return { section: name, offset: i, message: `section ${name}: bytes differ at offset 0x${i.toString(16)}` };
    }
    const n = Math.max(x.relocs.length, y.relocs.length);
    for (let i = 0; i < n; i++) {
      const p = x.relocs[i];
      const q = y.relocs[i];
      if (!p || !q || p.offset !== q.offset || p.type !== q.type || p.symbol !== q.symbol || p.addend !== q.addend) {
        const show = r => r ? `0x${r.offset.toString(16)} type ${r.type} ${r.symbol}${r.addend < 0n ? '' : '+'}${r.addend}` : 'none';
        return { section: name, offset: (p ?? q).offset, message: `section ${name}: relocation ${i}: ${show(p)} (clang) vs ${show(q)} (internal)` };
      }
    }
  }
  const key = s => `${s.name}|${s.bind}|${s.type}|${s.section}|${s.value}|${s.size}`;
  const sa = new Set(a.symbols.map(key));
  const sb = new Set(b.symbols.map(key));
  for (const s of sa) if (!sb.has(s)) return `symbol ${s} only in clang's object`;
  for (const s of sb) if (!sa.has(s)) return `symbol ${s} only in the internal object`;
  return null;
}

function run(argv) {
  const r = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', maxBuffer: 1 << 28 });
  return r;
}

export function checkFile(source, work, assembler) {
  const stem = join(work, basename(source).replace(/\.s$/, ''));
  const clang = run(['clang', '--target=x86_64-linux-gnu', '-c', source, '-o', `${stem}.clang.o`]);
  if (clang.status !== 0) return `clang failed: ${clang.stderr}`;
  const ours = run([...assembler, source, '-o', `${stem}.grail.o`]);
  if (ours.status !== 0) return `internal assembler failed: ${ours.stdout}${ours.stderr}`;
  const diff = compareObjects(readFileSync(`${stem}.clang.o`), readFileSync(`${stem}.grail.o`));
  if (!diff) return null;
  if (typeof diff === 'string') return diff;
  const window = o => run(['objdump', '-d', '-r', `--start-address=${Math.max(0, diff.offset - 32)}`, `--stop-address=${diff.offset + 32}`, '-j', diff.section, o]).stdout.split('\n').slice(6).join('\n');
  return `${diff.message}\n--- clang\n${window(`${stem}.clang.o`)}\n--- internal\n${window(`${stem}.grail.o`)}`;
}

if (import.meta.main) {
  const args = process.argv.slice(2);
  const assembler = process.env.GRAIL_ASM ? process.env.GRAIL_ASM.split(' ') : null;
  if (!assembler) {
    console.error('asm-oracle: set GRAIL_ASM to the internal assembler command');
    process.exit(2);
  }
  const work = join(import.meta.dir, '..', '.work/asm-oracle');
  mkdirSync(work, { recursive: true });
  let failed = 0;
  for (const file of args) {
    const result = checkFile(file, work, assembler);
    if (result) {
      failed++;
      console.log(`FAIL ${file}: ${result}`);
    } else {
      console.log(`ok ${file}`);
    }
  }
  console.log(`asm-oracle: ${args.length - failed} identical, ${failed} different`);
  process.exit(failed ? 1 : 0);
}
