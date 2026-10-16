# ChannelMap investigation — TASKS B1

**Date:** 2026-10-16 · **Outcome at B1:** source investigation complete; routing experiment defined, not run.

**Later B6 update:** [CM-E1 and multi-stream extension passed](2026-10-16-channelmap-routing-results.md). The text below preserves B1's evidence boundary; PCM-only spec wording has since been reconciled.

## Recommendation and evidence boundary

Reuse small preparation, PCM-copy, job-snapshot and verification patterns. Build a new explicit routing contract before attempting integration. None of the inspected apps supplies arbitrary source-stream-channel selection through audition and verified export.

B1 required inspection of actual seams/tests and definition of the smallest experiment, not an app or a passed feasibility gate. Two fresh-context agents inspected Avid/SAR and TestPatternGenerator; the coordinator inspected CameraTranscoder and TimeCodeEditor and synthesized this report. Source and test code were read; existing suites, audible playback, media generation and export were **not run** in this continuation. Earlier SoundHarvest results remain separate evidence. No other repository or desktop app was changed.

Source anchors below are relative to `/Users/sim/ProgrammingProjects/`, from local working copies inspected on this date. They are snapshot anchors, not claims about released or remote versions.

## Reuse versus new work

| Existing code | Useful seam | Boundary for ChannelMap |
|---|---|---|
| AvidMXFPeek | Injected preview preparation, pure FFmpeg argument builder, cancellation tests | Pairs separate mono files; first audio stream per file; AAC/HLS audition; label-based rendition selection |
| SAR | Bounded AVAudioFile PCM range-copy loop; transport and selected-pair display patterns | Copies all channels; seconds-based range; stereo/aggregate displays; no arbitrary channel routing |
| CameraTranscoder | Codec/layout vocabulary; immutable queued configuration and argument-array construction | Sets output counts/layouts and rate; no explicit channel references; video transcoding path |
| TimeCodeEditor | Per-check verdicts, verification protocol, fast/thorough orchestration and queue tests | Assumes unchanged first video/audio streams; rewritten audio needs a different oracle |
| TestPatternGenerator | Synthetic GLITS/flash-pop generation, decode helpers and meaningful negative control | Stereo identifiers and frame-scale timing; no eight-channel, sample-exact, delayed-track routing proof |

### AvidMXFPeek: file pairs, not channels within a stream

Root: `1-macOS/AvidMXFPeek/01_Project/`.

- `AvidMXFPeek/Models/AudioPair.swift:3,13,36`: left/right mono-MXF URLs and pair index; audio-only files sorted by filename and paired. An odd final URL is duplicated. No source snapshot or stream/channel identity.
- `AvidMXFPeek/Services/PreviewTranscoder.swift:138,145,179`: pure `buildArgs` deduplicates stem URLs, selects `[input:a:0]`, joins to stereo, encodes AAC at 192 kb/s. This is preview output, not lossless PCM export.
- `AvidMXFPeek/Services/PlaybackCoordinator.swift:24,139,181,197`: injected transcoder and cancellation guards are useful; preparation requires a video stem. Audio-only input needs a different path.
- `PlaybackCoordinator.swift:315`: pair selection finds HLS media options by display-name substring. Labels must not become route identities.
- `AvidMXFPeekTests/AudioPairTests.swift:50,65,82,98,111` cover pairs, odd/single stems and ordering. `PreviewTranscoderTests.swift:73,86,128` assert command construction and mono duplication. `PlaybackCoordinatorTests.swift:227,271` test cancellation/final selection using injected streams; the file explicitly excludes AVPlayer playing-state wiring.

These tests are useful patterns, not proof that the intended channel is audible. Independent solo/mute and audition-only gain remain new work.

### SAR: useful bounded copy, limited identity and displays

Root: `1-macOS/SAR/01_Project/`.

- `SAR/AudioExporter.swift:17`: actor entry point; lines 18–30 convert seconds to integer frames, clamp end, retain source settings and seek. Lines 32–44 copy all channels through a 65,536-frame buffer. An early empty read breaks the loop.
- There is no selected container stream, channel extraction/reorder, source snapshot, integer-range public contract, or output-validation/publication transaction in this exporter.
- `SARTests/AudioExporterTests.swift:6,39`: synthetic stereo float data; checks 2,400 frames, two channels and initial values. This is not an all-samples integer-PCM or multichannel-routing oracle. Earlier isolated 24-bit evidence is in [SoundHarvest feasibility](2026-10-16-soundharvest-feasibility.md), not a new B1 result.
- `SAR/RecorderViewModel.swift:17,255,617`: AVAudioPlayer transport, seconds-based seek, and 30 Hz selection-end polling. Adapt interaction ideas; do not claim sample-exact loop endpoints.
- `SAR/RecorderViewModel.swift:451,463` stores/downsamples combined/left/right peaks. `SAR/Recording.swift:48,96` has stereo summaries with legacy combined-waveform fallback.
- `SAR/WaveformEditor.swift:853,914,955`: spectrogram averages channels; RMS combines them; vectorscope reads first two channels and duplicates mono. These displays do not establish isolated-channel measurements.

### CameraTranscoder: layout settings are not explicit routing

Root: `1-macOS/CameraTranscoder/01_Project/`.

- `CameraTranscoder/Models/AudioConfiguration.swift:92` lists named speaker layouts with counts. It has no representation for an unknown eight-channel layout or source channel references.
- `AudioConfiguration.swift:366` produces argument arrays. Copy mode returns `-c:a copy`; rewriting sets codec and configured sample rate, then optionally `-ac` and `-channel_layout`. Preserving the layout flag is not a promise to preserve sample rate or sample format.
- `CameraTranscoder/Models/CameraPreset.swift:57,122` builds a video-encoding command and appends audio options, without explicit stream maps in that builder. `Utilities/FFmpegWrapper.swift:66` uses it and inserts the requested muxer. This path cannot serve unchanged as ChannelMap's mandatory video-copy export.
- `CameraTranscoderTests/JobConfigurationSnapshotTests.swift:23,52,67` checks that later UI/global-setting changes do not alter queued arguments. Reuse this contract for frozen routing plans.
- `QueuePlanningTests.swift:181` checks MXF audio-setting reconciliation. Inspected app tests do not establish channel sample identity.

Do not import automatic layout conversion or codec reconciliation as silent ChannelMap fallback behavior.

### TimeCodeEditor: adapt the verification contract, replace its assumptions

Root: `1-macOS/TimeCodeEditor/01_Project/`.

- `TimeCodeEditor/Services/CorrectionVerifier.swift:27,128,242`: structured severities, injectable `OutputVerifying`, fast/thorough checks and result persistence are reusable patterns.
- `CorrectionVerifier.swift:271`: structural comparison targets `v:0` and optional `a:0`, plus container duration. It does not enumerate every expected output route.
- `CorrectionVerifier.swift:376,393`: stream hashes explicitly map only the first video/audio streams under `-c copy`. A ChannelMap audio rewrite should differ from source compressed-audio bytes; it needs comparison against the selected decoded channel samples.
- `CorrectionVerifier.swift:428`: full-decode command has no explicit stream maps. Do not inherit its file-wide wording as evidence of all-stream coverage.
- `TimeCodeEditorTests/CorrectionVerifierTests.swift:13,117,195`: stubs test severity, queue wiring and escalation, not real FFmpeg routing/fidelity. Empty/no-verification results must not satisfy a ChannelMap feasibility gate.

A whole-stream content digest cannot prove timing. FFmpeg documents that streamhash ignores timestamps and defaults to conversions unless codecs are specified. Use explicit copied-video hashing and separate presentation-time checks. [Official streamhash documentation](https://ffmpeg.org/ffmpeg-formats.html#streamhash)

### TestPatternGenerator: good oracle patterns, stereo coverage

Root: `4-Other/TestPatternGenerator/01_Project/tpg-encode/`.

- `src/audio.rs:56,74`: GLITS and lip-sync blip are stereo/48 kHz. GLITS timing is explicitly reconstructed; it is not a certified BBC reference.
- `src/audio.rs:185,247`: windowed gap detection and a small five-second FFV1 fixture; gaps tolerate 20 ms. Not a one-sample or all-PCM equality test.
- `src/lib.rs:158` uses PCM24 and `-shortest`. Do not copy that policy into ChannelMap, which must not truncate video.
- `tests/verify_avsync.rs:73,191`: decode helpers and stereo identification; `:337,502` includes swapped L/R negative control.
- `verify_avsync.rs:365`: flash/pop checks at integer and fractional rates infer time from frame/sample positions with half-frame tolerance. Raw PCM does not retain presentation timestamps.
- `verify_avsync.rs:536`: recipe round-trip rendering equality tests configuration repeatability, not copied compressed-video identity.
- Some integration tests return when FFmpeg is missing (`:367`). Missing prerequisites must report blocked, not passed, in the new experiment.

Use the fixture/oracle structure and stereo smoke test; add eight-channel ground truth.

## Smallest explicit routing experiment — CM-E1 (not run)

**Question:** Can one explicit identity contract select channels 5 then 2, retain every intended PCM sample, copy video, and preserve delayed audio without truncation?

1. Generate one small two-second MOV: ProRes video, an eight-channel 48 kHz/24-bit PCM stream lasting one second, starting 12,000 samples (250 ms) after video. Give each channel a distinct tone plus a deterministic integer marker sequence. Retain the original interleaved integer PCM as the independent oracle. Probe the finished input and reject the fixture unless topology and intended offset are actually present.
2. Freeze a JSON plan containing source digest/size, absolute stream index from probe, zero-based channel indices `[4,1]`, input sample rate/format, output order and mono intent. Display these as channel 5 then channel 2. Declared speaker layout is optional evidence, never a replacement for numeric identity.
3. Export two mono WAVs and one MOV with copied video plus two mono PCM streams in that order. Use argument arrays and exact stream selectors, e.g. `[0:S]pan=mono|c0=c4[ch5]` and `[0:S]pan=mono|c0=c1[ch2]`, where S is the probed absolute stream index. Map each label explicitly. No gain, normalization, resampling, automatic stereo pairing, video-encoding fallback or `-shortest`.
4. Compare every decoded integer sample and total count against independently deinterleaved oracle channels. Check order and output topology. Tones provide readable diagnostics; equality is the acceptance oracle. FFmpeg documents a lossless optimized path for pure pan mappings; the actual pinned backend must still pass this test. [Official pan documentation](https://ffmpeg.org/ffmpeg-filters.html#pan)
5. Compare ordered copied-video packet payload hashes/counts separately from video presentation duration/timestamps. If a muxer legitimately transforms packet representation, record the reason and an explicit decoded-frame fallback; never silently relabel a failure as byte-identical.
6. Compare source/output audio-to-video presentation offset using rational timestamps and applicable MOV edit behavior: error at most 1/48,000 second. Verify video still spans two seconds. Plain WAV outputs preserve extracted samples, not the MOV A/V offset; record source offset in the experiment manifest.
7. Write only to a new isolated experiment directory; reject existing destinations. Use temporary siblings, validate before publishing, and record failures without a completed-output claim. Capture exact tool paths/version/build, argv, probes, selected identities, sample counts/digests, timing measurements and per-check outcomes.

**Required oracle negative controls:** reverse or duplicate selected channels; change one PCM sample; remove one sample; remove the audio delay while keeping PCM unchanged; alter/drop a video packet. Each corresponding assertion must reject its controlled mismatch. Missing tools are a blocked gate.

**Identity/topology extension before broader feasibility:** add a second audio stream containing different known data and prove selection by absolute stream index, then deliberately select the wrong stream. Reject an absent channel and changed source snapshot. Repeat with unknown layout without guessing surround semantics. These extend CM-E1; its single-audio-stream positive case alone cannot establish multi-stream routing.

**Audition boundary:** extracting the same selected-channel PCM establishes decoder/route agreement only. Actual audible solo/mute, seek/loop and audition gain isolated from export need a later explicitly authorized playback test. No desktop control is authorized now. Use spoken channel-number fixtures for that later test.

**Format extensions, not initial promises:** six-channel regression matching spec §7 literally; 16-bit, 32-bit integer values beyond float32 exact precision, float PCM, AAC decoded-reference/priming behavior, explicit cross-stream stereo pairing, unequal lengths/rates, and real owner-selected recordings. Do not claim 24-bit results establish these.

## Specification questions and remaining gates

- §9 says all MVP audio output is PCM, but §9.1/§9.2 allow whole compressed streams to be copied. CM-E1 uses PCM only. Reconcile this before an implementation plan; the source spec is preserved as a proposal.
- Defaulting unknown precision to PCM24 (§9.2) may lose information. Unknown precision must be disclosed and excluded from sample-exact claims until a supported policy is proved.
- Plain WAV has no MOV A/V relationship; distinguish sample-preserving extraction plus provenance from timeline-preserving MOV output.
- Layout count is not source topology. Presets need exact expected streams/channels and must reject mismatches.
- Timing, timecode/rotation/color retention, full stream coverage, cancellation/child lifetime, name collisions, disk-full/drive removal, safe publication and signed-helper packaging remain separate unpassed gates.
- Silence/duplicate analysis and user usefulness are outside CM-E1; none of these source inspections establishes market demand.

## Completion and next action

B1's inspection and experiment-definition deliverables are complete. No routing feasibility result is claimed. Track **B6** for executing CM-E1 and its negative controls in isolation; retain B2–B5 and I1–I4. No app creation or shared-package extraction is recommended before that evidence exists.
