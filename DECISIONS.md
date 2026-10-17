# Idea decisions

Record what to explore, combine, pursue or park, why, and what would justify revisiting it. Historical recommendations remain proposals until explicitly adopted.

## 2026 10 17 — Open & Go personal build

**Decision:** Record the owner's Open & Go handoff as a selected personal build and draft its pure core here until an app repository exists.

**Reason:** The owner supplied a build handoff with milestones and acceptance criteria. The cloud session had no Swift toolchain or API access, so it checked API shapes from upstream sources and drafted uncompiled domain code with synthetic fixtures.

**Effect:** [Spec](ideas/open-and-go/SPEC.md), [verification note](research/2026-10-17-open-and-go-api-verification.md) and [OpenAndGoCore](ideas/open-and-go/OpenAndGoCore/README.md). Move the package to the app repository once it is created. The media candidates are unaffected.

**Revisit when:** the first build or recorded fixtures contradict the chaining approach.

## 2026 10 16 — Organize around exploration

**Decision:** Use Future Ideas to discover and compare possible next projects. Detailed specifications support evaluation; they do not authorize implementation.

**Reason:** The user clarified that this repository is for finding what could come next, rather than developing an app here.

**Effect:** Keep the existing specs, expose questions through short concept notes, and provide an inbox and comparison index. No candidate is newly selected or parked by this reorganization.

## 2026 10 15 — Existing research baseline

The [research log](research/2026-10-15-video-audio-opportunities.md) records the rationale and evidence limits for these earlier choices:

- Develop proposals for ChannelMap, MediaCheck and VAM Core; retain SoundHarvest and DriftCheck as alternatives. The suggested build sequence is a recommendation.
- Combine Audio Channel Remapper with ChannelMap and QC Checker with MediaCheck delivery profiles.
- Place ArchiveMap, ClipLedger and proxy relationships within VAM. Explore MediaCompare verification within existing tools before deciding on a standalone app.
- Target notarised direct downloads for the current app proposals.

**Revisit when:** workflow observations support a separate product, existing-project inspection changes the overlap, or research changes a candidate's value. Demand, naming and format support remain open validation topics.

## 2026 10 16 — Reconcile ChannelMap PCM-only proposal

**Context:** The proposal requires PCM audio output, but the inherited remapper table also allowed unchanged compressed-stream copying.

**Resolution:** Keep the stated PCM-only MVP. Whole supported PCM streams may be copied; retained compressed streams decode to PCM. Defer compressed passthrough rather than expand the MVP.

**Reason and alternatives:** This follows the proposal's existing precedence rule and keeps output behavior explicit. Allowing compressed passthrough would require another support/verification policy. [B6](research/2026-10-16-channelmap-routing-results.md) proves only synthetic PCM24 routing with copied ProRes, not that alternative.

**Effect:** Clarified spec §9.1/§9.2. No app selected or implemented. Broader formats, metadata, lifecycle and audition remain gates. Revisit only with an explicit scope decision and format evidence.

## Recording the next decision

Include the date, affected idea, outcome, reason, supporting evidence, and a revisit condition for anything parked or combined. Link its concept note and update the index.

## 2026 10 16 — AAC research preservation contract

**Context:** Keeping every decoded AAC sample extended the delayed fixture 104 samples past its declared MOV presentation end.

**Resolution:** Preserve exact decoded samples inside the declared media edit, placed at its movie-time position. Keep full decoder output as separate evidence.

**Alternatives and rationale:** Keeping all raw samples fails presentation preservation; stripping assumed priming from every source changes the delayed source's actual edit. Read the finished file instead of recovering the generator's intended offset. [Three fixtures and independent verification](research/2026-10-16-channelmap-aac-boundaries.md) support this bounded contract.

**Consequences:** B7 research gate closes. No product support commitment or universal decoder/player guarantee. Revisit with multiple edits, alternate players/decoders, real media or a different preservation requirement.
