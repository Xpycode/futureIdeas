# Open & Go: API shape verification (2026-10-17)

The handoff asks for the response shapes to be checked. The cloud session could not reach `v6.bvg.transport.rest`, `v6.vbb.transport.rest` or the VBB GTFS-RT host (proxy refused them), so no live responses were recorded. This check uses upstream sources instead:

- hafas-client 6 docs: `departures.md`, `trip.md`, `journeys.md` (GitHub `public-transport/hafas-client`, branch `main`)
- hafas-rest-api 5.1.3 route sources from npm (`routes/*.js`, `lib/parse.js`), which v6.bvg.transport.rest serves
- MOTIS `openapi.yaml` (GitHub `motis-project/motis`, branch `master`)

## Confirmed

| Topic | Finding | Source |
|---|---|---|
| Response wrappers | `/stops/{id}/departures` returns `{departures, realtimeDataUpdatedAt}`; `/stops/{id}/arrivals` returns `{arrivals, …}`; `/trips/{id}` returns `{trip, …}`; `/journeys` returns `{journeys, earlierRef, laterRef, …}` | `res.json(depsRes)` etc. in route sources; hafas-client 6 return values |
| `/locations/nearby` | Returns a bare array of stops, each with `distance` in meters | route source |
| Realtime | `when` already includes the delay; `plannedWhen` is the plan; `delay` is in seconds | hafas-client docs |
| Cancellations | Cancelled events have `cancelled: true` and `when: null` | hafas-client departures example |
| Departure params | `when`, `direction` (stop ID), `duration` (default 10), `results`, `linesOfStops`, `remarks`, `includeRelatedStations` (default **true**), `stopovers` | route source |
| `when` format | ISO string, UNIX seconds, or human-relative text | `parseWhen` |
| Trip | `/trips/{id}`: `stopovers` defaults to **true**; no line-name parameter in v6 | route source |
| Journeys | `transferTime` (minutes, default 0), `walkingSpeed` (`slow`/`normal`/`fast`), `transfers`, `stopovers`, `results` exist | route source |
| Caching | Departures/arrivals/trip send `Cache-Control` for 30 s; journeys for 60 s; `ETag` per docs | route source; bvg-rest readme |
| Rate limit | 100 requests/minute, no key | bvg-rest readme |
| MOTIS | Current endpoints are `/api/v6/plan`, `/api/v6/stoptimes`, `/api/v6/trip`; `plan` has `minTransferTime`, `additionalTransferTime`, `transferTimeFactor` | openapi.yaml |

## Corrections to the handoff

1. **Discover mode cannot find tighter transfers by lowering `transferTime`.** In HAFAS, `transferTime` is a *minimum* added on top of the station's own transfer times (default 0 already). In MOTIS, `minTransferTime` is also a minimum, and `transferTimeFactor` below 1.0 is not supported. Neither router can be asked to use less than its built-in station times. Discover mode still helps to collect leg chains (lines and transfer stations), but the personal chainer has to judge their feasibility. Sweeping several departure times and `results=6` still seeds alternatives.
2. **`includeRelatedStations` defaults to true.** Departures at one stop can include departures at related stops (for example, another part of the same interchange). The chainer filters by line and requires that the trip reaches the alighting stop, so this is harmless for chaining. It matters for the nearby list, where the walk time belongs to the stop actually served (use `departure.stop.id`).
3. **Transitous may lag the MOTIS master spec.** Check `https://api.transitous.org` for the API version actually deployed before writing the provider.

## Still unverified (record live fixtures)

- Stop ID format on v6.bvg.transport.rest (9-digit such as `900100004` vs. 12-digit VBB IDs). The fixtures use the 9-digit form.
- That `tripId` is identical across departures at one stop and arrivals at another for the same vehicle. The chainer relies on it, with `/trips/{id}` as a fallback.
- Whether `duration=90` on a busy stop is truncated without `results`.
- Exact `ETag` behavior (the docs mention it; the route sources only set `Cache-Control`).

## Recording fixtures at home

```sh
B=https://v6.bvg.transport.rest
curl -s "$B/locations?query=Jannowitzbr%C3%BCcke&results=1" > locations-jannowitz.json
curl -s "$B/stops/<ID>/departures?duration=90&remarks=false" > departures-<stop>.json
curl -s "$B/stops/<ID>/arrivals?duration=90&remarks=false" > arrivals-<stop>.json
curl -s "$B/trips/<URL-ENCODED-TRIP-ID>?remarks=false" > trip-<line>.json
curl -s "$B/journeys?from=<ID>&to=<ID>&transferTime=0&walkingSpeed=fast&results=6&remarks=false" > journeys.json
curl -sI "$B/stops/<ID>/departures" | grep -i -E 'etag|cache-control'
```
