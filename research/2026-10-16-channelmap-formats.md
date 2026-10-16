# ChannelMap B7.1 — PCM precision, six channels and AAC timing

**2026-10-16: investigation executed; AAC offset presentation gate failed.** No app implementation or playback acceptance. The authoritative [formats-04 results](experiments/channelmap/formats-04/results.json) distinguish successful harness execution from media acceptance (`all_media_gates_passed: false`).

## Results

All fixtures use 48 kHz, 48,024 generated frames (1.0005 seconds), two seconds of copied ProRes video, and numeric source channels 5 then 2 exported as two ordered mono MOV tracks. Original PCM fixtures have unknown channel layout; AAC alone is explicitly generated as 5.1 because the encoder requires a supported layout.

| Fixture | Sample gate | Presentation gate | Observation |
|---|---|---|---|
| Eight-channel PCM32, +250 ms | Pass | Pass | All 48,024 samples/channel match the independent integer oracle, including low bits beyond float32 precision |
| Six-channel PCM24, +250 ms | Pass | Pass | All 48,024 samples/channel exact; six-channel routing regression passes |
| Six-channel AAC, zero origin → PCM32 | Pass | Pass | Demux exposes 1,024 skipped priming samples and 104 discarded tail samples; decode yields 48,024 frames |
| Six-channel AAC, +250 ms → PCM32 | Pass | **Fail** | Decode yields 49,152 frames; PCM preserves these exactly but ends 104 samples (2.1667 ms) after the source's declared presentation end |

The PCM32 integer generator uses signed, odd values around ±2^30 with channel-specific and sample-specific variation. Every selected channel-5 sample is inexact in float32. The normal path preserves every bit; an actual export forced through `aformat=sample_fmts=flt` fails both sample comparisons. This directly challenges precision rather than merely choosing a 32-bit container for low-amplitude, exactly representable values.

## AAC diagnosis and separate oracles

AAC is lossy. Its reference is **not** the original uncompressed waveform: the harness decodes the finished source MOV once to interleaved PCM32 with no pan filter, then extracts channel byte slices in Python. Routed outputs are decoded and compared against those slices. This tests channel identity, order, sample count and conversion agreement using the same installed decoder; it is not an independent AAC decoder correctness test.

Presentation is checked separately against the finished source's ffprobe stream start/duration, using rational time bases. Source frames and packets are retained in evidence. At zero origin the initial packet PTS is −1,024 with `skip_samples=1024`; the last packet has duration 920 and `discard_padding=104`. The decoded and routed 48,024-frame span is [0, 1.0005] seconds.

With the requested +250 ms input offset, the **generated source itself** starts at sample 10,976 (0.2286667 s), 1,024 samples before 250 ms. Its last packet begins at sample 59,104 with duration 920, ending at 60,024 (1.2505 s). Neither priming skip nor tail discard side data appears in this source's packet probe. Demux decoding emits 49,152 frames, including the priming region and full final AAC frame. Routed PCM starts at the same 10,976 but ends at 60,128 (1.2526667 s), extending the declared source span by 104 samples. Matching the decoded reference therefore does **not** imply matching presentation duration.

No trimming policy was added to make this pass. A next bounded experiment should explicitly map MOV edit-list/media-time boundaries to decoded frame sample intervals, then test priming and tail clipping independently. It must distinguish preserving the finished source's presentation from recovering an intended offset that its encoder/muxer did not express as expected. This report does not establish universal AAC or player behavior.

## Validation and controls

Ten actual alternate exports were rejected by their required diagnostics: reversed channel order for all four fixtures, timestamp reset for all three nonzero-start fixtures, forced float32 for PCM32, and one decoded tail sample removed for each AAC fixture. Timestamp-reset negatives specifically require a **start** mismatch, so the already failing AAC offset end does not falsely satisfy that control. AAC tail controls require a new sample-count failure.

Positive output checks include codec/rate/mono topology, exact sample bytes/count, source digest unchanged, contiguous PCM packets, packet byte divisibility and sample-duration agreement. Copied video ordered payload hashes/sizes and rational PTS, DTS and durations match. The sample and presentation gate predicates are separate. MOV edit atoms are not independently parsed in this harness; these presentation findings concern the recorded FFmpeg demux view, not Apple/NLE interpretation. No separate WAV output extension, audible audition, real footage, float PCM source, physical storage failure or packaged helper acceptance is claimed.

## Evidence and reproduction

- [Harness](experiments/channelmap/wider_formats.py), [frozen final harness](experiments/channelmap/formats-04/harness.snapshot.py), [commands](experiments/channelmap/formats-04/commands.json), [results](experiments/channelmap/formats-04/results.json).
- [Offset AAC source packets/streams](experiments/channelmap/formats-04/aac-six-offset.mov.probe.json), [decoded frames](experiments/channelmap/formats-04/aac-six-offset.mov.frames.json), [routed output](experiments/channelmap/formats-04/aac-six-offset-routed.mov.probe.json).
- [Zero-origin AAC source](experiments/channelmap/formats-04/aac-six-zero.mov.probe.json).

Run `python3 research/experiments/channelmap/wider_formats.py research/experiments/channelmap/formats-NEW` with a nonexistent evidence directory. Each child process has a 60-second deadline. Commands, process exits/stderr, probe data, backend versions, executable SHA-256, harness SHA-256, source hashes and reference/output PCM hashes are retained. Generated media remains in the private temporary directory recorded in results and may be cleaned by the OS.

Formats-01 failed while building AAC with unspecified six-channel layout; it is retained as failed setup evidence. Formats-02 and -03 are superseded iterations. Formats-04 includes review fixes for separate gate classification, normalized video timestamps including DTS, packet-byte remainder checks, and start-specific negative diagnostics. FFmpeg/FFprobe version is 9.0.1; precise build/platform data is in results. Reaching execution completion does not close the wider B7 media gate.

## Follow-up

The original results above remain unchanged. [AAC boundary research](2026-10-16-channelmap-aac-boundaries.md) resolves the timing gate under an explicit presented-sample contract, with independent edit parsing and 15 rejected controls. It does not make the original unbounded export pass.
