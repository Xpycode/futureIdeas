# Tile square

**Status:** Inbox · **Updated:** 2026-11-20

A summoned square, divided into a few rectangles of different sizes, as a shared way for MousePlus and QuickStatsPanel to show information and icons, where a click either runs an action or lets one rectangle take over the square.

## Problem and current workaround

MousePlus and QuickStatsPanel are both HUDs summoned at the cursor, and both now draw rings. MousePlus has its wedge menu with sub-items; QuickStatsPanel has the strip plus the gauge-ring prototype under owner review. A wedge is a good target to flick towards, but a poor container for text and numbers: QuickStatsPanel's ring work has already needed sub-rings, a More wedge and separate detail cards to fit its readings.

## Possible solution

```
┌───────────────┬───────────────┐                  ┌─────────────────────────┬───┐
│               │   MEM         │                  │ CPU 42%                 │MEM│
│   CPU  42%    ├───────────────┤    click CPU     │ user 30 · system 12     │DSK│
│               │   NET ↓ ↑     │   ──────────▶    │                         │NET│
├───────┬───────┼───────┬───────┤                  │ top processes           │BAT│
│  DSK  │  BAT  │  GPU  │  FAN  │                  │ …                       │GPU│
├───────┼───────┼───────┼───────┤                  │                         │ … │
│  PWR  │  TMP  │  LOAD │  UP   │                  └─────────────────────────┴───┘
└───────┴───────┴───────┴───────┘
```

- **Grid, not free layout.** A 4×4 grid with three tile sizes (1×1, 2×1, 2×2). One large, two wide and eight small tiles fill it exactly, which happens to be QuickStatsPanel's eleven stats.
- **No drawn borders.** Spacing separates the tiles; a tile's box appears only on hover or keyboard focus.
- **Two kinds of tile, visibly different.** An action tile runs and dismisses. An information tile expands. Because the boxes are invisible, the difference needs a small mark (for example a corner chevron on expanding tiles).
- **Expansion inside a fixed outer square.** The clicked tile grows to most of the square; the others shrink to a thin rail of icons along one edge rather than vanishing, so one click switches to another tile and Esc or a click on the rail returns. The outer square never moves or resizes.
- **Stable positions.** Size shows importance chosen in Settings, not the live value. Load is shown by colour, as the strip does today. Tiles that resize with their values would move under the cursor.

Smallest useful version: a third layout in QuickStatsPanel next to strip and ring, reusing its existing tiles and detail cards. It fits that app's [panel layouts spec](https://github.com/Xpycode/QuickStatsPanel/blob/main/specs/panel-layouts-and-appearance.md) rather than being a new product.

## Evidence and open questions

Known from the two repositories (read 2026-11-20, not built or run):

- MousePlus items already carry label, icon, action, colour and optional sub-items (`RingMenuItem`), so they map onto tiles without a new model.
- QuickStatsPanel already has per-stat tiles, detail cards, ordering and visibility settings.

Assumptions and open questions:

- **Is the square right for MousePlus at all?** Its ring is selected by direction, which works without looking. A square needs aiming. The square may suit only its information-heavy branches (running apps, window lists), with the ring kept as the top level.
- Does a rail of shrunken tiles read clearly at small sizes, or is a plain back control better?
- Shared package or two implementations? Extract shared layout and transition code only after it works in one app.
- Keyboard: arrow keys between tiles, Return to act or expand, Esc to step back then dismiss.

## Next investigation

Would the square show QuickStatsPanel's eleven stats more readably than the ring, without losing glance speed? Answer with a click-through mock (HTML or a SwiftUI preview with fixture values) of the 4×4 layout and the expand transition, judged by the owner next to the ring prototype. Worth pursuing if the owner prefers it for reading values; park it if the ring's E1 review settles the same need.

## Related material

- [QuickStatsPanel](https://github.com/Xpycode/QuickStatsPanel) — strip, ring prototype, panel layouts spec.
- [MousePlus](https://github.com/Xpycode/MousePlus) — ring menu and HUD customization.
