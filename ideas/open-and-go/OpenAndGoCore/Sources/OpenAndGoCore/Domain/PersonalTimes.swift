import Foundation

/// A personal transfer time at one station. `nil` lines mean "any line", so
/// one type covers the station default, one-sided rules and exact line pairs.
public struct TransferRule: Codable, Hashable, Sendable {
    public var station: StopID
    public var fromLine: String?
    public var toLine: String?
    public var minutes: Double

    public init(station: StopID, fromLine: String? = nil, toLine: String? = nil, minutes: Double) {
        self.station = station
        self.fromLine = fromLine
        self.toLine = toLine
        self.minutes = minutes
    }

    /// 2 = exact line pair, 1 = one side given, 0 = station default.
    var specificity: Int {
        (fromLine == nil ? 0 : 1) + (toLine == nil ? 0 : 1)
    }

    func applies(at station: StopID, from: String, to: String) -> Bool {
        guard self.station == station else { return false }
        if let fromLine, LineName.normalized(fromLine) != LineName.normalized(from) { return false }
        if let toLine, LineName.normalized(toLine) != LineName.normalized(to) { return false }
        return true
    }
}

/// Minutes on foot between a place (home, a work site, …) and a stop.
public struct WalkTime: Codable, Hashable, Sendable {
    public var placeID: String
    public var stop: StopID
    public var minutes: Double

    public init(placeID: String, stop: StopID, minutes: Double) {
        self.placeID = placeID
        self.stop = stop
        self.minutes = minutes
    }
}

public struct PersonalTimes: Codable, Hashable, Sendable {
    public var globalTransferMinutes: Double
    public var transferRules: [TransferRule]
    public var walkTimes: [WalkTime]

    public init(globalTransferMinutes: Double = 3, transferRules: [TransferRule] = [], walkTimes: [WalkTime] = []) {
        self.globalTransferMinutes = globalTransferMinutes
        self.transferRules = transferRules
        self.walkTimes = walkTimes
    }

    /// Line pair → one-sided rule → station default → global fallback.
    /// Among equally specific rules the first one wins.
    public func transferTime(at station: StopID, from fromLine: String, to toLine: String) -> TimeInterval {
        let best = transferRules
            .filter { $0.applies(at: station, from: fromLine, to: toLine) }
            .enumerated()
            .max { lhs, rhs in
                lhs.element.specificity != rhs.element.specificity
                    ? lhs.element.specificity < rhs.element.specificity
                    : lhs.offset > rhs.offset
            }?
            .element
        return (best?.minutes ?? globalTransferMinutes) * 60
    }

    /// Walk between a place and a stop, in either direction (access or egress).
    public func walkTime(place placeID: String, stop: StopID) -> TimeInterval? {
        walkTimes.first { $0.placeID == placeID && $0.stop == stop }.map { $0.minutes * 60 }
    }
}
