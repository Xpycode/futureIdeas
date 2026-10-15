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

Phase 1.1 adds black, freeze and silence candidates with duration and level thresholds. These are editorial observations, not automatic errors. A static locked-off shot is not a failed camera. Clipping analysis and delivery-standard compliance are later features.

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

Release requires a published format/codec test matrix, zero false corruption labels on the clean acceptance corpus, and explicit handling of incomplete analysis. Benchmark a 1,000-file metadata batch and long high-bitrate recordings on named hardware; record UI responsiveness, memory, scan throughput and storage impact.

## 10. Sources and product validation

- S1 — ffprobe documentation
- S2 — FFmpeg filters
- S3 — Shutter Encoder feature list
- S4 — Apple sandbox file access

Checked 15 October 2026. Shutter Encoder already offers multiple analysis functions. The proposed differentiation is understandable batch findings, explicit coverage and persistent integration with the user’s media history. Verify this with editors using their own troublesome media; current research does not establish an empty market.
