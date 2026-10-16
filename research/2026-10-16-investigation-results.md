# MediaCheck and SoundHarvest investigation results

**Date:** 2026-10-16 · **Outcome:** useful existing foundations, with specific gaps verified before recommending implementation.

## Recommendation

Treat MediaCheck as a possible evolution of VideoIntegrityChecker, beginning with truthful coverage and cancellation rather than additional detectors. SoundHarvest is suitable for a small video-to-sound extraction experiment using SAR's exporter, but provenance and safe output handling must be part of that experiment.

Neither finding approves a new app or changes an existing source project.

## MediaCheck findings

The existing checker contains real container inspection and video processing. Its current success result is too broad for the proposed MediaCheck contract:

- **Reproduced stream omission:** a generated MOV contains one video and two PCM audio streams. The exact existing FFmpeg argument policy exits successfully with empty stderr. A diagnostic run with the same selection policy shows only video and the first audio stream mapped. Explicit audio/video maps include all three. This establishes a coverage gap, not a damaged-file false-negative test or a full application test.
- **Source-verified audio limitation:** AVFoundation audio uses `outputSettings: nil`, which returns samples in their stored format rather than requesting decoded PCM. Reading compressed packets does not establish successful audio decoding. See [Apple's output settings documentation](https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput/outputsettings).
- **Source-verified result/lifecycle limitations:** results expose healthy/warning/error without per-stream completion coverage; the FFmpeg process wrapper has no cancellation handler to stop its child. These require runtime regression cases before reuse.

The stream-selection reproduction is consistent with [FFmpeg's documented automatic selection](https://ffmpeg.org/ffmpeg.html#Automatic-stream-selection). Evidence: [result](experiments/stream-coverage-result.json), [reproduction script](experiments/check-stream-coverage.py), [automatic mapping](experiments/stream-coverage-auto.log), [explicit mapping](experiments/stream-coverage-explicit.log).

See the [requirement gap analysis](2026-10-16-mediacheck-gap.md) for source locations, test coverage and further limits.

## SoundHarvest findings

An isolated command-line harness compiled and exercised an unchanged snapshot of SAR's `AudioExporter` with a matching minimal selection type. This bypasses the app UI and does not establish user-flow readiness.

- A nonconstant 48 kHz, 24-bit stereo fixture exported frames 1200 through 3599 as exactly 2400 frames with byte-identical PCM and unchanged channel count, rate and bit depth.
- A second isolated path wrapped that fixture in MOV, explicitly extracted its PCM audio with FFmpeg, and ran the same SAR exporter. The selected PCM again matched byte-for-byte. This is new experiment wiring, not an existing SAR video-import feature. [MOV-path results](experiments/soundharvest/mov-results.txt).
- Empty ranges and ranges starting beyond EOF were rejected.
- An end beyond EOF was silently clamped; fractional sample endpoints were truncated. SoundHarvest must explicitly define and record the actual sample range.
- The exporter itself does not provide movie-track extraction, source provenance, cancellation or temporary-output validation/publication.

See [exporter results](experiments/soundharvest/results.txt) and the [feasibility investigation](2026-10-16-soundharvest-feasibility.md) for evidence, integration boundaries and the small experiment design. These results cover synthetic PCM, not AAC encoder delay, arbitrary movie edit lists, multi-track selection or all audio formats.

## Bounded next experiments

| Work | Scope | Pass condition |
|---|---|---|
| MediaCheck coverage | Known multi-stream files, an unsupported stream, interruption and a deliberately damaged non-default audio stream | Every requested stream has a completed/unsupported/failed/cancelled outcome; no file-wide clean verdict hides omissions; stopping leaves no owned child process running |
| SoundHarvest extraction | One selected video audio stream → sample-bounded PCM excerpt → source-reference sidecar | Output PCM matches the intended decoded range; source is unchanged; sidecar records source identity, stream and actual sample bounds; failure/cancellation leaves no published partial output |

Do these within isolated fixtures first. Only then inspect representative owner-approved recordings and evaluate whether the interaction is useful. Portable source-reference metadata should be small enough for later VAM import without making either utility depend on VAM.

## Scope of work

Two agents inspected the relevant application source and tests; the root agent reproduced the FFmpeg stream-selection behavior. No desktop apps were launched, no existing application repositories were modified, and no changes were committed or pushed. Detailed reports distinguish inspected code, historical test descriptions and tests actually executed here.
