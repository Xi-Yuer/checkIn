import Foundation
import XCTest
@testable import checkIn

final class ReviewPromptPolicyTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 10))!
    }

    func testDoesNotRequestBeforeSevenDays() {
        let policy = makePolicy(checkIns: 9)
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: now)!

        XCTAssertFalse(record(policy, createdAt: sixDaysAgo))
    }

    func testDoesNotRequestBeforeTenSuccessfulCheckIns() {
        let policy = makePolicy(checkIns: 8)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        XCTAssertFalse(record(policy, createdAt: sevenDaysAgo))
    }

    func testRequestsOnTenthSuccessfulCheckInAfterSevenDays() {
        let policy = makePolicy(checkIns: 9)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        XCTAssertTrue(record(policy, createdAt: sevenDaysAgo))
    }

    func testIncompleteGoalCountsButDoesNotRequestUntilLaterCompletion() {
        let policy = makePolicy(checkIns: 9)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        XCTAssertFalse(record(policy, completedDailyGoal: false, createdAt: sevenDaysAgo))
        XCTAssertTrue(record(policy, completedDailyGoal: true, createdAt: sevenDaysAgo))
    }

    func testRequestsAtMostOncePerVersionAndCanRequestInNewVersion() {
        let policy = makePolicy(checkIns: 9)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        XCTAssertTrue(record(policy, createdAt: sevenDaysAgo, version: "1.0"))
        XCTAssertFalse(record(policy, createdAt: sevenDaysAgo, version: "1.0"))
        XCTAssertTrue(record(policy, createdAt: sevenDaysAgo, version: "1.1"))
    }

    func testMissingHabitsVersionAndFutureCreationDateSafelySkip() {
        let policy = makePolicy(checkIns: 20)
        let future = calendar.date(byAdding: .day, value: 1, to: now)!

        XCTAssertFalse(record(policy, createdDates: [], version: "1.0"))
        XCTAssertFalse(record(policy, createdAt: future, version: "1.0"))
        XCTAssertFalse(record(policy, createdAt: now, version: nil))
        XCTAssertFalse(record(policy, createdAt: now, version: "  "))
    }

    func testUsesOldestHabitForUsageAge() {
        let policy = makePolicy(checkIns: 9)
        let oldHabit = calendar.date(byAdding: .day, value: -8, to: now)!
        let newHabit = calendar.date(byAdding: .day, value: -1, to: now)!

        XCTAssertTrue(record(policy, createdDates: [newHabit, oldHabit], version: "1.0"))
    }

    func testUserDefaultsPolicyPersistsCountAndRequestedVersion() {
        let suiteName = "ReviewPromptPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let oldHabit = calendar.date(byAdding: .day, value: -7, to: now)!

        for _ in 0..<9 {
            let policy = UserDefaultsReviewPromptPolicy(defaults: defaults, calendar: calendar)
            XCTAssertFalse(record(policy, createdAt: oldHabit, version: "1.0"))
        }

        let tenth = UserDefaultsReviewPromptPolicy(defaults: defaults, calendar: calendar)
        XCTAssertTrue(record(tenth, createdAt: oldHabit, version: "1.0"))

        let reloaded = UserDefaultsReviewPromptPolicy(defaults: defaults, calendar: calendar)
        XCTAssertFalse(record(reloaded, createdAt: oldHabit, version: "1.0"))
    }

    private func makePolicy(checkIns: Int) -> InMemoryReviewPromptPolicy {
        InMemoryReviewPromptPolicy(
            successfulManualCheckIns: checkIns,
            calendar: calendar
        )
    }

    private func record(
        _ policy: any ReviewPromptPolicy,
        completedDailyGoal: Bool = true,
        createdAt: Date,
        version: String? = "1.0"
    ) -> Bool {
        record(
            policy,
            completedDailyGoal: completedDailyGoal,
            createdDates: [createdAt],
            version: version
        )
    }

    private func record(
        _ policy: any ReviewPromptPolicy,
        completedDailyGoal: Bool = true,
        createdDates: [Date],
        version: String? = "1.0"
    ) -> Bool {
        policy.recordSuccessfulManualCheckIn(
            completedDailyGoal: completedDailyGoal,
            habitCreatedDates: createdDates,
            now: now,
            appVersion: version
        )
    }
}
