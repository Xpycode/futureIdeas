# ChannelMap

**Status:** Exploring · **Updated:** 2026-10-16

Help editors understand, audition and reorganize audio channels inside camera and recorder files.

## Problem and possible solution

An eight-channel recording may contain only two useful channels. The proposed utility makes tracks and channels visible, lets users listen and label them, and exports selected PCM audio or a MOV with copied video. It complements the existing media utilities. The earlier Audio Channel Remapper draft is included in the detailed proposal.

## Evidence and open questions

Portfolio fit is promising in the existing research, while demand remains a hypothesis. The key question is whether inspection and audition improve the workflow enough to justify a separate app. Supported formats and metadata preservation need representative samples.

## Portfolio findings on October 16

The portfolio scan found stem-pair audition in AvidMXFPeek, channel-layout models in CameraTranscoder and verification in TimeCodeEditor. These are building blocks; arbitrary per-channel mapping and calibrated analysis remain new work.

See the [source-backed reuse map](../../research/2026-10-16-portfolio-opportunities.md) for components, gaps and proposed experiments.

## Next investigation

B1 source review is complete: see the [reuse boundaries and CM-E1 experiment](../../research/2026-10-16-channelmap-investigation.md). The [B6 results](../../research/2026-10-16-channelmap-routing-results.md) prove explicit 5→2 routing, PCM identity, copied video and delayed-audio timing for synthetic PCM24/ProRes fixtures, including second-stream selection. [B7 wider evidence](../../research/2026-10-16-channelmap-wider-feasibility.md) now covers PCM32, six-channel PCM, metadata and bounded lifecycle checks. The [AAC follow-up](../../research/2026-10-16-channelmap-aac-boundaries.md) now preserves declared presented samples and exact edit boundaries for three synthetic fixtures. No app or audible-playback test has started.

For user validation, observe editors identifying useful channels in their own files with their current tools. Record confusion, time spent and export mistakes. Use those examples to decide whether a small audition-and-mapping prototype is worthwhile.

## Related material

- [Detailed proposal](SPEC.md)
- [October 15 research and evidence limits](../../research/2026-10-15-video-audio-opportunities.md)
- [Idea index](../../README.md)
- [Decision log](../../DECISIONS.md)
