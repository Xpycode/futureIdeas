# SoundHarvest feasibility investigation

**2026-10-16 · Investigation, not an implementation decision**

A small SoundHarvest extraction experiment is technically plausible. **The actual SAR exporter preserved 24-bit stereo PCM exactly in an isolated test, including audio explicitly extracted from a generated MOV.** The missing value proposition is durable source references and finding a saved sound again. Neither a new app nor a shared media engine is warranted by this result.

## What was tested now

Compiled an unchanged copy of SAR's `AudioExporter.swift` with its small `AudioSelection` value type in a command-line harness. No app was launched; source projects were read only. Build products, generated media and compiler cache stayed under `/private/tmp/soundharvest-feasibility`.

The fixture contains 4,800 frames of 48 kHz, 24-bit stereo PCM with different, changing values in each channel. A Python RIFF parser compared decoded PCM payload bytes, independently of the Swift writer.

| Input/range | Observed result |
|---|---|
| WAV, 0.025–0.075 seconds | 2,400 frames; stereo, 48 kHz and 24-bit retained; PCM payload exactly equals source frames 1200..<3600 |
| WAV, fractional sample positions 1200.9–3600.9 | Same 2,400 frames: endpoints truncate toward zero; this is current behavior, not an endorsed selection policy |
| Empty selection | Throws `emptySelection` |
| Start beyond source end | Throws `emptySelection` |
| End beyond source end | Succeeds with end clamped to EOF; 1,200 frames for 0.075–0.2 seconds |
| Generated MOV with PCM audio → explicit `0:a:0` stream-copy extraction to WAV → SAR exporter | Demuxed source PCM equals original WAV; same selected-frame and PCM comparisons pass |

The MOV extraction is **new experimental glue using FFmpeg**, not an existing SAR video-import feature. It uses one zero-based, continuous PCM stream. AAC priming, delayed track starts, edits, multiple tracks, other rates/depths, long recordings, damaged files and real cameras remain untested. Existing app test suites were not rerun. No GUI, cancellation or retrieval test was performed.

Reproducible harness, fixture generator, exact source snapshot and logs are in [experiments/soundharvest](experiments/soundharvest/README.md).

## Concrete reuse and limits

Source references below are rooted at `/Users/sim/ProgrammingProjects/1-macOS/`.

| Component | Reuse evidence | Coupling or missing contract |
|---|---|---|
| SAR `AudioExporter.export(sourceURL:destinationURL:selection:)` | [AudioExporter.swift](/Users/sim/ProgrammingProjects/1-macOS/SAR/01_Project/SAR/AudioExporter.swift:17): bounded 65,536-frame buffer loop, seeks to selected frame, uses source format settings. The PCM case above was exercised. | Takes `AudioSelection` seconds; direct output write; no cancellation check, progress, source identity, verification or partial-file cleanup. EOF can exit the loop without confirming all requested frames were written. No independent finite/nonnegative endpoint validation. |
| SAR `AudioSelection` | [Recording.swift](/Users/sim/ProgrammingProjects/1-macOS/SAR/01_Project/SAR/Recording.swift:145): small Sendable struct. | Double-based seconds; duration clamps negative values but does not validate endpoints. Use integer sample boundaries for the new export contract. |
| SAR `WaveformEditor` | [WaveformEditor.swift](/Users/sim/ProgrammingProjects/1-macOS/SAR/01_Project/SAR/WaveformEditor.swift:4): stereo waveform, selection handles, seek callbacks, visible range. | Large SwiftUI view includes recording markers and numerous analysis modes. Extract interaction patterns only after the workflow proves useful. |
| SAR `RecorderViewModel.exportSelection()` | [RecorderViewModel.swift](/Users/sim/ProgrammingProjects/1-macOS/SAR/01_Project/SAR/RecorderViewModel.swift:345): snapshots range, exports, updates recording state. | Save panel, recording store/disposition and Finder activation are app behavior. Does not create a new sound-catalog item or source-range receipt. |
| Penumbra `TimeRange` | [TimeRange.swift](/Users/sim/ProgrammingProjects/1-macOS/Penumbra/01_Project/Penumbra/Penumbra/Models/TimeRange.swift:4): CMTime bounds, names, notes, tags and exact endpoint snapshot. | Depends on queued timecode decisions and snapshot types. Selection mutation requires explicit persistence notification. Project state says tags are intentionally disabled; stored fields do not prove usable tagging UI. |
| Penumbra `ExportArtifactPublisher` | [Publisher](/Users/sim/ProgrammingProjects/1-macOS/Penumbra/01_Project/Penumbra/Penumbra/Services/ExportArtifactPublisher.swift:11): privately owned attempt directory, exclusive final rename, collision refusal, identity-checked cleanup. | macOS/Darwin specific, runtime-isolation hooks and volume capability restrictions. A pattern to adapt, not a ready cross-platform export service. |
| Penumbra `ExportReceipt` / `ExportReceiptWriter.writeJSON` | [Receipt](/Users/sim/ProgrammingProjects/1-macOS/Penumbra/01_Project/Penumbra/Penumbra/Services/ExportReceiptWriter.swift:5): versioned sidecar, paths, technical fields, requested/effective IN and verification detail. | No complete audio stream/channel/sample interval identity; path-based source reference is insufficient after moves. Companion publication is separate from media publication, so an audio+receipt pair still needs an explicit completion policy. |

Penumbra's waveform generator reads the **first** audio track into mono 16-bit display data and normalizes peaks ([source](/Users/sim/ProgrammingProjects/1-macOS/Penumbra/01_Project/Penumbra/Penumbra/Utils/WaveformGenerator.swift:102)). It cannot supply original stereo samples or calibrated measurements. Its export template's PCM option is `pcm_s16le` ([source](/Users/sim/ProgrammingProjects/1-macOS/Penumbra/01_Project/Penumbra/Penumbra/Models/ExportTemplate.swift:53)); do not inherit that as a high-resolution sound-preservation default. Video keyframe snapping must not determine audio excerpt boundaries.

Penumbra's [artifact safety tests](/Users/sim/ProgrammingProjects/1-macOS/Penumbra/01_Project/Penumbra/PenumbraTests/ExportArtifactSafetyTests.swift:22) cover collisions, aliases, concurrent publication and unsupported volumes. Its [phase cancellation tests](/Users/sim/ProgrammingProjects/1-macOS/Penumbra/01_Project/Penumbra/PenumbraTests/ExportPhaseCancellationTests.swift:120) cover cancellation during metadata/verification and prevent publication. These were inspected, not run; adapting their invariants is preferable to importing the large `ExportManager` and its queue, history and licensing state.

## Smallest useful next experiment

Use a local scratch workflow with three excerpts from one owner-selected shoot. Keep originals intact. Explicitly choose one audio stream; retain all its channels. Start with PCM mono/stereo, one rate per source, and reject unsupported formats or timing layouts clearly. Produce a WAV plus a small versioned JSON record. Avoid normalization, channel remixing, effects, silence removal, AI classification and VAM database changes.

The receipt should record sound ID, title, tags/notes, source locator and verified content fingerprint, selected stream identity/channel order, source audio start timestamp/time base, integer start/end sample indices and rate, requested versus actual bounds, output format/hash and verification outcome. Source timecode is optional context, not the sample coordinate system. Fingerprints are a proposed identity mechanism; reading large originals has a cost that this tiny fixture did not measure.

Acceptance criteria:

1. Select three ranges and reopen their saved records without losing labels or exact boundaries. A sample interval is half-open `[start, end)`; define rounding explicitly and report any clamping.
2. For synthetic PCM, verify expected frame count, sample rate, bit depth, channel order and selected PCM equality. Add boundary impulses so a one-frame shift is visible. Never claim byte preservation for lossy-source decode.
3. Audition the exported sound and its original range manually. Audio must refer to the selected stream and the same timing origin, including a later test with a nonzero audio start.
4. Cancel during extraction, writing and verification. No completed catalog item or misleading success record may appear; unrelated files survive. A destination collision cannot overwrite anything. Treat media and receipt as a recoverable unit; a missing receipt leaves an explicitly incomplete item.
5. Reopen records after moving the output folder. Relocate a moved original by identity; if absent, mark it unavailable while the extracted sound remains playable. Never silently link a same-named different source.
6. A week later, find all three sounds by remembered description/tags, audition them and identify the original range without browsing the shoot. Record search time and which labels helped. This human retrieval result is still pending and is the product go/no-go question.

Follow-up technical fixtures: mono 24-bit, stereo 32-bit float, 44.1/96 kHz, distinct impulses per channel, a range spanning buffer boundaries, first/last sample, multiple audio tracks, audio starting after video, AAC with priming, interrupted output and a filename collision. Add each when that capability enters scope; do not expand into a format-compliance project before testing usefulness.

## Recommendation

Keep SoundHarvest as an extraction-and-retrieval experiment. The tested SAR kernel is a credible PCM building block; Penumbra offers useful selection, receipt and publication patterns. The next investment should prove source provenance and retrieval on three real sounds. Choose a permanent home—Penumbra feature, VAM workflow or separate tool—after that result, without adding release scope to either existing app now.
