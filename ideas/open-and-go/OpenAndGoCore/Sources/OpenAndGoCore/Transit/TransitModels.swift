import Foundation

// Subset of the Friendly Public Transport Format (FPTF) as returned by
// hafas-rest-api v6 (v6.bvg.transport.rest / v6.vbb.transport.rest).
// Shapes follow hafas-client 6 docs and hafas-rest-api 5.1.3 route sources;
// replace the synthetic test fixtures with recorded responses to confirm them.

public typealias StopID = String

public struct Line: Codable, Hashable, Sendable {
    public var id: String?
    public var name: String?
    public var product: String?
    public var mode: String?

    public init(id: String? = nil, name: String?, product: String? = nil, mode: String? = nil) {
        self.id = id
        self.name = name
        self.product = product
        self.mode = mode
    }
}

public struct Coordinates: Codable, Hashable, Sendable {
    public var latitude: Double?
    public var longitude: Double?

    public init(latitude: Double?, longitude: Double?) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Parent station reference. FPTF nests a full station; only the ID is needed.
public struct StationRef: Codable, Hashable, Sendable {
    public var id: StopID
    public var name: String?
}

public struct Stop: Codable, Hashable, Sendable {
    public var type: String?
    public var id: StopID
    public var name: String?
    public var location: Coordinates?
    public var station: StationRef?
    /// Only present in `/locations/nearby` results, in meters.
    public var distance: Double?

    public init(id: StopID, name: String? = nil, location: Coordinates? = nil, station: StationRef? = nil) {
        self.id = id
        self.name = name
        self.location = location
        self.station = station
    }

    public func matches(_ other: StopID) -> Bool {
        id == other || station?.id == other
    }
}

/// A departure or an arrival; FPTF uses the same shape for both.
/// `when` already includes the realtime delay. Cancelled events have `when == nil`.
public struct StopEvent: Codable, Hashable, Sendable {
    public var tripId: String
    public var when: Date?
    public var plannedWhen: Date?
    public var delay: Int?
    public var platform: String?
    public var plannedPlatform: String?
    public var direction: String?
    public var provenance: String?
    public var line: Line?
    public var stop: Stop?
    public var cancelled: Bool?

    public init(
        tripId: String,
        when: Date?,
        plannedWhen: Date? = nil,
        delay: Int? = nil,
        line: Line?,
        stop: Stop? = nil,
        cancelled: Bool? = nil
    ) {
        self.tripId = tripId
        self.when = when
        self.plannedWhen = plannedWhen ?? when
        self.delay = delay
        self.line = line
        self.stop = stop
        self.cancelled = cancelled
    }

    public var isCancelled: Bool { cancelled == true }

    /// Realtime time, falling back to the plan when no realtime is known. Nil if cancelled.
    public var effectiveTime: Date? {
        isCancelled ? nil : (when ?? plannedWhen)
    }
}

public struct DeparturesResponse: Codable, Sendable {
    public var departures: [StopEvent]
    public var realtimeDataUpdatedAt: Int?
}

public struct ArrivalsResponse: Codable, Sendable {
    public var arrivals: [StopEvent]
    public var realtimeDataUpdatedAt: Int?
}

public struct Stopover: Codable, Hashable, Sendable {
    public var stop: Stop
    public var arrival: Date?
    public var plannedArrival: Date?
    public var departure: Date?
    public var plannedDeparture: Date?
    public var cancelled: Bool?

    public init(stop: Stop, arrival: Date?, plannedArrival: Date? = nil, cancelled: Bool? = nil) {
        self.stop = stop
        self.arrival = arrival
        self.plannedArrival = plannedArrival ?? arrival
        self.cancelled = cancelled
    }
}

public struct Trip: Codable, Hashable, Sendable {
    public var id: String
    public var line: Line?
    public var direction: String?
    public var stopovers: [Stopover]?
    public var cancelled: Bool?

    public init(id: String, line: Line? = nil, stopovers: [Stopover]?, cancelled: Bool? = nil) {
        self.id = id
        self.line = line
        self.stopovers = stopovers
        self.cancelled = cancelled
    }
}

public struct TripResponse: Codable, Sendable {
    public var trip: Trip
    public var realtimeDataUpdatedAt: Int?
}

/// Journey endpoints can be stops, addresses or POIs, so the ID is optional.
public struct Place: Codable, Hashable, Sendable {
    public var type: String?
    public var id: String?
    public var name: String?
    public var address: String?
    public var latitude: Double?
    public var longitude: Double?
    public var location: Coordinates?
    public var station: StationRef?

    public init(id: String?, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

public struct JourneyLeg: Codable, Hashable, Sendable {
    public var tripId: String?
    public var line: Line?
    public var direction: String?
    public var origin: Place
    public var destination: Place
    public var departure: Date?
    public var plannedDeparture: Date?
    public var arrival: Date?
    public var plannedArrival: Date?
    public var walking: Bool?
    public var cancelled: Bool?

    public init(
        tripId: String?,
        line: Line?,
        origin: Place,
        destination: Place,
        departure: Date?,
        arrival: Date?,
        walking: Bool? = nil,
        cancelled: Bool? = nil
    ) {
        self.tripId = tripId
        self.line = line
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.plannedDeparture = departure
        self.arrival = arrival
        self.plannedArrival = arrival
        self.walking = walking
        self.cancelled = cancelled
    }

    public var isWalking: Bool { walking == true || line == nil }
}

public struct Journey: Codable, Hashable, Sendable {
    public var legs: [JourneyLeg]
    public var refreshToken: String?

    public init(legs: [JourneyLeg], refreshToken: String? = nil) {
        self.legs = legs
        self.refreshToken = refreshToken
    }
}

public struct JourneysResponse: Codable, Sendable {
    public var journeys: [Journey]
    public var earlierRef: String?
    public var laterRef: String?
    public var realtimeDataUpdatedAt: Int?
}

// MARK: - Coding

public enum TransportRestCoding {
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = parseDate(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unparseable date: \(string)"
                )
            }
            return date
        }
        return decoder
    }

    /// For the on-disk response cache; round-trips through `makeDecoder()`.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Accepts `2017-12-17T19:32:00+01:00`, `...Z` and fractional seconds.
    public static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}

// MARK: - Line names

public enum LineName {
    /// "S 7", "s7" and "S7" compare equal.
    public static func normalized(_ name: String) -> String {
        name.uppercased().filter { !$0.isWhitespace }
    }

    public static func matches(_ line: Line?, _ name: String) -> Bool {
        guard let lineName = line?.name else { return false }
        return normalized(lineName) == normalized(name)
    }
}
