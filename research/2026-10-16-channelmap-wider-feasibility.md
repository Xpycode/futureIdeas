# ChannelMap B7 wider feasibility

2026-10-16. **B7 bounded CLI research gates are complete, including the AAC edit-boundary follow-up.** No app implementation, personal-media inspection or audible acceptance.

| Gate | Result | Evidence |
|---|---|---|
| PCM32 precision | Pass: numeric 5→2 route retains independent integer samples beyond float32 precision | [Formats report](2026-10-16-channelmap-formats.md) |
| Six-channel PCM24 | Pass: sample identity and presentation span | [Final formats run](experiments/channelmap/formats-04/results.json) |
| AAC at zero origin | Pass for tested decoded samples and presentation span | Formats report |
| AAC delayed 250 ms | Original route fails; explicit edit-bounded route preserves 49,048 samples and exact declared interval | [AAC follow-up](2026-10-16-channelmap-aac-boundaries.md) |
| Rotation, color, timecode | Measured fields retained in generated ProRes MOV; three removal/replacement controls detected | [Metadata report](2026-10-16-channelmap-metadata.md) |
| Publication and cancellation | Per-file no-clobber and real child termination/reaping pass; later failure leaves earlier outputs published | [Lifecycle report](2026-10-16-channelmap-lifecycle.md) |

## Meaning and next gate

The precision result supports keeping numeric integer routing free of float32 conversion. A forced-float32 negative control loses sample values and is rejected. PCM32 evidence does not extend to arbitrary gain/mixing filters.

[The AAC follow-up](2026-10-16-channelmap-aac-boundaries.md) defines preservation of samples inside the finished source's declared edit. The delayed source decodes to 49,152 frames but presents 49,048. Explicit mapping excludes 104 samples outside the edit and preserves the declared start/end. Three routes and 15 negatives pass; independent review found no bounded blocker. The original formats-04 failure remains valid for its unbounded route. No universal AAC/player compatibility claim follows.

Metadata evidence covers a generated nondefault rotation/color/timecode source and the fields actually compared. A regenerated timecode track is not proof of arbitrary atom preservation. Lifecycle evidence covers a disposable Python protocol and owned FFmpeg worker, not an application export controller. Injected ENOSPC and flag checks are labeled demonstrations; physical disk-full, removal, crash recovery and cancellation during publication remain untested.

## Validation and review

Fresh-context agents owned formats and metadata independently; the coordinator owned lifecycle and integration. An independent reviewer inspected all three harnesses and final evidence. Formats review prompted separate sample/presentation gate classification, rational video timing including DTS, and stronger negative controls. The revised formats-04 is authoritative; earlier runs remain investigation history. Metadata-04 and lifecycle-01 are authoritative for their gates. No independent reviewer rerun is claimed.

The [completed B7 plan](../IMPLEMENTATION_PLAN.md) records closure; B7 is checked for bounded CLI research. This is a research finding, not an app-selection decision. Audible audition and Apple/NLE playback remain separate external acceptance work requiring the relevant explicit permission.
