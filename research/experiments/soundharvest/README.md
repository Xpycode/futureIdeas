# Isolated SAR PCM export experiment

Run on 2026-10-16. No apps launched. Source snapshot copied unchanged from `1-macOS/SAR/01_Project/SAR/AudioExporter.swift`; SHA-256 `3ac6d43cae01df9f473fb7ee6cde9b9e42363addf1528dfd3549646e809618d3`. `Harness.swift` supplies the same `AudioSelection` declaration from SAR's `Recording.swift`. This snapshot is evidence, not a maintained shared library.

From the FutureIdeas root, use a fresh temporary output directory on reruns (`-n` deliberately refuses to overwrite MOV/WAV destinations):

```sh
python3 research/experiments/soundharvest/fixture_check.py generate /private/tmp/soundharvest-feasibility
swiftc -module-cache-path /private/tmp/soundharvest-feasibility/swift-cache research/experiments/soundharvest/AudioExporter.snapshot.swift research/experiments/soundharvest/Harness.swift -o /private/tmp/soundharvest-feasibility/harness
/private/tmp/soundharvest-feasibility/harness /private/tmp/soundharvest-feasibility
python3 research/experiments/soundharvest/fixture_check.py verify /private/tmp/soundharvest-feasibility
mkdir -p /private/tmp/soundharvest-feasibility/mov-roundtrip
ffmpeg -hide_banner -loglevel error -f lavfi -i color=c=black:s=64x64:r=25:d=0.1 -i /private/tmp/soundharvest-feasibility/source.wav -map 0:v:0 -map 1:a:0 -c:v mpeg4 -c:a pcm_s24le -n /private/tmp/soundharvest-feasibility/fixture.mov
ffmpeg -hide_banner -loglevel error -i /private/tmp/soundharvest-feasibility/fixture.mov -map 0:a:0 -vn -c:a copy -n /private/tmp/soundharvest-feasibility/mov-roundtrip/source.wav
/private/tmp/soundharvest-feasibility/harness /private/tmp/soundharvest-feasibility/mov-roundtrip
python3 research/experiments/soundharvest/fixture_check.py verify /private/tmp/soundharvest-feasibility/mov-roundtrip
```

A separate Python `wave` comparison also confirmed the demuxed MOV audio's PCM payload equals the original generated WAV. The `.wav` container header differs; PCM payload equality is the intended claim.

[WAV results](results.txt) and [MOV results](mov-results.txt) retain actual output. Error cases were observed in harness output; the Python check asserts successful selections' frame payload and format. See [investigation](../../2026-10-16-soundharvest-feasibility.md) for boundaries and next criteria. Only one synthetic PCM format was exercised; this does not establish real-camera support, safe cancellation/publication or usable retrieval.
