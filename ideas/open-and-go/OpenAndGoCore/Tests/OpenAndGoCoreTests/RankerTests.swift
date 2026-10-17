import XCTest
@testable import OpenAndGoCore

final class RankerTests: XCTestCase {
    let work = Destination(id: workDestinationID, name: "Work", kind: .work, coordinates: Coordinates(latitude: 52.49, longitude: 13.48))
    let home = Destination(id: homeDestinationID, name: "Home", kind: .home)

    /// Custom S7 + 347 candidates plus the HAFAS suggestion, as the orchestrator would collect them.
    func workJourneys() throws -> [ChainedJourney] {
        let chained = RouteChainer().chain(
            s7Then347, accessWalk: minutes(4), egressWalk: minutes(3),
            times: personalTimes, snapshot: try Fixtures.commuteSnapshot(), now: fixtureNow
        ).journeys
        let hafas = try XCTUnwrap(Fixtures.load(JourneysResponse.self, "journeys-hafas").journeys.first)
        let suggestion = try XCTUnwrap(ChainedJourney(hafas: hafas, accessWalk: minutes(4), egressWalk: minutes(3)))
        return chained + [suggestion]
    }

    func input(shifts: [Shift] = [], nearby: [NearbyDeparture] = [], near: Set<UUID> = []) throws -> RankingInput {
        let journeys = try workJourneys()
        return RankingInput(
            now: fixtureNow,
            shifts: shifts,
            destinations: [work, home],
            journeys: [workDestinationID: journeys],
            nearby: nearby,
            nearDestinationIDs: near
        )
    }

    func shift(start: String, end: String) -> Shift {
        Shift(eventID: "e1", title: "DW Frühdienst", start: at(start), end: at(end), destinationID: workDestinationID)
    }

    func testCustomVariantBeatsHafasSuggestion() throws {
        let options = Ranker.options(for: workDestinationID, try input())
        let best = try XCTUnwrap(options.best)
        XCTAssertEqual(best.source, .variant(s7Then347.id))
        XCTAssertEqual(best.finalArrival, at("08:33"))
        XCTAssertEqual(best.transfers.first?.slack, 0)
        XCTAssertTrue(options.alternatives.contains { $0.source == .hafas })
    }

    func testShiftInNinetyMinutesIsOnTopWithEstimatedLeaveBy() throws {
        let sections = Ranker.rank(try input(shifts: [shift(start: "09:30", end: "17:00")]))
        guard case .upcomingShift(let top, let advice, let options)? = sections.first else {
            return XCTFail("Expected upcoming shift on top, got \(sections)")
        }
        XCTAssertEqual(top.eventID, "e1")
        XCTAssertEqual(options.best?.source, .variant(s7Then347.id))
        // Deadline 09:20 (10 min buffer); fastest door-to-door is 31 min.
        let leave = try XCTUnwrap(advice)
        XCTAssertTrue(leave.isEstimate)
        XCTAssertEqual(leave.leaveBy, at("08:49"))
    }

    func testLeaveByUsesLatestConnectionNearDeadline() throws {
        let sections = Ranker.rank(try input(shifts: [shift(start: "08:55", end: "17:00")]))
        guard case .upcomingShift(_, let advice?, _)? = sections.first else { return XCTFail("No advice") }
        XCTAssertFalse(advice.isEstimate)
        XCTAssertFalse(advice.isLate)
        XCTAssertEqual(advice.leaveBy, at("08:12"))
        XCTAssertEqual(advice.journey.legs.first?.tripID, "1|S7|3")
    }

    func testLateWhenNothingMakesTheDeadline() throws {
        let sections = Ranker.rank(try input(shifts: [shift(start: "08:40", end: "17:00")]))
        guard case .upcomingShift(_, let advice?, _)? = sections.first else { return XCTFail("No advice") }
        XCTAssertTrue(advice.isLate)
        XCTAssertEqual(advice.journey.finalArrival, at("08:33"))
    }

    func testShiftBeyondLookaheadIsIgnored() throws {
        let sections = Ranker.rank(try input(shifts: [shift(start: "10:30", end: "17:00")]))
        guard case .saved? = sections.first else { return XCTFail("Expected saved destinations only") }
    }

    func testHeadingHomeAfterShiftEnded() throws {
        let sections = Ranker.rank(try input(shifts: [shift(start: "00:00", end: "07:30")]))
        guard case .headingHome(let options)? = sections.first else { return XCTFail("Expected heading home") }
        XCTAssertEqual(options.destinationID, homeDestinationID)
    }

    func testHeadingHomeWhenNearWork() throws {
        let near = Geo.destinations(near: Coordinates(latitude: 52.4905, longitude: 13.4805), [work, home])
        XCTAssertEqual(near, [workDestinationID])
        let sections = Ranker.rank(try input(near: near))
        guard case .headingHome? = sections.first else { return XCTFail("Expected heading home") }
    }

    func testWithoutCalendarOrLocationOnlySavedRemain() throws {
        let sections = Ranker.rank(try input())
        XCTAssertEqual(sections.count, 1)
        guard case .saved(let saved) = sections[0] else { return XCTFail("Expected saved") }
        XCTAssertEqual(saved.map(\.destinationID), [workDestinationID, homeDestinationID])
        XCTAssertNil(saved[1].best)
    }

    func testNearbyHidesDeparturesYouCannotMake() throws {
        let nearby = [
            NearbyDeparture(event: event("a", "M10", "08:03"), stopName: "Stop", walk: minutes(5)),
            NearbyDeparture(event: event("b", "M10", "08:10"), stopName: "Stop", walk: minutes(5)),
            NearbyDeparture(event: event("c", "U8", "08:06"), stopName: "U", walk: minutes(2)),
            NearbyDeparture(event: event("d", "M10", "08:25"), stopName: "Stop", walk: minutes(5)),
            NearbyDeparture(event: event("e", "M10", nil, cancelled: true), stopName: "Stop", walk: 0),
        ]
        let sections = Ranker.rank(try input(nearby: nearby))
        guard case .nearby(let items)? = sections.first else { return XCTFail("Expected nearby first") }
        XCTAssertEqual(items.map(\.departure.event.tripId), ["c", "b"])
        XCTAssertEqual(items.map(\.leaveIn), [minutes(4), minutes(5)])
    }
}

final class ShiftMatcherTests: XCTestCase {
    let rules = CalendarMatchRules(
        calendarIDs: ["shifts"],
        calendarDestinationID: homeDestinationID,
        keywords: [.init(keyword: "DW", destinationID: workDestinationID)]
    )

    func info(_ id: String, _ title: String, calendar: String = "personal", location: String? = nil, allDay: Bool = false) -> CalendarEventInfo {
        CalendarEventInfo(id: id, calendarID: calendar, title: title, start: at("0\(id):00"), end: at("17:00"), location: location, isAllDay: allDay)
    }

    func testMatching() {
        let shifts = ShiftMatcher.shifts(from: [
            info("1", "DW Frühdienst", location: "  Voltastraße 6, Berlin "),
            info("2", "Dwelling viewing"),
            info("3", "Anything", calendar: "shifts"),
            info("4", "DW", allDay: true),
            info("5", "dw/rbb Spätdienst", calendar: "shifts", location: " "),
        ], rules: rules)

        XCTAssertEqual(shifts.map(\.eventID), ["1", "3", "5"])
        XCTAssertEqual(shifts[0].locationText, "Voltastraße 6, Berlin")
        XCTAssertEqual(shifts[1].destinationID, homeDestinationID)
        XCTAssertEqual(shifts[2].destinationID, workDestinationID, "Keyword wins over calendar")
        XCTAssertNil(shifts[2].locationText)
    }
}
