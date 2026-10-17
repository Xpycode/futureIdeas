import XCTest
@testable import OpenAndGoCore

final class RouteChainerTests: XCTestCase {
    let chainer = RouteChainer()

    func chain(_ variant: RouteVariant, _ snapshot: TransitSnapshot, times: PersonalTimes = personalTimes) -> ChainResult {
        chainer.chain(variant, accessWalk: minutes(4), egressWalk: minutes(3), times: times, snapshot: snapshot, now: fixtureNow)
    }

    func testFixturesDecode() throws {
        let departures = try Fixtures.load(DeparturesResponse.self, "departures-jannowitzbruecke").departures
        XCTAssertEqual(departures.count, 5)
        XCTAssertEqual(departures[1].when, at("08:06"))
        XCTAssertEqual(departures[1].plannedWhen, at("08:05"))
        XCTAssertEqual(departures[1].line?.name, "S7")
        XCTAssertTrue(departures[3].isCancelled)
        XCTAssertNil(departures[3].effectiveTime)

        let journeys = try Fixtures.load(JourneysResponse.self, "journeys-hafas").journeys
        XCTAssertEqual(journeys.first?.legs.count, 3)
        XCTAssertTrue(journeys.first?.legs[1].isWalking == true)
    }

    func testTwoLegChainWithPersonalTransferIsTight() throws {
        let result = chain(s7Then347, try Fixtures.commuteSnapshot())
        XCTAssertTrue(result.missingTripIDs.isEmpty)

        let first = try XCTUnwrap(result.journeys.first)
        XCTAssertEqual(first.leaveBy, at("08:02"))
        XCTAssertEqual(first.departure, at("08:06"))
        XCTAssertEqual(first.legs.map(\.tripID), ["1|S7|1", "1|347|1"])
        XCTAssertEqual(first.legs[0].arrival, at("08:13"))
        XCTAssertEqual(first.finalArrival, at("08:33"))

        let transfer = try XCTUnwrap(first.transfers.first)
        XCTAssertEqual(transfer.readyAt, at("08:15"))
        XCTAssertEqual(transfer.slack, 0)
        XCTAssertTrue(first.isTight)
    }

    func testCancelledDepartureIsSkipped() throws {
        let result = chain(s7Then347, try Fixtures.commuteSnapshot())
        XCTAssertEqual(result.journeys.map { $0.legs[0].tripID }, ["1|S7|1", "1|S7|3"])
    }

    func testGlobalTransferTimeMissesTheTightBus() throws {
        let result = chain(s7Then347, try Fixtures.commuteSnapshot(), times: PersonalTimes(globalTransferMinutes: 3))
        let first = try XCTUnwrap(result.journeys.first)
        XCTAssertEqual(first.legs[1].tripID, "1|347|2")
        XCTAssertEqual(first.transfers[0].slack, minutes(9))
        XCTAssertFalse(first.isTight)
        XCTAssertEqual(first.finalArrival, at("08:43"))
    }

    func testDeparturesBeforeAccessWalkAreIgnored() throws {
        let late = chainer.chain(
            s7Then347, accessWalk: minutes(7), egressWalk: 0,
            times: personalTimes, snapshot: try Fixtures.commuteSnapshot(), now: fixtureNow
        )
        XCTAssertEqual(late.journeys.first?.legs[0].tripID, "1|S7|3")
    }

    func testMissingArrivalIsReportedThenResolvedFromTrip() {
        let variant = RouteVariant(name: "U8", destinationID: workDestinationID, legs: [
            LegSpec(boardStop: "A", lineName: "U8", alightStop: "B"),
        ])
        var snapshot = TransitSnapshot()
        snapshot.addDepartures([event("u8-1", "U8", "08:10")], at: "A")
        snapshot.addArrivals([], at: "B")

        let first = chain(variant, snapshot)
        XCTAssertTrue(first.journeys.isEmpty)
        XCTAssertEqual(first.missingTripIDs, ["u8-1"])

        snapshot.addTrip(Trip(id: "u8-1", stopovers: [
            Stopover(stop: Stop(id: "A"), arrival: at("08:09")),
            Stopover(stop: Stop(id: "B-platform", station: StationRef(id: "B", name: nil)), arrival: at("08:17")),
        ]))
        let second = chain(variant, snapshot)
        XCTAssertTrue(second.missingTripIDs.isEmpty)
        XCTAssertEqual(second.journeys.first?.finalArrival, at("08:20"))
    }

    func testTripThatDoesNotReachAlightStopIsSkipped() {
        let variant = RouteVariant(name: "Bus", destinationID: workDestinationID, legs: [
            LegSpec(boardStop: "A", lineName: "M10", alightStop: "B"),
        ])
        var snapshot = TransitSnapshot()
        snapshot.addDepartures([event("wrong-way", "M10", "08:05"), event("right-way", "M10", "08:07")], at: "A")
        snapshot.addArrivals([event("right-way", "M10", "08:15")], at: "B")
        snapshot.addTrip(Trip(id: "wrong-way", stopovers: [Stopover(stop: Stop(id: "Z"), arrival: at("08:12"))]))

        let result = chain(variant, snapshot)
        XCTAssertTrue(result.missingTripIDs.isEmpty)
        XCTAssertEqual(result.journeys.map { $0.legs[0].tripID }, ["right-way"])
    }

    func testThreeLegChainSkipsConnectionThatDoesNotServeNextStop() throws {
        let variant = RouteVariant(name: "Three legs", destinationID: workDestinationID, legs: [
            LegSpec(boardStop: "A", lineName: "S7", alightStop: "B"),
            LegSpec(boardStop: "B", lineName: "U5", alightStop: "C"),
            LegSpec(boardStop: "C", lineName: "M5", alightStop: "D"),
        ])
        var snapshot = TransitSnapshot()
        snapshot.addDepartures([event("s7", "S7", "08:05")], at: "A")
        snapshot.addArrivals([event("s7", "S7", "08:10")], at: "B")
        snapshot.addDepartures([event("u5-short", "U5", "08:13"), event("u5", "U5", "08:15")], at: "B")
        snapshot.addArrivals([event("u5-short", "U5", nil, cancelled: true), event("u5", "U5", "08:20")], at: "C")
        snapshot.addDepartures([event("m5-early", "M5", "08:23"), event("m5", "M5", "08:24")], at: "C")
        snapshot.addArrivals([event("m5", "M5", "08:30")], at: "D")
        snapshot.addTrip(Trip(id: "m5-early", stopovers: []))

        let journey = try XCTUnwrap(chain(variant, snapshot).journeys.first)
        XCTAssertEqual(journey.legs.map(\.tripID), ["s7", "u5", "m5"])
        XCTAssertEqual(journey.transfers.map(\.slack), [minutes(2), minutes(1)])
        XCTAssertEqual(journey.finalArrival, at("08:33"))
    }

    func testNoConnectionInWindowYieldsNothing() {
        let variant = RouteVariant(name: "Dead end", destinationID: workDestinationID, legs: [
            LegSpec(boardStop: "A", lineName: "S7", alightStop: "B"),
            LegSpec(boardStop: "B", lineName: "U5", alightStop: "C"),
        ])
        var snapshot = TransitSnapshot()
        snapshot.addDepartures([event("s7", "S7", "08:05")], at: "A")
        snapshot.addArrivals([event("s7", "S7", "08:10")], at: "B")
        snapshot.addDepartures([event("u5", "U5", "08:11")], at: "B")

        let result = chain(variant, snapshot)
        XCTAssertTrue(result.journeys.isEmpty)
        XCTAssertTrue(result.missingTripIDs.isEmpty)
    }

    func testHafasJourneyConversion() throws {
        let journey = try XCTUnwrap(Fixtures.load(JourneysResponse.self, "journeys-hafas").journeys.first)
        let converted = try XCTUnwrap(ChainedJourney(hafas: journey, accessWalk: minutes(4), egressWalk: minutes(3), times: personalTimes))
        XCTAssertEqual(converted.source, .hafas)
        XCTAssertEqual(converted.leaveBy, at("08:00"))
        XCTAssertEqual(converted.finalArrival, at("08:45"))
        XCTAssertEqual(converted.legs.map(\.lineName), ["S5", "M13"])
        // Global 3 min applies at Warschauer Str.: ready 08:12, tram 08:17.
        XCTAssertEqual(converted.transfers.first?.slack, minutes(5))
    }

    func testFetchPlanDeduplicatesSharedStops() {
        let other = RouteVariant(name: "S7 only", destinationID: workDestinationID, legs: [
            LegSpec(boardStop: Stops.jannowitz, lineName: "S7", directionStop: Stops.ahrensfelde, alightStop: Stops.ostkreuz),
        ])
        XCTAssertEqual(FetchPlan.requests(for: [s7Then347, other]).count, 4)
    }

    func testEndpointEncodesTripIDs() {
        let url = TransportRestEndpoint.bvg.trip(id: "1|31431|28|86|17122017")
        XCTAssertEqual(url.absoluteString, "https://v6.bvg.transport.rest/trips/1%7C31431%7C28%7C86%7C17122017?remarks=false")
    }
}
