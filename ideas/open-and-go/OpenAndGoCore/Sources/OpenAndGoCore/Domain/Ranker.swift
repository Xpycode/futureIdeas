import Foundation

public struct Shift: Hashable, Sendable {
    public var eventID: String
    public var title: String
    public var start: Date
    public var end: Date
    /// Resolved by `ShiftMatcher`; nil when the event location still needs geocoding.
    public var destinationID: UUID?
    public var locationText: String?

    public init(eventID: String, title: String, start: Date, end: Date, destinationID: UUID?, locationText: String? = nil) {
        self.eventID = eventID
        self.title = title
        self.start = start
        self.end = end
        self.destinationID = destinationID
        self.locationText = locationText
    }
}

public struct NearbyDeparture: Hashable, Sendable {
    public var event: StopEvent
    public var stopName: String
    public var walk: TimeInterval

    public init(event: StopEvent, stopName: String, walk: TimeInterval) {
        self.event = event
        self.stopName = stopName
        self.walk = walk
    }
}

public struct NearbyItem: Hashable, Sendable {
    public var departure: NearbyDeparture
    public var leaveIn: TimeInterval
}

public struct LeaveByAdvice: Hashable, Sendable {
    public var leaveBy: Date
    public var journey: ChainedJourney
    /// True when no fetched connection is close to the deadline and `leaveBy`
    /// is derived from the fastest journey's duration instead.
    public var isEstimate: Bool
    /// True when even the best fetched connection arrives after the deadline.
    public var isLate: Bool
}

public struct DestinationOptions: Hashable, Sendable {
    public var destinationID: UUID
    public var best: ChainedJourney?
    public var alternatives: [ChainedJourney]
}

public enum HomeSection: Hashable, Sendable {
    case upcomingShift(Shift, LeaveByAdvice?, DestinationOptions)
    case headingHome(DestinationOptions)
    case nearby([NearbyItem])
    case saved([DestinationOptions])
}

public struct RankingConfig: Sendable {
    public var shiftLookahead: TimeInterval = 2 * 3600
    public var shiftEndedWindow: TimeInterval = 3600
    public var arrivalBuffer: TimeInterval = 10 * 60
    /// If the latest connection that makes the deadline arrives more than this
    /// early, the fetch window did not reach the deadline: estimate instead.
    public var estimateThreshold: TimeInterval = 15 * 60
    public var nearbyWindow: TimeInterval = 20 * 60
    public var nearbyLimit: Int = 12

    public init() {}
}

public struct RankingInput: Sendable {
    public var now: Date
    public var shifts: [Shift]
    public var destinations: [Destination]
    /// All candidates per destination, custom variants and the HAFAS suggestion alike.
    public var journeys: [UUID: [ChainedJourney]]
    public var nearby: [NearbyDeparture]
    /// Destinations the user is currently at, from `Geo.destinations(near:)`.
    public var nearDestinationIDs: Set<UUID>
    public var config: RankingConfig

    public init(
        now: Date,
        shifts: [Shift] = [],
        destinations: [Destination],
        journeys: [UUID: [ChainedJourney]],
        nearby: [NearbyDeparture] = [],
        nearDestinationIDs: Set<UUID> = [],
        config: RankingConfig = RankingConfig()
    ) {
        self.now = now
        self.shifts = shifts
        self.destinations = destinations
        self.journeys = journeys
        self.nearby = nearby
        self.nearDestinationIDs = nearDestinationIDs
        self.config = config
    }
}

/// Pure: decides what is on top. Order: upcoming shift, heading home, nearby, saved.
public enum Ranker {
    public static func rank(_ input: RankingInput) -> [HomeSection] {
        var sections: [HomeSection] = []
        let config = input.config

        let upcoming = input.shifts
            .filter { shift in
                shift.destinationID != nil
                    && shift.start > input.now
                    && shift.start.timeIntervalSince(input.now) <= config.shiftLookahead
            }
            .min { $0.start < $1.start }
        if let upcoming, let destinationID = upcoming.destinationID {
            let deadline = upcoming.start.addingTimeInterval(-config.arrivalBuffer)
            let advice = leaveBy(deadline: deadline, input.journeys[destinationID] ?? [], config)
            sections.append(.upcomingShift(upcoming, advice, options(for: destinationID, input)))
        }

        let workIDs = Set(input.destinations.filter { $0.kind == .work }.map(\.id))
        let shiftJustEnded = input.shifts.contains { shift in
            shift.end <= input.now && input.now.timeIntervalSince(shift.end) <= config.shiftEndedWindow
        }
        let atWork = !input.nearDestinationIDs.isDisjoint(with: workIDs)
        if upcoming == nil, shiftJustEnded || atWork,
           let home = input.destinations.first(where: { $0.kind == .home }) {
            sections.append(.headingHome(options(for: home.id, input)))
        }

        let nearby = input.nearby
            .compactMap { departure -> NearbyItem? in
                guard let time = departure.event.effectiveTime else { return nil }
                let untilDeparture = time.timeIntervalSince(input.now)
                let leaveIn = untilDeparture - departure.walk
                guard leaveIn >= 0, untilDeparture <= config.nearbyWindow else { return nil }
                return NearbyItem(departure: departure, leaveIn: leaveIn)
            }
            .sorted { $0.leaveIn < $1.leaveIn }
            .prefix(config.nearbyLimit)
        if !nearby.isEmpty {
            sections.append(.nearby(Array(nearby)))
        }

        sections.append(.saved(input.destinations.map { options(for: $0.id, input) }))
        return sections
    }

    static func options(for destinationID: UUID, _ input: RankingInput) -> DestinationOptions {
        let upcoming = (input.journeys[destinationID] ?? []).filter { $0.leaveBy >= input.now }
        let ranked = JourneyOrdering.ranked(upcoming)
        return DestinationOptions(destinationID: destinationID, best: ranked.first, alternatives: Array(ranked.dropFirst()))
    }

    /// Latest connection that still arrives by the deadline. When all fetched
    /// connections arrive much earlier (shift still far away), estimate from the
    /// fastest journey's door-to-door duration.
    static func leaveBy(deadline: Date, _ journeys: [ChainedJourney], _ config: RankingConfig) -> LeaveByAdvice? {
        guard let fastest = journeys.min(by: { $0.duration < $1.duration }) else { return nil }
        let onTime = journeys.filter { $0.finalArrival <= deadline }
        guard let latest = onTime.max(by: { $0.leaveBy < $1.leaveBy }) else {
            let earliest = journeys.min { $0.finalArrival < $1.finalArrival }!
            return LeaveByAdvice(leaveBy: earliest.leaveBy, journey: earliest, isEstimate: false, isLate: true)
        }
        if deadline.timeIntervalSince(latest.finalArrival) <= config.estimateThreshold {
            return LeaveByAdvice(leaveBy: latest.leaveBy, journey: latest, isEstimate: false, isLate: false)
        }
        return LeaveByAdvice(
            leaveBy: deadline.addingTimeInterval(-fastest.duration),
            journey: fastest,
            isEstimate: true,
            isLate: false
        )
    }
}
