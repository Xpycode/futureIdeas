# MediaCheck against VideoIntegrityChecker

Date: 16 October 2026. Scope: source investigation, not an implementation commitment.

**Recommendation:** evolve the existing VideoIntegrityChecker engine and workflow in a bounded experiment before creating another app. The overlap is real, but “already implements MediaCheck” would overstate it: reliable coverage, cancellation, evidence and persistence are central missing capabilities, not presentation polish.

## Evidence and limits

Read the proposed [MediaCheck spec](../ideas/mediacheck/SPEC.md), the existing application's models, coordinator, both backends, discovery, view model, container inspectors, UI and its sole checked-in test file. Also inspected VideoCorruptor's copy-based corruption engine, presets and manifest. No external project was modified; no application, build or test suite was launched by this investigation. Code-observed facts below are distinguished from runtime risks that still need reproduction. The root investigation separately ran an isolated synthetic FFmpeg command-line experiment; its evidence is incorporated below. This did not run the app.

Source shorthand in the matrix refers to the anchored inventory at the end. Negative findings mean absent from these checked-in implementation files, not a claim about every project in the portfolio.

## Requirement-to-implementation matrix

| MediaCheck requirement | Existing implementation | Gap and disposition |
|---|---|---|
| Folder/batch intake | Recursive extension-filtered discovery; drop/add workflow automatically starts analysis (D, V) | Reuse. Discovery silently skips missing/nonmatching inputs; no explicit unsupported/unavailable inventory. Discovery excludes `.aif`, `.mts`, `.aac`, `.ogg`, `.ogv`, `.vob` despite coordinator routes for them. |
| Quick Inspection separate from Deep Decode | Container inspector has quick/standard/thorough depths (C); coordinator always uses default standard followed by backend analysis (Q) | Partial building blocks; no user-level quick/deep mode or recorded sampled coverage. “Thorough” container NAL inspection remains sampling. |
| Complete audio/video decode | AVFoundation iterates video/audio tracks (A); FFmpeg null-output command (F) | Not sufficient. AV audio output requests no decoding format; FFmpeg has no explicit stream map. Need observed per-stream completion and PCM decode for compressed audio. |
| Open/probe failure taxonomy | Readability errors, generic caught errors, missing-FFmpeg issue (Q, A, V) | Add access/unavailable/unsupported/timeout/invalid categories, separate from corruption. Failed attribute lookup currently defaults to zero bytes in V, so missing input can be mislabeled empty. |
| Decode evidence with stream/range | Video last PTS/frame count; FFmpeg stderr descriptions (A, F) | Partial. Issue has no stream reference, explicit time base, range, confidence or structured backend error. Keep unknown positions null. |
| Explicit-profile missing-stream rule | AV errors when both audio and video absent; does not require audio for valid silent video (A) | Useful behavior to retain; profile expectations absent. |
| Stream-end mismatch with offsets/provenance | Metadata stores aggregate duration, not per-stream start/end (M) | New rule and per-stream timestamp model needed. |
| Irregular presentation timing | Video gaps compared to 1.5 × nominal frame duration; container stts/ctts checks (A, I) | Reuse raw observations, replace verdict rules. No coverage-aware VFR analysis; asset-wide nominal estimate is unsafe as truncation evidence. |
| Batch format comparison | Codec, resolution, rate and aggregate audio channels available (M) | Selected reference/profile and comparison absent; track topology not represented. |
| Timestamp discontinuity | Positive PTS-gap heuristic and container timing diagnostics (A, I) | Partial; no general per-stream presentation-order normalization, negative/repeated-PTS rule or covered-range record. |
| Incomplete/unsupported/cancelled states | Only healthy/warning/error in result (R) | Fundamental model change. Unsupported cannot be represented independently from error; completed checks cannot be distinguished from unfinished checks. |
| Findings/evidence contract | Random UUID, type, severity, optional timestamp/frame, description (E) | Add stable rule/version, snapshot/stream identity, measurements, thresholds, provenance, coverage, confidence, review state/note/date. Container conversion discards structured byte offset and category granularity (C). |
| Review, acceptance/dismissal and export | Detail display, issue list and metadata | No review-state store or JSON/Markdown export found. New workflow, though list/detail UI can be retained. |
| Worker lifetime and bounded diagnostics | Concurrent pipe draining on detached thread avoids dual-pipe blockage (F) | No process termination on cancellation, no deadline, no output cap. A worker process/service boundary is absent. |
| Source-aware concurrency | Global sliding window; default 2, settings clamp 1–8 (Q, V) | Reuse scheduling concept; no physical-source grouping. Overlapping calls can start independent batches, exceeding a single batch's intended bound. |
| Incremental persistence/restart | Results accumulated and returned after entire batch, then assigned in view model (Q, V) | No durable per-file store/restart. A completed file is not published as a final result until its batch finishes. |
| Snapshot invalidation/cache | Size and modification date captured on intake (M, V) | No before/after validation, versioned cache or stale-result handling found. |
| MediaIngest/VAM exchange | In-memory file IDs and result IDs (R, M) | Portable envelope and integration absent. Random local IDs are not snapshot identity. |
| Optional black/freeze/silence; later delivery/loudness | No detectors/profile evaluator/loudness code found | Defer. Basic metadata is a starting point, not standards-compliant delivery assessment. MXF structural parser already exposes operational-pattern metadata (C), worth retaining for future profiles. |
| Version-pinned helpers/direct distribution | Existing app targets macOS 15, Swift 6; detects user-installed FFmpeg (P, F) | Packaging/OS baseline differs from proposed macOS 26 and pinned bundled backend. Choose after experiment; no forced rewrite or deployment increase is justified by this inspection. |

## Correctness and coverage priorities

1. **Audio reading is not demonstrated audio decoding.** `AVAssetReaderTrackOutput(... outputSettings: nil)` at A:346 requests no PCM conversion. The loop counts sample buffers and reader failure; it never consumes decoded audio values. Apple documents that nil output settings return the original stored format ([outputSettings documentation](https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput/outputsettings)). This is a code-verified configuration gap. Its detection miss rate on damaged AAC/other codecs has not been measured. Do not advertise complete audio decode from this path.

2. **FFmpeg coverage is implicit.** F:97 supplies `-i ... -f null -` without explicit mapping. A per-stream contract must inventory audio/video streams, explicitly select each supported stream and record its completion. Do not solve this by indiscriminately mapping subtitles/data into an incompatible null output. The root agent reproduced this on FFmpeg 9.0.1: a generated MOV with video stream 0 and PCM audio streams 1/2 returned exit 0 and empty stderr under the exact checker arguments; an info-level trace mapped only 0/1. Explicit `-map 0:v? -map 0:a?` mapped 0/1/2. See the [reproduction script](experiments/check-stream-coverage.py) and its adjacent JSON/log artifacts. This confirms omitted-stream coverage, not a damaged-stream miss or an app runtime result. It agrees with [FFmpeg automatic stream selection documentation](https://ffmpeg.org/ffmpeg.html#Automatic-stream-selection).

3. **“Healthy” is stronger than the stored evidence.** R has no completed-with-limitations or cancelled state. The detail UI calls success “Healthy” (DetailView:81). FFprobe failure is swallowed (`try?`, F:70), malformed JSON returns empty metadata (F:158), and decoding can still yield healthy. Unsupported-tool absence becomes an error; AVFoundation reader setup errors become decode errors. Introduce scan completion separately from findings before adding rules.

4. **Timing heuristics risk false positives.** Metadata's frame rate is overwritten for each video track (A:113), and expected total is overall asset duration × that final rate (A:161). Every video track is tested against this shared estimate (A:223, A:311). A valid short video track beside longer audio, multivideo rates or VFR can therefore trigger an apparent truncation or gap. This is an inferred consequence of verified arithmetic; no such file was run here. The existing PTS checks are not proof of missing frames.

5. **Cancellation can leave real work running and produce stale results.** V:129 cancels the task and immediately clears UI running flags. F:242 retains no exposed process handle and has no cancellation handler; pipe reads wait through EOF. Q catches cancellation as a generic error and its batch loop continues admitting work without a cancellation gate. V:100 later writes results without a generation/run guard. A rapid cancel/reanalyze can let an older task overwrite newer state. Exact timing needs an integration test; the missing safeguards are code-observed.

6. **The video timeout is retrospective.** A:233 calls synchronous `copyNextSampleBuffer()` before elapsed time is tested; it cannot interrupt a call that never returns. Audio has no corresponding elapsed-time check. An external watchdog plus bounded worker shutdown is the safer experiment target.

7. **Container rules need an adversarial and clean-media audit.** They contain useful independent box/sample/NAL checks, but do not inherit trust automatically. For example I:638 multiplies untrusted UInt32 timescale by 10; I:682–685 multiplies by 5, converts to Int32 and applies `abs` to signed composition offsets. Extreme metadata can overflow/trap under normal Swift integer checks; reproduction remains pending. Both inspectors load via `Data(... .mappedIfSafe)` without a worker memory/deadline boundary. Do not run malformed-file fuzzing inside the production GUI.

8. **Cause confidence is currently overstated.** Q:89 promotes every container-metadata warning to error whenever any decode error exists, appending “likely cause.” Co-occurrence is insufficient to assign cause or confidence. Preserve independent observations and explain correlations without upgrading unrelated findings.

## Existing tests and missing evidence

`CoreFixTests.swift` has **17 @Test declarations**: six sample-size tests, three composition-offset tests, four discovery tests and four FFmpeg exit-code tests. The first groups call production parser/discovery code. The exit-code tests call a test-local copy of the classification helper, not the actual FFmpeg adapter, so they cannot catch drift in production or process behavior. No checked-in tests here cover real decoding, all-stream selection, cancel/restart races, malformed-file worker containment, clean VFR/B-frame media, report round-trips or input changes during analysis.

The project declares a `VideoIntegrityChecker` test scheme (P). For a later authorized test session, after checking test-host launch/state behavior, a conventional command is:

```sh
xcodebuild test \
  -project /Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker.xcodeproj \
  -scheme VideoIntegrityChecker \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/mediacheck-investigation-derived-data
```

This command was **not run**. App-hosted tests may launch an app, so the current no-remote-control preference must be honored. An isolated non-GUI worker harness is preferable for the first experiment.

## Smallest useful next experiment

**Question:** can the existing backends report exactly which streams/ranges were decoded, distinguish unsupported/incomplete from actual failures, and terminate a cancelled worker cleanly?

Create a disposable command-line harness and versioned JSON coverage record; keep it independent of user media and app settings. Use generated, short fixtures only initially:

- CFR with B-frames; valid video without audio; VFR; video shorter than audio; nonzero stream offsets.
- Two audio tracks, with controlled fault in the nondefault track and a separately verified decoder diagnostic.
- Readable damaged packet; truncated file; unsupported stream; nonexisting input.
- A controlled slow/stalled worker, cancellation and immediate second run; input replaced mid-scan.

Record requested checks, probed stream IDs, actual mapped streams, observed timestamp bounds, decoder exit/diagnostics, coverage limitations and file snapshot before/after. Compare the unchanged current path against explicit mapped decoding. Use first/last timestamp plus duration carefully: endpoints alone do not prove no gaps, and decoder concealment can hide visible defects.

**Pass gate:** all requested streams accounted for; no clean whole-file verdict on cancellation/unsupported/mutation; no false corruption label on the clean fixtures; old runs cannot overwrite new results; cancellation deadline and worker exit verified; each injected fault reported only when independently observed by the reference decoder. Report untargeted content as unchecked. A passing synthetic corpus warrants a small manually labeled real-media trial, not a universal detection claim.

VideoCorruptor supplies reusable seeded, copy-based mutation and JSON manifests (VC). Its generation status is not an expected scanner verdict. Preserve source, seed and operation provenance; independently confirm each fault is applicable and observable. Start with a small single-fault set; broad stacked corruption obscures which behavior was tested.

**Decision after experiment:** if coverage and containment can be added cleanly, evolve VideoIntegrityChecker and adopt MediaCheck as the broader product direction. If adapter isolation is expensive, extract a tiny shared scan/result package first; retain the existing app shell. Do not begin loudness, PDF reports or another GUI before this gate.

## Source anchors

All paths point to the local portfolio inspected on the date above.

- A: [AVFoundationAnalyzer](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Services/AVFoundationAnalyzer.swift:7).
- F: [FFmpegAnalyzer](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Services/FFmpegAnalyzer.swift:61).
- Q: [AnalysisCoordinator](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Services/AnalysisCoordinator.swift:48).
- D: [FileDiscovery](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Services/FileDiscovery.swift:4).
- V: [AnalyzerViewModel](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/ViewModels/AnalyzerViewModel.swift:44).
- R: [AnalysisResult](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Models/AnalysisResult.swift:3).
- E: [MediaIssue](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Models/MediaIssue.swift:39).
- M: [MediaMetadata](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Models/MediaMetadata.swift:10).
- C: [ContainerInspector contract/conversion](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Services/ContainerInspection/ContainerInspector.swift:5).
- I: [ISOBMFFInspector](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Services/ContainerInspection/ISOBMFFInspector.swift:605).
- P: [project configuration](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/project.yml:1).
- [Existing tests](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityCheckerTests/CoreFixTests.swift:1).
- [Detail UI](/Users/sim/ProgrammingProjects/1-macOS/VideoIntegrityChecker/01_Project/VideoIntegrityChecker/Views/DetailView.swift:80).
- VC: [copy-based seeded mutation](/Users/sim/ProgrammingProjects/1-macOS/VideoCorruptor/01_Project/VideoCorruptor/Services/CorruptionEngine.swift:47), [preset selection](/Users/sim/ProgrammingProjects/1-macOS/VideoCorruptor/01_Project/VideoCorruptor/Models/CorruptionPreset.swift:4), [manifest](/Users/sim/ProgrammingProjects/1-macOS/VideoCorruptor/01_Project/VideoCorruptor/Models/BatchManifest.swift:4).
