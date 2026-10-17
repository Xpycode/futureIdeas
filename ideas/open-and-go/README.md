# Open & Go

**Status:** Selected (personal build, owner handoff) · **Updated:** 2026-10-17

An iOS app that shows the relevant Berlin public transport connection the moment it opens, using the owner's own walk and transfer times to find tight connections that official planners hide.

## Problem and current workaround

Official planners (BVG, VBB, HAFAS) assume generic transfer times. At stations the owner knows well, this hides faster connections. Example: at Jannowitzbrücke the BVG app suggested S5 plus a bus, while S7 was faster with a transfer the app considered infeasible. Today the owner works this out by hand.

## Possible solution

A personal, zero-tap iOS app: user-defined route variants chained with personal transfer times, ranked against the official suggestion, with calendar-aware "leave by" for shifts. Full proposal in the [spec](SPEC.md).

## Evidence and open questions

- API shapes checked against upstream sources; live responses not yet recorded. Key correction: lowering `transferTime` cannot make HAFAS or MOTIS use shorter transfers, so personal chaining cannot be replaced by a router query. [Verification note](../../research/2026-10-17-open-and-go-api-verification.md).
- No consumer app with per-station personal transfer times was found (owner's research, in the spec).
- Open: work and home locations, known variants and transfer times, shift buffer, bundle ID.

## Next investigation

First build of the draft [OpenAndGoCore](OpenAndGoCore/README.md) package on a Mac, then record live fixtures for the S7 → 347 scenario and check `tripId` consistency between departures and arrivals.

## Related material

[Spec](SPEC.md) · [Core package](OpenAndGoCore/README.md) · [Decision](../../DECISIONS.md#2026-10-17--open--go-personal-build)
