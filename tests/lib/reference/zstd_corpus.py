# Generates tests/lib/zstd: NAME.in (a zstd stream made by the reference library) and manifest.txt,
# which lists "ok NAME LENGTH XXH64" (the decompressed length and its XXH64, seed 0) or
# "reject NAME" for streams the decoder must refuse.   python3 zstd_corpus.py ../zstd
import os, random, subprocess, sys, zstandard
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
rng = random.Random(1950)
words = b"the quick brown fox jumps over a lazy dog while geometry clusters stream pages of meshlets ".split()
def text(n):
    b = bytearray()
    while len(b) < n:
        b += rng.choice(words) + b" "
    return bytes(b[:n])
def structured(n):
    b = bytearray()
    i = 0
    while len(b) < n:
        b += (i * 2654435761 & 0xffffffff).to_bytes(4, 'little') + bytes([i & 7, 0, 0, 1])
        i += 1
    return bytes(b[:n])
def noise(n):
    return bytes(rng.getrandbits(8) for _ in range(n))
def runs(n):
    b = bytearray()
    while len(b) < n:
        b += bytes([rng.getrandbits(8)]) * rng.randint(1, 300)
    return bytes(b[:n])
inputs = {'empty': b'', 'one': b'x', 'text-small': text(100), 'text': text(70000), 'text-large': text(600000),
          'structured': structured(40000), 'noise': noise(8000), 'runs': runs(400000), 'mixed': text(30000) + noise(5000) + runs(30000) + structured(40000)}
manifest = []
def emit(name, stream, original):
    open(os.path.join(out, name + '.in'), 'wb').write(stream)
    if original is None:
        manifest.append('reject ' + name)
    else:
        digest = subprocess.run(['xxhsum', '-H1', '-'], input=original, capture_output=True, check=True).stdout.split()[0]
        manifest.append(f'ok {name} {len(original)} {int(digest, 16)}')
for key, data in inputs.items():
    levels = [1, 3, 9, 19, 22] if len(data) <= 200000 else [1, 12]
    for level in levels:
        for checksum in ((False, True) if len(data) <= 200000 else (True,)):
            c = zstandard.ZstdCompressor(level=level, write_checksum=checksum, write_content_size=(level % 2 == 1))
            emit(f'{key}-l{level}-c{int(checksum)}', c.compress(data), data)
    for level in ((-5, -1) if len(data) <= 200000 else ()):
        emit(f'{key}-fast{-level}', zstandard.ZstdCompressor(level=level).compress(data), data)
# Streaming (no content size, many blocks) and long-distance matching.
for key in ('text', 'runs', 'mixed'):
    data = inputs[key]
    c = zstandard.ZstdCompressor(level=6, write_checksum=True)
    obj = c.compressobj()
    emit(f'{key}-stream', obj.compress(data[:len(data) // 3]) + obj.compress(data[len(data) // 3:]) + obj.flush(), data)
    p = zstandard.ZstdCompressionParameters.from_level(9, enable_ldm=True, window_log=22)
    emit(f'{key}-ldm', zstandard.ZstdCompressor(compression_params=p).compress(data), data)
# Concatenated frames and a skippable frame between them.
a, b = inputs['text'][:5000], inputs['runs'][:7000]
fa = zstandard.ZstdCompressor(level=3).compress(a)
fb = zstandard.ZstdCompressor(level=19, write_checksum=True).compress(b)
skip = (0x184D2A53).to_bytes(4, 'little') + (5).to_bytes(4, 'little') + b'hello'
emit('two-frames', fa + fb, a + b)
emit('skippable', fa + skip + fb, a + b)
# Rejections: bad checksum, truncation, bad magic, dictionary frame, wrong content size.
good = zstandard.ZstdCompressor(level=3, write_checksum=True).compress(inputs['text'][:20000])
bad = bytearray(good); bad[-1] ^= 1
emit('reject-checksum', bytes(bad), None)
emit('reject-truncated', good[:len(good) // 2], None)
emit('reject-magic', b'\x29' + good[1:], None)
d = zstandard.train_dictionary(1024, [text(500) for _ in range(200)])
emit('reject-dictionary', zstandard.ZstdCompressor(dict_data=d).compress(text(3000)), None)
c = zstandard.ZstdCompressor(level=3, write_content_size=True).compress(inputs['text'][:4000])
wrong = bytearray(c); wrong[5] = (wrong[5] + 1) & 255
emit('reject-content-size', bytes(wrong), None)
open(os.path.join(out, 'manifest.txt'), 'w').write('\n'.join(manifest) + '\n')
print(len(manifest), 'streams')
