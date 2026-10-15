# Video and audio app opportunities — Research and decision log

**Date:** 15 October 2026 · **Status:** preliminary desk research and portfolio planning

## 1. Context and evidence limits

The user’s portfolio consists of focused Mac utilities. Relevant existing apps include TimeCodeEditor, Magpie, VideoContainerSwitcher, Conjoyn, QuickMotion and P2toMXF. MediaIngest is in development for offload; Penumbra is in development for culling. VAM is the working title for a personal video-focused asset manager.

This log preserves the ideas and competitor findings behind three accompanying specifications: [ChannelMap](../ideas/channelmap/SPEC.md), [MediaCheck](../ideas/mediacheck/SPEC.md) and [VAM Core](../ideas/vam-core/SPEC.md). Those three were selected from the previous recommendation’s final build sequence. SoundHarvest remains the strongest alternative creative-audio project.

Evidence comes from public vendor documentation and feature pages reviewed during this conversation. No competitor was installed or benchmarked; pricing, market size, customer demand, complete format support and naming availability were not validated. “Opportunity” below means a product hypothesis. Vendor feature descriptions establish advertised capability, not proven reliability or an exhaustive market comparison.

## 2. Selected direction

| Candidate | Decision | Reason |
|---|---|---|
| ChannelMap | Standalone app specification | Clear task; adjacent to existing media utilities; builds channel inspection and export capability |
| MediaCheck | Standalone app plus reusable scanner | Technical findings benefit ingest, culling and cataloging |
| VAM Core | First catalog milestone | Offline access, asset identity and relationships form the destination platform |
| ArchiveMap | Fold into VAM | A separate offline catalog would duplicate its core |
| ClipLedger | Fold into VAM | Relationship tracking should use the same asset model and store |

Build sequence is a recommendation, not an effort estimate: ChannelMap vertical slice; VAM catalog slice alongside it; MediaCheck probe/decode core; integration after a concrete interchange schema exists. Avoid a universal shared engine before real duplication appears.

## 3. Remaining candidate apps

### SoundHarvest

**Pitch:** Save useful sounds hiding in your footage.

Extract ambience, room tone and effects from marked video ranges, attach tags and preserve the exact source reference. A forest clip becomes both footage and a reusable sound asset. VAM later searches that asset and returns to its source recording.

**MVP:** waveform and video preview; in/out selection; editable handles; PCM export; notes/tags; source-range sidecar. Exclude automatic source separation, music generation and a general-purpose DAW. Annotation and export should preserve rational timing and make audition gain independent from export processing.

**Competitive overlap:** Sound Particles Explorer advertises waveform previews, tagging, metadata, playlists and audio-property searches. [S1] A generic sound browser would overlap substantially. The narrower hypothesis is convenient harvesting from one’s own video and durable source tracing.

**Validation:** ask five editors to retrieve three sounds they remember recording. Observe whether they can find and reuse them, then test a range-extraction prototype. Measure successful retrieval and retained provenance rather than asking whether the idea sounds appealing.

**Decision:** strongest later standalone experiment; it could also become a Penumbra range action plus a VAM audio view. Decide after inspecting how much Penumbra already provides.

### DriftCheck

**Pitch:** Find out why your audio slips out of sync.

Compare one continuous camera recording with a separate audio recording. Estimate initial offset and drift from multiple windows, report uncertainty and allow aligned audition. Display offset versus time so users can distinguish steady clock drift from a discontinuity.

MVP excludes multicamera timelines, automatic NLE project rewriting and unconditional correction. Do not stretch audio from a single matching window or a weak correlation. Silence, repeated music, edits, dropouts and recorder restarts must produce ambiguity or piecewise findings.

**Competitive overlap:** Tentacle Sync Studio advertises file/audio-timecode analysis, synchronization, multicam support and editing-system exports. [S2] That does not prove it covers this exact diagnostic workflow; waveform-only drift analysis requires direct comparison in a trial.

**Validation:** collect real long takes with measured drift and controlled synthetic offsets. Compare the diagnosis with known timing at several points. A correction phase requires explicit resampling/stretching quality evaluation and is a separate scope decision.

**Decision:** promising specialist utility, but a higher algorithmic and support burden than ChannelMap.

### DeliveryCheck

**Pitch:** Check an export before you send it.

Inspect an exported file against a user-defined delivery profile: dimensions, frame rate, audio layout and eventually loudness. Show evidence at candidate black, frozen or silent ranges. Save a report alongside the delivery.

**Boundary:** MediaCheck evaluates source media; DeliveryCheck applies a declared delivery contract. Reuse the scanner rather than building another detection engine. Begin as a MediaCheck profile or workspace; split into an app only if users demonstrate a distinct purchasing/workflow need.

**Competitive overlap:** Shutter Encoder advertises loudness/true-peak analysis and several content detectors. [S3] NUGEN AMB advertises batch loudness management and related processing. [S4] A simple loudness normalizer is therefore a weak novelty claim.

**Validation:** collect actual delivery sheets, including exceptions and channel naming requirements. Avoid presenting a preset as universally valid for a platform or broadcaster. Version the user-approved requirements and keep analysis separate from correction.

**Decision:** extension candidate after MediaCheck is stable. Specified as [MediaCheck §10](../ideas/mediacheck/SPEC.md#10-delivery-profiles-phase-two-deliverycheck), which absorbed the earlier QC Checker draft.

### MediaCompare

**Pitch:** See what changed between two versions of a clip.

Compare metadata, track arrangement, timing and aligned decoded frames. Useful for proving that a remux retained picture content or finding what a transcode changed. ChannelMap and VideoContainerSwitcher could expose its verification report.

**MVP:** side-by-side technical differences, timing alignment controls, synchronized preview and a documented comparison mode. Distinguish byte identity, compressed packet identity, decoded-sample equality and perceptual similarity. None implies all the others; scaling, color conversion and decoder choices affect visual comparisons.

**Competitive overlap:** Shutter Encoder lists VMAF and FrameMD5. [S3] The hypothesis is understandable, transformation-aware explanations rather than a new metric.

**Validation:** a fixture set of known remuxes, lossy encodes, channel changes, timestamp shifts and metadata-only edits. Verify the tool names the comparison level and does not flag a valid remux merely because whole-file hashes differ.

**Decision:** build verification primitives for existing apps first; evaluate a standalone UI later.

### Proxy relationship manager

**Pitch:** Know which footage has usable proxies—and which proxies belong to it.

Track missing or stale proxies, timing/channel differences and explicit original-to-proxy links. This differs from merely generating small videos. VAM is the natural place for the relationship state.

**Competitive overlap:** EditReady provides transcoding workflows, and EditReady Server explicitly targets headless ingest/proxy generation for asset managers. [S5] Existing capability weakens the case for another generic generator.

**Validation:** gather actual failed relinking examples in Final Cut Pro, Resolve and Premiere before promising interchange. Matching names are insufficient; timecode, reel naming, duration and stream characteristics may matter differently by editor.

**Decision:** VAM feature; potentially integrate an external encoder rather than immediately building another app.

### ArchiveMap and ClipLedger

**Pitches:** Find your footage on disconnected drives; know which files belong to a recording.

NeoFinder advertises offline previews, video thumbnails and cataloged media metadata. [S6] Offline browsing alone is not an uncovered category. The portfolio-specific angle is a recording graph connecting camera segments, Conjoyn outputs, remuxes, proxies, audio and Penumbra ranges.

**Decision:** specified together in [VAM Core](../ideas/vam-core/SPEC.md). Never treat derivatives as disposable duplicates, or a historical catalog entry as proof of a currently readable backup.

## 4. Existing-product findings

| Product | Supported finding from public material | Implication | Not established |
|---|---|---|---|
| EditReady | Audio-only/metadata changes via presets; silent-channel removal and overlays | ChannelMap needs an inspection/understanding advantage | Exact channel-audition UX and metadata retention across all formats |
| EditReady Server | Headless ingest/proxy workflow for asset managers | Consider integration; avoid generic proxy-generator scope | Licensing, cost and suitability for a small personal app |
| Tentacle Sync Studio | File/audio-timecode analysis, sync, multicam and interchange exports | Full sync is an established category | Accuracy for waveform-only drift diagnostics |
| Shutter Encoder | Audio normalization, content analysis, VMAF and FrameMD5 are advertised | A new utility needs workflow value beyond filters | False-positive rates and suitability for the user’s exact footage |
| NUGEN AMB | Modular batch loudness management and upmix capabilities | Standalone basic loudness normalization has substantial overlap | Current pricing and individual-creator fit |
| Sound Particles Explorer | Library organization, metadata, tags and waveform previews | SoundHarvest should focus on video-derived source ranges | Best workflow for linking extracted audio back to footage |
| NeoFinder | Offline catalog previews and multiple video thumbnails | VAM needs video-specific relationships and integration | Detailed lineage model and fit for this particular workflow |

## 5. Decisions shared by the recommendations

- Keep recording identity, immutable file content and storage location separate.
- Preserve original media; publish new outputs only after validation.
- Treat partial hashes and metadata as matching hints, not byte-identity proof.
- Retain source time ranges and operation provenance across apps.
- Use explicit coverage and uncertainty for analysis results.
- Start with portable, versioned interchange files; do not require VAM for utility use.
- Share value types and schemas first, processing engines only where reuse is demonstrated.
- Avoid multiplying apps when a feature belongs naturally in an existing product.
- Distribute as notarised direct downloads; the Mac App Store is not a goal *(added 15 October 2026)*.

## 6. Next research tasks

1. Inspect actual MediaIngest and Penumbra schemas and job models before finalizing integration.
2. Collect representative camera/recorder samples, with ownership/permission to retain test fixtures.
3. Run ChannelMap workflow interviews and a task-based prototype test.
4. Trial the nearest competitors against the same fixtures; document exact version and settings.
5. Test backend packaging, codec support and metadata preservation before publishing format promises.
6. Validate willingness to pay separately from personal usefulness. No pricing is recommended from this research alone.
7. Check app-name availability before public branding; all new names remain working titles.

## 7. Source register

Reviewed 15 October 2026. Sources support the narrow capability summaries above, not claims that competitors lack an unmentioned feature.

- S1: Sound Particles Explorer — library organization and audio browsing.
- S2: Tentacle Sync Studio — synchronization, metadata and exports.
- S3: Shutter Encoder and documentation — processing and analysis functions.
- S4: NUGEN AMB — modular batch audio management.
- S5: EditReady Server, custom presets and additional features — transcode/proxy and audio-related capabilities.
- S6: NeoFinder 9 announcement — offline previews and video thumbnails.
- S7: FFmpeg, ffprobe and filters — implementation references, to be checked against the pinned build.
- S8: Apple sandbox file access — persistent user-authorized file access.

## 8. Change log

- 2026-10-15: Initial portfolio assessment and public-source review.
- 2026-10-15: Selected ChannelMap, MediaCheck and VAM Core for separate implementation specifications; recorded remaining opportunities and limits here.
- 2026-10-15: Distribution decided: notarised direct download, no Mac App Store.
- 2026-10-15: Merged the earlier Audio Channel Remapper draft into ChannelMap (§9) and the QC Checker draft into MediaCheck (§10, DeliveryCheck). Platform baseline across specs: macOS 26+, Apple Silicon; MXF is phase two everywhere.
