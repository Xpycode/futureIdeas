import Foundation

/// Everything fetched during one refresh. `RouteChainer` reads only this, so it
/// stays pure: the orchestrator fetches, the chainer computes.
public struct TransitSnapshot: Sendable {
    public private(set) var departuresByStop: [StopID: [StopEvent]] = [:]
    public private(set) var arrivalsByStop: [StopID: [StopEvent]] = [:]
    public private(set) var tripsByID: [String: Trip] = [:]

    public init() {}

    public mutating func addDepartures(_ events: [StopEvent], at stop: StopID) {
        departuresByStop[stop] = Self.merge(departuresByStop[stop] ?? [], events)
    }

    public mutating func addArrivals(_ events: [StopEvent], at stop: StopID) {
        arrivalsByStop[stop] = Self.merge(arrivalsByStop[stop] ?? [], events)
    }

    public mutating func addTrip(_ trip: Trip) {
        tripsByID[trip.id] = trip
    }

    /// Requests for one stop with different `direction` filters overlap; keep one copy per trip.
    private static func merge(_ existing: [StopEvent], _ new: [StopEvent]) -> [StopEvent] {
        var seen = Set(existing.map(\.tripId))
        var merged = existing
        for event in new where !seen.contains(event.tripId) {
            seen.insert(event.tripId)
            merged.append(event)
        }
        return merged.sorted { ($0.effectiveTime ?? .distantFuture) < ($1.effectiveTime ?? .distantFuture) }
    }
}

/// One HTTP call. Identical requests from different variants collapse into one.
public struct FetchRequest: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case departures(direction: StopID?)
        case arrivals
    }

    public var stop: StopID
    public var kind: Kind
}

public enum FetchPlan {
    /// Departures at each boarding stop and arrivals at each alighting stop.
    /// All requests use the same `when`/`duration` window, so the chainer can
    /// work from a single snapshot instead of issuing dependent calls per leg.
    public static func requests(for variants: [RouteVariant]) -> Set<FetchRequest> {
        var requests = Set<FetchRequest>()
        for variant in variants {
            for leg in variant.legs {
                requests.insert(FetchRequest(stop: leg.boardStop, kind: .departures(direction: leg.directionStop)))
                requests.insert(FetchRequest(stop: leg.alightStop, kind: .arrivals))
            }
        }
        return requests
    }
}
