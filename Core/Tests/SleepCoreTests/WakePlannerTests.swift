import XCTest
@testable import SleepCore

final class WakePlannerTests: XCTestCase {
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return value
    }
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    var deadline: Date { date("2026-10-06T07:00:00+09:00") }
    var now: Date { date("2026-10-05T23:00:00+09:00") }
    func history(days: Int = 3, stage: SleepStage = .core) -> [SleepSlice] {
        (1...days).map { day in
            let end = calendar.date(byAdding: .day, value: -day, to: deadline)!
            return SleepSlice(start: end.addingTimeInterval(-1800), end: end.addingTimeInterval(-60), stage: stage, source: "watch")
        }
    }
    func choose(_ samples: [SleepSlice]) -> WakeChoice {
        WakePlanner.choose(deadline: deadline, windowMinutes: 30, now: now, slices: samples, calendar: calendar)
    }
    func testMissingHistoryUsesDeadline() { XCTAssertEqual(choose([]).date, deadline) }
    func testTwoDaysAreInsufficient() { XCTAssertEqual(choose(history(days: 2)).date, deadline) }
    func testEqualScoresChooseLatestEligibleTime() {
        XCTAssertEqual(choose(history()).date, deadline.addingTimeInterval(-300))
        XCTAssertEqual(choose(history()).evidenceDays, 3)
    }
    func testDeepAndUnknownNeverCauseEarlyWake() {
        XCTAssertEqual(choose(history(stage: .deep)).date, deadline)
        XCTAssertEqual(choose(history(stage: .unspecified)).date, deadline)
    }
    func testDuplicateSamplesDoNotMultiplyDays() {
        let samples = history(days: 1)
        XCTAssertEqual(choose(samples + samples + samples).date, deadline)
    }
    func testConflictingStagesAreExcluded() {
        XCTAssertEqual(choose(history() + history(stage: .deep)).date, deadline)
    }
    func testMixedSourcesFallBack() {
        let other = SleepSlice(start: now, end: deadline, stage: .core, source: "other")
        XCTAssertEqual(choose(history() + [other]).date, deadline)
    }
    func testPastCandidatesAreNotSelected() {
        let result = WakePlanner.choose(deadline: deadline, windowMinutes: 30, now: deadline.addingTimeInterval(-120), slices: history(), calendar: calendar)
        XCTAssertEqual(result.date, deadline)
    }
    func testDurationMergesOverlapsAndExcludesAwake() {
        let start = now
        let samples = [
            SleepSlice(start: start, end: start.addingTimeInterval(600), stage: .core, source: "watch"),
            SleepSlice(start: start.addingTimeInterval(300), end: start.addingTimeInterval(900), stage: .deep, source: "watch"),
            SleepSlice(start: start.addingTimeInterval(900), end: start.addingTimeInterval(1200), stage: .awake, source: "watch")
        ]
        XCTAssertEqual(WakePlanner.sleepDuration(samples, from: start, to: start.addingTimeInterval(1800)), 900)
    }
    func testNextWakeRollsToTomorrow() {
        XCTAssertEqual(WakePlanner.nextWake(hour: 7, minute: 0, now: now, calendar: calendar), deadline)
    }
    func testInvalidClockIsRejected() {
        XCTAssertNil(WakePlanner.nextWake(hour: 25, minute: 0, now: now, calendar: calendar))
    }
    func testSpringDSTProducesFutureDate() {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let instant = date("2026-03-08T01:55:00-05:00")
        let wake = WakePlanner.nextWake(hour: 2, minute: 30, now: instant, calendar: cal)
        XCTAssertNotNil(wake)
        XCTAssertGreaterThan(wake!, instant)
    }
}
