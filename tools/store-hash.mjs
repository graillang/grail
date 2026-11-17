// The digest the build store names blobs by and an interface's trailer carries (compiler/native.grl,
// fast_hash): XXH64 of the bytes under the seeds 0, 1, 2 and 3, each big-endian - 32 bytes, or 64 hex
// digits as the store writes them. The one JavaScript copy, so the tools that check a blob name or
// reseal an edited interface agree with the compiler by construction.
const M64 = (1n << 64n) - 1n;
const XP = [11400714785074694791n, 14029467366897019727n, 1609587929392839161n, 9650029242287828579n, 2870177450012600261n];
const rotl = (x, r) => ((x << r) | (x >> (64n - r))) & M64;
const xround = (acc, lane) => (rotl((acc + lane * XP[1]) & M64, 31n) * XP[0]) & M64;
const xmerge = (acc, lane) => (((acc ^ xround(0n, lane)) * XP[0]) & M64) + XP[3] & M64;
export function xxh64(data, seed) {
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const n = data.length;
  let at = 0, h;
  if (n >= 32) {
    const v = [(seed + XP[0] + XP[1]) & M64, (seed + XP[1]) & M64, seed, (seed - XP[0]) & M64];
    for (; at + 32 <= n; at += 32) for (let k = 0; k < 4; k++) v[k] = xround(v[k], view.getBigUint64(at + 8 * k, true));
    h = (rotl(v[0], 1n) + rotl(v[1], 7n) + rotl(v[2], 12n) + rotl(v[3], 18n)) & M64;
    for (let k = 0; k < 4; k++) h = xmerge(h, v[k]);
  } else h = (seed + XP[4]) & M64;
  h = (h + BigInt(n)) & M64;
  for (; at + 8 <= n; at += 8) h = ((rotl(h ^ xround(0n, view.getBigUint64(at, true)), 27n) * XP[0]) & M64) + XP[3] & M64;
  if (at + 4 <= n) { h = ((rotl(h ^ ((BigInt(view.getUint32(at, true)) * XP[0]) & M64), 23n) * XP[1]) & M64) + XP[2] & M64; at += 4; }
  for (; at < n; at++) h = (rotl(h ^ ((BigInt(data[at]) * XP[4]) & M64), 11n) * XP[0]) & M64;
  h = ((h ^ (h >> 33n)) * XP[1]) & M64;
  h = ((h ^ (h >> 29n)) * XP[2]) & M64;
  return h ^ (h >> 32n);
}
export const storeDigest = data => [0n, 1n, 2n, 3n].map(seed => xxh64(data, seed).toString(16).padStart(16, '0')).join('');
// The 32 raw bytes of the same digest: what an interface's trailer ends with.
export const fastDigest = data => Buffer.from(storeDigest(data), 'hex');
