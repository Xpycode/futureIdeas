import Foundation
import XCTest
@testable import OpenAndGoCore

// The fixtures are synthetic: they follow the documented v6 response shape but
// were not recorded. Replace them with recorded responses (keep the scenario:
// S7 → Bus 347 via Ostkreuz) once transport.rest is reachable.

enum Stops {
    static let jannowitz = "900100004"
    static let ostkreuz = "900120003"
    static let warschauer = "900120008"
    static let workStop = "900120025"
    static let ahrensfelde = "900170004"
}

enum Fixtures {
    static func load<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
            "Missing fixture \(name).json"
        )
        return try TransportRestCoding.makeDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    /// Snapshot for the commute scenario, as one refresh would fetch it.
    static func commuteSnapshot() throws -> TransitSnapshot {
        var snapshot = TransitSnapshot()
        snapshot.addDepartures(try load(DeparturesResponse.self, "departures-jannowitzbruecke").departures, at: Stops.jannowitz)
        snapshot.addArrivals(try load(ArrivalsResponse.self, "arrivals-ostkreuz").arrivals, at: Stops.ostkreuz)
        snapshot.addDepartures(try load(DeparturesResponse.self, "departures-ostkreuz").departures, at: Stops.ostkreuz)
        snapshot.addArrivals(try load(ArrivalsResponse.self, "arrivals-workstop").arrivals, at: Stops.workStop)
        return snapshot
    }
}

/// 2026-10-17 08:00 Berlin (CEST); all fixture times are on this morning.
let fixtureNow = Date(timeIntervalSince1970: 1_792_216_800)

func at(_ hhmm: String) -> Date {
    TransportRestCoding.parseDate("2026-10-17T\(hhmm):00+02:00")!
}

func minutes(_ value: Double) -> TimeInterval { value * 60 }

let workDestinationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
let homeDestinationID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

let s7Then347 = RouteVariant(
    name: "S7 + 347",
    destinationID: workDestinationID,
    legs: [
        LegSpec(boardStop: Stops.jannowitz, lineName: "S7", directionStop: Stops.ahrensfelde, alightStop: Stops.ostkreuz),
        LegSpec(boardStop: Stops.ostkreuz, lineName: "347", alightStop: Stops.workStop),
    ]
)

let personalTimes = PersonalTimes(
    globalTransferMinutes: 3,
    transferRules: [TransferRule(station: Stops.ostkreuz, fromLine: "S7", toLine: "347", minutes: 2)]
)

func event(_ tripID: String, _ line: String, _ hhmm: String?, cancelled: Bool = false) -> StopEvent {
    StopEvent(
        tripId: tripID,
        when: hhmm.map(at),
        plannedWhen: hhmm.map(at) ?? at("08:00"),
        line: Line(name: line),
        cancelled: cancelled ? true : nil
    )
}
