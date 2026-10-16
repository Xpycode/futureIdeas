# Website portfolio scan — 2026-10-16

Read-only local source and documentation scan of `3-Websites` and selected `8-PublishingMarketing` documents. No live-site checks, browser/app operation, deployment, or portfolio modification. “Live” below means recorded in project documentation, not independently reverified today. This is opportunity discovery, not market validation. Source paths are relative to `/Users/sim/ProgrammingProjects/`; line numbers identify the inspected evidence. Runtime media, personal records and credentials were not inspected.

## Portfolio and maturity

| Project | Purpose and documented position | Evidence |
|---|---|---|
| KinoBerlin | Cinema discovery with language/format/time filtering; live site, some device acceptance outstanding | `3-Websites/KinoBerlin/docs/PROJECT_STATE.md:7–20` |
| TheaterB | Theatre/opera discovery by production/date/venue/district; recorded live, latest state still calls for data refresh | `3-Websites/TheaterB/docs/PROJECT_STATE.md:7–22` |
| Offene Türen | Berlin-area open-day discovery; local working slice, two adapters, deployment pending | `3-Websites/OffeneTuerenBerlinUndUmgebung/docs/PROJECT_STATE.md:7–24` |
| PDF2Calendar | Department schedule PDF → calendar files; recorded live/maintenance | `3-Websites/PDF2Calendar/docs/PROJECT_STATE.md:7–17` |
| PRIVAT | Password-protected event photo/video sharing; video deployed, real-file acceptance pending | `3-Websites/PRIVAT/docs/PROJECT_STATE.md:7–24` |
| LUCESUMBRARUM | Photography portfolio and album administration; redesign recorded live, admin acceptance outstanding | `3-Websites/LUCESUMBRARUM/docs/PROJECT_STATE.md:8–21` |
| MacroPorn | Macro-nature video catalog and creator studio; local studio complete, curation/hosting pending | `3-Websites/MacroPorn/docs/PROJECT_STATE.md:4–17` |
| App-Websites | Shared app marketing/download sites; six published sites recorded, Penumbra preview-only, release acceptance follow-ups | `3-Websites/App-Websites/docs/PROJECT_STATE.md:6–24` |
| Bookmarks | Self-hosted visual bookmark dashboard; recorded live, tags/search improvements remain | `3-Websites/Bookmarks/docs/PROJECT_STATE.md:7–50` |
| Homepage | Local browser start page, cards/notes/JSON import-export; scaffold with favicon/default-content gaps | `3-Websites/Homepage/docs/PROJECT_STATE.md:6–37` |
| Colors | Accessible paired light/dark palette derivation; actual mathematical model built, UI/exporters still pending | `3-Websites/Colors/docs/PROJECT_STATE.md:7–27,50–55` |
| PhoneticAlphabet | Local multilingual spelling presenter; developed local tool, publication decision pending | `3-Websites/PhoneticAlphabet/docs/PROJECT_STATE.md:5–17,40–63` |
| MaskTaster | Interactive Taskmaster score rearrangement/simulation; records publication owner-confirmed, alternate scoring awaiting review | `3-Websites/MaskTaster/CLAUDE.md:1–16`; `docs/PROJECT_STATE.md:15–25` |
| MilkyWay | Interactive source-derived science-fiction atlas; implementation with visual acceptance outstanding | `3-Websites/MilkyWay/PROJECT_STATE.md:3–16` |
| SolarEntry | 3D orbital-approach sandbox; exploratory local prototype, hosting blocked | `3-Websites/SolarEntry/PROJECT_STATE.md:3–15` |

`LUmain` was encountered but not deeply inspected. Several old CLAUDE summaries contradict newer PROJECT_STATE records: particularly App-Websites releases and Colors implementation. Prefer newer state and actual source; none of these status labels establishes current production availability or demand.

## Reuse for the five media candidates

| Candidate | Existing asset and concrete use | Reuse boundary / missing work |
|---|---|---|
| **ChannelMap** | PRIVAT’s helper enumerates all audio streams, reports incompatible codecs and explicitly maps all audio during copying. Borrow inspection/error-language patterns and use representative owner-approved input files for compatibility tests. | No per-channel audition, channel map UI or PCM channel routing was found in inspected website source. Stream mapping is not channel mapping. |
| **MediaCheck** | PRIVAT already implements browser-delivery rules: one video, H.264, conservative pixel formats, HDR rejection, AAC audio. MacroPorn has another H.264/AAC import gate. Turn these into a first named, explainable delivery preset; reuse KinoBerlin’s structured issue/change-alert approach. | These are destination-specific restrictions, not universal media defects. No black-frame, clipping, silence, corruption or drift detector is established by these files. |
| **VAM Core** | MacroPorn supplies content hashing, repeat-import detection, copy verification, thumbnail generation, SQLite metadata and draft/published curation. PRIVAT and the photo portfolio provide real examples of originals versus prepared/published assets. | MacroPorn catalogs copied browser exports, not offline removable-drive originals. Need stable asset/volume identity, source→derivative relationships, relocation and missing-volume states. Its truncated hash identifier is not a finished global identity model. |
| **SoundHarvest** | MacroPorn’s import→preview→title/category→publish workflow is a close curation analogue. Its source verification and stable duplicate-import checks transfer conceptually to audio excerpts; parent recording + in/out times should become first-class provenance. | Website code does not provide sound-event segmentation, audio embedding/search, waveform editing or audio-excerpt extraction. A local vision pilot is a documented experiment, not a ready audio understanding engine. |
| **DriftCheck** | PRIVAT provides stream metadata intake and a safe output-staging pattern; KinoBerlin demonstrates presenting diagnostic evidence and separating logging from interruptions. | Weak direct reuse: none of these website projects establishes correlation, reference alignment, resampling estimation or clock-drift measurement. New DSP and ground-truth fixtures remain the core work. |

### Source-validated components

1. **Compatibility and preparation:** `3-Websites/PRIVAT/03_Scripts/video-prep/prepare.py:41–64` implements ffprobe inspection and codec/pixel/HDR/audio checks. `:109–152` creates a fresh temporary output, copies video/audio with `-c copy`, applies `+faststart`, reinspects the result, makes an aspect-preserving poster, checks source size/mtime and only then moves completed files into the upload folder. It explicitly omits ancillary streams such as timecode/subtitles; do **not** inherit that policy for archival or ChannelMap work. It is a narrow sharing helper, not a preservation engine.
2. **Catalog ingestion:** `3-Websites/MacroPorn/03_Scripts/import-media.py:16–33` calculates full SHA-256, derives a 24-character ID and checks existing imports. `:36–79` validates metadata, generates a thumbnail, copies the file, verifies both source and destination, and transactionally inserts a draft record. `3-Websites/MacroPorn/01_Project/lib/bootstrap.php:60–71` establishes the SQLite videos/settings tables. These implementations exist; no extraction/porting or runtime test was performed today.
3. **Diagnostic reporting:** `3-Websites/KinoBerlin/scripts/health_report.py:1037–1066` fingerprints check name/status/details, excluding fluctuating prose counts. `:1111–1154` decides notification once and logs unchanged failures too. Useful design precedent for MediaCheck batch history; cinema thresholds themselves have no media-QC meaning.
4. **Shared visual foundation:** `3-Websites/Colors/js/color.js:196–218,302–379` implements seed conversion, gamut mapping, ramp and paired-scheme derivation. `docs/PROJECT_STATE.md:50–55` explicitly says exporters and UI remain unwritten. Helpful to all five tools’ readable light/dark diagnostics, but exporting Swift colors still requires finishing or adapting the work.

## New opportunities suggested by existing work

These are proposals derived from portfolio overlap, not proof of market demand.

1. **Delivery preflight — a MediaCheck preset first.** “Will this recording work on my sharing site, and what exactly needs changing?” Start with read-only reports for PRIVAT/MacroPorn; offer handoff to an existing remux tool only when appropriate. Both sites already enforce concrete rules, so this can be tested against real rejection cases without inventing a sixth large media app. Validate with a small owner-approved set of accepted/rejected clips.
2. **Culture planner — extend the existing discovery sites.** Save an evening shortlist across cinema/theatre/open days and export chosen events to a calendar. KinoBerlin has actual time/attribute filtering (`frontend/src/lib/filters.ts:56–141`); TheaterB groups by production/venue/district/date (`frontend/src/lib/data.ts:85,159,192,256`); Offene Türen loads/filters/groups dated events (`01_Project/lib/events.php:27,104,136,151`). The data producers exist, but there is no demonstrated unified identity model or cross-site planner. First experiment: a local shortlist over one source, without new scraping or user accounts.
3. **Schedule-change detector — a PDF2Calendar extension.** Compare this month’s revised roster with the previous upload: added/removed/moved shifts, reviewed before calendar updates. Configurable table structure inference and extraction exist (`3-Websites/PDF2Calendar/01_Project/parsers/configurable.py:13–100`), as do calendar-generation and preview endpoints (`routes/calendar.py:35,85,132,166`). Stable event identity, revision comparison and conflict handling are new work; do not assume repeat imports update existing calendar events safely.
4. **Accessible palette workbench — finish Colors.** Show a real macOS-style window in both themes, highlight contrast issues and export usable tokens. The core math is implemented and documented as tested; the missing work is productization, not a new engine. Validate by applying one generated scheme to an existing app before broadening into a design-suite product.
5. **Publication readiness dashboard — internal tool first.** Combine release artifact/version, screenshot readiness, pending user acceptance and site-copy consistency. The publishing workspace explicitly describes release last-mile as the bottleneck (`8-PublishingMarketing/README.md:8–12`), while its September portfolio snapshot differs from App-Websites’ October state. A small evidence-linked checklist could reduce stale claims. No new external status-monitor service is justified yet.

## Distribution and audience implications

- PRIVAT/MacroPorn/photo publishing are practical owner workflows for testing media preparation and catalog provenance. They do not establish an external paying audience.
- Cinema/theatre audiences are primarily consumers of cultural listings; assuming they convert to professional media-tool customers would be weak. Cross-promotion should be measured and relevant.
- Existing App-Websites infrastructure and publishing playbooks are useful launch scaffolding for every candidate. They do not remove capture, accurate claims, licensing, runtime acceptance or distribution work.
- No traffic totals, revenue, conversion rates, competitor comparisons or market-size conclusions were established by this scan.

## Suggested next decision

For media, test **MediaCheck’s delivery preflight** and **VAM’s original→derivative→published provenance** against existing workflows before widening scope. For non-media, compare **PDF schedule revisions** with **culture shortlists** using one concrete task each. Keep Colors and release-readiness tooling as finishing/reuse opportunities rather than automatically opening more projects.
