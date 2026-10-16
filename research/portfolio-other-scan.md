# Portfolio scan: supporting apps, mobile tools, and packages

Date: 2026-10-16. Read-only local research; no builds, tests, remote synchronization, app control, or changes to source projects. Recommendations below are synthesis from the local portfolio, not market validation.

## Most useful findings

1. **VAM Core is already partly implemented in VAM.** Its README says “no code yet,” but that is stale: current state and source contain a browsable catalogue, volume identities, relative paths, scanning, proxy generation and playback integration. Decide whether the new candidate is a narrower milestone of that project before creating a second catalogue.
2. **SAR is the strongest adjacent source for ChannelMap and SoundHarvest.** It already has waveform editing, stereo meters, markers, IN/OUT selection, range export, spectral views and offline loudness analysis. These are app-owned implementations requiring extraction and tests against the new use case; they are not a multichannel routing engine.
3. **TestPatternGenerator supplies unusually valuable known-answer fixtures.** Its native Rust encoder has GLITS channel idents and frame-locked flash/pop output, plus encoded-output verification tests. Use these to prove ChannelMap channel order and DriftCheck timing before trying uncontrolled footage.
4. **DiskCatalogue and SearchAway provide complementary knowledge.** The former has explicit offline/unknown evidence semantics and feasibility spikes; the latter has actual local search/index code. Neither is a drop-in media relationship database.
5. **Shared infrastructure exists in two package locations.** The monorepo under `1-macOS/zPackages` and the root-level `zPackages` serve different purposes. Read their manifests and consumer evidence: catalogue prose sometimes lags implementation.

## Reuse for the five candidates

| Candidate | Existing assets worth using | New work still required |
|---|---|---|
| ChannelMap | SAR stereo metering and waveform/selection interaction; TestPatternGenerator GLITS fixtures; shared playback and shortcut packages | Enumerate all audio streams and channel layouts, preserve per-channel amplitudes, solo/mute/arbitrary channel routing, accurate output mapping and verification. SAR capture explicitly handles left/right, not arbitrary channel sets. |
| MediaCheck | SAR offline loudness implementation as an extraction candidate; TestPatternGenerator known-good outputs; FocusLab field metadata as context for expected FPS/audio | Agreed checks and evidence schema; conformance and multichannel tests before claiming standards compliance. Do not treat approximate live loudness as delivery QC. Core corruption inspection is covered by the separate media scan. |
| VAM Core | Existing VAM models, scanners, mount resolution, proxy relationships; SearchAway indexing/query techniques; DiskCatalogue identity/conflict research | Decide continuity with VAM; recording/version/derivative identity model; reconcile catalogue availability states; deliberate persistence choice. SearchAway is a live local index and DiskCatalogue is still spikes, so neither should simply replace VAM storage. |
| SoundHarvest | SAR audition/mark/trim/export interaction, spectrum/spectrogram views; VAM source locations and proxies; music-library organization experience | Extract audio from movie containers, save clips with original source/time-range provenance, tags and search. Automatic semantic sound identification is not established by these sources. |
| DriftCheck | TestPatternGenerator flash/pop and fractional-rate fixtures; shared rational timing in MediaEngineKit; SAR waveform display; FocusLab planned/observed cue records | Offset/drift estimator, confidence and insufficient-evidence states, discontinuity detection, multi-window fitting and long-recording tests. Existing playback clocks and test tones are infrastructure, not a finished drift detector. |

## Source-level evidence and readiness

Paths below are relative to `/Users/sim/ProgrammingProjects` unless stated otherwise; line references are local snapshot anchors.

### VAM, DiskCatalogue and SearchAway

- `1-macOS/VAM/docs/PROJECT_STATE.md:14` describes completed catalogue/proxy waves and ongoing playback work. This is stronger freshness evidence than the stale root README.
- `1-macOS/VAM/01_Project/VAM/VAM/Models/Volume.swift:4`: SwiftData volume with unique BSD UUID and related assets.
- `1-macOS/VAM/01_Project/VAM/VAM/Services/Volumes/PathResolver.swift:3`: relative path plus current mount; missing mount returns nil and supports offline indication.
- `1-macOS/VAM/01_Project/VAM/VAM/Services/Catalog/ScanService.swift:14`: video filtering with both collecting and cancellable streaming variants. It is video-specific; SoundHarvest/general recording support needs a broader filter.
- `1-macOS/DiskCatalogue/AGENTS.md:28`: explicit distinctions between unavailable/offline/missing permission/moved/deleted/cloud-stub conditions, stable volume identity, bounded scanning and read-only product scope.
- `1-macOS/DiskCatalogue/docs/PROJECT_STATE.md:15`: portable-library and search benchmark gates are blocked by incomplete harnesses; no Xcode feature app yet. Treat the `Spikes/` implementations as research, not production-ready packages.
- `1-macOS/SearchAway/01_Project/SearchAway/Index/TrigramIndex.swift:23`: real trigram index implementation, candidate lookup and sorted intersection. The state document records a substantial test suite and unfinished readiness work; it is not an offline disk catalogue. Useful extraction target only after accounting for live-index assumptions.
- DiskVerdict's state identifies a shipped workflow-oriented disk benchmark and incomplete real-device acceptance for newer drive-qualification work. Reuse its ideas for explaining storage suitability, not claims that a catalogue proves backup integrity.

### SAR

- `1-macOS/SAR/README.md:11`: capture, waveform/spectrum/spectrogram/stereo/phase/loudness inspection, markers and selection WAV export; pre-release.
- `1-macOS/SAR/01_Project/SAR/AudioExporter.swift:17`: actual AVAudioFile range copy with frame conversion and bounded 65,536-frame buffers. It does not itself implement movie-track extraction, channel remapping, safe publication policy or provenance metadata.
- `1-macOS/SAR/01_Project/SAR/SystemAudioRecorder.swift:382`: left/right peak/RMS, spectrum and stereo samples. This establishes a stereo implementation, not general multichannel analysis.
- `1-macOS/SAR/01_Project/SAR/WaveformEditor.swift:822`: sampled spectrogram analyzer; `:965`: BS1770Analyzer implementation including offline processing. Analysis types currently live inside a UI source file and need a clean engine seam.
- `1-macOS/SAR/01_Project/SAR/RecorderViewModel.swift:80`: live meter approximation is distinct from offline measurement. `WaveformEditor.swift:272` and `:669` distinguish provisional/estimated UI values. Do not market this reuse as certified loudness compliance; extraction must carry reference-fixture and channel-weighting validation.

### TestPatternGenerator and FocusLab

- `4-Other/TestPatternGenerator/docs/PROJECT_STATE.md:9`: native calibration export and frame-deterministic animation/flash+pop/GLITS are recorded complete; later motion patterns remain work.
- `4-Other/TestPatternGenerator/01_Project/tpg-encode/src/audio.rs:1`: explicit FFmpeg expression generation for reference tones and channel-gated GLITS/lip-sync audio. `:57` defines audio ident variants. This is Rust/FFmpeg tooling; use generated fixtures or a process boundary rather than assuming direct Swift import.
- `4-Other/TestPatternGenerator/01_Project/tpg-encode/tests/verify_avsync.rs:336`: channel-order verification; `:365`: flash/pop alignment test at integer and fractional frame rates. These are inspected test implementations, not tests rerun in this scan.
- `2-iOS/FocusLab/AGENTS.md:32`: offline field tool, stable recipe versions, minimal QR identity and fuller JSON metadata; no existing camera control or automatic quality inference.
- `2-iOS/FocusLab/01_Project/FocusLabFieldCompanion/Services/SessionExporter.swift:4`: versioned session export. `:39` onward includes take IDs, camera/lens, capture and playback FPS, audio expectation, cue events and operator verdict. This is a strong basis for machine-linkable source context; imports into other apps remain new work.
- `2-iOS/FocusLab/docs/PROJECT_STATE.md:10`: simulator validation exists; physical field acceptance remains open. Timing logs are observations, not calibrated audio/video ground truth.

## Packages: available versus proposed

`1-macOS/zPackages/Package.swift:15` confirms actual library products for ShortcutKit, MediaKit, MediaKitWaveform, MediaKitSceneDetect, MediaKitGPS, FolderAccessKit and opt-ins, MacUIKitSettings, PlayerKit, ProcessKit, SystemMetricsKit, SilentUpdateKit and AppShellKit. The nested `MediaEngineKit/Package.swift` is separate and maintains a macOS 13 floor; the root package requires macOS 14 and Swift tools 6.2.

- **High-value common starting points:** FolderAccessKit for permission/bookmark mechanisms; MediaKit for probe/thumbnail operations; PlayerKit/MediaEngineKit for playback/transport/timing; ShortcutKit and AppShellKit for familiar interaction. Validate each new consumer rather than inheriting a blanket readiness claim.
- **Important limitations:** MediaKitWaveform is a display waveform utility, not a channel-resolved measurement engine. ProcessKit exists despite an older “candidate” row in the catalogue; application-specific FFmpeg argument policy and progress interpretation still belong to consumers.
- **Still proposed in the current manifest/catalogue:** ImageIOKit, VisionOCRKit, generic VersionedJSONStore and GlobalEventMonitors. App source may be useful, but these names do not establish available package APIs.
- **Root `zPackages/FeedbackKit/README.md:7`:** package reports published/shipping with Conjoyn; shared endpoint configuration is still an app integration requirement.
- **Root `zPackages/AppCitizenshipKit/README.md:3`:** wraps feedback, tip links and About integration; manifest defines macOS 14+ product. Useful late in productization, no bearing on core media feasibility.
- **Root `zPackages/LicensingKit/README.md:7`:** extracted and tested but explicitly “No consumer yet”; original Aloft has not migrated. Treat as needing consumer proof. This scan did not run its tests or inspect credentials.

## Adjacent ideas suggested by the portfolio

These are new hypotheses, not approved additions or proven markets.

| Idea | Existing starting point | Small useful first scope | Relationship to five candidates |
|---|---|---|---|
| **Recording passport** | FocusLab IDs/JSON, VAM locations and source relationships, SAR selection markers | A sidecar recording source ID, take notes, channel roles, source ranges and which tool created a derivative | Prefer a shared exchange format/workflow across all five before a sixth app. |
| **Sync and channel test pack** | TestPatternGenerator GLITS and flash/pop | Generate known labelled channel/timing fixtures and a reproducible report for a recorder/capture path | Strong validation tool for ChannelMap and DriftCheck; could remain a TestPatternGenerator feature. |
| **Field sound notebook** | SAR trim/export, FocusLab offline take records, VAM catalogue | Select a useful sound, annotate it, export a clip with a return-to-source link | Concrete first version of SoundHarvest without requiring AI classification. |
| **Offline shoot locator** | VAM catalogue plus DiskCatalogue evidence rules, SearchAway query experience | “Which drive holds the original for this proxy/export?” with honest offline/unknown status | Best expressed as VAM Core's sharp product promise, not another general organizer. |
| **Broadcast incident notebook** | AGH-Tracker timestamped operator captures; FocusLab structured sessions; SAR recording | Time-stamped human notes linked to files and later QC findings | An adjacent logging workflow that can feed MediaCheck and DriftCheck. AGH state currently keeps broader templates/import/export at discussion stage. |

## Broad inventory and exclusions

The local state/README inventory also surfaced desktop productivity tools (Aloft/ClipSmart, MousePlus, SearchAway, LaunchAway, DeskFlow/WindowManagement, Contour, calendar/terminal/workspace apps), image/text tooling (AutoRedact, BatchTextExtractorPlus, AspectRatioUnifier, Images2WebP, CompressPhotos), diagnostics (MacBench, QuickStatsPanel, StatsWindow, DiskVerdict), and media-adjacent tools (GPSvideo, ColorX, TravelMapper, Kplay, MusicIntake). These are chiefly workflow/UI/domain knowledge sources unless a source seam is identified above. In particular, AutoRedact's state reports an unresolved export-redaction defect; do not assume it supplies a ready privacy export engine.

For iOS: AHAP is a haptic-document editor with a device document-opening issue; ChargeMap and DepTimes provide offline/service-state experience; Group Alarms offers scheduling/sync experience; MoCoFoCo remains a slider UI/Bluetooth prototype without hardware movement commands; Nag-App-Seed is extracted source, not a complete product. These do not materially shorten the five candidates' signal-analysis work.

For other/Windows work: BerlinOEPNV is a scheduled transit visualization; Blender Camera Tracker remains discovery; Market Monitor is an offline evidence/provenance CLI; LiveInterviewTool is a WebRTC proof of concept awaiting real-browser use. ZoomToSDI is a Windows C++ capture/SDI integration at capture-proof stage, with hardware/Windows validation requirements; YTdl-forWindows remains feasibility research. Their domain knowledge may help future broadcast tools, but they are not portable, finished macOS engines.

Source depth was intentionally concentrated on the strongest reusable seams, not a line-by-line audit of every project. This report excludes credentials, certificates, app profiles and personal media. No external SDK support, market demand, current GitHub status, build health or release claim was independently verified. A separate media scan covers the core processing apps and corruption tooling; a separate website scan covers the web portfolio.
