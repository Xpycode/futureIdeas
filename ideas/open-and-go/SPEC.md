# Handoff: Berlin ÖPNV "Open & Go" iOS App

> Owner handoff, saved 2026-10-17. Text below is as received. Corrections from the API check are in the [verification note](../../research/2026-10-17-open-and-go-api-verification.md); the main one is that a low `transferTime` cannot make HAFAS or MOTIS use *shorter* transfers than their built-in station times (see "HAFAS as a discovery candidate"). The draft [OpenAndGoCore](OpenAndGoCore/README.md) package implements the pure parts.

## Goal
A personal iOS app that shows relevant Berlin public transport info (BVG, S-Bahn, regional trains, all of VBB) **the moment it's opened**, with no taps needed. Setup can be as involved as needed; daily use must be zero-interaction.

Its key differentiator is **personal routing**. Official planners (BVG/VBB/HAFAS) use generic, conservative transfer times, so they hide tight-but-doable connections. The user knows their stations. The app chains legs using the user's own walk and transfer times, and so finds connections the official apps don't show.

> Real example: at Jannowitzbrücke, BVG suggested S5 plus a bus from a later station, while S7 was actually faster. BVG's assumed transfer time made the S7 connection look infeasible.

**Out of scope:** widgets, Live Activities, push notifications, backend server, App Store polish, a full on-device router. Personal use only.

---

## Core behavior on open
1. Show cached results from the last refresh immediately.
2. In parallel:
   - Get the location (reduced accuracy or last known fix is fine; it must be fast).
   - Read today's calendar events (EventKit).
   - Compute all relevant route variants (see "Personal routing") and nearby departures.
3. Rank and render, then update in place.
4. Refresh again every time the app returns to the foreground (`scenePhase == .active`), not just on cold launch.

### Ranking ("what's on top")
Priority, highest first:
1. **Upcoming shift**: a matching calendar event starting within ~2 h shows the best variant to work, with a **"leave by"** time.
2. **Shift just ended / near a work location**: show the best variant home.
3. **Current location**: nearby departures (closest stops, next ~20 min), each filtered by personal walk time ("leave in 3 min"; departures you can't make are hidden).
4. **Saved destinations**: fallback list underneath, always visible.

### Calendar matching (setup screen)
- The user picks either a specific calendar or title keywords (e.g. "DW", "rbb").
- If an event has a location/address, use it as the destination; otherwise use the saved work destination tied to that keyword.
- Needs **full** read access (`requestFullAccessToEvents`, iOS 17+). Write-only access is not enough.
- The app must work fully without calendar permission.

---

## Personal routing (core feature)

### Concepts
- **Destination**: e.g. "Work DW", "Home".
- **Route variant**: an ordered chain of legs defined by the user. Each destination can have several variants.
  - A **leg** is: board stop, line (e.g. `S7`), direction (a stop ID further along the line), alight stop.
  - Example: `Jannowitzbrücke --S7 (dir. Ahrensfelde)--> Ostkreuz --Bus 347--> …`
- **Personal times**:
  - `accessWalk`: minutes from an origin (home, work, or "current location", using a fixed value or walking distance) to the first stop.
  - `transferTime`: minutes at a station, keyed by station plus optionally (fromLine → toLine). A station default plus per-line-pair overrides covers cases like "S→S same platform 1 min, S→Bus 4 min".
  - `egressWalk`: minutes from the last stop to the destination.
  - Global fallback transfer time (e.g. 3 min) when nothing specific is set.

### Chaining algorithm (per variant)
Uses only existing endpoints of `v6.bvg.transport.rest` (all confirmed in the docs; verify the response shapes):
1. `earliestBoard = now + accessWalk`.
2. **Leg 1:** `GET /stops/{board}/departures?when={earliestBoard}&duration=30&direction={directionStopId}` and filter by `line.name`. Take the next N (e.g. 3) candidate departures.
3. **Arrival at the transfer stop:** prefer **one** call, `GET /stops/{alight}/arrivals?when=…&duration=…`, and match on `tripId`. Fall back to `GET /trips/{tripId}` (stopovers are included by default) if no match. Use realtime `when`, not `plannedWhen`.
4. **Next leg:** `readyAt = arrival + transferTime(station, fromLine, toLine)`. Then call `GET /stops/{transferStop}/departures?when={readyAt}&duration=30&direction=…`, filter by line, and take the first departure with `when >= readyAt`.
5. Repeat for further legs. `finalArrival = lastArrival + egressWalk`.
6. Output for each candidate: departure time from origin, "leave by", final arrival, every leg with its times, and the **slack** at each transfer (ready time vs. departure).

Then **rank all variants of a destination by `finalArrival`** and show the winner on top, with alternatives collapsible underneath.

Details to handle:
- Cancelled departures (`when == null` / `cancelled: true`) are skipped.
- Show a **tight-transfer indicator** when slack < 1 min. Optionally also show the "if missed" next connection.
- Batch requests: one departures call per stop per refresh, shared across variants that use the same stop. Cache with ETag.
- Request budget: ~3–5 calls per variant. The rate limit is 100 req/min (burst 200), which is fine for a handful of variants.

### HAFAS as a discovery candidate
`GET /journeys` supports **`transferTime`** (a minimum per transfer, default 0), `walkingSpeed` (`slow|normal|fast`), `transfers` (max), `stopovers`, and product filters. So:
- Always run one `/journeys` query per active destination with the user's global min transfer time and `walkingSpeed=fast`. Add its result to the ranking as a candidate labelled "BVG suggestion". This shows when a custom variant beats it, and vice versa.
- **"Discover" mode (setup):** run `/journeys` with low `transferTime` and `results=6` across a few departure times, and offer to save any new leg chains as variants. This seeds the user's variant list.

---

## Data sources

### Primary: `https://v6.bvg.transport.rest`
Community HAFAS wrapper; no key; realtime included; ETag/Cache-Control; CORS. Alternate host with the same shape: `v6.vbb.transport.rest`. It has had outages, so treat it as best-effort.

### Secondary (implement behind the same protocol later): Transitous / MOTIS 2
- `https://api.transitous.org/api/`, an open, volunteer-run router with an OpenAPI spec (MOTIS 2.x).
- Its `plan` endpoint supports a **minimum transfer time** and an **additional transfer time** per transfer. It also has `stoptimes` (departures/arrivals) and `trip` endpoints. Verify the names and versions against the current openapi.yaml.
- Usage policy: FOSS / non-profit only, a descriptive User-Agent with contact details, caching, light traffic, OpenStreetMap attribution. A personal app fits this.
- Value: a second, independent source for departures and journeys when transport.rest is down.

### Considered, not now: official VBB GTFS + GTFS-RT
- GTFS-RT: `https://production.gtfsrt.vbb.de/data`, CC-BY 4.0, no auth, 60 req/min, ETag.
- GTFS static is ~77 MB zipped and ~600 MB unzipped, far too heavy for on-device routing. The GTFS-RT full feed is also large.
- Possible future: a pre-filtered subset (only the user's stops/lines) for an offline schedule fallback.

### Prior art (for context)
No consumer app was found that offers **per-station** personal transfer times. SBB, for example, only offers +50% / double transfer time, and users have publicly asked for shorter, personalized ones. This feature is the app's niche.

---

## Tech stack
- Swift, SwiftUI, iOS 17+, Observation (`@Observable`), async/await, `TaskGroup` for parallel fetches.
- CoreLocation, EventKit.
- Persistence: SwiftData (destinations, variants, personal times) plus a Codable file cache for API responses.
- No third-party dependencies unless clearly justified.

## Suggested structure
```
App/
  OpenAndGoApp.swift
Features/
  Home/             HomeView, HomeViewModel (refresh orchestration)
  Setup/            destinations, variant editor (stop search, line+direction picker),
                    personal times editor, discover mode, calendar matching, permissions
Services/
  Transit/          TransitProvider protocol
                    TransportRestProvider, (later) TransitousProvider
                    models, ETag/response cache, request de-duplication per refresh
  Location/         LocationService (fast one-shot fix)
  Calendar/         ShiftService (EventKit → [Shift])
Domain/
  RouteChainer.swift   pure: (variant, personalTimes, departures/arrivals data, now) → [ChainedJourney]
  Ranker.swift         pure: (shifts, location, now, destinations, results) → sections
  PersonalTimes.swift  lookup with fallbacks: line-pair → station → global
```
`RouteChainer`, `Ranker` and `PersonalTimes` must be pure and unit-tested with recorded JSON fixtures. They are the core of the app.

## Milestones
1. **Data layer:** `TransitProvider` + transport.rest implementation (departures, arrivals, trip, journeys, locations, nearby), ETag cache, request de-dup. Record real JSON fixtures.
2. **RouteChainer + PersonalTimes** with unit tests on fixtures, including tight transfers, cancellations, missing trip match, and multi-leg chains.
3. **Home screen:** nearby departures with walk-time filtering, cached-first rendering, foreground refresh.
4. **Setup:** destinations, variant editor, personal times editor; ranking of variants; the HAFAS candidate alongside.
5. **Calendar ranking:** ShiftService, "leave by", calendar/keyword matching.
6. **Discover mode:** low-transferTime `/journeys` sweeps → "save as variant".
7. **Polish:** line colors (U/S/Tram/Bus), delays, tight-transfer and stale-data indicators, permission-denied states.
8. *(Optional)* TransitousProvider as a fallback.

## Acceptance criteria
- Cold launch shows cached content immediately and fresh data within ~2–3 s on a decent connection.
- Returning from background triggers a refresh automatically.
- Given fixtures where a custom variant (with a 2-min transfer) arrives earlier than the HAFAS suggestion, the custom variant ranks first, with correct times and slack.
- Personal transfer time lookup falls back from line-pair to station to global correctly.
- With a shift event starting in 90 min, the best variant to work with a correct "leave by" time is the top item.
- Denying location and/or calendar still yields a usable screen.
- Provider outage shows cached data with a stale label, with no crash and no blank screen.

## Open questions (ask the user)
- Work locations (DW, rbb sites) and home; the initial variants they already know (e.g. the S7 route from Jannowitzbrücke).
- Known personal transfer times at their regular stations.
- Buffer before shift start (default 10 min?).
- Bundle ID / project name.
