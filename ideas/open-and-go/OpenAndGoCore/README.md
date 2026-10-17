# OpenAndGoCore (draft, not yet compiled)

Pure core of the [Open & Go spec](../SPEC.md): models for the transport.rest v6 responses, personal transfer times, the route chainer, the ranker and calendar matching. Written in a cloud session **without a Swift toolchain**, so expect a few compile fixes on first build. Nothing here touches UIKit, CoreLocation or EventKit.

Move this folder into the app repository when it exists; it does not belong in Future Ideas long term.

## First build at home

```sh
cd ideas/open-and-go/OpenAndGoCore
swift build && swift test
```

Then add it to the Xcode app project as a local package (File → Add Package Dependencies → Add Local).

## What is here

| File | Covers |
|---|---|
| `Transit/TransitModels.swift` | FPTF subset (`StopEvent`, `Trip`, `Journey`, …), date decoding, line-name normalization |
| `Transit/TransitSnapshot.swift` | One refresh's data; `FetchPlan` de-duplicates requests across variants |
| `Transit/TransportRestEndpoint.swift` | URL builder for departures, arrivals, trip, journeys, locations, nearby |
| `Domain/PersonalTimes.swift` | Transfer rules with fallback line pair → one side → station → global; walk times |
| `Domain/RouteChainer.swift` | Chaining, slack, tight flag, HAFAS journey conversion, journey ordering |
| `Domain/Ranker.swift` | Home sections: upcoming shift with leave-by, heading home, nearby, saved |
| `Domain/ShiftMatcher.swift` | Calendar/keyword matching without EventKit; distance helper |

## Design choices that differ from the spec

- **One window per stop, not per leg.** The spec queries the next leg's departures at `readyAt`. Here every needed stop is fetched once per refresh (`when=now`, e.g. `duration=90`), and the chainer works on that snapshot. This keeps the chainer pure, shares calls across variants, and needs about 2 calls per leg instead of dependent calls in sequence. Missing trip arrivals come back as `missingTripIDs`: fetch those trips, add them, chain again.
- **Direction is double-checked.** `directionStop` is sent as the server filter, but a departure only counts if its trip is known to reach the alighting stop (via arrivals there or trip stopovers).
- **Transfer rules are one type.** A rule with `fromLine`/`toLine` left nil acts as the station default or a one-sided rule, so "S→S 1 min, anything→bus 4 min" fit without extra tables.
- **Leave-by estimate.** When the shift is far beyond the fetched window, leave-by is the deadline minus the fastest door-to-door duration, flagged `isEstimate`.
- **Same last trip, one entry.** Candidates that end on the same final trip collapse into the one that leaves latest.

## Tests and fixtures

`Tests/OpenAndGoCoreTests/Fixtures/*.json` are **synthetic** but follow the documented response shape. The scenario: at 08:00, S7 from Jannowitzbrücke to Ostkreuz, then Bus 347, with a personal 2-min S7→347 transfer. That catches a bus 10 minutes earlier than the global 3-min rule, and beats the "BVG suggestion" (S5 + walk + M13). Replace the fixtures with recorded responses (commands in the [verification note](../../../research/2026-10-17-open-and-go-api-verification.md#recording-fixtures-at-home)) and keep the assertions.

## Not done yet

`TransitProvider` protocol with URLSession, ETag cache, and the 30-second response cache; the refresh orchestrator (`TaskGroup`); `LocationService`; EventKit `ShiftService`; SwiftData models; all UI.
