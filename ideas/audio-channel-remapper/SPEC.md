# Audio Channel Remapper — Product & Technical Spec

**Working title:** TBD
**Platform:** macOS 14+, SwiftUI, Apple Silicon + Intel
**Category:** Video
**One-liner:** Reroute, reorder, split and merge audio channels in video files, without re-encoding the video.

---

## 1. Problem & audience

Audio tracks often arrive in the wrong layout: stereo where the delivery spec wants mono tracks, channels swapped, M&E on the wrong tracks, an empty channel where the mix should be. Fixing it today means an NLE round trip (re-rendering video) or hand-writing ffmpeg `-filter_complex` lines.

**Target users:** editors, broadcast operators, archive/ingest staff, and creators with camera files (e.g. a lav mic on channel 2 only).

**Positioning:** a visual routing matrix. The video is always untouched; audio is untouched wherever possible, and losslessly rewritten where needed.

---

## 2. Scope

### MVP (v1.0)
- Open/drop one or more files (MOV, MP4, MXF OP1a; also WAV/BWF).
- Show all **source channels** (track × channel), with labels and per-channel level indicator from a quick scan.
- Define the **output layout**: number of output tracks, channels per track.
- **Routing matrix**: each output channel is fed by exactly one source channel or silence.
- **Channel layout labels** on output tracks (mono, stereo, 5.1 and so on).
- **Presets**: save/load routing + output layout; built-in common presets.
- **Batch**: apply a preset to many files; files whose source layout doesn't fit get flagged and skipped.
- Video stream(s), timecode and metadata are always copied unchanged.
- **Post-write verification** that video is bit-identical (see §7).

### v1.1
- **Solo-listen** a source channel (plays a short excerpt) to identify what's on it.
- Per-route **gain** (dB) and **polarity invert**.
- Waveform thumbnails per source channel.

### v2
- **Summing / downmix**: multiple sources into one output channel (e.g. stereo to mono, 5.1 to stereo with standard coefficients).
- Track **naming/language tags** (`handler_name`, `language`).
- Sync offset per track (ms).

### Non-goals
- No video processing of any kind.
- No audio effects beyond gain/polarity (no EQ, no loudness normalisation; that's the QC app's territory).

---

## 3. Core rule: what gets re-encoded

The app must make this explicit in the UI before export.

| Situation | Action | Lossless? |
|---|---|---|
| Video stream(s) | Always stream copy | Yes |
| Output track identical to a source track (same channels, same order, no gain) | Stream copy | Yes |
| Source is PCM and the output track differs | Rewrite as PCM, **same bit depth and sample rate** | Yes (sample-exact) |
| Source is compressed (AAC, AC-3…) and the output track differs | Re-encode audio. Default: same codec, same or higher bitrate; offer "Output PCM instead" | **No**; show a warning badge |
| Mixed sources (PCM + AAC) into one track | Treat as compressed case | Warning |
| Gain ≠ 0 dB on PCM (v1.1) | Rewrite PCM; use 32-bit float internally, dither to 24/16 if needed | Effectively lossless at 24-bit |

**UI:** each output track shows a badge: `Copy`, `Lossless rewrite`, or `Re-encode`. The export button summary repeats this ("Video: copied · Audio: 2 tracks copied, 1 rewritten losslessly").

---

## 4. Architecture

| Layer | Choice | Notes |
|---|---|---|
| UI | SwiftUI | Matrix grid, preset sheet, batch queue |
| Probe | Bundled `ffprobe` | Stream list, channels, layout, codec, bit depth, timecode |
| Write | Bundled `ffmpeg` (LGPL build) | Build the command from the routing model; see §5 |
| Level scan | ffmpeg `astats` per channel on a sample (e.g. first 5 min, or full file option) | Shows peak/RMS so empty channels are obvious |
| Solo-listen (v1.1) | ffmpeg extracts N seconds of one channel to temp WAV → AVAudioPlayer | |
| Presets | JSON in Application Support | Codable, versioned |

Reuse the ffmpeg bundling and process-runner code from VideoContainerSwitcher / Conjoyn / P2toMXF where possible.

---

## 5. Data model & ffmpeg mapping

```swift
struct SourceChannel: Hashable, Codable {
    var trackIndex: Int     // audio stream index (0-based among audio streams)
    var channel: Int        // channel within that stream (0-based)
}

struct OutputTrack: Codable, Identifiable {
    var id: UUID
    var layout: ChannelLayout       // .mono, .stereo, .surround51, .custom(n)
    var routes: [Route?]            // one per output channel; nil = silence
    var label: String?              // optional handler_name (v2)
}

struct Route: Codable {
    var source: SourceChannel
    var gainDB: Double = 0          // v1.1
    var invert: Bool = false        // v1.1
}

struct RemapPreset: Codable, Identifiable {
    var id: UUID
    var schemaVersion: Int
    var name: String
    var requiredSource: SourceSignature?   // e.g. "1×stereo" or "8×mono"; used to check batch compatibility
    var outputTracks: [OutputTrack]
}
```

### Command construction
- Always: `-map 0:v -c:v copy`, `-map 0:d? -c:d copy` (timecode/data tracks), `-map_metadata 0`, and preserve the start timecode (`-timecode` read from probe for MXF/MOV if not carried automatically).
- **Copy track:** `-map 0:a:N -c:a:K copy`.
- **Rebuilt track:** build in `-filter_complex` with `pan`, e.g.
  - Swap stereo: `[0:a:0]pan=stereo|c0=c1|c1=c0[out0]`
  - Mono from channel 2 of track 1: `[0:a:0]pan=mono|c0=c1[out1]`
  - Stereo from two mono tracks: `[0:a:0][0:a:1]amerge=inputs=2,pan=stereo|c0=c0|c1=c1[out2]`
  - Silence channel: feed from `anullsrc` with the matching sample rate/duration, or `pan` with `c1=0*c0`.
  - Gain/polarity (v1.1): `c0=-0.5*c1` etc. (gain as linear factor, negative for invert).
- Set the layout via `aformat=channel_layouts=stereo` (or `mono`, `5.1`) at the end of each chain.
- PCM output: `-c:a:K pcm_s24le` (or match source: `pcm_s16le`, `pcm_s32le`, `pcm_f32le`); keep sample rate.
- Write to a temp file in the destination folder, then atomically rename on success.

**Container constraints:**
- **MXF OP1a:** audio is typically mono PCM tracks; warn if the user builds multichannel tracks for MXF and offer "split into mono tracks". Validate that output stays OP1a-valid (test with the target ingest in mind).
- **MP4:** PCM support is limited; if PCM is needed, suggest MOV output, or default to AAC re-encode with a warning.
- **MOV:** everything allowed; write channel layout atoms.

---

## 6. UI

### Main window (single file or "template" file for batch)
- **Top:** file info (container, video codec/res/fps, duration, timecode).
- **Source panel (columns):** every source channel as a column: `T1·Ch1`, `T1·Ch2`, `T2·Ch1`… with codec badge and level meter (peak/RMS from scan; "silent" badge below −90 dBFS). v1.1 adds a solo-listen button.
- **Output panel (rows):** output tracks as row groups, each with a layout picker (mono/stereo/5.1), its channel rows labelled (L, R, C, LFE, Ls, Rs or Ch n), and a status badge (`Copy` / `Lossless rewrite` / `Re-encode`).
- **Matrix:** click a cell to route that source column to that output row (radio behaviour per row in MVP; checkboxes once summing exists in v2).
- **Buttons:** Add track, Remove track, "Reset to source layout", "Split all to mono", "Pair mono tracks into stereo".
- **Export bar:** destination (same folder / choose / ask), naming suffix (default `_remap`), overwrite policy, the re-encode summary line, and the Export button.

### Presets
- Sidebar or menu with built-ins and user presets. Save the current routing as a preset; import/export JSON.

### Batch mode
- Queue table: file, detected source signature, compatible? (✓ / ✗ with reason), status, result.
- Apply the selected preset to all compatible files; skip and flag others.

---

## 7. Verification (trust feature)

After each export:
1. ffprobe the output: same video stream count, codec, resolution, fps, duration (±1 frame), timecode start.
2. **Video integrity check:** compare `-f framemd5` (or `streamhash`) of the video stream from source and output. Default on; can be disabled for speed in Settings.
3. Audio: the number of tracks/channels matches the plan; copied tracks are hash-identical; for PCM rewrites, optionally verify sample-exactness per routed channel (hash of the extracted channel in source vs output).
4. Show "Verified ✓" per file, or an error with details. Never delete or overwrite the source unless explicitly enabled.

---

## 8. Built-in presets

1. **Swap L/R** (1× stereo to 1× stereo, swapped).
2. **Stereo → 2× mono** (track 1 split into tracks 1 and 2).
3. **2× mono → stereo** (tracks 1+2 merged).
4. **Left to both** (copy ch 1 to L and R; camera lav on ch 1).
5. **Right to both.**
6. **8× mono → 4× stereo** (pairs 1/2, 3/4, 5/6, 7/8).
7. **4× stereo → 8× mono.**
8. **Broadcast 8 ch layout:** T1/T2 = stereo mix L/R, T3/T4 = M&E L/R, T5–T8 = silence (user assigns sources).
9. **Drop all but track 1.**

---

## 9. Edge cases

- **Sample rate mismatch** between source tracks combined into one output: resample to the highest rate (or the preset's), and mark as rewrite.
- **Different track durations:** pad shorter audio with silence to the video duration; never truncate the video.
- **Untagged channel layouts:** infer from channel count; let the user override.
- **More than 16 tracks / 64 channels:** the matrix must scroll; performance stays fine.
- **Files with no video** (WAV/BWF): allowed; output a WAV/BWF and preserve BWF metadata (bext, timecode reference) where possible.
- **Variable/unknown bit depth on PCM:** read `bits_per_raw_sample`; default to 24-bit if unknown and warn.
- **Edit lists in MOV/MP4** (start offsets): preserve them; verify A/V offset in output equals source.
- **Insufficient disk space:** check estimated output size first.

---

## 10. Acceptance criteria (MVP)

1. For every built-in preset, output on the test assets matches the expected layout (verified by ffprobe and channel-hash comparison).
2. The video stream is bit-identical to the source in all cases (framemd5 equal).
3. PCM rewrites are sample-exact for routed channels (hash equal); silence channels are digital zero.
4. Timecode start and video duration are preserved for MOV and MXF.
5. Re-encode is never applied silently: the UI badge and export summary state it every time it occurs.
6. Batch: incompatible files are skipped with a clear reason; compatible ones succeed; cancel leaves no partial files (temp files cleaned).
7. Works fully offline.

---

## 11. Test assets needed

- MOV ProRes with 1× stereo PCM 24-bit plus timecode.
- MOV with 2× mono PCM.
- MXF OP1a XDCAM HD422 with 8× mono PCM.
- MP4 H.264 with 1× stereo AAC (re-encode path).
- Camera file with audio on channel 1 only (silence on 2).
- Multi-track file with 48 kHz + 44.1 kHz mix.
- BWF with bext timecode.
- File with an edit list / start offset.

---

## 12. Open questions

1. App name.
2. For MXF output: should the app enforce mono-track layout (most broadcast ingest expects it), or just warn?
3. AAC re-encode default: same bitrate as source or a fixed 320 kbps?
4. Should solo-listen move into MVP? It's very useful for identifying unknown channels.
5. Shared ffmpeg/probe framework with QC app and VideoContainerSwitcher as a Swift package?
