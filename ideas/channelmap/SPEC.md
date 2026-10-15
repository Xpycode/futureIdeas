# ChannelMap — Product and implementation specification

**Version:** 0.1 · 15 October 2026 · **Status:** proposed build specification

## 1. Product decision

*See, hear and reorganize the audio inside your recordings.*

ChannelMap is a focused native Mac utility for people preparing camera and recorder media for editing. It makes the distinction between files, audio streams and individual channels visible, then exports a deliberately chosen arrangement. It complements TimeCodeEditor, VideoContainerSwitcher and P2toMXF. It is not a DAW.

The recommendation is based on portfolio fit and reusable engineering, not validated willingness to pay. Working name; availability and trademark checks are outstanding.

## 2. User problem and primary workflow

A camera file contains eight channels, but only two are useful. The user needs to identify them, label their sources and deliver predictable tracks without re-encoding the picture.

1. Drop a file or folder. Files appear immediately while inspection runs.
2. Select a file; expand each audio stream into numbered channel rows.
3. Audition channels, inspect waveforms and add labels such as Boom or Camera scratch.
4. Define outputs: separate mono WAV files or a MOV containing selected audio tracks and copied video.
5. Review a concrete plan showing retained, converted and excluded streams.
6. Export to a chosen destination and inspect the validation result.

For a batch, apply a preset only to files whose stream topology matches its requirements. Put mismatches into a review queue; do not guess a substitute mapping.

## 3. MVP scope

| Requirement | Behavior |
|---|---|
| Inspection | Show container, stream index, codec, sample rate, channel count, declared layout, duration and start timestamp. Unknown layouts remain unknown. |
| Audition | Solo one channel, mute, seek and loop a range. Keep audition gain separate from export gain. |
| Waveforms | Generate cached channel waveforms progressively, with cancellation. |
| Analysis | Suggest low-level/silent and likely duplicated channels; show coverage and thresholds. Suggestions never remove channels. |
| Mapping | Split an audio stream into mono outputs; reorder channels; pair explicitly selected channels as stereo; retain whole streams. |
| Labels | Persist user channel labels in the job and interchange record; write container labels only where verified supported. |
| Export | PCM WAV per selected channel, or MOV with copied supported video and selected PCM audio tracks. |
| Presets | Save topology requirements, channel mappings, labels, output settings and naming rules. |
| Batch queue | Per-file progress, cancellation, partial-failure reporting and retry. |

Initial support commitment: MOV/MP4 with validated H.264, HEVC or ProRes video and supported AAC/PCM audio; WAV input. Test each actual codec/container combination. MXF and unusual channel layouts are phase two, not implied by backend capability. MP4 export is deferred because supported audio formats and track behavior require a separate matrix.

Exclude automatic microphone identification, denoising, source separation, loudness mastering, time stretching, timeline editing and NLE project rewriting.

## 4. UX contract

Use a file list, a stream/channel inspector and an output-plan panel. Each channel has an unambiguous identifier such as stream 2/channel 3; a friendly label never replaces that identifier. Display audio tracks separately from channels within a track.

An eight-channel stream is not automatically surround audio. Two selected mono channels become stereo only through an explicit pairing action. Ambiguous analysis says “possible duplicate” or “low level in sampled ranges,” not “unused.”

Export preview must state whether video is copied, audio is decoded and encoded, metadata may be omitted, or a requested combination is unsupported. No silent fallback to video encoding. If required metadata cannot be preserved, block or obtain an explicit per-job acknowledgment of the loss.

## 5. Processing and technical architecture

Proposed baseline: Swift/SwiftUI, Apple Silicon, macOS 26+, background workers and an embedded, version-pinned FFmpeg/ffprobe distribution. This baseline is a design assumption; inspect the existing repositories before choosing package boundaries or changing deployment targets.

Use a backend adapter for probing, waveform extraction, audition and export. Native playback may be used only where channel selection and timing match the export interpretation. Fallback playback must support otherwise readable media without pretending every format has native support.

FFmpeg stream selection and stream copying are separate from audio filtering. Selecting entire compressed streams can avoid encoding; extracting or rearranging channels within a compressed stream generally requires decoding and encoding. PCM export avoids another lossy audio generation, but does not make the whole output byte-identical. [S1, S2]

Pass process arguments as arrays, never shell-generated command strings. Pin backend versions; record version and build configuration in results. Drain stderr while processing, bound logs, terminate child processes on cancellation and keep media paths out of optional telemetry.

Write to a temporary sibling output, validate, then atomically publish on the same volume. Never overwrite an input. Reserve output names before starting and use deterministic suffixes for collisions. A job may finish with some files successful and others failed. Never label an unfinished output complete.

**Distribution:** direct download, Developer ID signed and notarised; the Mac App Store is not a goal, so no App Sandbox is required. Bundled helpers must be signed with hardened runtime and included in notarisation; validate packaged-helper execution and file access in the feasibility gate. *(Original text, kept for reference if sandboxing is ever reconsidered: for sandboxed distribution, persist user-granted access through security-scoped bookmarks and handle stale permissions. Bookmarks are access mechanisms, not portable asset identities. Validate helper-process access in a distribution spike. [S3])*

## 6. Domain model

| Entity | Essential fields |
|---|---|
| SourceSnapshot | local file reference, size, modification time, probe version, optional full digest |
| AudioStream | stream index, codec, sample rate, channel count, declared layout, start timestamp |
| ChannelReference | source snapshot, stream index, zero-based channel index, user label |
| OutputMapping | destination stream, ordered channel references, mono/stereo intent, codec and sample format |
| AnalysisObservation | rule ID/version, measured value, thresholds, sampled/full coverage, affected range |
| ExportJob | UUID, inputs, mapping, destination, state, backend version, timestamps, errors |

Keep all internal timestamps as rational values or integer sample positions with an explicit rate. A displayed timecode is not the internal clock. Preserve original audio/video offsets unless the user chooses another policy in a later feature.

Adopt the versioned interchange envelope defined in [VAM Core §7](../vam-core/SPEC.md#7-shared-interchange-envelope-v01). Emit an operation record only after final output validation; attach failed-attempt details separately. ChannelMap can generate its own local IDs and work without VAM installed.

## 7. Verification and acceptance criteria

Create fixtures with distinct tones and spoken channel numbers, plus real camera samples supplied for development. Required cases:

- Six-channel input exported as channels 5 and 2: output order is proven by tone identity, not only metadata.
- Stereo input split to two mono PCM WAV files: sample count and decoded samples match the reference under a no-gain/no-resample path.
- Camera video retained: validate copied video packet payload sequence where the muxer permits direct comparison; otherwise use a documented decoded-frame comparison. Do not confuse different container bytes with changed picture.
- Audio starting later than video: output preserves the intended offset to within one output sample where the format supports it, with timestamp rounding documented.
- Timecode, rotation and color metadata fixtures: retained values match the declared support matrix; unsupported retention is disclosed before export.
- Quiet ambience and partially silent channels: suggestions do not remove content.
- Duplicate-channel detector: distinguish exact equality from high correlation; opposite-polarity and delayed copies do not become exact matches.
- Same filenames from different folders: outputs remain distinct.
- Drive removal, cancellation, full destination and process failure: original files are untouched and partial outputs are not presented as finished.
- A mismatched batch topology requires review rather than silently changing channel selection.

Provisional usability target: a new user can identify and export two desired channels from a known eight-channel fixture in under two minutes without reading a manual. Benchmark responsiveness and waveform throughput on named hardware before setting throughput promises.

## 8. Delivery sequence

1. Feasibility gate: eight-channel audition, PCM splitting, video-copy MOV export, metadata retention and packaged-helper permissions on real fixtures.
2. Vertical slice: one file through inspection, audition, mapping, export and verification.
3. Batch layer: topology-aware presets, queue, collisions and interruption recovery.
4. Analysis layer: silence/duplicate suggestions and clear coverage reporting.
5. Interchange and release hardening: operation records, accessibility, signed build, format matrix and installer testing.

Do not expand format promises before the gate passes. Review backend licensing and distribution obligations for the exact build; this specification makes no license determination.

## 9. Sources and remaining validation

Sources checked 15 October 2026; implementation must target the pinned backend, not assume nightly documentation matches it.

- S1 — FFmpeg stream selection and streamcopy
- S2 — FFmpeg audio filters
- S3 — Apple sandbox file access
- S4 — EditReady custom presets

EditReady already supports audio-only changes; the product hypothesis is that a channel-first review interface is valuable. Validate it with five editors or camera operators and their actual problem files before adding advanced DSP.
