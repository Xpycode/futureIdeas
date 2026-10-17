import Foundation

public enum JourneySource: Hashable, Sendable {
    case variant(UUID)
    /// The `/journeys` result, shown as "BVG suggestion".
    case hafas
}

public struct ChainedLeg: Hashable, Sendable {
    public var lineName: String
    public var tripID: String?
    public var boardStop: StopID?
    public var alightStop: StopID?
    public var departure: Date
    public var plannedDeparture: Date?
    public var arrival: Date
    public var plannedArrival: Date?
}

public struct TransferInfo: Hashable, Sendable {
    public var station: StopID?
    public var arrival: Date
    /// Arrival plus the personal transfer time.
    public var readyAt: Date
    public var departure: Date
    /// Time to spare after `readyAt`; negative means the transfer only works with luck.
    public var slack: TimeInterval
    public var isTight: Bool
}

public struct ChainedJourney: Hashable, Sendable {
    public var source: JourneySource
    public var label: String
    public var leaveBy: Date
    public var departure: Date
    public var legs: [ChainedLeg]
    public var transfers: [TransferInfo]
    /// Last arrival plus egress walk.
    public var finalArrival: Date

    public var isTight: Bool { transfers.contains { $0.isTight } }
    public var duration: TimeInterval { finalArrival.timeIntervalSince(leaveBy) }
}

public struct ChainResult: Sendable {
    public var journeys: [ChainedJourney]
    /// Trips whose arrival at an alighting stop was not in the snapshot. Fetch
    /// `/trips/{id}`, add them to the snapshot and chain again.
    public var missingTripIDs: Set<String>
}

/// Pure: (variant, personal times, snapshot, now) → candidate journeys.
public struct RouteChainer: Sendable {
    public var candidateCount: Int
    public var tightThreshold: TimeInterval

    public init(candidateCount: Int = 3, tightThreshold: TimeInterval = 60) {
        self.candidateCount = candidateCount
        self.tightThreshold = tightThreshold
    }

    public func chain(
        _ variant: RouteVariant,
        accessWalk: TimeInterval,
        egressWalk: TimeInterval,
        times: PersonalTimes,
        snapshot: TransitSnapshot,
        now: Date
    ) -> ChainResult {
        guard let firstLeg = variant.legs.first else {
            return ChainResult(journeys: [], missingTripIDs: [])
        }
        let earliestBoard = now.addingTimeInterval(accessWalk)
        var journeys: [ChainedJourney] = []
        var missing = Set<String>()

        for candidate in departures(at: firstLeg.boardStop, line: firstLeg.lineName, notBefore: earliestBoard, in: snapshot) {
            if journeys.count >= candidateCount { break }
            switch follow(variant, from: candidate, accessWalk: accessWalk, egressWalk: egressWalk, times: times, snapshot: snapshot) {
            case .journey(let journey): journeys.append(journey)
            case .missing(let tripID): missing.insert(tripID)
            case .infeasible: continue
            }
        }
        return ChainResult(journeys: journeys, missingTripIDs: missing)
    }

    private enum Outcome {
        case journey(ChainedJourney)
        case missing(String)
        case infeasible
    }

    private func follow(
        _ variant: RouteVariant,
        from first: StopEvent,
        accessWalk: TimeInterval,
        egressWalk: TimeInterval,
        times: PersonalTimes,
        snapshot: TransitSnapshot
    ) -> Outcome {
        var legs: [ChainedLeg] = []
        var transfers: [TransferInfo] = []
        var boarding = first

        for index in variant.legs.indices {
            let spec = variant.legs[index]
            guard let departure = boarding.effectiveTime else { return .infeasible }

            let arrival: Date
            let plannedArrival: Date?
            switch arrivalLookup(trip: boarding.tripId, after: departure, at: spec.alightStop, in: snapshot) {
            case .arrives(let time, let planned):
                arrival = time
                plannedArrival = planned
            case .notServed:
                return .infeasible
            case .unknown:
                return .missing(boarding.tripId)
            }
            legs.append(ChainedLeg(
                lineName: boarding.line?.name ?? spec.lineName,
                tripID: boarding.tripId,
                boardStop: spec.boardStop,
                alightStop: spec.alightStop,
                departure: departure,
                plannedDeparture: boarding.plannedWhen,
                arrival: arrival,
                plannedArrival: plannedArrival
            ))

            guard index + 1 < variant.legs.count else { break }
            let next = variant.legs[index + 1]
            let readyAt = arrival.addingTimeInterval(
                times.transferTime(at: spec.alightStop, from: spec.lineName, to: next.lineName)
            )
            // Skip departures that are known not to reach the next alighting stop
            // (wrong branch or direction); an unknown one is taken and resolved later.
            let connection = departures(at: next.boardStop, line: next.lineName, notBefore: readyAt, in: snapshot)
                .first { event in
                    guard let time = event.effectiveTime else { return false }
                    if case .notServed = arrivalLookup(trip: event.tripId, after: time, at: next.alightStop, in: snapshot) {
                        return false
                    }
                    return true
                }
            guard let connection, let connectionTime = connection.effectiveTime else { return .infeasible }
            let slack = connectionTime.timeIntervalSince(readyAt)
            transfers.append(TransferInfo(
                station: spec.alightStop,
                arrival: arrival,
                readyAt: readyAt,
                departure: connectionTime,
                slack: slack,
                isTight: slack < tightThreshold
            ))
            boarding = connection
        }

        guard let start = legs.first, let end = legs.last else { return .infeasible }
        return .journey(ChainedJourney(
            source: .variant(variant.id),
            label: variant.name,
            leaveBy: start.departure.addingTimeInterval(-accessWalk),
            departure: start.departure,
            legs: legs,
            transfers: transfers,
            finalArrival: end.arrival.addingTimeInterval(egressWalk)
        ))
    }

    private func departures(at stop: StopID, line: String, notBefore: Date, in snapshot: TransitSnapshot) -> [StopEvent] {
        (snapshot.departuresByStop[stop] ?? [])
            .filter { event in
                guard let time = event.effectiveTime else { return false }
                return LineName.matches(event.line, line) && time >= notBefore
            }
            .sorted { $0.effectiveTime! < $1.effectiveTime! }
    }

    private enum ArrivalLookup {
        case arrives(Date, planned: Date?)
        case notServed
        case unknown
    }

    /// Arrivals at the stop are preferred (one call per stop per refresh); the
    /// trip's stopovers are the fallback. Either source that lists the trip
    /// without a usable arrival there means the trip does not serve the stop.
    private func arrivalLookup(trip tripID: String, after departure: Date, at stop: StopID, in snapshot: TransitSnapshot) -> ArrivalLookup {
        if let arrivals = snapshot.arrivalsByStop[stop] {
            let matches = arrivals.filter { $0.tripId == tripID }
            if let hit = matches.first(where: { ($0.effectiveTime ?? .distantPast) > departure }) {
                return .arrives(hit.effectiveTime!, planned: hit.plannedWhen)
            }
            if !matches.isEmpty { return .notServed }
        }
        if let trip = snapshot.tripsByID[tripID], let stopovers = trip.stopovers {
            let hit = stopovers.first { stopover in
                guard stopover.stop.matches(stop), stopover.cancelled != true,
                      let time = stopover.arrival ?? stopover.plannedArrival else { return false }
                return time > departure
            }
            if let hit, let time = hit.arrival ?? hit.plannedArrival {
                return .arrives(time, planned: hit.plannedArrival)
            }
            return .notServed
        }
        return .unknown
    }
}

extension ChainedJourney {
    /// Wraps a `/journeys` result so it can be ranked next to custom variants.
    /// Transfer slack is measured against the user's own transfer times, which
    /// shows where the official suggestion is tighter or looser than needed.
    public init?(
        hafas journey: Journey,
        label: String = "BVG suggestion",
        accessWalk: TimeInterval = 0,
        egressWalk: TimeInterval = 0,
        times: PersonalTimes? = nil,
        tightThreshold: TimeInterval = 60
    ) {
        guard !journey.legs.contains(where: { $0.cancelled == true }),
              let departure = journey.legs.first?.departure,
              let arrival = journey.legs.last?.arrival else { return nil }

        var legs: [ChainedLeg] = []
        for leg in journey.legs where !leg.isWalking {
            guard let legDeparture = leg.departure, let legArrival = leg.arrival else { return nil }
            legs.append(ChainedLeg(
                lineName: leg.line?.name ?? "?",
                tripID: leg.tripId,
                boardStop: leg.origin.id,
                alightStop: leg.destination.id,
                departure: legDeparture,
                plannedDeparture: leg.plannedDeparture,
                arrival: legArrival,
                plannedArrival: leg.plannedArrival
            ))
        }

        var transfers: [TransferInfo] = []
        for (previous, next) in zip(legs, legs.dropFirst()) {
            var readyAt = previous.arrival
            if let times, let station = previous.alightStop {
                readyAt = readyAt.addingTimeInterval(times.transferTime(at: station, from: previous.lineName, to: next.lineName))
            }
            let slack = next.departure.timeIntervalSince(readyAt)
            transfers.append(TransferInfo(
                station: previous.alightStop,
                arrival: previous.arrival,
                readyAt: readyAt,
                departure: next.departure,
                slack: slack,
                isTight: slack < tightThreshold
            ))
        }

        self.init(
            source: .hafas,
            label: label,
            leaveBy: departure.addingTimeInterval(-accessWalk),
            departure: departure,
            legs: legs,
            transfers: transfers,
            finalArrival: arrival.addingTimeInterval(egressWalk)
        )
    }
}

public enum JourneyOrdering {
    /// Earliest arrival first; on equal arrival, the one that lets you leave later.
    /// Candidates that reach the same final trip collapse into the latest-leaving one.
    public static func ranked(_ journeys: [ChainedJourney]) -> [ChainedJourney] {
        let sorted = journeys.sorted {
            $0.finalArrival != $1.finalArrival ? $0.finalArrival < $1.finalArrival : $0.leaveBy > $1.leaveBy
        }
        var seenFinalTrips = Set<String>()
        return sorted.filter { journey in
            guard let tripID = journey.legs.last?.tripID else { return true }
            return seenFinalTrips.insert(tripID).inserted
        }
    }
}
