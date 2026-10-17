import Foundation

/// Builds hafas-rest-api v6 URLs. Paths and parameter names are taken from
/// hafas-rest-api 5.1.3 `routes/*.js`. `when` is sent as UNIX seconds, which
/// `parseWhen` accepts without timezone ambiguity.
public struct TransportRestEndpoint: Sendable {
    public static let bvg = TransportRestEndpoint(baseURL: URL(string: "https://v6.bvg.transport.rest")!)
    public static let vbb = TransportRestEndpoint(baseURL: URL(string: "https://v6.vbb.transport.rest")!)

    public var baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public enum WalkingSpeed: String, Sendable {
        case slow, normal, fast
    }

    public func departures(stop: StopID, when: Date, durationMinutes: Int, direction: StopID? = nil) -> URL {
        var items = window(when: when, durationMinutes: durationMinutes)
        if let direction { items.append(URLQueryItem(name: "direction", value: direction)) }
        return url(path: "/stops/\(Self.escape(stop))/departures", items)
    }

    public func arrivals(stop: StopID, when: Date, durationMinutes: Int) -> URL {
        url(path: "/stops/\(Self.escape(stop))/arrivals", window(when: when, durationMinutes: durationMinutes))
    }

    /// Stopovers are on by default for this route.
    public func trip(id: String) -> URL {
        url(path: "/trips/\(Self.escape(id))", [URLQueryItem(name: "remarks", value: "false")])
    }

    public func journeys(
        from: StopID,
        to: StopID,
        departure: Date,
        transferTimeMinutes: Int,
        walkingSpeed: WalkingSpeed = .fast,
        results: Int = 3,
        stopovers: Bool = false
    ) -> URL {
        url(path: "/journeys", [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "departure", value: Self.unixSeconds(departure)),
            URLQueryItem(name: "transferTime", value: String(transferTimeMinutes)),
            URLQueryItem(name: "walkingSpeed", value: walkingSpeed.rawValue),
            URLQueryItem(name: "results", value: String(results)),
            URLQueryItem(name: "stopovers", value: String(stopovers)),
            URLQueryItem(name: "remarks", value: "false"),
        ])
    }

    public func locations(query: String, results: Int = 8) -> URL {
        url(path: "/locations", [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "results", value: String(results)),
            URLQueryItem(name: "addresses", value: "false"),
            URLQueryItem(name: "poi", value: "false"),
        ])
    }

    public func nearby(latitude: Double, longitude: Double, results: Int = 8, distanceMeters: Int = 600) -> URL {
        url(path: "/locations/nearby", [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "results", value: String(results)),
            URLQueryItem(name: "distance", value: String(distanceMeters)),
        ])
    }

    public func url(for request: FetchRequest, when: Date, durationMinutes: Int) -> URL {
        switch request.kind {
        case .departures(let direction):
            departures(stop: request.stop, when: when, durationMinutes: durationMinutes, direction: direction)
        case .arrivals:
            arrivals(stop: request.stop, when: when, durationMinutes: durationMinutes)
        }
    }

    private func window(when: Date, durationMinutes: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "when", value: Self.unixSeconds(when)),
            URLQueryItem(name: "duration", value: String(durationMinutes)),
            URLQueryItem(name: "remarks", value: "false"),
        ]
    }

    private func url(path: String, _ items: [URLQueryItem]) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath = path
        components.queryItems = items
        return components.url!
    }

    private static func unixSeconds(_ date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }

    /// Trip IDs contain `|` and sometimes `#`; encode everything but unreserved characters.
    private static func escape(_ segment: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
    }
}
