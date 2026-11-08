// Deterministic tar.gz and zip writers for release artifacts.
//
// Release packaging must not depend on the host's `tar`/`zip` behaviour: the
// same files must produce byte-identical archives on every lane. Entries are
// sorted by path, timestamps come from SOURCE_DATE_EPOCH (default 0) and both
// writers use the ordinary public formats, so stock tools can read them.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { gunzipSync, gzipSync } from 'node:zlib';

export const BLOCK = 512;

export function sourceDateEpoch(env = process.env) {
  const raw = env.SOURCE_DATE_EPOCH;
  if (raw === undefined || raw === '') return 0;
  if (!/^\d+$/.test(raw)) throw new Error(`SOURCE_DATE_EPOCH must be a non-negative integer, got ${JSON.stringify(raw)}`);
  return Number(raw);
}

export function normalizeEntries(entries) {
  return entries
    .map(entry => {
      if (!entry.path || entry.path.startsWith('/') || entry.path.includes('..')) {
        throw new Error(`Unsafe archive path ${JSON.stringify(entry.path)}`);
      }
      return {
        path: entry.path,
        data: Buffer.isBuffer(entry.data) ? entry.data : Buffer.from(entry.data ?? ''),
        mode: entry.mode ?? 0o644,
        mtime: entry.mtime ?? 0,
      };
    })
    .sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
}

function octal(value, width) {
  const text = Math.max(0, Math.floor(value)).toString(8);
  if (text.length > width - 1) throw new Error(`tar field overflow: ${value} does not fit ${width - 1} octal digits`);
  return text.padStart(width - 1, '0') + '\0';
}

function tarChecksum(header) {
  let total = 0;
  for (let i = 0; i < BLOCK; i += 1) total += i >= 148 && i < 156 ? 0x20 : header[i];
  return total.toString(8).padStart(6, '0') + '\u0000 ';
}

function tarHeader(entry) {
  const name = Buffer.byteLength(entry.path, 'utf8');
  if (name > 100) throw new Error(`tar path longer than 100 bytes: ${entry.path}`);
  const header = Buffer.alloc(BLOCK);
  header.write(entry.path, 0, 'utf8');
  header.write(octal(entry.mode, 8), 100, 'ascii');
  header.write(octal(0, 8), 108, 'ascii');
  header.write(octal(0, 8), 116, 'ascii');
  header.write(octal(entry.data.length, 12), 124, 'ascii');
  header.write(octal(entry.mtime, 12), 136, 'ascii');
  header.write('        ', 148, 'ascii');
  header.write('0', 156, 'ascii');
  header.write('ustar\u000000', 257, 'ascii');
  header.write(octal(0, 8), 329, 'ascii');
  header.write(octal(0, 8), 337, 'ascii');
  header.write(tarChecksum(header), 148, 'ascii');
  return header;
}

export function createTar(entries) {
  const parts = [];
  for (const entry of normalizeEntries(entries)) {
    if (entry.data.length > 0o77777777777) throw new Error(`tar entry too large: ${entry.path}`);
    parts.push(tarHeader(entry), entry.data);
    const padding = (BLOCK - (entry.data.length % BLOCK)) % BLOCK;
    if (padding) parts.push(Buffer.alloc(padding));
  }
  parts.push(Buffer.alloc(BLOCK * 2));
  return Buffer.concat(parts);
}

export function createTarGz(entries, options = {}) {
  return gzipSync(createTar(entries), { level: options.level ?? 9, mtime: 0 });
}

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i += 1) {
    let value = i;
    for (let bit = 0; bit < 8; bit += 1) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
    table[i] = value >>> 0;
  }
  return table;
})();

export function crc32(data) {
  let value = 0xffffffff;
  for (const byte of data) value = CRC_TABLE[(value ^ byte) & 0xff] ^ (value >>> 8);
  return (value ^ 0xffffffff) >>> 0;
}

// DOS timestamp for 1980-01-01 00:00:00, the earliest representable value.
const DOS_DATE = 0x21;
const DOS_TIME = 0;

export function createZip(entries) {
  const files = normalizeEntries(entries);
  const locals = [];
  const central = [];
  let offset = 0;
  for (const file of files) {
    const name = Buffer.from(file.path, 'utf8');
    const crc = crc32(file.data);
    if (file.data.length > 0xffffffff || offset > 0xffffffff) throw new Error('zip64 is not supported; artifact is too large');
    const header = Buffer.alloc(30);
    header.writeUInt32LE(0x04034b50, 0);
    header.writeUInt16LE(20, 4);
    header.writeUInt16LE(0x0800, 6); // UTF-8 names
    header.writeUInt16LE(0, 8); // stored, no compression
    header.writeUInt16LE(DOS_TIME, 10);
    header.writeUInt16LE(DOS_DATE, 12);
    header.writeUInt32LE(crc, 14);
    header.writeUInt32LE(file.data.length, 18);
    header.writeUInt32LE(file.data.length, 22);
    header.writeUInt16LE(name.length, 26);
    header.writeUInt16LE(0, 28);
    locals.push(header, name, file.data);

    const entry = Buffer.alloc(46);
    entry.writeUInt32LE(0x02014b50, 0);
    entry.writeUInt16LE(0x031e, 4); // Unix, version 3.0
    entry.writeUInt16LE(20, 6);
    entry.writeUInt16LE(0x0800, 8);
    entry.writeUInt16LE(0, 10);
    entry.writeUInt16LE(DOS_TIME, 12);
    entry.writeUInt16LE(DOS_DATE, 14);
    entry.writeUInt32LE(crc, 16);
    entry.writeUInt32LE(file.data.length, 20);
    entry.writeUInt32LE(file.data.length, 24);
    entry.writeUInt16LE(name.length, 28);
    entry.writeUInt16LE(0, 30);
    entry.writeUInt16LE(0, 32);
    entry.writeUInt16LE(0, 34);
    entry.writeUInt16LE(0, 36);
    entry.writeUInt32LE(((((0o100000 | (file.mode & 0xfff)) & 0xffff) << 16) >>> 0), 38);
    entry.writeUInt32LE(offset, 42);
    central.push(entry, name);
    offset += header.length + name.length + file.data.length;
  }
  const directory = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  end.writeUInt16LE(0, 20);
  return Buffer.concat([...locals, directory, end]);
}

export function createArchive(format, entries, options = {}) {
  if (format === 'tar.gz') return createTarGz(entries, options);
  if (format === 'zip') return createZip(entries);
  throw new Error(`Unknown archive format ${format}; expected tar.gz or zip`);
}

export function writeArchive(path, format, entries, options = {}) {
  const bytes = createArchive(format, entries, options);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, bytes);
  return bytes;
}

// Lists entry names without extracting. Used by tests and `ci.mjs verify`.
export function listArchive(path) {
  const bytes = readFileSync(path);
  if (bytes.length >= 4 && bytes.readUInt32LE(0) === 0x04034b50) return listZip(bytes);
  if (bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b) {
    return listTar(gunzipSync(bytes));
  }
  return listTar(bytes);
}

function listTar(bytes) {
  const names = [];
  for (let offset = 0; offset + BLOCK <= bytes.length; offset += BLOCK) {
    const header = bytes.subarray(offset, offset + BLOCK);
    if (header.every(byte => byte === 0)) break;
    const name = header.toString('utf8', 0, 100).replace(/\u0000.*$/s, '');
    const sizeText = header.toString('ascii', 124, 136).replace(/\u0000.*$/s, '').trim();
    const size = sizeText ? parseInt(sizeText, 8) : 0;
    names.push(name);
    offset += Math.ceil(size / BLOCK) * BLOCK;
  }
  return names;
}

function listZip(bytes) {
  let end = bytes.length - 22;
  while (end >= 0 && bytes.readUInt32LE(end) !== 0x06054b50) end -= 1;
  if (end < 0) throw new Error('zip end-of-central-directory record not found');
  const count = bytes.readUInt16LE(end + 10);
  let offset = bytes.readUInt32LE(end + 16);
  const names = [];
  for (let i = 0; i < count; i += 1) {
    if (bytes.readUInt32LE(offset) !== 0x02014b50) throw new Error('zip central directory is corrupt');
    const nameLength = bytes.readUInt16LE(offset + 28);
    const extraLength = bytes.readUInt16LE(offset + 30);
    const commentLength = bytes.readUInt16LE(offset + 32);
    names.push(bytes.toString('utf8', offset + 46, offset + 46 + nameLength));
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return names;
}
