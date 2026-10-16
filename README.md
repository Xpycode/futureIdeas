# Future Ideas

A workspace for finding, researching and comparing ideas for what to build next. Capture problems, explore possible solutions, and decide which deserve more attention. A detailed spec is a proposal, not a commitment to build.

## Start here

For session continuity, read [project state](PROJECT_STATE.md), [research follow-ups](TASKS.md), and the [session log](sessions/2026-10-16.md).

- Capture rough thoughts in the [inbox](INBOX.md).
- Compare candidates below; follow concept notes for their next questions.
- Use the [idea template](ideas/TEMPLATE.md) when a thought needs its own page.
- Keep evidence in [dated research](research/2026-10-15-video-audio-opportunities.md) and outcomes in the [decision log](DECISIONS.md).

## Latest portfolio research

The [October 16 portfolio scan](research/2026-10-16-portfolio-opportunities.md) maps existing app and website code to the five candidates and proposes six adjacent opportunities. Key finding: VAM and integrity checking already have substantial implementations to build on. These are research recommendations, not new build decisions.

The [MediaCheck and SoundHarvest follow-up](research/2026-10-16-investigation-results.md) records concrete gaps and isolated experiment results.

The [ChannelMap B1 investigation](research/2026-10-16-channelmap-investigation.md) separates reusable audition/export patterns from new channel-routing work and defines the next synthetic experiment. The [B6 routing experiment](research/2026-10-16-channelmap-routing-results.md) now passes its bounded synthetic PCM/MOV gate and negative controls; [B7 wider evidence](research/2026-10-16-channelmap-wider-feasibility.md) adds precision, metadata and lifecycle checks, with the [AAC edit-boundary follow-up](research/2026-10-16-channelmap-aac-boundaries.md) now passing its bounded presentation gate.

## Candidate ideas

These candidates come from the October 15 research. Their order is not a build queue; no build is approved by this index.

| Idea | Problem to explore | Current position | Next question |
|---|---|---|---|
| [ChannelMap](ideas/channelmap/README.md) | Understand and reorganize audio channels | Exploring; detailed spec | Is inspection and audition enough of an improvement over existing workflows? |
| [MediaCheck](ideas/mediacheck/README.md) | Find technical footage problems before editing | Exploring; detailed spec | Which findings help users act, and which are misleading? |
| [VAM Core](ideas/vam-core/README.md) | Find offline recordings and understand related files | Exploring; detailed spec | What is the smallest useful catalog alongside MediaIngest and Penumbra? |
| [SoundHarvest](ideas/soundharvest/README.md) | Reuse sounds hidden in personal footage | Exploring; research note | Separate utility or a Penumbra action with a VAM audio view? |
| [DriftCheck](ideas/driftcheck/README.md) | Diagnose audio slipping out of sync | Exploring; research note | Can real long takes be diagnosed reliably, including ambiguous cases? |

## Features and combined ideas

These placements come from the existing research and can be revisited with new evidence.

| Idea | Current home | Reason |
|---|---|---|
| Audio Channel Remapper | [ChannelMap spec](ideas/channelmap/SPEC.md) | Earlier draft merged into the channel inspection and export concept |
| QC Checker / DeliveryCheck | [MediaCheck delivery profiles](ideas/mediacheck/SPEC.md#10-delivery-profiles-phase-two-deliverycheck) | Proposed later workflow using the same scanner |
| ArchiveMap / ClipLedger | [VAM Core spec](ideas/vam-core/SPEC.md) | Offline locations and recording relationships share one catalog |
| Proxy relationship manager | [Research note](research/2026-10-15-video-audio-opportunities.md#proxy-relationship-manager) | Proposed VAM feature; encoder integration remains open |
| MediaCompare | [Research note](research/2026-10-15-video-audio-opportunities.md#mediacompare) | Verification primitives first; standalone UI remains open |

## How to use this collection

Keep new ideas short: the problem, who encounters it, the current workaround, and one question worth answering. Develop technical specs when that detail helps evaluate an idea. Personal usefulness and commercial demand are separate considerations.

Use **Inbox** for rough thoughts, **Exploring** for active questions, **Parked** for ideas set aside with a reason, **Combined** for ideas folded into another, and **Selected** after an explicit decision to pursue one. Record status changes with a date and reason in the decision log and update this index. Selection can lead to a separate implementation project.

The current research focuses on Mac video/audio tools. Its specs propose macOS 26+ on Apple Silicon and notarised direct downloads. Those are assumptions for these candidates, not restrictions on every future idea.

## Files

- `ideas/<name>/README.md`: short concept and open questions.
- `ideas/<name>/SPEC.md`: optional deeper proposal.
- `research/`: dated findings, sources and evidence limits.
- `INBOX.md`: quick capture before an idea needs a folder.
- `DECISIONS.md`: choices, reasons and conditions for revisiting them.
