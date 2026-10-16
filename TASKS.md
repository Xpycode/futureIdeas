# Research follow-ups

These are investigation tasks, not approved app changes. Detailed evidence and acceptance criteria remain in the linked reports.

## Backlog

- [x] **B1 — ChannelMap investigation complete (2026-10-16).** Inspected audition/routing/layout/export seams and tests; defined CM-E1 and its limits. [Evidence and experiment](research/2026-10-16-channelmap-investigation.md). Experiment not run; no app started.
- [ ] **B2 — MediaCheck coverage follow-up.** The current FFmpeg policy omits a second audio stream in the reproduced case; AV audio uses stored-format samples; result and process-lifecycle contracts need work. Investigate explicit per-stream decode/coverage and bounded cancellation before new detectors. [Evidence and gate](research/2026-10-16-mediacheck-gap.md).
- [ ] **B3 — SoundHarvest provenance and retrieval experiment.** PCM slicing passed in an isolated harness. Next prove explicit stream/sample identity, source references and safe publication/cancellation, then three real owner-selected sounds and later retrieval. Do not select personal files automatically. [Evidence and criteria](research/2026-10-16-soundharvest-feasibility.md).
- [ ] **B4 — VAM Core reconciliation.** Compare the proposed model with the existing VAM catalog and MediaIngest receipts; map migration/identity gaps without creating a second catalog. [Concept](ideas/vam-core/README.md).
- [ ] **B5 — DriftCheck feasibility.** Investigate multi-window alignment, known-drift fixtures, confidence and discontinuities; TestPatternGenerator supplies useful signals but no drift estimator. [Concept](ideas/driftcheck/README.md).

- [x] **B6 — ChannelMap routing experiment complete (2026-10-16).** CM-E1 and second-stream/unknown-layout extension passed: exact PCM, copied video, delayed timing/edit lists; 13 negative controls rejected. PCM-only wording reconciled. [Results and limits](research/2026-10-16-channelmap-routing-results.md).

- [x] **B7 — ChannelMap wider feasibility gates complete (2026-10-16).** PCM32, six-channel PCM, measured metadata and bounded lifecycle evidence pass. AAC edit-bounded routes preserve presented samples and exact timelines for three fixtures; 15 negatives rejected and independently reviewed. Audible/Apple/NLE acceptance remains separate and unperformed; desktop control requires explicit permission. No app implementation. [Results](research/2026-10-16-channelmap-wider-feasibility.md).

## Inbox

- [ ] **I1 — Reproduce MediaCheck cancel/restart races.** Source lacks child cancellation and run-generation protection; actual stale-result/worker-lifetime behavior is not yet tested. [Analysis](research/2026-10-16-mediacheck-gap.md).
- [ ] **I2 — Test clean timing edge cases.** VFR, multiple video rates and unequal stream durations may trigger false truncation/gap warnings. This is inferred from source, not reproduced. [Analysis](research/2026-10-16-mediacheck-gap.md).
- [ ] **I3 — Test parser containment in isolation.** Review suspected integer-overflow paths and stalled reads with disposable workers, never the production GUI. No malformed-file crash reproduction yet. [Analysis](research/2026-10-16-mediacheck-gap.md).
- [ ] **I4 — Validate adjacent product hypotheses.** Recording passport, browser-delivery preflight, schedule revisions, culture shortlist, archive reconnect review and palette workbench remain proposals. Select one concrete task before expanding research or creating projects. [Ideas](research/2026-10-16-portfolio-opportunities.md#new-ideas-from-the-portfolio).
