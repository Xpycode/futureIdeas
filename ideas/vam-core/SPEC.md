# VAM Core — Offline catalog and recording relationships

**Version:** 0.1 · 15 October 2026 · **Status:** proposed build specification

## 1. Product decision

*Find your recordings, know where their files live, and understand how those files relate.*

VAM is the user’s working title for a personal video-focused media asset manager. Its first release should establish a trustworthy offline catalog and explicit relationships between recordings, copies and derivatives. ArchiveMap and ClipLedger are capabilities inside this core, not two additional applications to maintain.

MediaIngest remains the offload tool; Penumbra remains the culling tool. VAM stores their results and makes media discoverable. ChannelMap and MediaCheck work independently and contribute operation records. No existing source repositories were inspected for this specification; all integration points are proposed contracts.

## 2. Scope and user journey

1. Add selected folders or volumes without moving media.
2. Index file metadata and generate a bounded preview cache.
3. Browse recordings, search filenames/tags/technical properties and see file locations.
4. Disconnect a drive; continue browsing cached information with clear offline badges.
5. Attach related files manually or import a trusted operation record from another app.
6. Reconnect or locate a moved file; verify its identity before changing catalog relationships.
7. Export catalog metadata and back up the catalog independently of source media.

Example: a GoPro recording has two camera segments, a Conjoyn join, a proxy, a selected range in Penumbra and an extracted sound. VAM should show the relationship and the drive holding each file. It must not flatten all of these into duplicates or infer that any may safely be deleted.

## 3. MVP boundaries

Include folder/volume cataloging, thumbnails, metadata search, offline browsing, tags/notes, manual relationship creation, exact-copy verification, operation-record import, stale-source detection and catalog backup/restore.

Defer semantic AI search, face recognition, full transcription, waveform synchronization, automatic proxy generation, NLE project rewriting, cloud collaboration, destructive deduplication and a timeline editor. No always-on daemon is required. Background work is scoped to selected roots.

Start with imported or manually confirmed relationships. Similarity-based suggestions are phase two. No automatic grouping based only on matching filenames, durations, timestamps or camera IDs.

## 4. Core model: do not conflate these identities

| Entity | Meaning | Important fields |
|---|---|---|
| Recording | Logical captured event or take | UUID, title, notes, optional capture date and provenance |
| MediaObject | One immutable byte sequence, or a provisional object awaiting full verification | UUID, byte length, optional full SHA-256 digest, verification state |
| FileLocation | Where a MediaObject is believed to exist | UUID, volume reference, relative path, availability, observed size/mtime, last checked |
| Volume | An observed storage volume | local ID, OS identity hints, user label, last seen |
| Representation | A MediaObject’s role relative to a Recording | source segment, joined source, proxy, audio, export; provenance |
| Derivation | Directed transformation from input objects/ranges to output objects | operation ID/type, ordered inputs, outputs, settings, tool/version |
| Annotation | User or imported information | target ID, optional range, tags/rating/note, author/source |
| Analysis | Versioned technical findings | source object/snapshot, engine/rules, coverage, findings |

One object can have multiple locations. One recording can have multiple representations. An output compilation can involve multiple recordings. Filenames and path names are never globally unique IDs. Keep the schema capable of many-to-many relationships even if the first UI emphasizes simple cases.

Use source-qualified external IDs on import. A producer’s UUID is not silently treated as a VAM UUID. Full digest plus byte length can establish byte equivalence; partial hashes and metadata are candidate evidence only. A remux normally has a different file digest even when picture essence is unchanged.

## 5. Offline and moved-file behavior

Distinguish online, volume offline, file missing on an online volume, permission required, changed since indexed, and not yet checked. Unmounting a drive must not mark every file deleted.

On reconnect, compare stored volume identity hints and resolve accessible roots. Duplicate volume names are not sufficient. Cloned identifiers are possible: ambiguous matches require a user-selected root and verification.

After a path changes, offer candidate locations. A full verified digest match can add a location for the same object. Metadata-only matches remain suggestions. If bytes changed in place, preserve the old object and its annotations; create a new object/version relationship rather than rewriting history.

Do not follow symlink loops. Cloud placeholders remain unavailable until explicitly materialized. Handle network disconnections separately from missing local files. Never infer that an offline file is a valid backup merely because it was once cataloged.

## 6. UI

Sidebar: Library, Volumes, Collections, Needs attention. Main area: switchable recording grid and file table. Inspector: metadata, locations, related representations, analysis and operation history.

Search MVP: filename, user title, tags, camera metadata where available, codec, dimensions, frame rate, duration, date and volume. Dates show provenance: file creation time is not automatically capture time. Saved filters are sufficient; no AI search promise.

An offline item can display cached thumbnails and metadata, but playback is available only if an accessible playable representation exists. Show whether the preview is an original or proxy. Scrubbable offline proxies are an optional later feature because they add generation time and storage.

Relationship actions are reversible catalog edits. Reject derivation cycles. Support ordered source segments and explicit ranges. Display uncertain associations separately from confirmed relationships.

## 7. Shared interchange envelope v0.1

Use a UTF-8 JSON document, optionally paired with preview attachments. Each app can write and read documents without a shared running service. Do not share a mutable SQLite file between applications.

Required top-level fields: `schemaVersion`, `producer` (app and version), `operationId`, `operationType`, `createdAt`, `inputs`, `outputs`, `parameters`, `outcome`. Operation IDs are stable across retries of the same finalized record. Successful output records refer only to validated, published files.

Illustrative minimal successful export record:

```json
{
  "schemaVersion": "0.1",
  "producer": {"app": "ChannelMap", "version": "0.1.0"},
  "operationId": "40cf6680-ce7f-48ef-9c90-9b14c3adb8fa",
  "operationType": "audio.channel_export",
  "createdAt": "2026-10-15T19:00:00Z",
  "inputs": [{
    "externalId": "source-1",
    "locator": {"relativePath": "Camera/A001.mov", "rootLabel": "Shoot SSD"},
    "snapshot": {"sizeBytes": 123456, "modifiedAt": "2026-10-15T12:00:00Z"},
    "digest": null
  }],
  "outputs": [{
    "externalId": "output-1",
    "locator": {"relativePath": "Audio/A001-Boom.wav", "rootLabel": "Working SSD"},
    "snapshot": {"sizeBytes": 65432, "modifiedAt": "2026-10-15T19:00:00Z"},
    "digest": null
  }],
  "parameters": {"inputStreamIndex": 1, "channelIndices": [0], "audioCodec": "pcm_s24le"},
  "outcome": {"status": "completed", "validation": "decoded-output-checked"}
}
```

Numbers and identifiers above are illustrative. Null digest means no byte-identity claim. A real digest has algorithm, full-versus-partial scope and value. Root labels are hints, not volume identity. Users map imported roots to accessible locations; no security-scoped bookmarks or private absolute paths are required in portable exports.

Represent time ranges as start/duration rational pairs with explicit origin and source stream; define ranges as half-open. Preserve source timestamps and frame rates exactly rather than using rounded decimals. Analysis extensions carry coverage, rule versions and findings. Annotations retain their producer and external IDs.

Importer requirements: size limits, schema validation, safe path handling, no execution of embedded commands, no automatic access outside approved roots, transactional writes and idempotency by producer plus operationId. Reject unsupported major versions; tolerate unknown optional fields without discarding them on export. If an already imported operation ID arrives with changed content, flag a conflict instead of silently replacing history.

Finalize a formal JSON Schema with fixtures before implementing integration in a second application. The envelope is a proposal, not an existing standard.

## 8. Architecture and persistence

Proposed platform: Swift/SwiftUI, Apple Silicon/macOS 26+, SQLite with full-text indexing and a versioned migration layer. Confirm against existing app choices. Store the active database on local storage; use database-safe snapshot backups rather than copying a live database incompletely.

Separate CatalogStore, IndexingCoordinator, MediaProbe, PreviewCache, LocationResolver, RelationshipService and InterchangeImporter. Pin media backends behind adapters. Generate thumbnails asynchronously; cache by object and generator version, with a user-visible size limit and eviction policy. Never evict source media.

Keep annotations and operations separate from regenerable previews. Record access permissions locally with security-scoped bookmarks where required. Filesystem identifiers are useful hints, not permanent cross-volume identities. [S1]

**Distribution:** direct download, Developer ID signed and notarised; the Mac App Store is not a goal, so no App Sandbox is required.

The initial integration shares schemas and value types. Extract processing packages only after two real consumers justify them; do not delay VAM for a speculative universal media framework.

## 9. Acceptance criteria

- Index 10,000 synthetic catalog entries; indexed searches return their first page within 300 ms on the named development machine after warm-up. This is a provisional engineering target, not a marketing guarantee.
- Disconnect a cataloged drive: all cached records remain searchable and receive offline rather than deleted status.
- Reconnect two same-named drives: no automatic cross-assignment of media.
- Move a known file: verified digest resolution reconnects it without losing tags or history.
- Replace bytes at the same path: old analysis is not applied to the new object.
- Import an operation record twice: only one operation/relationship set exists.
- Import a proxy relationship without a digest: preserve its declared provenance and provisional identity rather than marking byte verification complete.
- Model two segments joined into one output: input order and source ranges survive export/import.
- A proposed relationship cycle is rejected with an understandable message.
- Interrupted indexing preserves committed records and resumes safely.
- Catalog backup restored on a clean installation preserves tags, relationships and IDs; missing root permissions can be re-established.
- Deleting a catalog entry does not delete media. No source-file deletion feature ships in this MVP.

## 10. Milestones

1. Catalog vertical slice: choose folder, probe, thumbnails, SQLite storage and offline browsing.
2. Identity slice: objects versus locations, full verification on request and changed-file handling.
3. Relationship slice: manual recording grouping, source/proxy/derived roles and ordered joins.
4. Integration slice: JSON Schema, ChannelMap/MediaCheck imports and Penumbra annotation adapters once their real formats are inspected.
5. Reliability slice: backup/restore, migrations, interruption tests, scale measurement and accessibility.

Prefer completing milestone 1 early while ChannelMap is developed. ChannelMap need not wait for VAM. MediaCheck can initially export the same standalone reports consumed later by VAM.

## 11. Sources and unresolved decisions

- S1 — Apple sandbox file access
- S2 — NeoFinder offline previews and video thumbnails
- S3 — EditReady Server asset-manager workflow

Checked 15 October 2026. Existing offline catalog functionality means VAM’s hypothesis is the combination of video-specific relationships and this portfolio’s workflow history, not novelty of offline catalogs.

Decisions to validate during development: existing MediaIngest/Penumbra identifiers and schemas; ~~direct distribution versus App Store~~ *(decided 15 October 2026: notarised direct distribution, no Mac App Store)*; actual camera format corpus; catalog packaging and backup UI; thumbnail storage budget; whether reference media changes in place in the user’s real workflow. These are implementation gates, not reasons to block the first catalog prototype.
