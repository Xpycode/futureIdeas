# VAM Core

**Status:** Exploring · **Updated:** 2026-10-16

Find recordings on disconnected drives and understand how originals, copies, joined clips and derivatives relate.

## Problem and possible solution

A recording can span several files and drives, with proxies, extracted audio and selected ranges elsewhere. The proposal is a personal video catalog with offline previews, search and explicit relationships. ArchiveMap and ClipLedger are combined here; proxy relationships are a possible feature. MediaIngest handles offload and Penumbra handles culling.

## Evidence and open questions

Offline catalogs already appear in the research. The proposed value lies in video relationships and integration. The original proposal did not inspect existing app schemas. The October 16 scan below establishes concrete VAM and MediaIngest foundations; integration contracts still need reconciliation.

## Portfolio findings on October 16

The October 16 source scan found an existing VAM catalog, volume/path resolution and proxy relationships. The earlier spec was written without inspecting these implementations. Reconcile it with VAM as a continuation, preserving existing libraries; do not treat it as a fresh catalog project.

See the [source-backed reuse map](../../research/2026-10-16-portfolio-opportunities.md) for components, gaps and proposed experiments.

## Next investigation

Compare the proposed spec with the existing VAM model and MediaIngest receipts. Trace one recording through originals, proxies and derivatives, then identify the smallest missing catalog view while preserving existing libraries.

## Related material

- [Detailed proposal](SPEC.md)
- [October 15 research and evidence limits](../../research/2026-10-15-video-audio-opportunities.md)
- [Idea index](../../README.md)
- [Decision log](../../DECISIONS.md)
