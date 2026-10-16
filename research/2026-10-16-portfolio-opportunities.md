# Portfolio opportunities and reuse

**Date:** 2026-10-16 · **Status:** research and proposed next investigations

The portfolio already contains substantial foundations for the five candidates. The useful next step is to identify small missing workflows and validate them against real material, rather than assume each candidate needs a new application.

## Scope and evidence

Three agents inspected local media apps, websites, and other apps/shared packages. This is a source and documentation survey, not a runtime or release audit. Historical test results in project notes were not rerun. Local working copies may include work not yet pushed. Public-site fetch attempts were unavailable through the web tool; this report does not establish current live behavior, audience size or commercial demand.

Supporting scans provide the inventory and source locations:

- [Media applications](portfolio-media-scan.md)
- [Websites](portfolio-web-scan.md)
- [Other apps and packages](portfolio-other-scan.md)

## What this changes for the five candidates

| Candidate | Reuse first | Missing or uncertain | Proposed next move |
|---|---|---|---|
| **ChannelMap** | AvidMXFPeek stem audition, SAR stereo display, CameraTranscoder layouts, TimeCodeEditor verification, TestPatternGenerator channel fixtures | Arbitrary per-track/per-channel mapping, independent audition and calibrated measurements; output fidelity across supported formats | Test one eight-channel file through inspection → solo → explicit mapping → verified PCM/MOV export |
| **MediaCheck** | VideoIntegrityChecker decode/container diagnostics, VideoCorruptor controlled fixtures, Stills From Video frame evidence, website compatibility rules | Coverage semantics, false-positive handling, content detectors and delivery-profile validation | Compare the existing checker against the proposed spec before starting a new project; use browser-delivery preflight as a narrow test workflow |
| **VAM Core** | Existing VAM catalog, volume/path resolution and proxies; MediaIngest receipts; Conjoyn/P2/Avid recording grouping; MacroPorn import patterns | Existing-library migration, recording/file/derivative identity, portable imports, reliable cross-volume and NAS identity | Reconcile the proposed spec with the existing app; demonstrate one recording's journey without replacing the catalog |
| **SoundHarvest** | Penumbra range interaction, SAR marked-range export and stereo display, VAM catalog, MacroPorn curation pattern | Video audio demux, format/fidelity coverage, durable source-range provenance, tags/search workflow | Extract three useful sounds from one shoot, retain source references, and try finding them again a week later |
| **DriftCheck** | TestPatternGenerator GLITS/flash-pop fixtures, shared rational timing and playback, existing audio decode/display patterns | Multi-window signal alignment, clock-rate fit, confidence, dropouts/restarts and discontinuity handling | Run a diagnostic research spike on known-offset/known-drift pairs; defer any correction/export promise |

These are source-backed reuse candidates, not drop-in integrations. The [media scan](portfolio-media-scan.md), [other-app scan](portfolio-other-scan.md) and [website scan](portfolio-web-scan.md) identify the actual files and their coupling.

**Most important correction to the earlier research:** VAM and integrity checking already have implementations. The earlier specs were written without inspecting them. Treat those specs as desired behavior to compare with existing code, not instructions to create duplicate apps.

TestPatternGenerator is an especially useful discovery: its Rust/FFmpeg code generates channel identifiers and frame-locked flash/pop output, with decoded-output verification tests in the repository. Use those fixtures to test channel order and timing. They do not supply DriftCheck's estimator or prove behavior on real ambiguous recordings. FocusLab's versioned take/session exports also provide a concrete starting point for a recording passport. See the [supporting-app evidence](portfolio-other-scan.md#testpatterngenerator-and-focuslab).

## New ideas from the portfolio

All names below describe proposed workflows, not cleared product names. None is selected for implementation.

| Opportunity | Existing ingredients | Smallest useful experiment | Natural home |
|---|---|---|---|
| **Recording passport** | FocusLab take IDs/JSON, MediaIngest receipts, Conjoyn/P2/Avid grouping, VAM identities and publication derivatives | One JSON record traces an original, join, proxy, sound excerpt and QC report; reopen it after moving the drive | Interchange feature across existing apps |
| **Browser delivery preflight** | PRIVAT and MacroPorn compatibility gates, VideoIntegrityChecker, existing remux utilities | Read-only report for ten accepted/rejected clips, with explicit destination rules and a repair suggestion | MediaCheck profile; avoid silently dropping ancillary tracks |
| **Schedule revision review** | PDF2Calendar parsing, preview and calendar export | Compare two versions of one roster; explain added, removed and moved shifts before any calendar write | PDF2Calendar extension; stable event identity is new work |
| **Culture shortlist** | KinoBerlin filters, TheaterB production/date grouping, Offene Türen events | Save three events from one source and export a reviewed calendar selection; combine sources only after that works | Existing discovery sites, potentially a shared companion later |
| **Archive reconnect review** | VAM volume/path resolution, catalog identity and offline state | Reconnect a drive with renamed, moved and missing files; preview proposed catalog changes without applying them | VAM feature; never infer a valid backup from a catalog entry |
| **Accessible palette workbench** | Colors' implemented palette math, AppShellKit's theme model | Apply one generated light/dark scheme to a real app preview and export its tokens | Finish Colors; UI/exporters still need work |

The [website scan](portfolio-web-scan.md) supplies implementation evidence for schedule revisions, culture shortlists, palette tooling and destination rules. The [media scan](portfolio-media-scan.md) supplies evidence for recording passports and archive reconnect review.

## Suggested investigation order

This order reflects overlap with existing code and the size of the unanswered question, not a market ranking or development estimate.

1. **Audit MediaCheck against VideoIntegrityChecker.** Identify what is already usable and what the spec adds. A browser-delivery preset makes the output immediately testable against existing sites.
2. **Try a narrow SoundHarvest workflow.** SAR and Penumbra make the interaction/export experiment plausible; test retrieval and provenance as well as extraction.
3. **Validate ChannelMap's distinct workflow.** The building blocks exist, but the central per-channel mapping experience still needs proving.
4. **Reconcile VAM Core with VAM.** Treat this as scope and integration work in an existing substantial project, with an explicit catalog-migration boundary.
5. **Keep DriftCheck as a bounded research experiment.** It has the least reusable core algorithm in the inspected portfolio.

For a non-media direction, start with **schedule revision review**: it has a concrete before/after task and an existing parser/export path. Culture shortlists are another plausible extension, but cross-site identities and freshness add scope.

## What to decide next

Choose one real workflow and collect a small owner-approved example set before writing more specifications. Preserve the source apps and prove extracted components in their original consumers. Keep observations, fixture results and proposed product choices distinct. No app code, production site, package or remote repository was changed during this scan.

## Shared foundations already present

| Foundation | Verified source | Useful for | Boundary |
|---|---|---|---|
| Media probe, thumbnails and cache | [zPackages manifest](/Users/sim/ProgrammingProjects/1-macOS/zPackages/Package.swift), [MediaProbe](/Users/sim/ProgrammingProjects/1-macOS/zPackages/Sources/MediaKit/MediaProbe.swift) | All media candidates | Native inspection is not a full decode/QC engine or universal codec support |
| ProcessKit | [ProcessRunner](/Users/sim/ProgrammingProjects/1-macOS/zPackages/Sources/ProcessKit/ProcessRunner.swift), [RunSpec](/Users/sim/ProgrammingProjects/1-macOS/zPackages/Sources/ProcessKit/RunSpec.swift) | Bundled analysis/export tools | Exists despite older catalog sections listing it as a future extraction; tool-specific progress parsing remains separate |
| FolderAccessKit, PlayerKit, AppShellKit | [Manifest](/Users/sim/ProgrammingProjects/1-macOS/zPackages/Package.swift), [package state](/Users/sim/ProgrammingProjects/1-macOS/zPackages/docs/PROJECT_STATE.md) | File access, playback and common UI | Package existence does not prove every consumer integration; app-specific behavior stays in the app |
| Rational frame timing and audio readouts | [FrameClock](/Users/sim/ProgrammingProjects/1-macOS/zPackages/MediaEngineKit/Sources/MediaEngineKit/FrameClock.swift), [AudioIdentity](/Users/sim/ProgrammingProjects/1-macOS/zPackages/MediaEngineKit/Sources/MediaEngineKit/AudioIdentity.swift), [AudioMeter](/Users/sim/ProgrammingProjects/1-macOS/zPackages/MediaEngineKit/Sources/MediaEngineKit/AudioMeter.swift) | ChannelMap, SoundHarvest, DriftCheck playback | FrameClock assumes constant frame rate; audio meters are not a drift estimator |
| Preview waveform | [Waveform generator](/Users/sim/ProgrammingProjects/1-macOS/zPackages/Sources/MediaKitWaveform/Waveform.swift) | Audition and range-selection display | Reads the first audio track, downmixes to mono, and normalizes peaks. Do not use it unchanged for channel comparison, silence measurement, loudness or drift correlation |

Prefer an existing package when its behavior fits. For app-owned code, first isolate the smallest needed component and prove it in its original app. No shared universal media engine is justified by this scan alone.
