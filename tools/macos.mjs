// macOS platform linkage beyond libSystem: framework stubs, dylib dependency inspection and
// ad-hoc code signatures. Everything here is static (Mach-O parsing and hashing); nothing runs on
// Apple hardware and no result here is evidence of runtime behaviour.
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { frameworkInstallName } from './native.mjs';

export const LC_LOAD_DYLIB = 0x0c;
export const LC_CODE_SIGNATURE = 0x1d;
export const LC_LOAD_WEAK_DYLIB = 0x80000018;
export const LC_REEXPORT_DYLIB = 0x8000001f;
export const CS_ADHOC = 0x2;
const CSMAGIC_EMBEDDED_SIGNATURE = 0xfade0cc0;
const CSMAGIC_CODEDIRECTORY = 0xfade0c02;

function readHeader(bytes) {
  const magic = bytes.readUInt32LE(0);
  if (magic !== 0xfeedfacf) throw new Error(`not a 64-bit Mach-O image (magic 0x${magic.toString(16)})`);
  const cputype = bytes.readUInt32LE(4);
  const ncmds = bytes.readUInt32LE(16);
  return { cputype, ncmds, offset: 32 };
}

const cpuNames = { 0x01000007: 'x86_64', 0x0100000c: 'arm64' };

// Load commands: dylib dependencies (with their install names) and the code-signature region.
export function loadCommands(binary) {
  const bytes = readFileSync(binary);
  const header = readHeader(bytes);
  const found = [];
  let offset = header.offset;
  for (let i = 0; i < header.ncmds; i++) {
    const cmd = bytes.readUInt32LE(offset);
    const size = bytes.readUInt32LE(offset + 4);
    if (size < 8) throw new Error(`malformed load command ${i} in ${binary}`);
    if (cmd === LC_LOAD_DYLIB || cmd === LC_LOAD_WEAK_DYLIB || cmd === LC_REEXPORT_DYLIB) {
      const nameOffset = bytes.readUInt32LE(offset + 8);
      const end = bytes.indexOf(0, offset + nameOffset);
      found.push({ cmd, name: bytes.toString('latin1', offset + nameOffset, end < 0 ? offset + size : end) });
    }
    if (cmd === LC_CODE_SIGNATURE) {
      found.push({ cmd, dataoff: bytes.readUInt32LE(offset + 8), datasize: bytes.readUInt32LE(offset + 12) });
    }
    offset += size;
  }
  return { size: bytes.length, cpu: cpuNames[header.cputype] ?? `0x${header.cputype.toString(16)}`, commands: found };
}

export function dylibs(binary) {
  return loadCommands(binary).commands.filter(c => c.name !== undefined).map(c => c.name);
}

// Static validation of the ad-hoc signature: SuperBlob -> CodeDirectory -> page hashes + cdhash.
export function verifyCodeSignature(binary) {
  const bytes = readFileSync(binary);
  const { commands, cpu } = loadCommands(binary);
  const signature = commands.find(c => c.cmd === LC_CODE_SIGNATURE);
  const problems = [];
  if (!signature) return { present: false, valid: false, cpu, problems: ['no LC_CODE_SIGNATURE'] };
  if (signature.dataoff + signature.datasize > bytes.length) {
    return { present: true, valid: false, cpu, problems: ['signature extends past end of file'] };
  }
  const blob = bytes.subarray(signature.dataoff, signature.dataoff + signature.datasize);
  if (blob.readUInt32BE(0) !== CSMAGIC_EMBEDDED_SIGNATURE) {
    return { present: true, valid: false, cpu, problems: ['superblob magic is not CSMAGIC_EMBEDDED_SIGNATURE'] };
  }
  const count = blob.readUInt32BE(8);
  let codeDirectory = null;
  for (let i = 0; i < count; i++) {
    const type = blob.readUInt32BE(12 + i * 8);
    const at = blob.readUInt32BE(16 + i * 8);
    if (type === 0) codeDirectory = at;
  }
  if (codeDirectory === null) return { present: true, valid: false, cpu, problems: ['no CodeDirectory slot'] };
  if (blob.readUInt32BE(codeDirectory) !== CSMAGIC_CODEDIRECTORY) {
    return { present: true, valid: false, cpu, problems: ['CodeDirectory magic mismatch'] };
  }
  const cd = blob.subarray(codeDirectory);
  const cdLength = cd.readUInt32BE(4);
  const version = cd.readUInt32BE(8);
  const flags = cd.readUInt32BE(12);
  const hashOffset = cd.readUInt32BE(16);
  const nCodeSlots = cd.readUInt32BE(28);
  const codeLimit = cd.readUInt32BE(32);
  const hashSize = cd[36];
  const hashType = cd[37];
  const pageSize = 1 << cd[39];
  if (hashType !== 2) problems.push(`hash type ${hashType} is not SHA-256`);
  if (hashSize !== 32) problems.push(`hash size ${hashSize} is not 32`);
  if (codeLimit > signature.dataoff) problems.push('code limit overlaps the signature');
  if ((flags & CS_ADHOC) === 0) problems.push('CS_ADHOC flag is not set');
  // Every page hash must match the page it covers; this is what makes the signature a real check.
  // Code slots start at hashOffset and run forward; special slots sit immediately before it.
  let mismatched = 0;
  let firstMismatch = 0;
  for (let slot = 1; slot <= nCodeSlots; slot++) {
    const start = (slot - 1) * pageSize;
    const end = Math.min(start + pageSize, codeLimit);
    if (end > bytes.length) { problems.push(`page ${slot} is past end of file`); break; }
    const digest = createHash('sha256').update(bytes.subarray(start, end)).digest();
    const stored = cd.subarray(hashOffset + (slot - 1) * hashSize, hashOffset + slot * hashSize);
    if (!digest.equals(stored)) {
      mismatched += 1;
      if (firstMismatch === 0) firstMismatch = slot;
    }
  }
  if (mismatched > 0) {
    problems.push(mismatched === 1
      ? `page ${firstMismatch} hash mismatch`
      : `page ${firstMismatch} hash mismatch (${mismatched} pages mismatched)`);
  }
  const cdhash = createHash('sha256').update(cd.subarray(0, cdLength)).digest('hex');
  return {
    present: true,
    valid: problems.length === 0,
    cpu,
    version: `0x${version.toString(16)}`,
    flags,
    adhoc: (flags & CS_ADHOC) !== 0,
    pages: nCodeSlots,
    pageSize,
    codeLimit,
    cdhash,
    problems,
  };
}

// `bun tools/macos.mjs inspect BIN` prints dependencies and the signature verdict; `verify` exits
// non-zero unless the signature is structurally valid, so it can gate a release step.
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [mode, binary] = process.argv.slice(2);
  if (!binary) throw new Error('usage: bun tools/macos.mjs inspect|verify BINARY');
  const { cpu, commands } = loadCommands(binary);
  const deps = commands.filter(c => c.name !== undefined).map(c => `  ${c.name}`);
  const signature = verifyCodeSignature(binary);
  console.log(`${binary}: Mach-O ${cpu}`);
  console.log(`dylibs (${deps.length}):`);
  console.log(deps.length ? deps.join('\n') : '  none');
  console.log(`signature: ${signature.present ? (signature.valid ? 'valid ad-hoc' : 'invalid') : 'absent'}`);
  if (signature.present) {
    console.log(`  cdhash ${signature.cdhash}, ${signature.pages} pages of ${signature.pageSize} bytes, code limit ${signature.codeLimit}`);
    for (const problem of signature.problems) console.log(`  problem: ${problem}`);
  }
  if (mode === 'verify' && !signature.valid) process.exit(1);
}
