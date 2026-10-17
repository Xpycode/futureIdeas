import Foundation

public struct Destination: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case home, work, other
    }

    public var id: UUID
    public var name: String
    public var kind: Kind
    public var coordinates: Coordinates?

    public init(id: UUID = UUID(), name: String, kind: Kind, coordinates: Coordinates? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.coordinates = coordinates
    }
}

/// One user-defined ride: board `lineName` at `boardStop`, alight at `alightStop`.
/// `directionStop` is any stop further along the line; it is sent as the
/// server-side `direction` filter. The chainer additionally requires the trip
/// to reach `alightStop`, so a missing or wrong direction cannot produce a bad leg.
public struct LegSpec: Codable, Hashable, Sendable {
    public var boardStop: StopID
    public var lineName: String
    public var directionStop: StopID?
    public var alightStop: StopID
    public var boardName: String?
    public var alightName: String?

    public init(
        boardStop: StopID,
        lineName: String,
        directionStop: StopID? = nil,
        alightStop: StopID,
        boardName: String? = nil,
        alightName: String? = nil
    ) {
        self.boardStop = boardStop
        self.lineName = lineName
        self.directionStop = directionStop
        self.alightStop = alightStop
        self.boardName = boardName
        self.alightName = alightName
    }
}

public struct RouteVariant: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var destinationID: UUID
    public var legs: [LegSpec]

    public init(id: UUID = UUID(), name: String, destinationID: UUID, legs: [LegSpec]) {
        self.id = id
        self.name = name
        self.destinationID = destinationID
        self.legs = legs
    }
}
