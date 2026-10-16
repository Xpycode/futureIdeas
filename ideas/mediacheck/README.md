# MediaCheck

**Status:** Exploring · **Updated:** 2026-10-16

Help editors find and understand technical problems in footage before editing.

## Problem and possible solution

A verified copy can still contain media that fails to decode. The proposal inspects recordings, explains findings and supplies evidence for review. It could support MediaIngest and VAM while working independently. DeliveryCheck and the earlier QC Checker draft are included as later delivery-profile work.

## Evidence and open questions

Scanner reuse is a potential benefit, but product demand remains open. A useful result must distinguish unsupported media, incomplete checks and actual failures. Black, frozen or silent material can be intentional.

## Portfolio findings on October 16

VideoIntegrityChecker already implements decode, timing and container inspection, and VideoCorruptor supplies controlled fixture-generation code. Compare that implementation with this proposal before starting another checker. Browser-delivery checks from PRIVAT and MacroPorn offer a narrow profile experiment.

See the [source-backed reuse map](../../research/2026-10-16-portfolio-opportunities.md) for components, gaps and proposed experiments.

## Next investigation

Collect examples of real footage problems and intentional material that resembles a problem. Identify which findings would change an editor's next action. Compare those needs with MediaIngest's responsibilities before choosing standalone scope.

## Related material

- [Detailed proposal](SPEC.md)
- [October 15 research and evidence limits](../../research/2026-10-15-video-audio-opportunities.md)
- [Idea index](../../README.md)
- [Decision log](../../DECISIONS.md)

## Follow-up investigation

The [October 16 investigation](../../research/2026-10-16-investigation-results.md) includes source-level gaps and isolated runtime experiments. Read it before treating portfolio components as ready-made implementations.
