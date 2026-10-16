# ChannelMap B7.2 — synthetic MOV metadata

2026-10-16. **Bounded CLI experiment passed:** the tested source's rotation, color signalling and timecode survived numeric audio routing with copied video. No loss was observed among these measured fields. This is not a claim that arbitrary MOV metadata survives.

The [harness](experiments/channelmap/wider_metadata.py) and final [metadata-04 results](experiments/channelmap/metadata-04/results.json) use installed FFmpeg/FFprobe 9.0.1. Exact argv, stderr, tool digests, platform, harness snapshot and complete probes are retained in the evidence directory. Generated media lives in the private temporary directory recorded in results and may be removed by OS cleanup.

## Verified source and output

The generated source has 160×90 ProRes Proxy picture, 25 fps, two seconds, and eight-channel 48 kHz PCM24 audio lasting one second. The harness checks the finished source before routing, including decoded audio against independently generated integer bytes.

| Measurement | Source | Routed output |
|---|---|---|
| Display matrix | 90° rotation, full matrix retained | Identical matrix and rotation |
| Color primaries | BT.2020 | BT.2020 |
| Transfer | SMPTE ST 2084 (PQ) | SMPTE ST 2084 (PQ) |
| Matrix/range | BT.2020 nonconstant luminance / limited | Identical |
| Video timecode tag | `01:02:03:04` | Identical |
| `tmcd` track | One track, matching start code, two-second duration | Same measured fields and packet payload/timing |
| Video packets | 50 | All ordered payload hashes, sizes, rational PTS, DTS and durations identical |
| Selected audio | Channels 5 then 2, zero-based 4 and 1 | Two ordered mono tracks; all 48,000 samples per track exact |

The test pattern is assigned deliberately nondefault color signalling; it is not a calibrated HDR image or a validation of visual color correctness. Rotation is metadata, not rotated encoded pixels. FFmpeg automatically creates a timecode track from the retained video timecode tag even though the routing command maps only video and filtered audio; equality of the measured `tmcd` fields does not prove arbitrary original timecode-track atom preservation. MOV track IDs and container bytes are not promised identical.

## Negative controls and observed behavior

Three actual remuxed files exercise the comparator:

- Removing rotation with an input display-rotation override removes display-matrix side data. The comparator rejects it while all video payloads and packet times remain equal.
- Removing global/video metadata and disabling `tmcd` writing removes both the video timecode tag and timecode track. The comparator rejects both losses, while video payloads and packet times remain equal.
- The `prores_metadata` filter's named `unknown` values replace nondefault color signalling. FFprobe reports **reserved primaries, reserved transfer and GBR matrix**, with limited range retained. This is a loss/replacement of the intended signalling, not absence of every color field. The comparator rejects it. Video payload hashes change because encoded headers are edited; timing remains identical.

These controls demonstrate that packet identity alone would miss rotation and timecode loss. They do not establish every possible metadata failure mode.

## Retained investigation history

[metadata-01](experiments/channelmap/metadata-01/results.json) failed the strict finished-source assertion: encoder flags alone did not produce the required complete color signalling after the rotation remux. No routing claim rests on that fixture. The corrected source explicitly sets ProRes header values and container color flags, then verifies the final file.

[metadata-02](experiments/channelmap/metadata-02/results.json) passed positive routing but failed an overly strong negative-control expectation that all `unknown` color values would probe as absent/unknown; they instead probe as reserved/GBR. [metadata-03](experiments/channelmap/metadata-03/results.json) tried numeric unspecified codepoint 2 and failed because this ProRes bitstream filter rejects it. The final run retains the supported named `unknown` control and asserts its actual reserved/GBR interpretation. These are fixture/control development failures, not observed losses in the final copied-video route.

## Reproduction and limits

From the repository root, run `python3 research/experiments/channelmap/wider_metadata.py research/experiments/channelmap/metadata-NEW` with a nonexistent evidence directory. Runtime media and logs require write access. No apps, desktop control, personal recordings or Git writes are involved.

This test uses a single generated ProRes MOV and FFmpeg's own demux/probe interpretation. It does not independently inspect all MOV atoms, test conflicting container/bitstream color metadata, HDR mastering/light-level metadata, drop-frame timecode, multiple timecode tracks, H.264/HEVC, Apple/NLE playback or calibrated color rendering. The existing B6 timing/edit-list evidence is separate; this metadata test does not extend it to new edit-list arrangements. No app acceptance or universal preservation guarantee follows.
