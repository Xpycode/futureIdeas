import Foundation

/// EventKit-free copy of the event fields the matcher needs, so it stays testable.
public struct CalendarEventInfo: Hashable, Sendable {
    public var id: String
    public var calendarID: String
    public var title: String
    public var start: Date
    public var end: Date
    public var location: String?
    public var isAllDay: Bool

    public init(id: String, calendarID: String, title: String, start: Date, end: Date, location: String? = nil, isAllDay: Bool = false) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.isAllDay = isAllDay
    }
}

public struct CalendarMatchRules: Codable, Hashable, Sendable {
    public struct Keyword: Codable, Hashable, Sendable {
        public var keyword: String
        public var destinationID: UUID

        public init(keyword: String, destinationID: UUID) {
            self.keyword = keyword
            self.destinationID = destinationID
        }
    }

    /// Every event in these calendars is a shift at `calendarDestinationID`.
    public var calendarIDs: Set<String>
    public var calendarDestinationID: UUID?
    public var keywords: [Keyword]

    public init(calendarIDs: Set<String> = [], calendarDestinationID: UUID? = nil, keywords: [Keyword] = []) {
        self.calendarIDs = calendarIDs
        self.calendarDestinationID = calendarDestinationID
        self.keywords = keywords
    }
}

public enum ShiftMatcher {
    /// Keywords match as whole words, case-insensitively, so "DW" does not hit "Dwelling".
    /// A keyword match wins over a calendar match because it names a specific site.
    /// The event's own location is passed through for the caller to geocode.
    public static func shifts(from events: [CalendarEventInfo], rules: CalendarMatchRules) -> [Shift] {
        events.compactMap { event -> Shift? in
            guard !event.isAllDay else { return nil }
            let keywordHit = rules.keywords.first { containsWord($0.keyword, in: event.title) }
            let calendarHit = rules.calendarIDs.contains(event.calendarID)
            guard keywordHit != nil || calendarHit else { return nil }
            let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)
            return Shift(
                eventID: event.id,
                title: event.title,
                start: event.start,
                end: event.end,
                destinationID: keywordHit?.destinationID ?? rules.calendarDestinationID,
                locationText: (location?.isEmpty ?? true) ? nil : location
            )
        }
        .sorted { $0.start < $1.start }
    }

    static func containsWord(_ word: String, in text: String) -> Bool {
        let needle = word.lowercased()
        return text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .contains { $0 == needle }
    }
}

public enum Geo {
    public static func distanceMeters(_ a: Coordinates, _ b: Coordinates) -> Double? {
        guard let lat1 = a.latitude, let lon1 = a.longitude, let lat2 = b.latitude, let lon2 = b.longitude else { return nil }
        let radius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }

    public static func destinations(near location: Coordinates, _ destinations: [Destination], radiusMeters: Double = 300) -> Set<UUID> {
        Set(destinations.compactMap { destination -> UUID? in
            guard let coordinates = destination.coordinates,
                  let distance = distanceMeters(location, coordinates),
                  distance <= radiusMeters else { return nil }
            return destination.id
        })
    }
}
