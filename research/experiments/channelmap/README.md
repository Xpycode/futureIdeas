# ChannelMap CM-E1 experiment

Synthetic CLI research only. No app, personal media, desktop control or source-repository changes.

Run from FutureIdeas with a **new, nonexistent** evidence directory:

```sh
python3 research/experiments/channelmap/routing_experiment.py research/experiments/channelmap/run-03
```

Requires Python 3 and FFmpeg/FFprobe at the explicit paths in the script. Run-02 used Homebrew 9.0.1; every run records actual versions, executable digests and build configuration. Later installations may behave differently. No automatic download or installation occurs.

The harness creates a unique temporary directory for generated WAV/MOV media. Results record its path; those files are not durable evidence and OS cleanup may remove them. The named evidence directory stores JSON/logs and is never reused or overwritten. Per-command subprocess timeout is 45 seconds.

**Current authoritative result:** [run-02/results.json](run-02/results.json). Two positive cases passed; 13 negative controls rejected. [Full report](../../2026-10-16-channelmap-routing-results.md).

Run-01 predates review fixes and is superseded. Each run directory includes the corresponding harness snapshot for audit. The root script matches run-02.

Publication is per-file validation followed by a same-filesystem no-clobber hard link and temporary-name removal. It is not job-level rollback or a production publication service. Oracle-only interior timestamp mutations are labeled separately from actual media mutations.

Files contain generated test paths only. No real recordings were inspected.

## B7 wider feasibility

See [integrated report](../../2026-10-16-channelmap-wider-feasibility.md). Authoritative evidence: formats-04 (completed investigation, delayed AAC presentation gate failed), metadata-04 (bounded pass), lifecycle-01 (bounded pass). Each wider_*.py accepts a new evidence directory. Earlier numbered attempts are preserved with snapshots; do not treat them as final acceptance.

## AAC edit-boundary follow-up

[Report](../../2026-10-16-channelmap-aac-boundaries.md), [final results](aac-boundaries-03/results.json), [harness](aac_boundaries.py). Three positives and 15 rejected exports. Reads durable synthetic fixtures from aac-boundaries-02, checked against formats-04 hashes. Run from FutureIdeas with a new output directory. Run-01 failed, run-02 passed, run-03 strengthens final checks. Historical formats-04 failure remains unchanged.
