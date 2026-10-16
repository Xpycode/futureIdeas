# ChannelMap AAC priming, padding and edit boundaries

2026-10-16. B7.1 synthetic follow-up: **three routes pass; 15 deliberately incorrect exports rejected** with FFmpeg 9.0.1. [Final results](experiments/channelmap/aac-boundaries-03/results.json), [commands](experiments/channelmap/aac-boundaries-03/commands.json), [harness](experiments/channelmap/aac_boundaries.py).

## Preservation contract

Preserve the finished source's declared presentation: decode the media from its beginning, select only samples inside its single nonempty unit-rate MOV edit, route numeric channels 5 then 2 into mono PCM32 tracks, and place those samples at the edit's movie-time position. Intervals are half-open. The reference is decoded AAC, not the pre-encode WAV; AAC encoding is lossy.

This deliberately separates full decoder output from presented samples. It does not repair a generator's intended offset or infer priming from silence. In particular, the delayed source explicitly includes media sample zero; removing another 1,024 samples would change that source's declared presentation.

Apple describes edit lists as the means of locating source audio within encoded AAC media, with additional sample-group structures needed for its complete explicit-delay convention. This experiment verifies edit mapping, not compliance with that complete convention or Apple player behavior. [Apple AAC track structures](https://developer.apple.com/documentation/quicktime-file-format/using_track_structures_to_represent_encode_delay_explictly).

## Independently inspected boundaries

All values below are samples at 48 kHz; these fixtures also use a 48 kHz movie timescale. The parser reads `mvhd`, `mdhd`, and `elst` bytes directly, separately from FFprobe. Known fixture constants additionally check its interpretation.

| Fixture | Empty edit | Media interval retained | Movie interval | Kept samples | Raw samples excluded at tail |
|---|---:|---|---|---:|---:|
| Existing zero origin | none | [1,024, 49,048) | [0, 48,024) | 48,024 | 104 |
| Existing delayed | 10,976 | [0, 49,048) | [10,976, 60,024) | 49,048 | 104 |
| Explicit interior edit | 12,000 | [1,061, 48,061) | [12,000, 59,000) | 47,000 | 1,091 |

The original two source files are exact SHA-256 matches to formats-04. The third is a disposable copy of the delayed source with its two edit entries and audio track duration changed, retaining encoded media. Its boundaries intentionally fall within AAC packets. Its 1,091 excluded tail samples include intentionally edited-out content, not merely encoder padding.

All full decodes expose 49,152 frames. Normal decoding produces 48,024, 49,152 and 47,067 frames respectively. The harness proves the normal zero-origin decode equals raw [1,024,49,048), and the normal delayed decode equals the whole raw decode. The third normal decode count is an observation, not an accepted presentation oracle.

The delayed source begins at 10,976/48,000 s (about 228.667 ms), not the intended generator offset of 250 ms. Its empty edit explains that early start. The bounded route ends at exactly 60,024/48,000 s (1.2505 s), resolving the previous 104-sample excess without changing the declared start.

## Verification and failed first attempt

Run 01 failed its tail-plus-one negative: `-ignore_editlist 1` alone still allowed decoder tail discard, yielding only 49,048 raw frames for the zero-origin fixture. Explicit `-flags2 +skip_manual` exposed all 49,152 frames. Runs 02 and 03 pass; 03 additionally uses durable source files, asserts known fixture boundaries and normal/full decode mappings, checks formats and diagnostic-specific negatives, and records executable hashes.

The route uses full decode, sample-count `atrim`, explicit timestamp placement, numeric `pan`, and copied video. Python independently slices/deinterleaves the full decoded bytes for its reference. FFmpeg documents that `atrim` sample options count samples, its end is exclusive, and it does not reset timestamps. [FFmpeg atrim documentation](https://ffmpeg.org/ffmpeg-filters.html#atrim).

For each positive, both mono tracks match every reference byte, sample count, codec/rate/channel count, independently parsed edit start/duration, FFprobe stream span, packet continuity and packet size/duration. Video packet hashes and rational PTS/DTS/durations match the source. Sources remain unchanged.

Each fixture rejects five actual exports: first retained sample removed, last retained sample removed, one extra tail sample, one-sample timeline shift, and reversed channel selection. The timeline shift retains identical sample bytes; reversed channels retain correct timing. This demonstrates separate sample and timeline checks.

## Scope and reproduction

This is a research harness for three small, generated, six-channel AAC/ProRes MOVs, with one contiguous unit-rate audio edit and integer sample boundaries. It is not a general MOV parser or application exporter. Both sample paths share the installed AAC decoder; the reference independently verifies routing, slicing and placement, not decoder conformance. No claim covers multiple media edits, fractional sample boundaries, speed changes, arbitrary video edits, alternate decoders, real camera media, sample-group preroll/seeking, audible playback or Apple/NLE compatibility.

From FutureIdeas, use a new evidence directory:

```sh
python3 research/experiments/channelmap/aac_boundaries.py research/experiments/channelmap/aac-boundaries-next
```

The script reads retained synthetic inputs in `aac-boundaries-02`, verifies their formats-04 hashes, and writes media, probes, commands, stderr, results and its exact source snapshot into the new directory. No temporary historical media is required. Earlier runs remain investigation history. The existing formats-04 failure remains true for its original unbounded route; this follow-up establishes a different, explicit presentation-preserving contract.

## Independent review

A fresh-context reviewer found no remaining blocker within this scope. They independently parsed run-02 edit tuples, decoded all 18 run-02 outputs and matched recorded hashes/reference slices, and checked run-02/run-03 saved video packet tuples and bounded audio packet endpoints/continuity. They reviewed the strengthened final script; no independent full run-03 rerun is claimed.
