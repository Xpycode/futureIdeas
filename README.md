# Future Ideas

A collection of product ideas and specs for possible future apps.

## Specs

| Idea | Platform | Status | One-liner |
|---|---|---|---|
| [ChannelMap](ideas/channelmap/SPEC.md) | macOS (SwiftUI) | Proposed build spec v0.1 | See, hear and reorganize the audio inside your recordings. Includes the former Audio Channel Remapper draft. |
| [MediaCheck](ideas/mediacheck/SPEC.md) | macOS (SwiftUI) | Proposed build spec v0.1 | Find technical problems in footage before you edit. Delivery profiles and loudness (former QC Checker draft) are its phase two. |
| [VAM Core](ideas/vam-core/SPEC.md) | macOS (SwiftUI) | Proposed build spec v0.1 | Offline catalog of recordings, file locations and their relationships. Also defines the shared interchange envelope. |

## Research

- [Video and audio app opportunities — research and decision log (2026-10-15)](research/2026-10-15-video-audio-opportunities.md): why ChannelMap, MediaCheck and VAM Core were chosen, plus SoundHarvest, DriftCheck, DeliveryCheck, MediaCompare and the proxy manager as remaining candidates.

## Conventions

Each idea lives in `ideas/<name>/` with a `SPEC.md`. Research and decision logs live in `research/`.

All apps here target macOS 26+ on Apple Silicon (to confirm against existing apps) and ship as direct downloads, signed with Developer ID and notarised. The Mac App Store is not a goal.
