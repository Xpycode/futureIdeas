import XCTest
@testable import OpenAndGoCore

final class PersonalTimesTests: XCTestCase {
    let times = PersonalTimes(
        globalTransferMinutes: 3,
        transferRules: [
            TransferRule(station: "OK", minutes: 4),
            TransferRule(station: "OK", toLine: "347", minutes: 5),
            TransferRule(station: "OK", fromLine: "S7", toLine: "S5", minutes: 1),
            TransferRule(station: "OK", fromLine: "s 7", toLine: "S5", minutes: 9),
        ]
    )

    func testLinePairWinsAndFirstOfEqualSpecificityWins() {
        XCTAssertEqual(times.transferTime(at: "OK", from: "S7", to: "S5"), minutes(1))
    }

    func testOneSidedRuleBeatsStationDefault() {
        XCTAssertEqual(times.transferTime(at: "OK", from: "S7", to: "347"), minutes(5))
    }

    func testStationDefault() {
        XCTAssertEqual(times.transferTime(at: "OK", from: "S3", to: "M10"), minutes(4))
    }

    func testGlobalFallback() {
        XCTAssertEqual(times.transferTime(at: "Elsewhere", from: "S7", to: "S5"), minutes(3))
    }

    func testLineNamesAreNormalized() {
        XCTAssertEqual(times.transferTime(at: "OK", from: "s7", to: " s5 "), minutes(1))
    }

    func testWalkTimes() {
        let walks = PersonalTimes(walkTimes: [WalkTime(placeID: "home", stop: "JB", minutes: 4)])
        XCTAssertEqual(walks.walkTime(place: "home", stop: "JB"), minutes(4))
        XCTAssertNil(walks.walkTime(place: "work", stop: "JB"))
    }
}
