# QC Checker — Product & Technical Spec

**Working title:** TBD
**Platform:** macOS 14+, SwiftUI, Apple Silicon + Intel
**Category:** Video
**One-liner:** Check video files against a delivery spec, including loudness, and get a pass/fail report.

---

## 1. Problem & audience

Editors, freelancers, small post houses and broadcast staff need to confirm a file meets a delivery spec before sending it. Today that means MediaInfo plus manual comparison, or expensive pro QC suites (Baton, Vidchecker, Aurora). Loudness rejections are the most common failure.

**Target users:** freelance editors, YouTube/streaming creators delivering to clients, broadcast operators, small post facilities.

**Positioning:** "MediaInfo with a verdict." Fast, local, affordable, with a report you can send to a client.

---

## 2. Scope

### MVP (v1.0)
- Drag & drop files or folders (recursive) into a queue.
- Select a **spec preset** (built-in or user-made).
- Run **metadata checks** (container, video, audio, duration).
- Run **loudness measurement** (EBU R128 / ITU-R BS.1770-4) as a check.
- Per-file result: **Pass / Warn / Fail / Error**, with per-check detail.
- **Preset editor** (create, duplicate, edit, import/export as JSON).
- **Export report:** PDF (client-facing), CSV and JSON (machine-readable).
- Cancel, progress per file, configurable concurrency.

### v1.x / v2
- Content checks: black frames, frozen frames, digital silence (head/tail and anywhere), plus audio phase/mono check.
- Watch folder mode.
- Loudness graph (short-term / momentary over time) in the detail view and PDF.
- CLI companion (`qc check --preset x.json file.mxf`) for automation.
- Quick Look / Finder extension "Check with…".

### Non-goals
- No correction/transcoding (except possibly a later loudness gain-only fix; out of scope here).
- No cloud processing, no account system.
- No full broadcast-grade QC (e.g. PSE flash testing, gamut legality); possibly later.

---

## 3. Architecture

| Layer | Choice | Notes |
|---|---|---|
| UI | SwiftUI | Main window, preset editor sheet, settings |
| Metadata | Bundled `ffprobe` (LGPL build) | `-show_streams -show_format -of json`; also needed for MXF/P2 support beyond AVFoundation |
| Audio decode | Bundled `ffmpeg` → raw float32 PCM via pipe | `-map 0:a:N -f f32le -ac <n> -ar <native> -` |
| Loudness | Native Swift implementation of BS.1770-4 + EBU Tech 3342 (LRA) | Or libebur128 (MIT) via C module. Native is preferred for control; see §6 |
| Content checks (v2) | ffmpeg filters `blackdetect`, `freezedetect`, `silencedetect`, `idet` | Parse stderr |
| Presets | JSON files in Application Support | Codable model, versioned schema |
| Reports | PDF via PDFKit / Core Graphics render of a SwiftUI view; CSV; JSON | |

**Concurrency:** Swift concurrency with a configurable max parallel jobs (default: 2). Each file is a job; loudness decode is the expensive part. Subprocesses must be cancellable (terminate on cancel).

**Distribution:** direct download, Developer ID signed and notarised. Mac App Store is not a goal, so no App Sandbox is required. Bundled `ffmpeg`/`ffprobe` helpers must be signed with hardened runtime and included in notarisation.

---

## 4. Data model

```swift
struct SpecPreset: Codable, Identifiable {
    var id: UUID
    var schemaVersion: Int          // start at 1
    var name: String
    var notes: String?
    var checks: [CheckRule]
    var audioTracksToMeasure: AudioSelection   // which tracks/channels form the programme mix
    var loudness: LoudnessTarget?   // nil = loudness not checked
}

struct CheckRule: Codable, Identifiable {
    var id: UUID
    var checkID: CheckID            // see catalog §5
    var condition: Condition        // equals, oneOf, range, min, max, exists, notExists
    var severity: Severity          // .fail or .warn when violated
    var enabled: Bool
}

enum Verdict { case pass, warn, fail, error, skipped }

struct CheckResult {
    var checkID: CheckID
    var verdict: Verdict
    var expected: String            // human-readable rule
    var actual: String              // human-readable measured value
    var message: String?
}

struct FileReport {
    var url: URL
    var preset: SpecPreset
    var results: [CheckResult]
    var overall: Verdict            // worst of results, error > fail > warn > pass
    var probeJSON: Data             // raw ffprobe output, kept for JSON export/debug
    var loudness: LoudnessResult?
    var startedAt, finishedAt: Date
}
```

**Overall verdict:** the worst result wins (`error` > `fail` > `warn` > `pass`). `skipped` is ignored.

---

## 5. Check catalog (MVP)

All values come from ffprobe JSON unless noted. "Track" = audio stream index within the file.

### Container / file
| checkID | Source | Typical rule |
|---|---|---|
| `container.format` | `format.format_name` | oneOf [mov, mxf, mp4] |
| `container.mxfOperationalPattern` | `format.tags` / probe | equals OP1a |
| `file.duration` | `format.duration` | range (e.g. 00:29:30–00:30:00) |
| `file.timecodeStart` | `tags.timecode` (format or tmcd stream) | equals 10:00:00:00 |
| `file.hasTimecode` | presence of tmcd/timecode | exists |

### Video (first video stream unless configured)
| checkID | Source | Typical rule |
|---|---|---|
| `video.codec` | `codec_name` | oneOf [prores, dnxhd, h264, hevc, mpeg2video, xdcam…] |
| `video.profile` | `profile` | e.g. "ProRes 422 HQ" / "XDCAM HD422" |
| `video.resolution` | `width`×`height` | equals 1920×1080 |
| `video.frameRate` | `r_frame_rate`, `avg_frame_rate` | equals 25 / 29.97 / 50 |
| `video.vfr` | compare r vs avg frame rate | must be constant (warn if differ) |
| `video.scanType` | `field_order` | equals tt / progressive |
| `video.pixelFormat` | `pix_fmt` | oneOf [yuv422p10le …] |
| `video.bitDepth` | derived from `pix_fmt` / `bits_per_raw_sample` | min 10 |
| `video.bitrate` | `bit_rate` (stream or format fallback) | range |
| `video.colorPrimaries` | `color_primaries` | equals bt709 |
| `video.colorTransfer` | `color_transfer` | equals bt709 |
| `video.colorMatrix` | `color_space` | equals bt709 |
| `video.colorRange` | `color_range` | equals tv (limited) |
| `video.displayAspect` | `display_aspect_ratio` | equals 16:9 |

### Audio
| checkID | Source | Typical rule |
|---|---|---|
| `audio.trackCount` | number of audio streams | equals 4 / min 1 |
| `audio.channelsPerTrack` | `channels` per stream | equals 2 (or per-track list) |
| `audio.totalChannels` | sum | equals 8 |
| `audio.codec` | `codec_name` | oneOf [pcm_s24le, pcm_s16le, aac] |
| `audio.sampleRate` | `sample_rate` | equals 48000 |
| `audio.bitDepth` | `bits_per_raw_sample` / codec | equals 24 |
| `audio.channelLayout` | `channel_layout` | e.g. stereo / 5.1 (warn only; often untagged) |

### Loudness (see §6)
| checkID | Rule |
|---|---|
| `loudness.integrated` | target ± tolerance (LUFS) |
| `loudness.truePeak` | max (dBTP) |
| `loudness.lra` | max (LU), optional |
| `loudness.maxShortTerm` | max (LUFS), optional (e.g. ads) |
| `loudness.maxMomentary` | max (LUFS), optional |

### v2 content checks
`content.blackHead`, `content.blackTail`, `content.blackAnywhere` (min duration), `content.freeze`, `content.silenceAnywhere`, `content.silenceHead/Tail`, `audio.phase` (correlation per stereo pair).

**Missing data rule:** if a field is absent in the probe, the result is `warn` with "not reported by file", unless the rule is `exists` (then `fail`).

---

## 6. Loudness measurement

### Standard
- **ITU-R BS.1770-4** for integrated loudness and true peak.
- **EBU Tech 3341** for momentary (400 ms) and short-term (3 s) loudness.
- **EBU Tech 3342** for LRA.

### Algorithm (native implementation)
1. Decode the selected audio to float32 at native sample rate (ffmpeg pipe), with channels in a known order.
2. **K-weighting:** two-stage biquad (high-shelf "pre-filter" + RLB high-pass). Coefficients must be **recomputed for the actual sample rate** (do not hardcode 48 kHz values only).
3. Mean square per channel over **400 ms blocks with 75 % overlap** (100 ms hop).
4. **Channel weights:** L, R, C = 1.0; Ls, Rs = 1.41; **LFE excluded**.
5. Block loudness: `-0.691 + 10·log10(Σ Gᵢ·zᵢ)`.
6. **Gating:** absolute gate −70 LUFS → compute ungated mean → relative gate −10 LU → integrated = mean of blocks passing both.
7. **LRA (Tech 3342):** short-term 3 s windows, absolute gate −70 LUFS, relative gate −20 LU, LRA = 95th − 10th percentile.
8. **True peak:** 4× oversampling (polyphase FIR interpolation, BS.1770 Annex 2 style) per channel, max absolute sample → dBTP. For 96 kHz+ input, 2× is acceptable.
9. Keep momentary and short-term series for v2 graphs.

**Validation:** must match the EBU Tech 3341/3342 compliance test set (EBU test files) within ±0.1 LU and true peak within the tolerance given there. Include these as unit/integration tests.

### Programme selection (`AudioSelection`)
Which audio forms the "programme" varies by file:
- `track(n)`: one multichannel stream (e.g. track 1 stereo).
- `channels([(track, channel)…], layout)`: assemble from mono tracks (common in MXF: tracks 1+2 = L/R).
- `eachTrack`: measure every track separately (report all; check uses the worst or a designated one).

Default: first audio track, interpreted by its channel count (1 = mono, 2 = stereo, 6 = 5.1 in L R C LFE Ls Rs order).

### Built-in loudness targets
| Preset | Integrated | Tolerance | True peak max | Notes |
|---|---|---|---|---|
| EBU R128 (broadcast) | −23 LUFS | ±0.5 LU (file-based) | −1 dBTP | |
| EBU R128 S1 (ads/short-form) | −23 LUFS | ±0.5 LU | −1 dBTP | + max short-term −18 LUFS |
| ATSC A/85 (US) | −24 LKFS | ±2 LU | −2 dBTP | |
| Streaming −14 | −14 LUFS | ±1 LU | −1 dBTP | YouTube/Spotify-style; warn-level |
| Streaming −16 | −16 LUFS | ±1 LU | −1 dBTP | Apple-style; warn-level |

All values must be editable in the preset; these are only defaults. Verify current figures against the source documents before shipping.

---

## 7. Built-in spec presets (starting set)

Ship 4–6 generic, clearly labelled examples. Do **not** name them after broadcasters or platforms unless the values are verified against their current published specs.

1. **HD Broadcast Master (25i)**: MXF OP1a or MOV, XDCAM HD422 50 Mbit or ProRes 422 HQ, 1920×1080, 25 fps, top-field-first, BT.709, 8 or more mono PCM tracks at 24-bit / 48 kHz, EBU R128.
2. **HD Progressive Master (25p / 50p)**: as above, progressive.
3. **ProRes Mezzanine (any rate)**: ProRes 422 HQ, 10-bit, BT.709, PCM 24/48, no loudness check.
4. **Web Delivery H.264**: MP4, H.264 High, 1080p, CFR, AAC 48 kHz stereo, −14 LUFS (warn).
5. **Loudness only (R128)**: no metadata checks, loudness only.

---

## 8. UI

### Main window
- **Toolbar:** preset picker, "Check" button, "Export report", concurrency setting (or in Settings).
- **Left/main: file list table** with columns for status icon, file name, duration, codec, resolution, fps, integrated LUFS, true peak, and overall verdict. Sortable; filter by verdict.
- **Detail pane** (selected file): grouped check results (Container / Video / Audio / Loudness) with expected vs actual, coloured verdict, and a "Show raw probe" disclosure.
- **Empty state:** drop zone with short explanation.
- Re-check selected or all after changing the preset (results cached per file + preset hash).

### Preset editor (sheet)
- List of checks grouped by category; each row has enable toggle, condition editor (picker for operator, value fields), and severity (Fail/Warn).
- Loudness section: target, tolerance, true peak max, optional LRA / short-term / momentary max, and audio selection.
- Duplicate, rename, delete, import/export JSON.

### Status presentation
- Pass = green check, Warn = yellow, Fail = red, Error = grey/exclamation.
- The app icon badge / Dock progress shows the number of files remaining.

---

## 9. Report output

### PDF (client-facing)
- Header: app name, report date/time, preset name, machine/user (optional toggle), and an optional logo/name field from Settings ("Prepared by").
- Summary table: one row per file with its overall verdict.
- Per-file page/section: file metadata summary, check table (check / expected / actual / verdict), and loudness numbers (integrated, TP, LRA, max ST, max M). v2 adds a loudness graph.
- Footer: page numbers and the measurement standard used ("Loudness measured per ITU-R BS.1770-4 / EBU R128").

### CSV
One row per file × check: `file, check, expected, actual, verdict, message`. Plus a summary CSV option with one row per file.

### JSON
The full `FileReport` array including raw probe data, for automation.

---

## 10. Edge cases

- **MXF with many mono tracks:** handle 8–16 audio streams. Loudness selection must allow mapping mono tracks into a stereo or 5.1 programme.
- **Interlaced metadata missing/unknown:** `field_order` missing gives a warn; v2 can use `idet` to detect actual content.
- **VFR files** (phone footage): flag r_frame_rate vs avg_frame_rate mismatch.
- **Drop-frame timecode** (29.97 DF): parse `;` separator correctly.
- **Very long files** (multi-hour): stream audio, never load it fully into memory. Show loudness progress.
- **Unreadable / corrupt file:** verdict `error` with the ffprobe/ffmpeg stderr excerpt.
- **Audio-only files** (WAV, BWF): allow; video checks get `skipped`.
- **Files with no audio:** loudness check gets `fail` or `skipped` depending on preset ("audio required" flag).
- **Silence-only audio:** integrated loudness below the gate gives "−∞ / below gate". Treat as fail for loudness targets.

---

## 11. Performance targets

- Metadata checks: < 1 s per file.
- Loudness: at least 20× realtime for stereo PCM on Apple Silicon (a 1 h file in under 3 min); decode is the bottleneck, DSP should be vectorised (Accelerate/vDSP).
- UI stays responsive with 500+ files queued.

---

## 12. Acceptance criteria (MVP)

1. Dropping a folder of mixed MOV/MXF/MP4 files lists all supported files, with unsupported files shown as `error` and a clear message.
2. Every catalog check in §5 (MVP) produces a correct verdict on the test asset set (§13).
3. Loudness matches EBU Tech 3341/3342 test files within the stated tolerances.
4. A preset can be created, edited, exported as JSON, deleted, re-imported, and gives identical results.
5. The PDF report renders correctly for 1 file and for 100 files (pagination), and CSV/JSON exports parse cleanly.
6. Cancel stops all subprocesses within 1 s; no orphaned ffmpeg processes remain.
7. Works fully offline, with no network calls.

---

## 13. Test assets needed

- EBU loudness test set (Tech 3341/3342 compliance files).
- XDCAM HD422 MXF OP1a, 25i, 8 mono PCM tracks.
- ProRes 422 HQ MOV, 25p, one stereo track plus timecode.
- H.264 MP4 from a phone (VFR, AAC).
- 29.97 DF file with timecode.
- File with missing colour tags.
- Truncated/corrupt file.
- WAV/BWF audio-only.

---

## 14. Open questions

1. App name.
2. ffmpeg bundling: reuse the build/config from P2toMXF / VideoContainerSwitcher?
3. Native loudness vs libebur128: native preferred, libebur128 as reference for tests?
4. Pricing: one-time purchase vs free basic version + paid reports/presets?
5. Should loudness be sold as a separate lite app later (same engine)?
