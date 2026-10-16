# B7 wider feasibility research plan — completed

## Goal and scope
Extend ChannelMap synthetic evidence without app implementation, personal media, desktop control, commits or pushes. Preserve all existing mixed research changes.

## Acceptance criteria
- [x] B7.1: independently generated PCM32 low bits survive numeric 5→2 routing; six-channel regression and AAC priming have separate sample/timeline results and negative controls.
- [x] B7.2: generated MOV timecode, rotation and color metadata are compared before/after copied-video routing; losses are explicitly recorded.
- [x] B7.3: disposable publication collisions, failed worker and cancellation cases leave existing destinations intact and workers reaped; distinguish injected faults from real storage failures.
- [x] B7.4: independent review, evidence reconciliation and linked handoff completed. Failed media gates remain explicit, not silently waived.

## Schedule and ownership
Wave 1: B7.1 and B7.2 independent, with exclusive harness/evidence paths and private temporary directories. B7.3 coordinator-owned, independent of media harnesses. Wave 2: B7.4 depends on all three investigations. Existing B6 evidence is immutable reference.

### B7.1 — precision, six-channel and AAC
Dependencies/external gates: none. Owns research/experiments/channelmap/wider_formats.py, formats-* evidence and research/2026-10-16-channelmap-formats.md. Validation: execute harness against installed FFmpeg, preserve commands, versions, source checks, independent integer reference, decoded AAC reference and presentation times.

### B7.2 — metadata
Dependencies/external gates: none. Owns research/experiments/channelmap/wider_metadata.py, metadata-* evidence and research/2026-10-16-channelmap-metadata.md. Validation: execute synthetic harness; verify fixture really contains nondefault metadata before comparing output; include removal negative control.

### B7.3 — lifecycle
Dependencies/external gates: none. Owns research/experiments/channelmap/wider_lifecycle.py, lifecycle-* evidence and research/2026-10-16-channelmap-lifecycle.md. Validation: run disposable failure harness with specific diagnostics, no-clobber checks, cancellation deadline and wait/reap verification.

### B7.4 — integration/review
Depends on B7.1–3. Coordinator owns state, tracker, plan, summary report and sessions. Independent reviewer reads scripts/results; fix concrete findings and rerun affected evidence. Validate links, syntax and recorded status. No application acceptance is implied.

## External checks
Audible audition and Apple/NLE playback remain separate, unperformed and outside B7 CLI evidence. Desktop control requires explicit permission. Physical disk-full/drive removal and signed distribution remain outside synthetic claims.

## Execution log
- 2026-10-16: inspected B6 run-02 and handoff. Starting independent bounded investigations under user request “B7 wider feasibility”. No commits: preserve existing mixed untracked research and prior Git-write restriction.

- 2026-10-16: B7.1 formats agent ran formats-04; PCM32, six-channel PCM24 and zero-origin AAC pass; delayed AAC has exact decoded samples but 104-sample presentation-end excess. B7.1 remains open for a defined priming/padding contract and a passing timing experiment.
- B7.2 metadata agent ran metadata-04: measured rotation/color/timecode retained, three negative controls detected. B7.3 coordinator ran lifecycle-01: actual collision and owned-worker cancellation checks pass; injected faults explicitly bounded, no multi-output transaction.
- B7.4 independent reviewer found no remaining blocker for bounded claims after formats fixes. No reviewer rerun claimed. Reports and state integrated; syntax, snapshot hashes and local links checked at handoff. No commits/pushes; mixed prior research preserved.

## Historical acceptance gate (resolved below)
Delayed AAC presentation preservation failed. Next: explicit priming/end-padding and edit-list mapping experiment; preserve independent sample and timing oracles. No app or audible work authorized. [Integrated evidence](research/2026-10-16-channelmap-wider-feasibility.md).

## Completion — 2026-10-16

B7.1 now passes under an explicit presented-sample contract. Three positive routes and 15 actual negative exports verify zero, delayed and interior edit boundaries. The delayed route keeps 49,048 presented samples, excludes 104 outside the edit and preserves movie interval [10,976,60,024). Full-decoder identity is separate evidence. [AAC results](research/2026-10-16-channelmap-aac-boundaries.md).

Coordinator implemented serially because mapping, decoding and integration are coupled. A fresh-context reviewer independently checked media/probes and the final harness; no remaining bounded blocker. Prior PCM32/PCM24/metadata/lifecycle evidence reused, not rerun. B7 research plan complete; no application acceptance implied. No commits or pushes. Original plan retained in place after automatic review rejected the proposed archive operation over a deletion-risk concern. Next: select B2–B5 research or separately scope playback acceptance.
