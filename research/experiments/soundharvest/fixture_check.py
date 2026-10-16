"""Generate or verify a tiny deterministic 24-bit PCM export fixture."""
import pathlib
import struct
import sys
import wave
root = pathlib.Path(sys.argv[2])
if sys.argv[1] == 'generate':
    root.mkdir(parents=True, exist_ok=True)
    raw = b''.join(v.to_bytes(3, 'little', signed=True)
                   for i in range(4800)
                   for v in (i * 1000 - 2400000, 2399999 - i * 999))
    with wave.open(str(root / 'source.wav'), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(3)
        out.setframerate(48000)
        out.writeframes(raw)
else:
    def pcm(path):
        data = path.read_bytes()
        offset, chunks = 12, {}
        while offset + 8 <= len(data):
            tag, size = struct.unpack_from('<4sI', data, offset)
            chunks[tag] = data[offset + 8:offset + 8 + size]
            offset += 8 + size + (size % 2)
        return struct.unpack_from('<HHIIHH', chunks[b'fmt ']), chunks[b'data']
    _, source = pcm(root / 'source.wav')
    for name, start, end in [('exact', 1200, 3600), ('fractional', 1200, 3600), ('overEnd', 3600, 4800)]:
        fmt, output = pcm(root / (name + '.wav'))
        equal = output == source[start * 6:end * 6]
        print(f'{name}: PCM bytes match source[{start}:{end}]={equal}; WAV fmt={fmt}; data bytes={len(output)}')
        assert equal and fmt[1] == 2 and fmt[2] == 48000 and fmt[5] == 24
