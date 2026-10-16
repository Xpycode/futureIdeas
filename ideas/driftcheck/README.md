# DriftCheck

**Status:** Exploring · **Updated:** 2026-10-16

Explain why separately recorded audio slips out of sync.

## Portfolio foundations

TestPatternGenerator channel-identification and frame-locked flash/pop fixtures, shared rational timing and playback, audio decode/display patterns, and TimeCodeEditor metadata handling. Fixture generation is a strong testing foundation; it does not provide the drift estimator.

## Open questions

Metadata mismatch detection does not measure clock drift. Multi-window alignment, uncertainty, discontinuities and realistic ground-truth fixtures are new work.

## Next investigation

Compare known-offset and known-drift pairs at multiple points; report inconclusive cases rather than automatically correcting audio.

## Related material

- [Portfolio reuse map](../../research/2026-10-16-portfolio-opportunities.md)
- [Original research](../../research/2026-10-15-video-audio-opportunities.md#driftcheck)
- [Idea index](../../README.md)
