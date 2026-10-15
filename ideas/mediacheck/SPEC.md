# MediaCheck — Product and implementation specification

**Version:** 0.1 · 15 October 2026 · **Status:** proposed build specification

## 1. Product decision

*Find technical problems in footage before you edit.*

MediaCheck inspects batches of recordings, explains findings and provides reviewable evidence. MediaIngest establishes that a copy matches its source; MediaCheck examines whether the copied media can be interpreted and decoded. Neither establishes that the camera recorded every intended moment. Penumbra remains responsible for creative selection.

Build the scanner as a reusable engine with a standalone UI. The engine must not depend on VAM or MediaIngest. Product demand remains a hypothesis; the working name is not cleared.

## 2. Primary workflow

1. Drop a folder or receive explicit file references from MediaIngest.
2. Run Quick Inspection automatically; select whether to run Deep Decode.
3. Review a table grouped by errors, observations and files needing attention.
4. Select a finding to see its evidence, coverage, explanation and available preview.
5. Mark reviewed findings accepted, dismissed or needing action without deleting their evidence.
6. Export a portable JSON report and a readable Markdown report; VAM can import the JSON.

The headline must be precise: “No findings in completed checks” rather than “Footage safe.” Unsupported streams, incomplete scans and unreadable inputs are always visible.

## 3. Scan modes

| Mode | Work performed | Valid conclusion |
|---|---|---|
| Quick Inspection | Container/stream metadata and bounded packet or frame samples | Metadata findings and observations within explicitly sampled intervals |
| Deep Decode | Sequential decode of supported audio/video streams over the complete readable file | Decode findings for the streams and ranges actually scanned |
| Optional content checks | Black/freeze/silence candidates during full or sampled analysis | Candidate content events needing human review |

Quick Inspection does not claim whole-file validation. Deep Decode is not a checksum comparison, a forensic recovery tool or proof of perceptual quality. Unsupported codecs produce an unsupported result, not a corruption verdict.

## 4. MVP rules

| Rule | Result and scope |
|---|---|
| Cannot open/probe | Error with cause category: access, unavailable storage, unsupported media, timeout or invalid structure where determinable |
| Decode failure | Error tied to stream and approximate affected range when known; raw backend evidence retained |
| Missing expected stream | Warning only when an explicit profile requires video or audio |
| Stream-end mismatch | Observation based on actual timestamps and duration provenance; configurable threshold |
| Irregular presentation timing | Observation derived from timestamps; do not infer VFR solely from unequal nominal-rate fields |
| Batch format inconsistency | Compare resolution, frame rate, sample rate and channel topology against a selected reference/profile |
| Timestamp discontinuity | Report suspicious presentation-time behavior after distinguishing decode order from presentation order |
| Incomplete/unsupported analysis | Dedicated status explaining what remains unchecked |

Phase 1.1 adds black, freeze and silence candidates with duration and level thresholds. These are editorial observations, not automatic errors. A static locked-off shot is not a failed camera. Clipping analysis and delivery-standard compliance are later features; delivery profiles are specified in §10.

Do not repair, transcode, normalize, delete or rename media in the MVP. Do not claim universally reliable missing-frame detection from an arbitrary file without reference timing or expected-frame evidence.

## 5. Findings and evidence contract

Each finding contains:

- Stable finding ID; rule ID/version; severity separate from confidence.
- File snapshot identity and stream reference.
- Range with explicit time base, or null when unknown.
- Measured values, threshold/profile values and evidence provenance.
- Coverage: metadata-only, sampled intervals or full decoded range.
- Human explanation, suggested next action and technical details.
- Review state, user note and review timestamp.

Store scan-level states independently from findings: queued, probing, scanning, completed, completed-with-limitations, cancelled or failed. “Completed” requires every requested check to be accounted for. Never manufacture a timestamp for an error when the backend cannot locate it.

Defaults are provisional product settings, not industry standards. For example, propose a 0.5-second duration-difference review threshold and let profiles override it. Show the threshold with every triggered observation. Do not compare durations without normalizing start offsets and identifying duration sources.

## 6. Architecture

Proposed baseline: native Swift/SwiftUI on Apple Silicon/macOS 26+, a bounded background worker service and a version-pinned ffprobe/FFmpeg adapter. Confirm compatibility with existing repositories first.

Components: FileEnumerator, ProbeAdapter, DecodeRunner, RuleEvaluator, FindingsStore, ReportExporter and ScanCoordinator. Keep the rule layer independent of process output formats. Use typed normalized observations; retain bounded raw diagnostics for troubleshooting.

ffprobe exposes stream, packet and frame information plus bounded intervals. Seeking to a requested interval is not necessarily exact, so record actual examined coverage. Do not use nominal-rate metadata as definitive temporal analysis. [S1]

Read media only. Use argument arrays for child processes, close cancelled processes, drain logs and cap output. Enumerate without following symlink cycles. Do not automatically download cloud placeholders or scan every mounted drive. Network/cloud locations require an explicit chosen source and show their availability limitations.

Cache results by source snapshot, scan configuration and engine/rule versions. Size plus modification time is a cache heuristic, not proof of identity. If the file changes during analysis, invalidate the result. Imported verified digests can strengthen identity but are not required for a first scan.

Limit concurrent deep scans per physical source to avoid competing sequential reads. Start conservatively with one deep scan per selected source; make the limit configurable. Cancellation is checked between operations; do not block the UI while a worker terminates.

Persist completed file results incrementally. After restart, retain them and rerun interrupted files from the beginning in the MVP; arbitrary frame-level resume is out of scope.

**Distribution:** direct download, Developer ID signed and notarised; the Mac App Store is not a goal, so no App Sandbox is required. Bundled helpers must be signed with hardened runtime and included in notarisation.

## 7. Integration contract

MediaIngest supplies file references and any existing digest/verification provenance. MediaCheck returns analysis linked to those exact snapshots. Keep copy verification, decode assessment and content observations as distinct fields and UI badges.

Use the interchange envelope from [VAM Core §7](../vam-core/SPEC.md#7-shared-interchange-envelope-v01) with a scan operation and attached findings. Deep scans must not implicitly compute extra full-file hashes unless the user enables that cost or a validated shared read path exists. VAM imports results without requiring a rescan, and marks them stale if source identity changes.

Penumbra may receive candidate ranges, but a technical finding must not automatically become a creative rejection.

## 8. Acceptance criteria and fixtures

| Fixture | Expected result |
|---|---|
| Valid CFR file with B-frames | Decode succeeds; valid decode/presentation ordering does not generate a false corruption warning |
| VFR screen capture | Timing observation includes measured coverage; no unsupported claim that all editors reject it |
| Deliberately damaged readable packet | Deep scan identifies the injected fault when the reference decoder reports it |
| Truncated file | Reports actual probe/decode behavior; never claims all truncation is detectable |
| Unsupported codec | Unsupported/unchecked, not corrupt |
| Silent valid video | No missing-audio error unless the chosen profile requires audio |
| Black leader/static scene | Content candidate only, not automatic failure |
| Different stream start offsets | Duration comparison accounts for offsets |
| Input changes mid-scan | Result invalidated and user offered a fresh scan |
| Removed drive or denied permission | Incomplete status with retry action; other queued files continue |
| Cancelled scan | Coverage remains partial; no clean whole-file result |
| Same scan and engine versions | Deterministic findings apart from run IDs and timestamps |

Test report round-tripping and rule-version invalidation. For malformed media, fuzz and resource-limit the parsing boundary. Keep a manually labeled real-world corpus separate from synthetic fixtures to estimate false-positive rates. Set launch targets after measuring; do not promise a universal detection rate.

## 9. Milestones and release gate

1. Probe-and-report vertical slice with exact coverage semantics.
2. Deep-decode worker with cancellation, crash handling and damaged fixtures.
3. Review UI, batch profiles and report export.
4. MediaIngest/VAM interchange and stale-result handling.
5. Optional content detectors only after technical findings are trusted.
6. Delivery profiles and loudness (§10) once the scanner and report export are stable.

Release requires a published format/codec test matrix, zero false corruption labels on the clean acceptance corpus, and explicit handling of incomplete analysis. Benchmark a 1,000-file metadata batch and long high-bitrate recordings on named hardware; record UI responsiveness, memory, scan throughput and storage impact.

## 10. Delivery profiles (phase two: DeliveryCheck)

*Merged from the earlier QC Checker draft. This is the DeliveryCheck idea from the research log, built as a MediaCheck profile workspace on the same scanner rather than a separate app. Split it out only if users show a distinct workflow or purchasing need.*

A delivery profile is a user-declared contract applied to an exported file: “does this file meet the spec I was given?” Source-media checks (§4) answer a different question and stay separate in the UI.

### 10.1 Profile model and verdicts

```swift
struct DeliveryProfile: Codable, Identifiable {
    var id: UUID
    var schemaVersion: Int              // start at 1
    var name: String
    var notes: String?
    var rules: [ProfileRule]
    var audioSelection: AudioSelection  // which tracks/channels form the programme mix (§10.3)
    var loudness: LoudnessTarget?       // nil = loudness not checked
    var audioRequired: Bool             // no audio → fail if true, otherwise not applicable
}

struct ProfileRule: Codable, Identifiable {
    var id: UUID
    var checkID: CheckID                // catalog §10.2
    var condition: Condition            // equals, oneOf, range, min, max, exists, notExists
    var severity: Severity              // fail or warn when violated
    var enabled: Bool
}
```

- Each violated rule becomes a finding with the full evidence contract (§5): expected value, measured value, coverage (metadata-only or full decode) and the profile/rule version.
- Per-file summary: **Pass**, **Warn**, **Fail** or **Incomplete**. The worst result wins; Incomplete (unreadable, unsupported, cancelled or not yet scanned) outranks Pass and is never shown as a pass.
- Missing data: a field the file doesn't report gives a warn (“not reported by file”), except for an `exists` rule, which fails.
- Profiles are JSON, versioned, and can be duplicated, edited, imported and exported. Exporting and re-importing a profile gives identical results.

### 10.2 Check catalog

Values come from the ffprobe adapter unless noted. Video checks use the first video stream unless configured; audio-only files mark video checks not applicable.

| Group | Check IDs | Notes |
|---|---|---|
| Container / file | `container.format`, `file.duration`, `file.timecodeStart`, `file.hasTimecode` | ffprobe reports the same `format_name` for MOV and MP4 (`mov,mp4,m4a,3gp,3g2,mj2`); distinguish them by `major_brand`. Parse drop-frame timecode (`;`) correctly. |
| Video | `video.codec`, `video.profile`, `video.resolution`, `video.frameRate`, `video.timing`, `video.scanType`, `video.pixelFormat`, `video.bitDepth`, `video.bitrate`, `video.colorPrimaries`, `video.colorTransfer`, `video.colorMatrix`, `video.colorRange`, `video.displayAspect` | ffprobe has no `xdcam` codec: XDCAM HD422 is `mpeg2video` with a 4:2:2 profile plus a bitrate, so match it as a combined rule. `video.timing` uses the timestamp-derived observation from §4, not a comparison of nominal `r_frame_rate` and `avg_frame_rate`. Missing `field_order` warns. |
| Audio | `audio.trackCount`, `audio.channelsPerTrack`, `audio.totalChannels`, `audio.codec`, `audio.sampleRate`, `audio.bitDepth`, `audio.channelLayout` | Channel layout is warn-only by default; it is often untagged. |
| Loudness | `loudness.integrated`, `loudness.truePeak`, `loudness.lra`, `loudness.maxShortTerm`, `loudness.maxMomentary` | Target ± tolerance for integrated; maxima for the rest. LRA, short-term and momentary are optional. |
| Later | `container.mxfOperationalPattern` | ffprobe doesn't reliably report the operational pattern; needs MXF header parsing. Arrives with MXF support. |

### 10.3 Loudness measurement

Loudness needs a full decode of the selected audio, so it runs as part of Deep Decode and reports full coverage, or partial coverage if cancelled.

Standards: ITU-R BS.1770-4 for integrated loudness and true peak; EBU Tech 3341 for momentary (400 ms) and short-term (3 s); EBU Tech 3342 for LRA.

1. Decode the selected audio to float32 at the native sample rate through the backend, streamed, never loaded whole into memory, with channels in a known order.
2. K-weighting: two-stage biquad (high-shelf pre-filter plus RLB high-pass). Recompute coefficients for the actual sample rate.
3. Mean square per channel over 400 ms blocks with 75 % overlap (100 ms hop).
4. Channel weights: L, R, C = 1.0; Ls, Rs = 1.41; LFE excluded.
5. Block loudness: `-0.691 + 10·log10(Σ Gᵢ·zᵢ)`.
6. Gating: absolute gate −70 LUFS, then relative gate −10 LU below the absolutely gated mean; integrated is the mean of blocks passing both.
7. LRA: short-term 3 s windows, absolute gate −70 LUFS, relative gate −20 LU, LRA = 95th − 10th percentile.
8. True peak: 4× oversampling (polyphase FIR, BS.1770 Annex 2 style) per channel; 2× is acceptable at 96 kHz and above.
9. Keep the momentary and short-term series for a later loudness graph.

Native Swift (vectorised with Accelerate) is preferred; libebur128 (MIT) serves as a test reference. Validation: match the EBU Tech 3341/3342 compliance set within ±0.1 LU and the true-peak tolerance stated there. Silence-only or below-gate audio reports “below gate” and fails a loudness target. Throughput is benchmarked on named hardware before any promise (§9); a working goal is at least 20× realtime for stereo PCM on Apple Silicon.

**Programme selection (`AudioSelection`):** `track(n)` for one multichannel stream; `channels([(track, channel)…], layout)` to assemble a programme from mono tracks; or `eachTrack` to measure every track (the rule uses the worst or a designated track). Default: the first audio track, interpreted by channel count (1 = mono, 2 = stereo, 6 = 5.1 in L R C LFE Ls Rs order).

### 10.4 Starting loudness targets

Defaults only; every value is editable. Verify against the current source documents before shipping.

| Target | Integrated | Tolerance | True peak max | Notes |
|---|---|---|---|---|
| EBU R128 (broadcast) | −23 LUFS | ±0.5 LU (file-based) | −1 dBTP | |
| EBU R128 S1 (short-form) | −23 LUFS | ±0.5 LU | −1 dBTP | plus max short-term −18 LUFS |
| ATSC A/85 | −24 LKFS | ±2 LU | −2 dBTP | |
| Streaming −14 | −14 LUFS | ±1 LU | −1 dBTP | warn-level |
| Streaming −16 | −16 LUFS | ±1 LU | −1 dBTP | warn-level |

### 10.5 Example profiles

Ship a few generic, clearly labelled examples. Never name one after a broadcaster or platform unless its values are verified against their current published spec.

1. **HD Progressive Master:** MOV, ProRes 422 HQ, 1920×1080, 25p/50p, BT.709, PCM 24-bit / 48 kHz, EBU R128.
2. **ProRes Mezzanine:** ProRes 422 HQ, 10-bit, BT.709, PCM 24/48, no loudness check.
3. **Web Delivery H.264:** MP4, H.264 High, 1080p, constant timing, AAC 48 kHz stereo, −14 LUFS (warn).
4. **Loudness only (R128):** no metadata rules.
5. **HD Interlaced Broadcast Master (25i):** XDCAM HD422 MXF OP1a or ProRes MOV, top-field-first, 8+ mono PCM tracks, EBU R128. Ships only once MXF is in the tested format matrix.

### 10.6 Delivery reports

In addition to the JSON and Markdown reports (§2):

- **PDF (client-facing):** header with report date, profile name and an optional “Prepared by” name or logo; a summary table with one row per file; a per-file section with the check table (check / expected / actual / result) and loudness figures (integrated, true peak, LRA, max short-term, max momentary); footer with page numbers and the measurement standard. Must paginate correctly from 1 to 100+ files.
- **CSV:** one row per file × check (`file, check, expected, actual, result, message`), plus an optional one-row-per-file summary.

### 10.7 Additional fixtures

EBU Tech 3341/3342 compliance files; ProRes 422 HQ MOV 25p with stereo PCM and timecode; phone H.264 MP4 with irregular timing and AAC; 29.97 drop-frame file with timecode; file with missing colour tags; WAV/BWF audio-only; XDCAM HD422 MXF OP1a with 8 mono tracks once MXF is in scope.

### 10.8 Open questions

1. Pricing: whether delivery profiles and PDF reports are a paid tier.
2. Whether a loudness-only mode later ships as a separate lite app on the same engine.

## 11. Sources and product validation

- S1 — ffprobe documentation
- S2 — FFmpeg filters
- S3 — Shutter Encoder feature list
- S4 — Apple sandbox file access

Checked 15 October 2026. Shutter Encoder already offers multiple analysis functions. The proposed differentiation is understandable batch findings, explicit coverage and persistent integration with the user’s media history. Verify this with editors using their own troublesome media; current research does not establish an empty market.
