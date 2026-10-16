# ChannelMap B7 lifecycle evidence

2026-10-16. Isolated CLI research; no application lifecycle implementation.

[Harness](experiments/channelmap/wider_lifecycle.py) · [results](experiments/channelmap/lifecycle-01/results.json) · [commands](experiments/channelmap/lifecycle-01/commands.json)

## Observed

- Actual same-filesystem hard-link publication rejected an existing destination with EEXIST and retained both its bytes and the partial file. A destination created after the preflight absence check was also preserved.
- Successful publication preserved bytes and removed the partial name.
- A collision on the next output left the earlier output published: **this is per-file publication, not a multi-output transaction**.
- An actual FFmpeg invalid-filter failure returned exit 8; its scratch partial was cleaned and no final destination was created. A missing executable produced ENOENT.
- A real FFmpeg worker wrote at least 262,144 bytes before cancellation. SIGTERM plus wait completed in about 43 ms, without SIGKILL. waitpid then confirmed the direct child was already reaped. The partial was removed and no final output was published. Only this harness-owned process group was signaled.
- Two explicitly synthetic controls exercised an injected ENOSPC exception after a partial write and an in-process precommit cancellation flag. Neither is evidence of actual storage exhaustion or cancellation races in an app.

## Limits

The harness calls cleanup and chooses not to publish after failure; there is no production controller under test. Missing-helper, injected ENOSPC and flag checks establish narrow exception/control behavior only. Physical disk-full, drive removal, cross-filesystem publication, crash recovery, restart/stale callbacks, child-process trees, durability/fsync and cancellation concurrent with the publication commit are untested. The experiment does not provide a job rollback policy. No external files or running apps were touched.

Reproduce with a new evidence directory:

```sh
python3 research/experiments/channelmap/wider_lifecycle.py research/experiments/channelmap/lifecycle-02
```

Use the recorded snapshot/hash to distinguish original evidence from later harness edits. Generated files remain in the unique temporary directory recorded by results.

Independent read-only review found no blocker for these bounded claims. The missing-helper attempt is checked by ENOENT but is not recorded in commands.json because process creation fails before a command result exists. SIGKILL fallback and unlink failure after successful link publication were not exercised.
